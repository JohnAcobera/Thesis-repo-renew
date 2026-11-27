import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const OTP_TTL_MINUTES = 5;
const OTP_TTL_MS = OTP_TTL_MINUTES * 60 * 1000;
const MAX_ATTEMPTS = 5;

// Per-email send limits (enforced atomically in the database).
const SEND_MAX_PER_WINDOW = 5;
const SEND_WINDOW_SECONDS = 60 * 60; // 1 hour
const SEND_COOLDOWN_SECONDS = 60;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const MAILJET_API_KEY = Deno.env.get("MAILJET_API_KEY");
const MAILJET_SECRET_KEY = Deno.env.get("MAILJET_SECRET_KEY");
const MAIL_FROM = Deno.env.get("MAIL_FROM");
const OTP_HMAC_SECRET = Deno.env.get("OTP_HMAC_SECRET");

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function normalizeEmail(value: unknown): string | null {
  if (typeof value !== "string") return null;

  const email = value.trim().toLowerCase();

  if (
    email.length > 254 ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  ) {
    return null;
  }

  return email;
}

function generateOTP(): string {
  const limit = Math.floor(0x100000000 / 1_000_000) * 1_000_000;
  const random = new Uint32Array(1);

  do {
    crypto.getRandomValues(random);
  } while (random[0] >= limit);

  return String(random[0] % 1_000_000).padStart(6, "0");
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function hashOTP(email: string, otp: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(OTP_HMAC_SECRET!),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${email}:${otp}`),
  );

  return bytesToHex(new Uint8Array(signature));
}

function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;

  let result = 0;

  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }

  return result === 0;
}

function parseSender(value: string): { Email: string; Name?: string } {
  const match = value.trim().match(/^(.*?)\s*<([^<>]+)>$/);

  if (match) {
    const name = match[1].trim().replace(/^["']|["']$/g, "");
    const email = match[2].trim();

    if (!normalizeEmail(email)) {
      throw new Error("MAIL_FROM contains an invalid email address.");
    }

    return name ? { Email: email, Name: name } : { Email: email };
  }

  const email = value.trim();

  if (!normalizeEmail(email)) {
    throw new Error("MAIL_FROM contains an invalid email address.");
  }

  return { Email: email };
}

async function sendMailjetEmail(
  recipient: string,
  otp: string,
): Promise<void> {
  const from = parseSender(MAIL_FROM!);
  const authorization = btoa(`${MAILJET_API_KEY}:${MAILJET_SECRET_KEY}`);

  const response = await fetch("https://api.mailjet.com/v3.1/send", {
    method: "POST",
    headers: {
      Authorization: `Basic ${authorization}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      Messages: [
        {
          From: from,
          To: [{ Email: recipient }],
          Subject: "Your QuizForge verification code is here",
          TextPart:
            `Your email verification code is ${otp}. ` +
            `It expires in ${OTP_TTL_MINUTES} minutes. ` +
            `If you did not request this code, ignore this email.`,
          HTMLPart: `
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <meta name="color-scheme" content="light dark">
            <meta name="supported-color-schemes" content="light dark">
            <title>Verify your email</title>
          </head>

          <body style="margin:0;padding:0;background-color:#ffffff;font-family:Arial,Helvetica,sans-serif;color:#f5f5f5;">

            <div style="display:none;max-height:0;overflow:hidden;opacity:0;">
              Your verification code is ${otp}. It expires in ${OTP_TTL_MINUTES} minutes.
            </div>

            <!-- Plain White Outer Background -->
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"
              bgcolor="#ffffff" style="width:100%;background-color:#ffffff;">
              <tr>
                <td align="center" style="padding:24px 12px;">

                  <!-- Main Card -->
                  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"
                    bgcolor="#1b1c20"
                    style="width:100%;max-width:440px;background-color:#1b1c20;border:1px solid #303136;border-radius:18px;overflow:hidden;">

                    <!-- Three-Tone Orange Gradient Header -->
                    <tr>
                      <td align="center" bgcolor="#FF7434"
                        style="padding:30px 20px 28px;
                        background-color:#FF7434;
                        background-image:linear-gradient(115deg,#D94718 0%,#FF7434 52%,#FFB080 100%);">

                        <h1 style="margin:17px 0 0;font-size:24px;line-height:1.3;font-weight:700;letter-spacing:-0.5px;color:#ffffff;">
                          You're almost there!
                        </h1>

                        <p style="margin:8px 0 0;font-size:14px;line-height:1.6;color:#ffffff;">
                          One last step to get you started.
                        </p>

                        <!-- Gradient Accent Line -->
                        <table role="presentation" cellspacing="0" cellpadding="0" border="0"
                          style="margin-top:19px;">
                          <tr>
                            <td style="width:36px;height:3px;background-color:#ffffff;border-radius:3px;font-size:0;line-height:0;">
                              &nbsp;
                            </td>
                          </tr>
                        </table>

                      </td>
                    </tr>

                    <!-- Main Content -->
                    <tr>
                      <td bgcolor="#1b1c20"
                        style="padding:26px 22px 26px;background-color:#1b1c20;">

                        <p style="margin:0 0 10px;font-size:16px;line-height:1.6;font-weight:700;color:#ffffff;">
                          Welcome aboard!
                        </p>

                        <p style="margin:0 0 23px;font-size:14px;line-height:1.8;color:#c2c2ca;">
                          Thanks for creating an account. Use the verification code below to confirm your email address.
                        </p>

                        <!-- OTP Panel -->
                        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"
                          bgcolor="#25262b"
                          style="width:100%;background-color:#25262b;border:1px solid #414047;border-radius:14px;">
                          <tr>
                            <td align="center" style="padding:23px 10px 22px;">

                              <p style="margin:0 0 13px;font-size:11px;line-height:1.5;font-weight:700;letter-spacing:2px;color:#d7b7a7;">
                                YOUR VERIFICATION CODE
                              </p>

                              <div style="font-family:'Courier New',monospace;font-size:30px;line-height:1.5;font-weight:bold;letter-spacing:5px;color:#FF8956;overflow-wrap:anywhere;">
                                ${otp}
                              </div>

                              <!-- Expiration Badge: No Emoji -->
                              <table role="presentation" cellspacing="0" cellpadding="0" border="0"
                                style="margin-top:14px;">
                                <tr>
                                  <td align="center" bgcolor="#38251f"
                                    style="background-color:#38251f;border:1px solid #75432f;border-radius:20px;padding:8px 14px;font-size:12px;line-height:1.4;font-weight:600;color:#FFB18D;">
                                    Expires in ${OTP_TTL_MINUTES} minutes
                                  </td>
                                </tr>
                              </table>

                            </td>
                          </tr>
                        </table>

                        <!-- Security Notice -->
                        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"
                          bgcolor="#222126"
                          style="width:100%;margin-top:20px;background-color:#222126;border:1px solid #39343a;border-radius:11px;">
                          <tr>
                            <td valign="top"
                              style="width:27px;padding:14px 0 14px 13px;font-size:17px;color:#FF8956;">
                              &#128274;
                            </td>
                            <td style="padding:14px 13px 14px 8px;">
                              <p style="margin:0 0 5px;font-size:13px;line-height:1.5;font-weight:700;color:#ffffff;">
                                Keep your code safe
                              </p>
                              <p style="margin:0;font-size:12px;line-height:1.7;color:#c2c2ca;">
                                Never share this code with anyone. Our team will never ask you for it.
                              </p>
                            </td>
                          </tr>
                        </table>

                        <p style="margin:21px 0 0;font-size:12px;line-height:1.8;color:#b4b4bd;">
                          Didn't request this code? You can safely ignore this email.
                        </p>

                      </td>
                    </tr>

                    <!-- Footer -->
                    <tr>
                      <td align="center" bgcolor="#17181b"
                        style="padding:19px 18px 22px;background-color:#17181b;border-top:1px solid #303136;">

                        <p style="margin:0;font-size:11px;line-height:1.7;color:#b4b4bd;">
                          Automated security email · Please do not reply
                        </p>

                        <p style="margin:7px 0 0;font-size:11px;line-height:1.6;color:#85858e;">
                          &copy; ${new Date().getFullYear()} All rights reserved.
                        </p>

                      </td>
                    </tr>

                  </table>

                  <!-- Outside Card Footer -->
                  <p style="margin:15px 8px 0;font-size:11px;line-height:1.6;color:#777780;text-align:center;">
                    Sent securely to your inbox.
                  </p>

                </td>
              </tr>
            </table>

          </body>
          </html>
          `,
        },
      ],
    }),
  });

  const result = await response.json().catch(() => null);

  if (!response.ok) {
    // Log provider details for debugging, but never log the OTP or API keys.
    console.error("Mailjet API request failed:", JSON.stringify(result));
    throw new Error("Mail provider rejected the email request.");
  }

  const messages = result?.Messages;

  if (
    !Array.isArray(messages) ||
    messages.length === 0 ||
    messages[0]?.Status !== "success"
  ) {
    console.error("Mailjet did not accept the message.");
    throw new Error("Mail provider did not accept the email.");
  }
}

