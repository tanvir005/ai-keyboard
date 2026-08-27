/**
 * The one thing every provider has to do.
 *
 * Deliberately narrow. Anthropic, OpenAI and Google disagree about almost
 * everything — parameter names, how a system prompt is passed, how you ask for
 * JSON back, what a response object looks like — and none of that disagreement
 * is allowed past this file. An adapter takes a request and returns strings.
 *
 * The narrowness is the point: adding a fourth provider should mean writing one
 * function, not touching the endpoint, the prompt, or the app.
 */

/** Which tool the user tapped. Only `fix` is wired up so far. */
export type Tool = "fix" | "rewrite" | "tone" | "translate" | "synonyms" | "ask";

export interface SuggestRequest {
  tool: Tool;
  /** The text to work on — the scope the keyboard resolved, never the whole field. */
  text: string;
  /** Tone preset, target language, and so on. Tool-specific. */
  options?: Record<string, string | undefined>;
  /** Only for Ask AI. */
  prompt?: string;
}

export interface Provider {
  /** For logs and error messages — `"anthropic"`, `"openai"`, `"google"`. */
  readonly name: string;
  /** The model actually being used, so a response can say what produced it. */
  readonly model: string;

  /**
   * Between one and three alternatives, best first.
   *
   * Throws on transport or auth failure. Returning an empty array is a valid
   * answer meaning "nothing worth suggesting" — the caller distinguishes the
   * two, so a provider must not throw simply because it had no ideas.
   */
  suggest(request: SuggestRequest): Promise<string[]>;
}

/** Thrown when the environment names a provider that does not exist. */
export class UnknownProviderError extends Error {
  constructor(name: string) {
    super(
      `Unknown AI_PROVIDER "${name}". Expected one of: anthropic, openai, google.`,
    );
    this.name = "UnknownProviderError";
  }
}
