import { anthropicProvider } from "./anthropic.js";
import { googleProvider } from "./google.js";
import { openaiProvider } from "./openai.js";
import { UnknownProviderError, type Provider } from "./types.js";

/**
 * Which model runs when nothing says otherwise.
 *
 * Cheap ones, deliberately. Fix is a bounded task — spelling and grammar have
 * mostly-right answers — and the first question worth answering is whether the
 * prompt is doing the work. If it reads well on the cheapest model in each
 * family, it will read at least as well on a larger one; the reverse tells you
 * nothing.
 */
const DEFAULT_MODEL: Record<string, string> = {
  anthropic: "claude-haiku-4-5",
  openai: "gpt-5-nano",
  google: "gemini-2.5-flash-lite",
};

/**
 * Builds the provider named by the environment.
 *
 * Two variables, both set in the Vercel dashboard and neither in the app:
 *
 *   AI_PROVIDER   anthropic | openai | google
 *   AI_MODEL      optional; overrides the default for that provider
 *
 * Changing provider is therefore a redeploy, not an edit — which is the whole
 * reason the adapters exist. Nothing in the keyboard knows or cares which one
 * answered, because the app talks to this service and this service talks to
 * them.
 *
 * The API key is read by each SDK from its own conventional variable
 * (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`), so keys for
 * several providers can sit side by side and only the selected one is used.
 */
export function providerFromEnvironment(): Provider {
  const name = (process.env.AI_PROVIDER ?? "anthropic").toLowerCase();
  const model = process.env.AI_MODEL ?? DEFAULT_MODEL[name];

  if (!model) throw new UnknownProviderError(name);

  switch (name) {
    case "anthropic":
      return anthropicProvider(model);
    case "openai":
      return openaiProvider(model);
    case "google":
      return googleProvider(model);
    default:
      throw new UnknownProviderError(name);
  }
}

export type { Provider, SuggestRequest, Tool } from "./types.js";
