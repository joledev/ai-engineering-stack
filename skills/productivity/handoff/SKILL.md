---
name: handoff
description: >
  Generate a structured handoff document for the current session — what was done,
  current state, pending work, blockers, and next steps — and print it as one
  fenced block the user copies with /copy into the next chat. Writes no file
  (unlike claude-mem:handoff, which writes HANDOFF.md). Use when the user says
  /handoff or wants to hand the session to another chat or person.
version: "1.2.0"
modes: [architect]
stacks: [all]
argument-hint: "What will the next session be used for?"
---

# Handoff

Generate a complete, accurate handoff document by examining real project state — not from memory alone, not from guesses.

**Core principle:** Every claim in the handoff must be verifiable from `git`, files, or claude-mem. No hallucinated state.

If the user passed arguments, treat them as a description of what the next session
will focus on and tailor the document accordingly.

---

## Phase 1 — Gather Real State

Run these in parallel:

```bash
# 1. Git state
git status
git log --oneline -15
git diff --stat HEAD~5..HEAD 2>/dev/null || git diff --stat

# 2. Uncommitted changes
git diff --name-only
git diff --cached --name-only

# 3. Current branch
git branch --show-current
```

Also check:
- Any `.claude/plans/` files for active plans
- Recent session context from claude-mem (`get_observations` for last 5–10 obs if available)
- Any open TODO comments in recently touched files (`rg "TODO|FIXME|HACK" --changed-files` if applicable)

---

## Phase 2 — Build the Handoff Document

Structure the document as follows. Skip any section where there's genuinely nothing to report — do not pad with placeholders.

```markdown
# Handoff — [Project Name] — [Date YYYY-MM-DD HH:mm]

## Branch
`[branch-name]`

## What Was Done
<!-- List completed work items with file paths and brief descriptions -->
- [Item 1]: `path/to/file.ts` — description
- [Item 2]: ...

## Current State
<!-- Honest description of what's working, what's partially done, what's broken -->
[Paragraph or bullets. No fluff.]

## Uncommitted Changes
<!-- List files with uncommitted changes and their status -->
- `path/to/file.ts` — [modified/new/deleted]: what changed

## Pending Work
<!-- What needs to be done next, in priority order -->
1. [Task 1] — [why it's next / dependency]
2. [Task 2]
...

## Blockers / Open Decisions
<!-- Decisions pending, questions unanswered, external dependencies -->
- [Blocker]: [what's needed to unblock]

## Context for Next Session
<!-- The non-obvious things that would trip up someone picking this up cold -->
- [Key context 1]
- [Key context 2]

## Quick Resume
<!-- One-liner or two to paste into the next session to get up to speed fast -->
> "We were working on [X]. Last thing done was [Y]. Next step is [Z]."

## Suggested Skills
<!-- Skills the next agent should invoke, and for what -->
- `/[skill]` — [why it applies to the pending work]
```

Do not duplicate content already captured in other artifacts (PRDs, plans, ADRs,
issues, commits, diffs). Reference them by path or URL instead.

---

## Phase 3 — Deliver as a Code Block

**Do not save a file** and **do not run `pbcopy`, `xclip`, `wl-copy` or `clip`.**
The Bash sandbox blocks clipboard access, and excluding those commands from the
sandbox makes every run prompt for permission. Print the document instead.

Print the full handoff document in your reply as **one fenced block** tagged
`markdown`. Open and close it with four backticks (` ```` `) so any triple-backtick
fence inside the document does not end the block early.

### Report to user

Right after the block, one line telling the user to run `/copy` and pick that
block, then paste it into the next chat with Cmd+V. Do **not** report a file
path (there is none).

### Optional — save to memory

If the session had significant architectural decisions, decisions about approach, or non-obvious context, **offer** to save a project memory with the key facts via claude-mem. This is independent of the handoff block and only happens if the user accepts.

---

## Rules

- **Redact secrets:** Never include API keys, passwords, tokens, connection strings or personally identifiable information. Reference the env var name, not the value.
- **No hallucination:** If you don't know something, say "unknown — verify with git/code."
- **No padding:** Empty sections get removed, not filled with "N/A."
- **File paths must be real:** Every file path you list must have been seen in this session or verified via `git`.
- **Be specific:** "Updated the glucose wizard" is bad. "Added `horaActual()` to `glucosa.ts:45` and wired it into `RegistroGlucosaMovil`" is good.
- **Quick Resume must be copy-pasteable** as a conversation opener.
- **Code block, not file or clipboard:** The handoff is printed for `/copy`. Never write a handoff file, never call a clipboard command.
