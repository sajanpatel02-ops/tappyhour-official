// Supabase Edge Function: extract-happy-hour
// Fetches a bar's website and asks Claude to pull out happy hour info
// as structured JSON. Returns { found: bool, confidence, days[], notes }.
//
// Retry ladder:
//   1. Plain fetch            — free, works for server-rendered pages
//   2. Browserless /content   — rendered HTML after JS (unblocks SPAs, 403s)
//   3. Browserless /screenshot → Claude vision (unblocks image-only menus)
//
// Secrets required:
//   ANTHROPIC_API_KEY   — Claude
//   BROWSERLESS_TOKEN   — optional; without it we skip to step 3... wait, no
//                         — without it we skip steps 2 & 3 entirely.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY");
const BROWSERLESS_TOKEN = Deno.env.get("BROWSERLESS_TOKEN");
const BROWSERLESS_BASE = "https://production-sfo.browserless.io";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Strip HTML down to something resembling readable text. Keeps headings,
// paragraphs, lists. Drops scripts/styles/nav chrome.
function htmlToText(html: string): string {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<noscript[\s\S]*?<\/noscript>/gi, " ")
    .replace(/<!--[\s\S]*?-->/g, " ")
    .replace(/<(\/)?(p|div|li|ul|ol|br|h[1-6]|section|article|header|footer)[^>]*>/gi, "\n")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&#39;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/[ \t]+/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

const EXTRACTION_PROMPT = `You are extracting happy hour information from a bar/restaurant webpage. Return STRICT JSON matching this exact schema — no prose, no markdown, just JSON:

{
  "found": boolean,                  // true if any happy hour info is present
  "confidence": "high" | "medium" | "low",
  "notes": string,                   // 1-2 sentence human summary. If not found, explain why.
  "days": [
    {
      "day": "mon" | "tue" | "wed" | "thu" | "fri" | "sat" | "sun",
      "start": "HH:MM",              // 24-hour, e.g. "15:00"
      "end": "HH:MM",                // 24-hour, e.g. "18:00"
      "headline": string,            // short summary like "Half-off wine by the glass"
      "items": [
        // EITHER numeric: { "name": string, "normal": number, "deal": number }
        // OR labeled:   { "name": string, "label": string }     // for vague deals
        { "name": string, "normal": number | null, "deal": number | null, "label": string | null }
      ]
    }
  ]
}

Rules:
- Output MUST be valid JSON. Nothing else.
- If the page describes "Mon–Fri" or "weekdays", expand to one entry per day (mon, tue, wed, thu, fri).
- If times are like "3 PM" convert to "15:00". Always pad to HH:MM.
- Every item MUST be EITHER numeric OR labeled. An item with normal=null AND deal=null AND label=null is INVALID — never output one.
- For each menu item, pick ONE format:
  * NUMERIC — BOTH a specific normal price AND a specific deal price are stated (e.g. "Martini $16, now $8"). Fill "normal" and "deal" as numbers; set "label" to null.
  * LABELED — anything else: percentages, ranges, "1/2 off", single-price-only, vague deals. Fill "label" with a short human-readable deal string; set "normal" AND "deal" to null.
- NEVER invent numbers. If a normal price is not explicitly stated, you MUST use LABELED format — do NOT guess a normal price.
- If only a deal price is given (e.g. "$5 drafts", "$6 wine"), that is LABELED: label="$5", normal=null, deal=null. Do not put the $5 in "deal" — "deal" only fills when you ALSO have a "normal".
- Label examples: "50% off", "1/2 off", "$6-$12", "$5", "25% off", "2-for-1", "buy one get one".
- Examples of correct items:
  * "1/2 off reserve wine" → { "name": "Reserve wine", "normal": null, "deal": null, "label": "1/2 off" }
  * "$6-$12 small bites" → { "name": "Small bites", "normal": null, "deal": null, "label": "$6-$12" }
  * "$5 drafts" → { "name": "Drafts", "normal": null, "deal": null, "label": "$5" }
  * "Martini normally $16, happy hour $8" → { "name": "Martini", "normal": 16, "deal": 8, "label": null }
- If no happy hour exists on the page, return { "found": false, "confidence": "high", "notes": "<why>", "days": [] }.
- Price numbers only — drop the "$".
- If the page has happy hour but no per-item menu, still return days with empty "items" arrays.
- Do not invent days. Only include days explicitly mentioned.
- LIMIT to at most 8 items per day — pick the most representative/headline deals. If there are many similar items (e.g. 10 different bottled beers at the same price), collapse them into one entry like { "name": "Domestic bottles", ... }.
- Item "name" MUST be ≤ 28 characters. Use short category labels like "Domestic bottles", "Well drinks", "House wine", "Drafts", "IPAs". DO NOT list brand names in parentheses. Never exceed 28 chars.`;

