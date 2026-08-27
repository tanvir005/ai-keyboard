import OpenAI from "openai";

import { SUGGESTION_COUNT, systemPrompt, userPrompt } from "../prompt.js";
import type { Provider, SuggestRequest } from "./types.js";

/**
 * OpenAI, via the official SDK.
 *
 * Same contract as every other adapter: strings out, no provider vocabulary
 * escaping. The JSON schema below says the same thing the Zod schema says in
 * the Anthropic adapter — each provider spells "give me an array of strings"
 * differently, and that difference stops here.
 */
export function openaiProvider(model: string): Provider {
  const client = new OpenAI();

  return {
    name: "openai",
    model,

    async suggest(request: SuggestRequest): Promise<string[]> {
      const completion = await client.chat.completions.create({
        model,
        max_completion_tokens: 1024,
        messages: [
          { role: "system", content: systemPrompt(request.tool) },
          { role: "user", content: userPrompt(request) },
        ],
        response_format: {
          type: "json_schema",
          json_schema: {
            name: "suggestions",
            strict: true,
            schema: {
              type: "object",
              additionalProperties: false,
              required: ["suggestions"],
              properties: {
                suggestions: { type: "array", items: { type: "string" } },
              },
            },
          },
        },
      });

      const body = completion.choices[0]?.message.content;
      if (!body) return [];

      return parseSuggestions(body);
    },
  };
}

/**
 * Shared by the adapters that get JSON as text rather than as a parsed object.
 *
 * Never throws. A provider returning something unexpected should cost the user
 * a suggestion, not a 500 — the keyboard has a working fallback and a crash
 * here would take it away.
 */
export function parseSuggestions(body: string): string[] {
  try {
    const parsed: unknown = JSON.parse(body);
    if (typeof parsed !== "object" || parsed === null) return [];

    const list = (parsed as { suggestions?: unknown }).suggestions;
    if (!Array.isArray(list)) return [];

    return list
      .filter((item): item is string => typeof item === "string")
      .slice(0, SUGGESTION_COUNT);
  } catch {
    return [];
  }
}
