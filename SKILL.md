---
name: codex-gemini-loop
description: >-
  Before sending a non-trivial result to the user, have Gemini read the draft
  cold and rewrite it in plain language, then check that no fact changed.
  Use when the user is not an expert in the topic, asks to "explain simply",
  "说人话", "讲明白点", "看不懂", "通俗一点", or when your draft is full of
  jargon, file paths, flags, or internal terms. Skip for one-line answers.
---

# Plain-talk: let Gemini make your answer readable

You know too much about the task to see what a newcomer trips over. Gemini has
seen none of it, so it is a real cold reader. Use it as the last step before you
reply, not as a co-author.

## Loop (one pass is normally enough)

1. **Write the draft as usual** — result first, then what you did and what to do next. Do the work and the checks before this; Gemini edits wording, not correctness.
2. **Run the editor:**
   ```bash
   scripts/plain.sh draft.md                       # or: cat draft.md | scripts/plain.sh
   scripts/plain.sh --audience "PI, no coding background" --lang zh draft.md
   ```
   Pass `--audience` whenever you know who is reading. Default is "smart non-expert". `--lang` defaults to the language of the draft.
3. **Read what comes back.** It has two parts: `REWRITE` and `STUMBLES` (terms or jumps a newcomer could not follow). The script also prints `WARN` lines for code spans or numbers from the draft that are missing in the rewrite.
4. **Gate, then send.** Take the rewrite only if all of these hold, otherwise fix it by hand or keep your draft:
   - every number, path, command, name, and error text is unchanged (resolve each `WARN`);
   - nothing was added that you did not do or verify; no softened failures, no claims of success you lack;
   - the first sentence is the conclusion or the thing the user must decide.
5. **Reply with the final text only.** Do not paste Gemini's raw output or mention the editing step unless the user asked.

If `plain.sh` exits non-zero (no CLI, no key, quota, timeout), rewrite the draft yourself using the rules below and carry on. Do not block the reply on Gemini.

## What "plain" means here

- Conclusion first; one idea per sentence; short paragraphs.
- Say what a thing does before what it is called. Define a term once, in a few words, where it first appears; keep the exact technical name next to it so the user can search for it.
- Replace "I refactored the dispatch layer" with the effect: "Requests now go to the right handler, and the crash is gone."
- Keep exact identifiers, paths, commands, versions and numbers in code format. Plain language never means vaguer facts.
- End with what the user needs to do, or say that nothing is needed.
- No hype, no filler openers, no apology piles, no hedges that carry no information.

## Setup

Needs the Gemini CLI on `PATH` (or `GEMINI_BIN`) and credentials in its usual place.
Optional env: `GEMINI_MODEL` (one model id), `GEMINI_FALLBACK_MODELS` (space-separated, tried in order), `GEMINI_TIMEOUT` (seconds per model, default 60; default fallbacks `gemini-3.5-flash gemini-3-flash-preview`). Defaults and the NFS-home workaround are in `scripts/plain.sh`.

Send only the draft. Strip secrets, tokens and personal data first; the draft leaves the machine.