interface ClaudeResponse {
  content: Array<{ type: string; text?: string }>;
}

// Fetch the URL directly. Returns the response (nullable on failure).
async function plainFetch(url: string): Promise<Response | null> {
  try {
    const r = await fetch(url, {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
        "Accept":
          "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
        "Accept-Encoding": "gzip, deflate, br",
        "Sec-Fetch-Dest": "document",
        "Sec-Fetch-Mode": "navigate",
        "Sec-Fetch-Site": "none",
        "Upgrade-Insecure-Requests": "1",
      },
      redirect: "follow",
      signal: AbortSignal.timeout(15000),
    });
    return r.ok ? r : null;
  } catch {
    return null;
  }
}

// Ask Browserless for the rendered HTML after JS runs.
async function browserlessContent(url: string): Promise<string | null> {
  if (!BROWSERLESS_TOKEN) return null;
  try {
    const r = await fetch(`${BROWSERLESS_BASE}/content?token=${BROWSERLESS_TOKEN}`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        url,
        waitForTimeout: 2500,   // let JS settle
        gotoOptions: { waitUntil: "networkidle2", timeout: 20000 },
      }),
      signal: AbortSignal.timeout(30000),
    });
    if (!r.ok) {
      console.warn("Browserless /content failed:", r.status, await r.text());
      return null;
    }
    return await r.text();
  } catch (err) {
    console.warn("Browserless /content error:", err);
    return null;
  }
}

// Ask Browserless for a full-page screenshot as a base64 PNG.
async function browserlessScreenshot(url: string): Promise<string | null> {
  if (!BROWSERLESS_TOKEN) return null;
  try {
    const r = await fetch(`${BROWSERLESS_BASE}/screenshot?token=${BROWSERLESS_TOKEN}`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        url,
        options: { fullPage: true, type: "png" },
        gotoOptions: { waitUntil: "networkidle2", timeout: 20000 },
      }),
      signal: AbortSignal.timeout(35000),
    });
    if (!r.ok) {
      console.warn("Browserless /screenshot failed:", r.status, await r.text());
      return null;
    }
    const buf = await r.arrayBuffer();
    return arrayBufferToBase64(buf);
  } catch (err) {
    console.warn("Browserless /screenshot error:", err);
    return null;
  }
}

// Send content to Claude and return parsed JSON (or null).
// deno-lint-ignore no-explicit-any
async function askClaude(userContent: any, tag: string): Promise<any | null> {
  let claudeJSON: string;
  try {
    const resp = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY!,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-haiku-4-5",
        max_tokens: 8000,
        system: EXTRACTION_PROMPT,
        messages: [{ role: "user", content: userContent }],
      }),
      signal: AbortSignal.timeout(60000),
    });
    if (!resp.ok) {
      console.error(`Claude error (${tag}):`, resp.status, await resp.text());
      return null;
    }
    const data: ClaudeResponse = await resp.json();
    const first = data.content?.find((c) => c.type === "text");
    if (!first?.text) return null;
    claudeJSON = first.text.trim();
  } catch (err) {
    console.error(`Claude call failed (${tag}):`, err);
    return null;
  }

  const stripped = claudeJSON
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();
  // deno-lint-ignore no-explicit-any
  const tryParse = (s: string): any | null => {
    try { return JSON.parse(s); } catch { return null; }
  };
  let parsed = tryParse(stripped);
  if (!parsed) {
    const lo = stripped.indexOf("{");
    const hi = stripped.lastIndexOf("}");
    if (lo !== -1 && hi > lo) parsed = tryParse(stripped.slice(lo, hi + 1));
  }
  if (parsed) console.log(`Claude parsed (${tag}):`, JSON.stringify(parsed));
  else console.error(`Claude non-JSON (${tag}):`, claudeJSON);
  return parsed;
}

// Run Claude against extracted HTML text (shared by plain + browserless paths).
// deno-lint-ignore no-explicit-any
async function extractFromHtml(html: string, url: string, tag: string): Promise<any | null> {
  let text = htmlToText(html);
  const MAX_CHARS = 12000;
  if (text.length > MAX_CHARS) text = text.slice(0, MAX_CHARS);
  if (text.length < 100) return null;
  const userContent = `URL: ${url}\n\nPage text:\n---\n${text}\n---\n\nReturn JSON only.`;
  return await askClaude(userContent, tag);
}