// Checks both public.users and auth.users via the email_registered RPC.
async function isEmailRegistered(
  supabase: ReturnType<typeof createClient>,
  email: string,
): Promise<boolean> {
  const { data, error } = await supabase.rpc("email_registered", {
    p_email: email,
  });

  if (error) throw new Error(`Registration lookup failed: ${error.message}`);

  return data === true;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }

  if (
    !SUPABASE_URL ||
    !SUPABASE_SERVICE_ROLE_KEY ||
    !MAILJET_API_KEY ||
    !MAILJET_SECRET_KEY ||
    !MAIL_FROM ||
    !OTP_HMAC_SECRET
  ) {
    console.error("Required environment secrets are missing.");
    return json({ error: "Server configuration error." }, 500);
  }

  let body: Record<string, unknown>;

  try {
    const parsed = await req.json();

    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return json({ error: "Invalid JSON request." }, 400);
    }

    body = parsed as Record<string, unknown>;
  } catch {
    return json({ error: "Invalid JSON request." }, 400);
  }

  const action = body.action;
  const email = normalizeEmail(body.email);

  if (!email) {
    return json({ error: "Enter a valid email address." }, 400);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  try {
    // SEND OTP
    if (action === "send") {
      // Reject already-registered emails before any send slot is spent
      // and before any code is generated, stored or emailed.
      if (await isEmailRegistered(supabase, email)) {
        return json({
          error: "This email is already registered. Please log in instead.",
          code: "email_registered",
        }, 409);
      }

      // Atomic per-email cooldown + hourly cap. Must pass before any code is
      // generated, stored or emailed.
      const { data: reserved, error: reserveError } = await supabase.rpc(
        "reserve_otp_send",
        {
          p_email: email,
          p_max: SEND_MAX_PER_WINDOW,
          p_window_seconds: SEND_WINDOW_SECONDS,
          p_cooldown_seconds: SEND_COOLDOWN_SECONDS,
        },
      );

      if (reserveError) {
        console.error("Send reservation failed:", reserveError.message);
        return json({ error: "Could not process the request." }, 500);
      }

      const slot = Array.isArray(reserved) ? reserved[0] : reserved;

      if (!slot || slot.allowed !== true) {
        return json({
          error: slot?.reason === "hourly_limit"
            ? "Too many codes requested for this email. Try again later."
            : "Please wait before requesting another code.",
          retryAfterSeconds: slot?.retry_after_seconds ?? SEND_COOLDOWN_SECONDS,
        }, 429);
      }

      const otp = generateOTP();
      const otpHash = await hashOTP(email, otp);
      const now = new Date();
      const expiresAt = new Date(now.getTime() + OTP_TTL_MS);

      const { error: saveError } = await supabase
        .from("registration_otps")
        .upsert(
          {
            email,
            otp_hash: otpHash,
            expires_at: expiresAt.toISOString(),
            last_sent_at: now.toISOString(),
            attempts: 0,
          },
          { onConflict: "email" },
        );

      if (saveError) {
        console.error("OTP save failed:", saveError.message);
        return json({ error: "Could not process the request." }, 500);
      }

      try {
        await sendMailjetEmail(email, otp);
      } catch (error) {
        console.error(
          "Email sending failed:",
          error instanceof Error ? error.message : "Unknown provider error",
        );

        // Remove this OTP if it is still the one created by this request.
        await supabase
          .from("registration_otps")
          .delete()
          .eq("email", email)
          .eq("otp_hash", otpHash);

        return json({
          error: "Could not send the email. Check your sender configuration.",
        }, 502);
      }

      return json({
        success: true,
        message: "Verification code sent. Check your inbox and spam folder.",
        expiresInSeconds: OTP_TTL_MS / 1000,
      });
    }

    // VERIFY OTP AND CREATE THE SUPABASE AUTH USER
    if (action === "verify") {
      const otp = body.otp;
      const password = body.password;

      if (typeof otp !== "string" || !/^\d{6}$/.test(otp)) {
        return json({ error: "Enter the six-digit verification code." }, 400);
      }

      if (
        typeof password !== "string" ||
        password.length < 8 ||
        password.length > 128
      ) {
        return json({
          error: "Password must be between 8 and 128 characters.",
        }, 400);
      }

      // Re-check in case the email was registered between "send" and "verify".
      // Done before the attempt is consumed so a rejected request costs nothing.
      if (await isEmailRegistered(supabase, email)) {
        return json({
          error: "This email is already registered. Please log in instead.",
          code: "email_registered",
        }, 409);
      }

      // Atomically spend one attempt BEFORE comparing the code.
      // Parallel requests cannot exceed MAX_ATTEMPTS because the database
      // only increments while attempts < MAX_ATTEMPTS.
      const { data: spent, error: spendError } = await supabase.rpc(
        "consume_otp_attempt",
        { p_email: email, p_max: MAX_ATTEMPTS },
      );

      if (spendError) {
        console.error("OTP attempt update failed:", spendError.message);
        return json({ error: "Could not process the request." }, 500);
      }

      const record = Array.isArray(spent) ? spent[0] : spent;

      if (!record) {
        return json({
          error:
            "No active verification code or too many incorrect attempts. Request a new code.",
        }, 400);
      }

      if (Date.now() >= Date.parse(record.expires_at)) {
        await supabase
          .from("registration_otps")
          .delete()
          .eq("email", email)
          .eq("otp_hash", record.otp_hash);

        return json({
          error: "The verification code has expired. Request a new one.",
        }, 400);
      }

      const submittedHash = await hashOTP(email, otp);

      if (!constantTimeEqual(submittedHash, record.otp_hash)) {
        return json({
          error: "Incorrect verification code.",
          attemptsRemaining: Math.max(0, MAX_ATTEMPTS - record.attempts),
        }, 400);
      }

      // Create the account BEFORE burning the code, so a failure here (for
      // example a rejected password) lets the user retry with the same code.
      // Single use still holds: Auth allows only one account per email, so a
      // parallel request with the same code cannot create a second account.
      const { data: created, error: createError } =
        await supabase.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
        });

      if (createError || !created?.user) {
        const code = (createError as { code?: string } | null)?.code;
        const message = createError?.message ?? "No user returned";

        console.error("Account creation failed:", code ?? "", message);

        if (code === "email_exists" || code === "user_already_exists") {
          return json({
            error: "This email is already registered. Please log in instead.",
            code: "email_registered",
          }, 409);
        }

        if (code === "weak_password") {
          return json({
            error:
              "That password is too weak. Choose a stronger password and try again with the same code.",
            code: "weak_password",
          }, 400);
        }

        // Fallback for older supabase-js versions that don't expose codes.
        if (/already (been )?registered|already exists/i.test(message)) {
          return json({
            error: "This email is already registered. Please log in instead.",
            code: "email_registered",
          }, 409);
        }

        if (/password/i.test(message)) {
          return json({
            error:
              "That password was rejected. Choose a different password and try again with the same code.",
            code: "weak_password",
          }, 400);
        }

        return json({
          error: "Could not create the account. Please try again.",
        }, 500);
      }

      // The account exists, so burn the code now. A failure here is non-fatal:
      // the registered-email check blocks any reuse and the row expires anyway.
      const { error: cleanupError } = await supabase
        .from("registration_otps")
        .delete()
        .eq("email", email)
        .eq("otp_hash", record.otp_hash);

      if (cleanupError) {
        console.error("OTP cleanup failed:", cleanupError.message);
      }

      return json({
        success: true,
        message: "Email verified and account created successfully.",
        userId: created.user.id,
        email: created.user.email,
      });
    }

    return json({
      error: 'Invalid action. Use "send" or "verify".',
    }, 400);
  } catch (error) {
    console.error(
      "Unexpected registration OTP error:",
      error instanceof Error ? error.message : "Unknown error",
    );

    return json({ error: "An unexpected server error occurred." }, 500);
  }
});