# Nib backend

One endpoint, three interchangeable AI providers.

```
POST /api/suggest
{ "tool": "fix", "text": "...", "options": {...}, "prompt": "..." }
->
{ "suggestions": ["...", "..."], "model": "claude-haiku-4-5" }
```

## Switching provider

Two environment variables in the Vercel dashboard. No code change, no redeploy
of the app, nothing in the keyboard to update.

| Variable | Values |
|---|---|
| `AI_PROVIDER` | `anthropic` (default) · `openai` · `google` |
| `AI_MODEL` | optional; overrides that provider's default |

Defaults are the cheapest model in each family — `claude-haiku-4-5`,
`gpt-5-nano`, `gemini-3.5-flash-lite`. Fix is a bounded task, and if the prompt
reads well on the cheapest model then the prompt is doing the work rather than
the model covering for it.

Model names age out. When a provider answers "no longer available to new
users", nothing is broken except a string — set `AI_MODEL` to the replacement
it names and redeploy.

Each SDK reads its own key, so several can sit side by side and only the
selected one is used:

| Provider | Key |
|---|---|
| anthropic | `ANTHROPIC_API_KEY` |
| openai | `OPENAI_API_KEY` |
| google | `GEMINI_API_KEY` |

`NIB_APP_SECRET` is optional. When set, requests must carry it as `x-nib-key`.

## Two things to know before shipping this

**The shared secret is not real security.** It ships inside the app, so anybody
willing to unpack an IPA can read it. It stops an open endpoint being found and
drained by accident; it does not stop a person who means it. Device attestation
replaces it when there is something worth protecting.

**Do not use Google's free tier here.** It may use prompts to improve their
products. Paid tiers and Vertex do not. Nib's onboarding promises that text is
sent only when a tool is tapped and only in the scope needed — a tier that
trains on that text makes the promise false.

## Layout

```
api/suggest.ts          Vercel adapter: Node (req, res) in, JSON out. Nothing else.
lib/handler.ts          the endpoint: validates, delegates, never leaks upstream errors
lib/prompt.ts           one prompt, shared by every provider
lib/providers/types.ts  the seam — the only thing the handler knows about
lib/providers/*.ts      one adapter each; provider vocabulary stops here
smoke.mjs               runs the endpoint over real HTTP; no key, no network
```

`api/suggest.ts` is deliberately thin. The first deployment failed because it
was written to the web-standard `Request`/`Response` signature while the
runtime hands Node's `(req, res)` — every request 500ed, and the ones that did
not hung for 300 seconds waiting on a `res.end()` that a returned object was
never going to produce. A host's calling convention should be able to be wrong
in one small file, so now it is: `lib/handler.ts` takes data and returns data,
and moving to another host is a new adapter rather than a new endpoint.

```bash
npm run typecheck
npm run smoke      # both run in CI
```

The prompt is shared deliberately. If each adapter wrote its own, switching
provider would change two things at once and any comparison between them would
be measuring prompts while calling it measuring models.
