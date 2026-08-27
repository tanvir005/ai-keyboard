import type { IncomingMessage, ServerResponse } from "node:http";

import { handleSuggest } from "../lib/handler.js";

/**
 * `POST /api/suggest` — the only endpoint.
 *
 *   { tool, text, options?, prompt? }  ->  { suggestions: [...], model }
 *
 * One endpoint rather than one per tool, because every tool is the same
 * request with a different instruction, and six routes that differ by a string
 * are five routes too many.
 *
 * ## This file is an adapter and nothing else
 * Vercel's Node runtime calls handlers with Node's `(req, res)` — not with the
 * web-standard `Request`, and not expecting a `Response` back. Getting that
 * wrong is what broke the first deployment: every request failed, and the ones
 * that did not fail hung for 300 seconds waiting for a `res.end()` that a
 * returned object was never going to produce.
 *
 * So the rules live in `lib/handler.ts`, which takes data and returns data.
 * Everything host-shaped is below, and it is short on purpose.
 */

export const config = { runtime: "nodejs" };

export default async function handler(
  request: IncomingMessage,
  response: ServerResponse
): Promise<void> {
  const { status, body } = await handleSuggest({
    method: request.method ?? "GET",
    key: header(request, "x-nib-key"),
    body: await readBody(request),
  });

  response.statusCode = status;
  response.setHeader("content-type", "application/json");
  response.end(JSON.stringify(body));
}

/** Node gives `string | string[] | undefined`; a repeated header is not one. */
function header(request: IncomingMessage, name: string): string | undefined {
  const value = request.headers[name];
  return Array.isArray(value) ? value[0] : value;
}

/**
 * Vercel parses JSON bodies onto `req.body` before the handler runs. A bare
 * Node server does not, so the stream is read when it hasn't been — which is
 * what lets the same handler run outside Vercel unchanged.
 */
async function readBody(request: IncomingMessage): Promise<unknown> {
  const parsed = (request as IncomingMessage & { body?: unknown }).body;
  if (parsed !== undefined) return parsed;

  const chunks: Buffer[] = [];
  for await (const chunk of request) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  return Buffer.concat(chunks).toString("utf8");
}
