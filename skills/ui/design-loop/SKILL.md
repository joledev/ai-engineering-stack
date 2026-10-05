---
name: design-loop
stacks: [ios]
argument-hint: "[section | screen | requirement ID | 'audit <section>']"
description: >
  Design or improve iOS screens in a code-generated OpenPencil design file, the
  way Claude Design works: diagnose the screen yourself, ask only product
  questions, build 2-3 variants side by side for the user to pick, iterate on
  the pick until the user says it is done, then audit it in a read-only
  design-auditor subagent, stop for approval, apply the approved findings and
  re-audit. Use when the user wants a new screen, wants a screen improved (even
  with no idea how), runs a UX/UI audit, or says "design-loop". Needs a
  "Design pipeline" section in the project's CLAUDE.md.
---

# Design Loop

```
brief → propose (2-3 variants) → pick → iterate → "listo" → audit → STOP → apply → re-audit
```

The user often has no idea how to improve a screen. That is your job. Never ask
the user how something should look. Ask about the product, decide the design,
and show it built.

## 0. Read the project's design pipeline

Read the `## Design pipeline` section of the project's `CLAUDE.md` (root, or a
package `CLAUDE.md` linked from it). It must name Source, Tokens, Build, Output,
Find id, Export, Compare and Spec. Missing section or key → STOP, ask for it,
offer to add it. Never guess a build command.

Mode from `$ARGUMENTS`:

- `audit <section>` → skip to step 5 on the existing screens.
- A section, screen or requirement ID → step 1.
- Empty → ask which section, listing the pages of the Output as options.

## 1. brief: diagnose first, then ask only what the code can't tell you

1. Export every screen of the section (light and dark) and read the PNGs and their source.
   New screen for a requirement: read the requirement in the Spec instead.
2. Diagnose against [references/audit-ios.txt](references/audit-ios.txt). Keep it
   short: the 3-6 problems that hurt this screen most, each with its evidence.
3. Domain lookups with ui-ux-pro-max (optional, see Prerequisites), one domain per call:

   ```bash
   S=$(ls ~/.claude/plugins/cache/ui-ux-pro-max-skill/ui-ux-pro-max/*/.claude/skills/ui-ux-pro-max/scripts/search.py 2>/dev/null | tail -1)
   [ -n "$S" ] && python3 "$S" "<product keywords>" --domain ux -n 3
   ```

   Domains: `ux`, `typography`, `color`, `icons`; `--stack swiftui` for SwiftUI
   guidance. Script missing → skip, say so once.
4. Ask at most 3 **product** questions, only the ones the Spec and code can't
   answer, with "No sé" always a valid option. Good: "¿Qué hace la mayoría al
   abrir esta pantalla?", "¿Quién la usa más, admin o jugador?", "¿Algo te
   molesta aunque no sepas por qué?". Never: "¿Cómo quieres el header?",
   "¿Qué color prefieres?". If the user gave a clear direction already, ask nothing.

## 2. propose: build 2-3 variants, don't describe them

Each variant attacks a different problem from the diagnosis, so the user picks
a direction, not a shade (e.g. A hierarchy, B density, C next action first).

- Variants live in the Source as new screen functions, on their own page
  `Propuestas · <section>`, named `<screen> — <letter>: <direction> · <mode>`.
  The real screens stay untouched until the user picks.
- Every variant is built in light and dark.
- Design rules while building (the same checklist, used as constraints):
  - Tokens and kit first; a new color or size goes in Tokens, never inline.
  - 44pt hit areas, iOS text styles, safe areas, native navigation.
  - Contrast computed for every new text/background pair (formula in audit-ios.txt).
  - Brand accent and platform font are locked. A different typeface or accent is
    a proposal in the summary, never built into a variant.
  - Product copy: reuse the existing text. Any new string is marked
    `COPY: user decides` in the summary.
- Run Build, export the variants, and tell the user where to look: the page name
  in the Output (open it in OpenPencil) and the PNG paths.

Summary per variant, one line each: the problem it attacks, what changed, the
trade-off. Then ask which one: a letter, a mix ("A con el header de C"), or none.

## 3. pick and iterate

- **None** → ask one question about what didn't work ("No sé" is valid), then a
  new round of variants. Never repeat a rejected direction.
- **A pick or a mix** → promote it: the chosen variant replaces the real screen in
  its section file, the proposal code and its page are removed. Build, export,
  show the before/after.
- **Feedback** ("más aire", "el botón más abajo") → change, Build, show again.
  Each round keeps the design rules from step 2.

Repeat until the user says it is done ("listo", "ya", "me gusta"). Then commit
the design (one commit, subject line only) and go straight to step 4.

## 4. audit (read-only subagent)

Copy the current Output to the scratchpad as the pre-apply baseline. Export
every changed screen (light and dark) and dispatch ONE `design-auditor` subagent
with a complete prompt: the PNG paths, the screen source files, the Tokens path,
the Spec requirement IDs, the full text of
[references/audit-ios.txt](references/audit-ios.txt) pasted verbatim, and "Report only."
Never summarize or shorten the checklist: a dropped rule changes severities (the
"Apple system colors below 4.5:1 are Sev 1" rule is the one that goes missing).
Don't ask the auditor to write out its reasoning; ask for the table and the evidence.

## 5. STOP

Show the findings table, highest severity first:

| # | Sev | Screen | Rule | Evidence | Proposed fix |
|---|-----|--------|------|----------|--------------|

Ask which rows to apply and the exact text for every `COPY: user decides` row.
Wait. Never continue on silence or a partial answer.

## 6. apply

1. Edit the Source for the approved rows only. A shared fix goes once, in the kit or Tokens.
2. Build.
3. Compare every screen the edit can reach against the pre-apply baseline. Every
   delta must trace to an approved row; an untraced delta is a regression to fix now.
4. Commit, one commit per round, subject line only.

## 7. re-audit

A new `design-auditor` checks the applied rows only, with the same verbatim checklist. A row still failing goes
back to step 6. After 2 rounds, stop and list what is left.

## Prerequisites

- The `design-auditor` agent from this stack (`install-global.sh`).
- Python 3 (stdlib only) for ui-ux-pro-max. Install the plugin one command at a time:
  `/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill`, then
  `/plugin install ui-ux-pro-max@ui-ux-pro-max-skill`. Without it the loop still
  runs; only the lookups are skipped.

Sources for every rule: [../README.md](../README.md#sources).
