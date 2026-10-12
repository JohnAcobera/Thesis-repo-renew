import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import JSZip from "npm:jszip@3.10.1";
import { XMLParser } from "npm:fast-xml-parser@4.5.3";
import { getDocument } from "npm:pdfjs-dist@4.10.38/legacy/build/pdf.mjs";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

const maxFileBase64Length = 4_500_000;
const maxExtractedTextLength = 100_000;
const maxPdfPages = 200;

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function collectWordText(value: unknown, words: string[]): void {
  if (Array.isArray(value)) {
    for (const item of value) collectWordText(item, words);
    return;
  }
  if (!isRecord(value)) return;

  for (const [key, child] of Object.entries(value)) {
    if (key === "t" && typeof child === "string" && child.length > 0) {
      words.push(child);
    } else {
      collectWordText(child, words);
    }
  }
}

async function extractDocxText(bytes: Uint8Array): Promise<string> {
  let archive: JSZip;
  try {
    archive = await JSZip.loadAsync(bytes);
  } catch {
    throw new Error("The Word document could not be opened.");
  }

  const documentFile = archive.file("word/document.xml");
  if (!documentFile) {
    throw new Error("The Word document does not contain readable text.");
  }

  const xml = await documentFile.async("string");
  let document: unknown;
  try {
    document = new XMLParser({
      ignoreAttributes: true,
      removeNSPrefix: true,
      textNodeName: "#text",
    }).parse(xml);
  } catch {
    throw new Error("The Word document text could not be read.");
  }

  const words: string[] = [];
  collectWordText(document, words);
  return words.join(" ").replace(/\s+/g, " ").trim();
}

async function extractPdfText(bytes: Uint8Array): Promise<string> {
  let pdf: Awaited<ReturnType<typeof getDocument>["promise"]> | undefined;
  try {
    pdf = await getDocument({
      data: bytes,
      isEvalSupported: false,
      useSystemFonts: true,
      disableFontFace: true,
      verbosity: 0,
    }).promise;
    if (pdf.numPages > maxPdfPages) {
      throw new Error(
        "The PDF has too many pages. Choose a file with 200 pages or fewer.",
      );
    }

    const pages: string[] = [];
    for (let pageNumber = 1; pageNumber <= pdf.numPages; pageNumber++) {
      const page = await pdf.getPage(pageNumber);
      const content = await page.getTextContent();
      const pageText = content.items
        .filter((item) => "str" in item && typeof item.str === "string")
        .map((item) => ("str" in item ? item.str : ""))
        .join(" ");
      pages.push(pageText);
    }
    return pages.join("\n").replace(/\s+/g, " ").trim();
  } catch (error) {
    if (error instanceof Error && error.message.startsWith("The PDF has")) {
      throw error;
    }
    throw new Error(
      "The PDF could not be read. Make sure it is not password-protected or damaged.",
    );
  } finally {
    await pdf?.destroy();
  }
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(405, { error: "Use POST to extract document text." });
  }

  let requestBody: unknown;
  try {
    requestBody = await request.json();
  } catch {
    return jsonResponse(400, { error: "The request body must be valid JSON." });
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
  if (
    (mimeType !== "application/pdf" &&
      mimeType !==
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document") ||
    (mimeType === "application/pdf" &&
      !fileName.toLowerCase().endsWith(".pdf")) ||
    (mimeType !== "application/pdf" &&
      !fileName.toLowerCase().endsWith(".docx"))
  ) {
    return jsonResponse(400, { error: "Choose a PDF or DOCX source file." });
  }

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
    const { error } = await supabase.rpc("verify_session", {
      p_session_token: sessionToken,
    });
    if (error) {
      return jsonResponse(401, {
        error: "Your session has expired. Please log in again.",
      });
    }
  } catch {
    return jsonResponse(503, {
      error: "Could not verify your login session. Please try again.",
    });
  }

  let bytes: Uint8Array;
  try {
    bytes = Uint8Array.from(
      atob(fileBase64),
      (character) => character.charCodeAt(0),
    );
  } catch {
    return jsonResponse(400, { error: "The source file data is invalid." });
  }

  let text: string;
  try {
    text = mimeType === "application/pdf"
      ? await extractPdfText(bytes)
      : await extractDocxText(bytes);
  } catch (error) {
    return jsonResponse(422, {
      error: error instanceof Error
        ? error.message
        : "The source file text could not be extracted.",
    });
  }

  if (text.trim().length === 0) {
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
});
