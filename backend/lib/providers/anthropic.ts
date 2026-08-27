import Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { z } from "zod";

import { SUGGESTION_COUNT, systemPrompt, userPrompt } from "../prompt.js";
import type { Provider, SuggestRequest } from "./types.js";

const Suggestions = z.object({
  suggestions: z.array(z.string()),
});

/**
 * Claude, via the official SDK.
 *
 * `messages.parse` with an output format is used rather than asking for JSON in
 * the prompt and hoping: the shape is enforced by the API, so there is no
 * parsing to get wrong and no "sure, here's your JSON:" preamble to strip.
 */
export function anthropicProvider(model: string): Provider {
  const client = new Anthropic();

  return {
    name: "anthropic",
    model,

    async suggest(request: SuggestRequest): Promise<string[]> {
      const response = await client.messages.parse({
        model,
        max_tokens: 1024,
        system: systemPrompt(request.tool),
        messages: [{ role: "user", content: userPrompt(request) }],
        output_config: { format: zodOutputFormat(Suggestions) },
      });

      // Null when the model's output failed validation. An empty list is the
      // honest answer there — better a strip with nothing in it than text of
      // unknown shape pushed into somebody's message.
      return response.parsed_output?.suggestions.slice(0, SUGGESTION_COUNT) ?? [];
    },
  };
}
