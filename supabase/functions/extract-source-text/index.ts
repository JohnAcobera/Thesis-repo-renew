import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import JSZip from "npm:jszip@3.10.1";
import { XMLParser } from "npm:fast-xml-parser@4.5.3";
import { getDocument } from "npm:pdfjs-dist@4.10.38/legacy/build/pdf.mjs";

// ============================================================
// SUPABASE EDGE FUNCTION: TEXT EXTRACTION (PDF / DOCX)
//
// Request:  POST { sessionToken, fileName, fileBase64, mimeType }
// Response: 200 { text }   |   4xx/5xx { error }
// The response shape is unchanged, so the frontend and the
// generate-quiz function keep working as-is.
// ============================================================

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

const PDF_MIME = "application/pdf";
const DOCX_MIME =
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document";

const maxFileBase64Length = 4_500_000;
const maxExtractedTextLength = 100_000;
const maxPdfPages = 200;
const maxDocumentXmlBytes = 25_000_000; // zip-bomb guard for word/document.xml

// An error that carries the HTTP status it should be returned with.
class ExtractionError extends Error {
  status: number;
  constructor(message: string, status = 422) {
    super(message);
    this.status = status;
  }
}

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

// Collapse runs of spaces, keep line breaks (max one blank line).
function normalizeText(text: string): string {
  return text
    .replace(/\r/g, "")
    .replace(/[ \t\u00a0]+/g, " ")
    .replace(/ ?\n ?/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

// ============================================================
// DOCX
// ============================================================

// With preserveOrder, a <w:t> element parses to: { t: [ { "#text": "..." } ] }
function textOf(node: unknown): string {
  if (!Array.isArray(node)) return "";
  return node
    .map((child) => (isRecord(child) ? String(child["#text"] ?? "") : ""))
    .join("");
}

function walkDocx(nodes: unknown, out: string[]): void {
  if (!Array.isArray(nodes)) return;

  for (const node of nodes) {
    if (!isRecord(node)) continue;

    for (const [key, child] of Object.entries(node)) {
      if (key === "t") {
        out.push(textOf(child)); // runs are joined with NO space (fixes split words)
      } else if (key === "p") {
        walkDocx(child, out);
        out.push("\n"); // paragraph break
      } else if (key === "tab" || key === "br" || key === "cr") {
        out.push(" ");
      } else if (key === "Fallback") {
        continue; // mc:Fallback duplicates the text of mc:Choice
      } else {
        walkDocx(child, out);
      }
    }
  }
}

async function extractDocxText(bytes: Uint8Array): Promise<string> {
  let archive: JSZip;
  try {
    archive = await JSZip.loadAsync(bytes);
  } catch {
    throw new ExtractionError("The Word document could not be opened.");
  }

  const documentFile = archive.file("word/document.xml");
  if (!documentFile) {
    throw new ExtractionError(
      "The Word document does not contain readable text.",
    );
  }

  // Check the declared uncompressed size BEFORE inflating (zip-bomb guard).
  const declaredSize = (documentFile as unknown as {
    _data?: { uncompressedSize?: number };
  })._data?.uncompressedSize;
  if (typeof declaredSize === "number" && declaredSize > maxDocumentXmlBytes) {
    throw new ExtractionError(
      "The Word document is too large to process.",
      413,
    );
  }

  const xml = await documentFile.async("string");
  if (xml.length > maxDocumentXmlBytes) {
    throw new ExtractionError(
      "The Word document is too large to process.",
      413,
    );
  }

  let parsed: unknown;
  try {
    parsed = new XMLParser({
      ignoreAttributes: true,
      removeNSPrefix: true,
      preserveOrder: true, // keeps tables/paragraphs in document order
      parseTagValue: false, // keep "2024" as text instead of a number
      trimValues: false, // keep meaningful spaces inside <w:t>
    }).parse(xml);
  } catch {
    throw new ExtractionError("The Word document text could not be read.");
  }

  const out: string[] = [];
  walkDocx(parsed, out);
  return normalizeText(out.join(""));
}

// ============================================================
// PDF
// ============================================================

async function extractPdfText(bytes: Uint8Array): Promise<string> {
  const loadingTask = getDocument({
    data: bytes,
    isEvalSupported: false,
    useSystemFonts: true,
    disableFontFace: true,
    verbosity: 0,
  });

  try {
    const pdf = await loadingTask.promise;

    if (pdf.numPages > maxPdfPages) {
      throw new ExtractionError(
        "The PDF has too many pages. Choose a file with 200 pages or fewer.",
        400,
      );
    }

    const pages: string[] = [];
    let total = 0;

    for (let pageNumber = 1; pageNumber <= pdf.numPages; pageNumber++) {
      const page = await pdf.getPage(pageNumber);
      const content = await page.getTextContent();

      let pageText = "";
      for (const item of content.items) {
        if (!("str" in item) || typeof item.str !== "string") continue;
        pageText += item.str;
        pageText += item.hasEOL ? "\n" : " ";
      }
      page.cleanup();

      const cleaned = normalizeText(pageText);
      if (cleaned.length > 0) {
        pages.push(cleaned);
        total += cleaned.length;
      }

      // Stop early instead of reading the rest of a huge document.
      if (total > maxExtractedTextLength) {
        throw new ExtractionError(
          "The extracted text is too long. Choose a shorter source file.",
          413,
        );
      }
    }

    return pages.join("\n\n"); // page breaks preserved as blank lines
  } catch (error) {
    if (error instanceof ExtractionError) throw error;
    throw new ExtractionError(
      "The PDF could not be read. Make sure it is not password-protected or damaged.",
    );
  } finally {
    try {
      await loadingTask.destroy();
    } catch {
      // ignore cleanup errors
    }
  }
}

// ============================================================
// FILE SIGNATURE CHECKS
// ============================================================

function looksLikePdf(bytes: Uint8Array): boolean {
  const head = new TextDecoder("latin1").decode(bytes.slice(0, 1024));
  return head.includes("%PDF-");
}

function looksLikeZip(bytes: Uint8Array): boolean {
  return bytes.length > 4 && bytes[0] === 0x50 && bytes[1] === 0x4b; // "PK"
}

// ============================================================
// HANDLER
// ============================================================

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(405, { error: "Use POST to extract document text." });
  }

  try {
    let requestBody: unknown;
    try {
      requestBody = await request.json();
    } catch {
      return jsonResponse(400, {
        error: "The request body must be valid JSON.",
      });
    }
    if (!isRecord(requestBody)) {
      return jsonResponse(400, {
        error: "The request body must be a JSON object.",
      });
    }

    const { sessionToken, fileName, fileBase64, mimeType } = requestBody;

    if (
      typeof sessionToken !== "string" ||
      sessionToken.length < 32 ||
      sessionToken.length > 256
    ) {
      return jsonResponse(401, {
        error: "Please log in to extract document text.",
      });
    }
    if (
      typeof fileName !== "string" ||
      fileName.trim().length === 0 ||
      fileName.length > 200
    ) {
      return jsonResponse(400, { error: "A source file name is required." });
    }
    if (
      typeof fileBase64 !== "string" ||
      fileBase64.length === 0 ||
      fileBase64.length > maxFileBase64Length
    ) {
      return jsonResponse(400, {
        error: "The source file is empty or too large.",
      });
    }

    const lowerName = fileName.toLowerCase();
    const isPdf = mimeType === PDF_MIME && lowerName.endsWith(".pdf");
    const isDocx = mimeType === DOCX_MIME && lowerName.endsWith(".docx");
    if (!isPdf && !isDocx) {
      return jsonResponse(400, { error: "Choose a PDF or DOCX source file." });
    }

    // ---------- Session ----------

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!supabaseUrl || !supabaseAnonKey) {
      return jsonResponse(500, {
        error: "Document extraction service configuration is incomplete.",
      });
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    try {
      const { data, error } = await supabase.rpc("verify_session", {
        p_session_token: sessionToken,
      });
      // `data === false` covers RPCs that return false instead of raising
      // (same check as generate-quiz). Adjust if verify_session differs.
      if (error || data === false) {
        return jsonResponse(401, {
          error: "Your session has expired. Please log in again.",
        });
      }
    } catch {
      return jsonResponse(503, {
        error: "Could not verify your login session. Please try again.",
      });
    }

    // ---------- Decode ----------

    let bytes: Uint8Array;
    try {
      // Tolerate a "data:...;base64," prefix and stray whitespace.
      const cleanBase64 = fileBase64
        .replace(/^data:[^,]*,/, "")
        .replace(/\s+/g, "");
      bytes = Uint8Array.from(
        atob(cleanBase64),
        (character) => character.charCodeAt(0),
      );
    } catch {
      return jsonResponse(400, { error: "The source file data is invalid." });
    }

    if (isPdf && !looksLikePdf(bytes)) {
      return jsonResponse(400, { error: "The file is not a valid PDF." });
    }
    if (isDocx && !looksLikeZip(bytes)) {
      return jsonResponse(400, {
        error: "The file is not a valid Word (.docx) document.",
      });
    }

    // ---------- Extract ----------

    let text: string;
    try {
      text = isPdf ? await extractPdfText(bytes) : await extractDocxText(bytes);
    } catch (error) {
      if (error instanceof ExtractionError) {
        return jsonResponse(error.status, { error: error.message });
      }
      console.error("Unexpected extraction error", error);
      return jsonResponse(422, {
        error: "The source file text could not be extracted.",
      });
    }

    if (text.length === 0) {
      return jsonResponse(422, {
        error:
          "No selectable text was found. Scanned PDFs need OCR before import.",
      });
    }
    if (text.length > maxExtractedTextLength) {
      return jsonResponse(413, {
        error: "The extracted text is too long. Choose a shorter source file.",
      });
    }

    return jsonResponse(200, { text });
  } catch (error) {
    // Without this, an unexpected throw returns a 500 with no CORS headers,
    // which the browser reports as a confusing CORS error.
    console.error("Unhandled error in extract-text", error);
    return jsonResponse(500, {
      error: "Something went wrong while extracting the document.",
    });
  }
});