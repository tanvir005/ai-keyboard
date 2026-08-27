import { providerFromEnvironment } from "../lib/providers/index.js";
import type { Tool } from "../lib/providers/types.js";

/**
 * `POST /api/suggest` — the only endpoint.
 *
 * Body matches the contract `APIModels.swift` was written around, so the app
 * needs no new types:
 *
 *   { tool, text, options?, prompt? }  ->  { suggestions: [...] }
 *
 * One endpoint rather than one per tool, because every tool is the same
 * request with a different instruction, and six routes that differ by a string
 * are five routes too many.
 */

const TOOLS: readonly Tool[] = [
  "fix",
  "rewrite",
  "tone",
  "translate",
  "synonyms",
  "ask",
];

/** Longer than any scope the keyboard resolves, and short enough to bound cost. */
const MAX_TEXT = 2000;

export const config = { runtime: "nodejs" };

export default async function handler(request: Request): Promise<Response> {
  if (request.method !== "POST") {
    return json({ error: "Use POST." }, 405);
  }

  // Not real security, and worth being honest about in the place somebody will
  // read it: this secret ships inside the app, so anybody willing to unpack an
  // IPA can read it. It stops an open endpoint being found and drained by
  // accident. It does not stop a person who means it. Device attestation is
  // what replaces this when there is something worth protecting.
  const expected = process.env.NIB_APP_SECRET;
  if (expected && request.headers.get("x-nib-key") !== expected) {
    return json({ error: "Not authorised." }, 401);
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Body must be JSON." }, 400);
  }

  const parsed = parseRequest(body);
  if ("error" in parsed) return json({ error: parsed.error }, 400);

  try {
    const provider = providerFromEnvironment();
    const suggestions = await provider.suggest(parsed.request);

    // `model` is echoed back so a suggestion can always be traced to what
    // produced it. Comparing two providers is guesswork otherwise.
    return json({ suggestions, model: provider.model });
  } catch (error) {
    // The message is logged and never returned: provider errors carry key
    // prefixes, account ids and internal URLs, and this response goes to a
    // keyboard on somebody's phone.
    console.error("suggest failed:", error);
    return json({ error: "Upstream failed." }, 502);
  }
}

type ParsedRequest =
  | { request: { tool: Tool; text: string; options?: Record<string, string>; prompt?: string } }
  | { error: string };

function parseRequest(body: unknown): ParsedRequest {
  if (typeof body !== "object" || body === null) {
    return { error: "Body must be an object." };
  }

  const { tool, text, options, prompt } = body as Record<string, unknown>;

  if (typeof tool !== "string" || !TOOLS.includes(tool as Tool)) {
    return { error: `tool must be one of: ${TOOLS.join(", ")}.` };
  }

  if (typeof text !== "string" || text.trim().length === 0) {
    return { error: "text must be a non-empty string." };
  }

  if (text.length > MAX_TEXT) {
    return { error: `text must be ${MAX_TEXT} characters or fewer.` };
  }

  return {
    request: {
      tool: tool as Tool,
      text,
      options: isStringRecord(options) ? options : undefined,
      prompt: typeof prompt === "string" ? prompt : undefined,
    },
  };
}

function isStringRecord(value: unknown): value is Record<string, string> {
  return (
    typeof value === "object" &&
    value !== null &&
    Object.values(value).every((entry) => typeof entry === "string")
  );
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
