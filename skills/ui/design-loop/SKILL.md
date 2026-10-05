---
name: design-loop
stacks: [ios]
argument-hint: "[screen | section | requirement ID | 'audit <section>']"
description: >
  Create or improve iOS screens in a code-generated design file, audit them in a
  fresh subagent against an iOS checklist (Nielsen, HIG, WCAG, Norman, Refactoring
  UI), stop for the user's approval, apply only the approved findings, and
  re-audit. Use when the user wants to design a new screen, improve existing
  mocks, run a UX/UI audit on a section, or says "design-loop". Needs a
  "Design pipeline" section in the project's CLAUDE.md.
---

# Design Loop

`design → audit → STOP → apply → re-audit`, at most 2 apply rounds per run.

The user decides what ships. This skill proposes and verifies; it never applies
a finding the user did not approve, and never writes product copy on its own.

## 0. Read the project's design pipeline

Read the `## Design pipeline` section of the project's `CLAUDE.md` (root or the
package that holds the design). It must name:

| Key | Example |
|-----|---------|
| Source | `design/src/` (screens, kit, tokens) |
| Tokens | `design/src/tokens.mjs` |
| Build | command that regenerates the design file |
| Output | `design/app.fig` |
| Export | command that renders one screen to PNG |
| Compare | command that diffs a screen against a baseline |
| Spec | where requirements live (`docs/requirements.md`) |

Missing section or key → STOP. Ask the user for it and offer to add it. Never
guess a build command.

## 1. design

Create a new screen or improve an existing one in the Source, then run Build.

- Start from a requirement ID in the Spec. No requirement → ask which one.
- Reuse the kit and tokens. A new part goes in the kit only if 2+ screens use it.
- Lookups with ui-ux-pro-max (optional, see Prerequisites). Domain queries only,
  one domain per call:

  ```bash
  S=$(ls ~/.claude/plugins/cache/ui-ux-pro-max-skill/ui-ux-pro-max/*/.claude/skills/ui-ux-pro-max/scripts/search.py 2>/dev/null | tail -1)
  [ -n "$S" ] && python3 "$S" "<product keywords>" --domain typography -n 2
  ```

  Use `--domain` with `typography`, `color`, `ux` or `icons`, and `--stack swiftui`
  for SwiftUI guidance. Script missing → skip the lookup, say so once, continue.

Rails on ui-ux-pro-max output (it targets web landing pages):

- Never run `--design-system`. Ignore Pattern, Key Effects, hover/cursor/breakpoint advice.
- The brand accent is locked. A palette suggestion never replaces it.
- Typography stays on the platform font. A different typeface is reported as a
  proposal in the audit table (section 3), never applied in this phase.

## 2. audit (fresh subagent)

Export every screen in scope to PNG (light and dark), then dispatch ONE subagent
(`code-reviewer`; it is read-only) with a complete prompt:

- the PNG paths, the screen source files, the Tokens path, the Spec requirement IDs;
- the full text of [references/audit-ios.md](references/audit-ios.md);
- "Report only. Do not edit files. Every finding: severity 0-4, screen, rule ID,
  evidence (`file:line` or measured value), proposed fix. Product copy: write
  `COPY: user decides` instead of inventing text."

The subagent has not seen the design phase, so it does not grade its own work.

## 3. STOP

Show the findings table to the user, highest severity first:

| # | Sev | Screen | Rule | Evidence | Proposed fix |
|---|-----|--------|------|----------|--------------|

Ask which rows to apply, and for every `COPY: user decides` row, the exact text.
Wait. Do not continue on silence or on a partial answer.

## 4. apply

1. Copy the current Output to the scratchpad. That copy is the pre-apply baseline.
2. Edit the Source for the approved rows only. Shared fix → once, in the kit or tokens.
3. Run Build.
4. Run Compare for every screen the edit can reach, against the pre-apply copy.
   Every delta must trace to an approved row. An untraced delta is a regression:
   fix it before moving on.
5. Commit in the design repo, one commit per round, subject line only.

## 5. re-audit

Dispatch a new audit subagent on the applied rows only. A row still failing goes
back to step 4. After 2 rounds, stop and list what is left for the user.

## Prerequisites

- Python 3 (stdlib only) for ui-ux-pro-max. Install the plugin, one command at a time:
  `/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill`, then
  `/plugin install ui-ux-pro-max@ui-ux-pro-max-skill`.
- Without it the loop still runs; only the design-phase lookups are skipped.

Sources for every rule: [../README.md](../README.md#sources).
