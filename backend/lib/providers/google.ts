import { GoogleGenAI } from "@google/genai";

import { systemPrompt, userPrompt } from "../prompt.js";
import { parseSuggestions } from "./openai.js";
import type { Provider, SuggestRequest } from "./types.js";

/**
 * Gemini, via the official SDK.
 *
 * A warning that belongs next to the code rather than in a document: Google's
 * *free* tier may use prompts to improve their products. Paid tiers and Vertex
 * do not. This keyboard promises on its own onboarding screen that text is sent
 * only when a tool is tapped and only in the scope needed — running that text
 * through a tier that trains on it would make the promise false. Use a paid
 * key here.
 */
export function googleProvider(model: string): Provider {
  const client = new GoogleGenAI({});

  return {
    name: "google",
    model,

    async suggest(request: SuggestRequest): Promise<string[]> {
      const response = await client.models.generateContent({
        model,
        contents: userPrompt(request),
        config: {
          systemInstruction: systemPrompt(request.tool),
          responseMimeType: "application/json",
          responseSchema: {
            type: "object",
            required: ["suggestions"],
            properties: {
              suggestions: { type: "array", items: { type: "string" } },
            },
          },
        },
      });

      return parseSuggestions(response.text ?? "");
    },
  };
}
