import { providerFromEnvironment } from "./providers/index.js";
import type { Tool } from "./providers/types.js";

/**
 * The `/api/suggest` logic, with no host's vocabulary in it.
 *
 * ## Why this is not in `api/suggest.ts`
 * Because the first deployment failed here. That file was written to the
 * web-standard `Request`/`Response` signature; Vercel's Node runtime hands a
 * `IncomingMessage` instead, whose `headers` has no `.get()`. Every request
 * died — including `GET`, which touches nothing — and half of them hung for
 * 300 seconds because a returned `Response` object is not something that
 * runtime knows how to send.
 *
 * The lesson is not "use the other signature". It is that a host's calling
 * convention is a detail that should be able to be wrong in exactly one small
 * file. So the rules about what a valid request is now live here, in plain
 * data in and plain data out, and every host gets a short adapter:
 *
 *     Vercel      api/suggest.ts     (IncomingMessage/ServerResponse)
 *     Node/DO     one http server    (same, ~15 lines)
 *     Workers     Request -> Response
 *
 * Moving hosts is now a rewrite of the adapter, not of the endpoint.
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

export interface SuggestInput {
  method: string;
  /** The `x-nib-key` header, if the request carried one. */
  key: string | undefined;
  /**
   * The request body: either the raw string, or an object if the host already
   * parsed it. Vercel does parse it; a bare Node server does not.
   */
  body: unknown;
}

export interface SuggestOutput {
  status: number;
  body: Record<string, unknown>;
}

export async function handleSuggest(input: SuggestInput): Promise<SuggestOutput> {
  if (input.method.toUpperCase() !== "POST") {
    return { status: 405, body: { error: "Use POST." } };
  }

  // Not real security, and worth being honest about in the place somebody will
  // read it: this secret ships inside the app, so anybody willing to unpack an
  // IPA can read it. It stops an open endpoint being found and drained by
  // accident. It does not stop a person who means it. Device attestation is
  // what replaces this when there is something worth protecting.
  const expected = process.env.NIB_APP_SECRET;
  if (expected && input.key !== expected) {
    return { status: 401, body: { error: "Not authorised." } };
  }

  const body = parseBody(input.body);
  if (body === undefined) {
    return { status: 400, body: { error: "Body must be JSON." } };
  }

  const parsed = parseRequest(body);
  if ("error" in parsed) {
    return { status: 400, body: { error: parsed.error } };
  }

  try {
    const provider = providerFromEnvironment();
    const suggestions = await provider.suggest(parsed.request);

    // `model` is echoed back so a suggestion can always be traced to what
    // produced it. Comparing two providers is guesswork otherwise.
    return { status: 200, body: { suggestions, model: provider.model } };
  } catch (error) {
    // The message is logged and never returned: provider errors carry key
    // prefixes, account ids and internal URLs, and this response goes to a
    // keyboard on somebody's phone.
    console.error("suggest failed:", error);
    return { status: 502, body: { error: "Upstream failed." } };
  }
}

/** `undefined` means "not usable as JSON" — an empty body included. */
function parseBody(raw: unknown): unknown {
  if (typeof raw !== "string") return raw ?? undefined;
  if (raw.trim().length === 0) return undefined;
  try {
    return JSON.parse(raw);
  } catch {
    return undefined;
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
