---
name: prompt-rewrite
stacks: [all]
description: Audit or rewrite LLM instructions — a skill (SKILL.md), CLAUDE.md, agent definition, system prompt, tool description or a single prompt — against Anthropic's prompting guidance for current Claude models. Diagnoses first, then proposes the rewrite with the reason for each change; it does not overwrite the file until the user approves. Use when the user asks to improve, audit, tighten or fix a prompt or skill, or asks why an agent keeps doing the wrong thing (skips a stop, over-builds, ignores a rule).
---

# Prompt rewrite

The goal is the instructions that most reliably produce the behavior the user wants — not the
shortest ones. Cut what carries no signal; keep every reason and every ordering that does.

Source of truth: Anthropic's prompting docs (links at the end). When a rule below and the docs
disagree, the docs win — re-read the relevant page instead of guessing.

## 1. Get the artifact and the failure

Read the whole file. Ask for one concrete failure if the user hasn't named one ("it started coding
after I invoked it", "it adds tests nobody asked for"). A rewrite without a failure to fix is
polish; say so and keep the edits small.

## 2. Classify it

The type decides what matters most:

| Type | What matters most |
|---|---|
| Skill (`SKILL.md`) | The `description` — it is read first and decides both when the skill fires and what the model thinks it was invoked to do. It must say where the skill ends. |
| CLAUDE.md / project rules | Only what the model can't infer from the code: team decisions, each with its one-line reason. |
| Agent / system prompt | The default for acting vs. suggesting, scope, and which stops are wanted. |
| Tool description | One job, when to use it, when not to (if another tool overlaps), what it returns. |
| Single prompt | Explicit ask, desired output, the data placed above the question. |

## 3. Diagnose

Name each problem found, with the line it's on:

- **Vague ask.** The model has to guess the output or the scope. Say what you want; ask
  explicitly for "go beyond the basics" if you want it.
- **Rule without a reason.** "NEVER use X" generalizes worse than one line saying why. The model
  extends a reason to cases the rule didn't list.
- **Negative framing.** "Don't use markdown" works worse than "write flowing prose paragraphs".
  State the behavior you want.
- **Shouting.** `CRITICAL`, `MUST`, ALL CAPS were compensation for older, less attentive models.
  Current models over-apply them: a tool marked "CRITICAL: always use" fires where it shouldn't.
  Use plain wording ("Use X when…") and, if a rule truly has a high cost, its reason instead of caps.
- **Order-dependent steps written as prose — or prose reasoning scripted as steps.** When order
  or completeness matters (a workflow with stops, a checklist), use a numbered list. When the
  model has to *reason* ("find the root cause"), a general instruction beats a hand-written plan.
- **Implicit act/suggest default.** Nothing says whether to change files or only propose. Set it
  (see snippets). This is the usual cause of "it started coding before I approved".
- **Unnamed stops.** "Stop when appropriate" is guessed. Name the stops wanted (after the plan,
  before a risky step) and the ones not wanted (stopping to announce the next step instead of doing it).
- **Scope creep invitations.** Nothing limits scope, so the model adds tests, docs, refactors.
- **Legacy over-prompting.** "Be thorough", "if in doubt use [tool]", "verify your work", "think
  carefully before answering" — needed by older models, causes over-exploration and
  over-verification now. Remove rather than rewrite. How much the model thinks is set by
  `effort`, not by prompt text.
- **Asking for the reasoning in the answer.** "Write your reasoning before the answer" can trigger
  `reasoning_extraction` refusals on current models. Remove it.
- **Mixed content without structure.** Instructions, context, examples and input run together.
  Wrap each in its own XML tag; examples in `<example>`, 3–5, relevant and varied.
- **Long data below the question.** Put long documents first, the question last.
- **Style mismatch.** A prompt full of bullets and bold gets answers full of bullets and bold.
- **Redundancy / stale content.** The same rule in three places, or rules about code that no
  longer exists. Keep one copy; link instead of copying.

## 4. Rewrite

- Fix what the diagnosis found. Leave working parts alone — no rewriting for style.
- Keep every reason, ordering, exact command and hard stop. Those are signal even when long.
- Shorter is a side effect, not a target. There is no percentage to hit.
- For a skill: keep `SKILL.md` to what every run needs; move reference material to a sibling file
  the skill tells the model to read when needed.

Snippets from the docs worth reusing (adapt the wording to the artifact):

```text
<!-- Plan first, act on approval (conservative default) -->
When the user asks for ideas, options or a plan, give them that and stop. Don't start building
or changing anything until they say to go ahead.

<!-- Keep scope to the ask -->
When the work the user asked for is done and checked, stop and report. Don't add features,
tests, files, docs or refactors that weren't asked for. If you think one would help, mention
it at the end instead of doing it.

<!-- Finish instead of checking in (act-by-default agents) -->
Keep working until everything the user asked for is done, and only stop to ask when you can't
go on without the user or before a risky step.

<!-- Risky actions -->
For actions that are hard to reverse, affect shared systems, or could be destructive, ask the
user before proceeding.
```

## 5. Deliver

```
## Diagnosis
- <problem> — <file:line> — <why it causes the failure>

## Rewrite
<full rewritten artifact, or a diff when the changes are local>

## What changed and why
- <change> — <reason, pointing to the diagnosis>
```

If the artifact is already sound, say so and list only targeted edits. Don't write the file until
the user approves the rewrite.

## Sources

- General: https://platform.claude.com/docs/es/build-with-claude/prompt-engineering/claude-prompting-best-practices
- Opus 5.5: https://platform.claude.com/docs/es/build-with-claude/prompt-engineering/prompting-claude-opus-5-5
- Sonnet 5.5: https://platform.claude.com/docs/es/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5

Structure adapted from rubentanahara/claude-code-config-devtalk `skills/prompt-rewrite`, with its
two conflicts with the docs removed: it treated numbered steps as an anti-pattern, and it set a
20–40% token-cut target.
