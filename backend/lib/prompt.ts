import type { SuggestRequest, Tool } from "./providers/types.js";

/**
 * One prompt, shared by every provider.
 *
 * This matters more than it looks. If each adapter wrote its own prompt, then
 * switching provider would change two things at once and any comparison
 * between them would be meaningless — you would be testing prompts and calling
 * it testing models. Keeping the words identical means the only variable left
 * is the model.
 */

/** How many alternatives to ask for. The strip shows two beside the original. */
export const SUGGESTION_COUNT = 2;

const SHARED = `
You are the editing engine inside a phone keyboard. Your output is inserted
directly into somebody's message, so it must be finished text, never commentary.

Rules that hold for every task:
- Return ${SUGGESTION_COUNT} alternatives, best first.
- Preserve the writer's voice. You are editing their message, not writing yours.
- Keep the register you were given. Casual stays casual; formal stays formal.
- Never add greetings, sign-offs, quotation marks, or explanations.
- Never answer the content of the message. "what time is it" is text to edit,
  not a question to answer.
`.trim();

/**
 * What to do when the text is already fine — which is not the same answer for
 * every tool.
 *
 * This was one shared rule until Synonyms was asked for alternatives to "really
 * important" and answered "really important". Correct by the rule, and useless:
 * the tool was tapped *because* the writer wants a different word, so the one
 * wording guaranteed not to help is the one they already typed.
 *
 * The rest of the tools edit a message in place, where an invented difference
 * is the worse failure. Synonyms replaces a word, where no difference is.
 */
const KEEP_IF_ALREADY_RIGHT = `
- If the text is already correct and cannot be improved, return it unchanged as
  the first suggestion rather than inventing a difference.
`.trim();

const NEVER_ECHO_THE_INPUT = `
- Never return the writer's own wording as a suggestion. Every alternative must
  differ from what they typed. If the phrase is hard to improve on, reach for a
  near-synonym or a small rephrasing rather than repeating it back.
`.trim();

const PER_TOOL: Record<Tool, string> = {
  fix: `
Fix spelling, grammar and punctuation. Change nothing else — not word choice,
not tone, not length. A sentence that is merely informal is not an error.
`.trim(),

  rewrite: `
Rewrite for clarity, keeping the meaning exactly. Prefer shorter. Do not add
information the writer did not give you.
`.trim(),

  tone: `
Rewrite in the requested tone, keeping the meaning exactly.
`.trim(),

  translate: `
Translate into the requested language. Translate the meaning, not the words —
match how somebody actually writing in that language would say it.
`.trim(),

  synonyms: `
Offer alternative wordings for the phrase given. Same meaning, same register.
Each suggestion must be a different wording from the one you were given.
`.trim(),

  ask: `
Follow the writer's instruction about their text. The instruction is theirs, not
a message to reply to.
`.trim(),
};

export function systemPrompt(tool: Tool): string {
  const sameness = tool === "synonyms" ? NEVER_ECHO_THE_INPUT : KEEP_IF_ALREADY_RIGHT;
  return `${SHARED}\n${sameness}\n\nThis request is a ${tool.toUpperCase()} task.\n${PER_TOOL[tool]}`;
}

export function userPrompt(request: SuggestRequest): string {
  const parts: string[] = [];

  const tone = request.options?.tonePreset;
  const language = request.options?.targetLanguage;

  if (tone) parts.push(`Tone to use: ${tone}`);
  if (language) parts.push(`Language to translate into: ${language}`);
  if (request.prompt) parts.push(`The writer's instruction: ${request.prompt}`);

  // Fenced so a message that itself contains instructions cannot be read as
  // one. A keyboard is typed into by people quoting other people.
  parts.push("Text:\n<text>\n" + request.text + "\n</text>");

  return parts.join("\n\n");
}