// Gate: call is_app_admin() using the caller's JWT. If the RPC returns true,
// the user is an admin. Any other result (false, 401, network error) denies.
async function callerIsAdmin(authHeader: string | null): Promise<boolean> {
  if (!authHeader) return false;
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) {
    console.error("SUPABASE_URL or SUPABASE_ANON_KEY missing");
    return false;
  }
  try {
    const r = await fetch(`${supabaseUrl}/rest/v1/rpc/is_app_admin`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "apikey": anonKey,
        "authorization": authHeader,
      },
      body: "{}",
      signal: AbortSignal.timeout(5000),
    });
    if (!r.ok) return false;
    const result = await r.json();
    return result === true;
  } catch (err) {
    console.error("is_app_admin check failed:", err);
    return false;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (!ANTHROPIC_API_KEY) {
    return json({ error: "ANTHROPIC_API_KEY not configured" }, 500);
  }

  // Only admins can trigger extraction — regular signed-in users have no
  // reason to call this, and it's the most expensive endpoint.
  if (!(await callerIsAdmin(req.headers.get("authorization")))) {
    return json({ error: "Forbidden" }, 403);
  }

  let body: { url?: string };
  try { body = await req.json(); }
  catch { return json({ error: "Invalid JSON body" }, 400); }

  const url = body.url?.trim();
  if (!url || !/^https?:\/\//i.test(url)) {
    return json({ error: "Provide a valid http(s) URL" }, 400);
  }

  // PDFs get their own fast path — Claude reads them directly.
  const isPDFUrl = url.toLowerCase().endsWith(".pdf");

  // ── Attempt 1: plain fetch ──────────────────────────────────────────
  const resp = await plainFetch(url);
  if (resp) {
    const ct = (resp.headers.get("content-type") || "").toLowerCase();
    const isPDF = ct.includes("application/pdf") || isPDFUrl;
    if (isPDF) {
      const buf = await resp.arrayBuffer();
      const base64 = arrayBufferToBase64(buf);
      const userContent = [
        { type: "document", source: { type: "base64", media_type: "application/pdf", data: base64 } },
        { type: "text", text: `URL: ${url}\n\nExtract happy hour info from this PDF. Return JSON only.` },
      ];
      const parsed = await askClaude(userContent, "pdf");
      if (parsed) return json(parsed, 200);
    } else {
      const html = await resp.text();
      const parsed = await extractFromHtml(html, url, "plain");
      if (parsed?.found === true) return json(parsed, 200);
      console.log("Plain fetch: found=false, escalating to Browserless");
    }
  } else {
    console.log("Plain fetch failed; escalating to Browserless");
  }

  // ── Attempt 2: Browserless rendered HTML ───────────────────────────
  if (BROWSERLESS_TOKEN && !isPDFUrl) {
    const rendered = await browserlessContent(url);
    if (rendered) {
      const parsed = await extractFromHtml(rendered, url, "browserless-html");
      if (parsed?.found === true) return json(parsed, 200);
      console.log("Browserless HTML: found=false, escalating to screenshot");
    }
  }

  // ── Attempt 3: Browserless screenshot + Claude vision ──────────────
  if (BROWSERLESS_TOKEN && !isPDFUrl) {
    const shot = await browserlessScreenshot(url);
    if (shot) {
      const userContent = [
        { type: "image", source: { type: "base64", media_type: "image/png", data: shot } },
        { type: "text", text: `URL: ${url}\n\nExtract happy hour info from this screenshot of the page. Return JSON only.` },
      ];
      const parsed = await askClaude(userContent, "browserless-shot");
      if (parsed) return json(parsed, 200);
    }
  }

  return json(
    {
      found: false,
      confidence: "high",
      notes: "Couldn't extract happy hour info from that page (tried plain fetch, rendered HTML, and screenshot).",
      days: [],
    },
    200,
  );
});

function arrayBufferToBase64(buf: ArrayBuffer): string {
  const bytes = new Uint8Array(buf);
  const CHUNK = 0x8000;
  let binary = "";
  for (let i = 0; i < bytes.length; i += CHUNK) {
    binary += String.fromCharCode(...bytes.subarray(i, i + CHUNK));
  }
  return btoa(binary);
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}
