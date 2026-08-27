import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import http from "node:http";
import { rmSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

/**
 * Runs the endpoint over a real HTTP server and checks what comes back.
 *
 * ## Why this exists
 * `tsc --noEmit` passed on a version of this endpoint that failed on every
 * single request in production. It was written to the web-standard
 * `Request`/`Response` signature; the runtime hands Node's `(req, res)`. Types
 * cannot catch that — the handler's own signature was what was wrong, so it
 * typechecked against itself perfectly.
 *
 * Nothing here needs a key or a network: every case is one the endpoint must
 * answer on its own, before any provider is contacted. Those are exactly the
 * cases that were broken, which is the point.
 */

const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, ".smoke");
const PORT = 8788;

console.log("compiling…");
rmSync(out, { recursive: true, force: true });
// The compiler is invoked through node rather than npx: `npx.cmd` cannot be
// spawned directly on Windows, and this repo is developed on one.
execFileSync(
  process.execPath,
  [join(here, "node_modules", "typescript", "bin", "tsc"), "--noEmit", "false", "--outDir", out],
  { cwd: here, stdio: "inherit" }
);

const { default: handler } = await import(new URL("./.smoke/api/suggest.js", import.meta.url));
const { handleSuggest } = await import(new URL("./.smoke/lib/handler.js", import.meta.url));

const server = http.createServer((req, res) => {
  handler(req, res).catch((error) => {
    console.error("handler threw:", error);
    res.statusCode = 599;
    res.end("{}");
  });
});
await new Promise((resolve) => server.listen(PORT, resolve));

async function call(method, body, headers = {}) {
  const response = await fetch(`http://127.0.0.1:${PORT}/api/suggest`, {
    method,
    headers: { "content-type": "application/json", ...headers },
    body,
  });
  return { status: response.status, body: await response.json() };
}

let failures = 0;
async function check(name, run) {
  try {
    await run();
    console.log(`  ok   ${name}`);
  } catch (error) {
    failures += 1;
    console.error(`  FAIL ${name}\n       ${error.message.split("\n")[0]}`);
  }
}

console.log("checking…");

await check("GET is refused, not hung", async () => {
  const { status, body } = await call("GET");
  assert.equal(status, 405);
  assert.equal(body.error, "Use POST.");
});

await check("a body that is not JSON is a 400", async () => {
  const { status, body } = await call("POST", "not json");
  assert.equal(status, 400);
  assert.equal(body.error, "Body must be JSON.");
});

await check("an empty body is a 400", async () => {
  const { status } = await call("POST", "");
  assert.equal(status, 400);
});

await check("an unknown tool is a 400", async () => {
  const { status, body } = await call("POST", JSON.stringify({ tool: "nope", text: "hi" }));
  assert.equal(status, 400);
  assert.match(body.error, /tool must be one of/);
});

await check("blank text is a 400", async () => {
  const { status } = await call("POST", JSON.stringify({ tool: "fix", text: "   " }));
  assert.equal(status, 400);
});

await check("text past the cap is a 400", async () => {
  const { status } = await call("POST", JSON.stringify({ tool: "fix", text: "x".repeat(2001) }));
  assert.equal(status, 400);
});

// The host may hand the handler a parsed object (Vercel) or a raw string (a
// bare Node server). Both have to work, and only one of them is reachable
// over HTTP — so this one calls the handler directly.
await check("an already-parsed body is accepted", async () => {
  const { status, body } = await handleSuggest({
    method: "POST",
    key: undefined,
    body: { tool: "nope", text: "hi" },
  });
  assert.equal(status, 400);
  assert.match(body.error, /tool must be one of/);
});

await check("a wrong shared key is a 401", async () => {
  process.env.NIB_APP_SECRET = "letmein";
  const wrong = await handleSuggest({
    method: "POST",
    key: "nope",
    body: { tool: "fix", text: "hi" },
  });
  const missing = await handleSuggest({
    method: "POST",
    key: undefined,
    body: { tool: "fix", text: "hi" },
  });
  delete process.env.NIB_APP_SECRET;
  assert.equal(wrong.status, 401);
  assert.equal(missing.status, 401);
});

server.close();
rmSync(out, { recursive: true, force: true });

if (failures > 0) {
  console.error(`\n${failures} check(s) failed`);
  process.exit(1);
}
console.log("\nall checks passed");
