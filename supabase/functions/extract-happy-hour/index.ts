// Supabase Edge Function: extract-happy-hour
// Fetches a bar's website and asks Claude to pull out happy hour info
// as structured JSON. Returns { found: bool, confidence, days[], notes }.
//
// Deploy via: Supabase Dashboard → Edge Functions → New Function → paste this.
// Secret required: ANTHROPIC_API_KEY

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY");

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
    // Turn block-level tags into newlines so text is readable
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
        { "name": string, "normal": number, "deal": number }
      ]
    }
  ]
}

Rules:
- Output MUST be valid JSON. Nothing else.
- If the page describes "Mon–Fri" or "weekdays", expand to one entry per day (mon, tue, wed, thu, fri).
- If times are like "3 PM" convert to "15:00". Always pad to HH:MM.
- If a menu item's normal price isn't listed but only the deal price is, estimate normal as 1.5× deal and round. Put a note.
- If no happy hour exists on the page, return { "found": false, "confidence": "high", "notes": "<why>", "days": [] }.
- Price numbers only — drop the "$".
- If the page has happy hour but no per-item menu, still return days with empty "items" arrays.
- Do not invent days. Only include days explicitly mentioned.`;

interface ClaudeResponse {
  content: Array<{ type: string; text?: string }>;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!ANTHROPIC_API_KEY) {
    return json({ error: "ANTHROPIC_API_KEY not configured" }, 500);
  }

  let body: { url?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const url = body.url?.trim();
  if (!url || !/^https?:\/\//i.test(url)) {
    return json({ error: "Provide a valid http(s) URL" }, 400);
  }

  // 1. Fetch the page
  let html: string;
  try {
    const res = await fetch(url, {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17 Safari/605.1.15",
      },
      signal: AbortSignal.timeout(15000),
    });
    if (!res.ok) {
      return json(
        { found: false, confidence: "high", notes: `Page returned ${res.status}`, days: [] },
        200,
      );
    }
    html = await res.text();
  } catch (err) {
    return json(
      {
        found: false,
        confidence: "high",
        notes: `Could not fetch page: ${err instanceof Error ? err.message : String(err)}`,
        days: [],
      },
      200,
    );
  }

  // 2. Reduce to readable text, cap length so we don't blow token budget
  let text = htmlToText(html);
  const MAX_CHARS = 12000; // ≈ 3k tokens
  if (text.length > MAX_CHARS) text = text.slice(0, MAX_CHARS);

  if (text.length < 100) {
    return json(
      { found: false, confidence: "high", notes: "Page had almost no readable text (probably SPA or image-only).", days: [] },
      200,
    );
  }

  // 3. Ask Claude
  let claudeJSON: string;
  try {
    const resp = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-haiku-4-5",
        max_tokens: 2000,
        system: EXTRACTION_PROMPT,
        messages: [
          {
            role: "user",
            content: `URL: ${url}\n\nPage text:\n---\n${text}\n---\n\nReturn JSON only.`,
          },
        ],
      }),
      signal: AbortSignal.timeout(30000),
    });
    if (!resp.ok) {
      const errText = await resp.text();
      return json({ error: `Claude API error: ${resp.status} ${errText}` }, 502);
    }
    const data: ClaudeResponse = await resp.json();
    const first = data.content?.find((c) => c.type === "text");
    if (!first?.text) return json({ error: "Empty Claude response" }, 502);
    claudeJSON = first.text.trim();
  } catch (err) {
    return json({ error: `Claude call failed: ${err instanceof Error ? err.message : String(err)}` }, 502);
  }

  // 4. Parse and return. Tolerate stray ```json fences just in case.
  const cleaned = claudeJSON.replace(/^```(?:json)?/i, "").replace(/```$/, "").trim();
  try {
    const parsed = JSON.parse(cleaned);
    return json(parsed, 200);
  } catch {
    return json(
      { error: "Claude returned non-JSON", raw: claudeJSON.slice(0, 500) },
      502,
    );
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}
