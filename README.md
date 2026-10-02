# My AI Stack

Central AI stack for all engineering projects: global rules, specialized agents, and skills for autonomous, context-aware development in Claude Code.

**Claude Code only.** Support for Windsurf, OpenCode, and other editors was removed — everything here targets Claude Code's own conventions (`.claude/commands/`, `.claude/agents/`, root `CLAUDE.md`).

## Global layer (once per machine)

```bash
~/dev/personal/ai-engineering-stack/install-global.sh
```

- Symlinks `~/.claude/agents` to `global/agents/`: software-architect,
  business-analyst, code-reviewer, security-auditor, debugger, test-writer.
  An existing `~/.claude/agents` directory is moved to `agents.bak-<timestamp>`.
- Symlinks the skills every session needs into `~/.claude/skills`: fill-context,
  prd-to-github-backlog, prompt-rewrite, sdd-apply, sdd-verify, grill-me, handoff. Stale links
  are replaced; a real directory with the same name is skipped.
- Sets `"agent": "software-architect"` in `~/.claude/settings.json` with `jq`,
  so every session runs as the architect. Other keys are left untouched.
- Symlinks `~/.claude/statusline-command.sh` to `global/` (repo, branch, PR,
  running agent, model, context and rate limits; needs a Nerd Font) and sets
  `statusLine` only when none is configured.
- Prints the `claude mcp add` commands for context7 and GitHub. Run them by hand:
  the tokens live in `~/.claude.json` and never in this repo.

Safe to re-run. Agents update with `git pull`, since they are a symlink.

## Installation (per project)

Use the init script rather than symlinking by hand. It wires the symlinks, the
context tree, the gitignore entries, and the Obsidian bridge in one pass.

```bash
# Web / Next.js project
~/dev/ai-engineering-stack/init-project.sh ~/dev/my-app --stack=web

# .NET Clean Architecture project
~/dev/ai-engineering-stack/init-dotnet-project.sh ~/dev/my-api

# Android / Kotlin project
~/dev/ai-engineering-stack/init-project.sh ~/dev/my-app --stack=android
```

### `--stack` — install only what the project needs

Every skill declares a `stacks:` field in its frontmatter, and the init
script links only the matching ones. An Android project has no use for
`audit-layer-boundaries`. Agents are not per project: see Global layer.

| `--stack` | skills |
|-----------|--------|
| `web`     | 15 |
| `dotnet`  | 16 |
| `android` | 16 |
| `all`     | 18 |

Omitting the flag installs everything (`all`); `init-dotnet-project.sh` defaults
to `dotnet`.

### After init

1. Open Claude Code in the project and run `/fill-context`. It scans the codebase,
   asks what the code cannot tell it, and writes the `.claude/` context tree with
   the root `CLAUDE.md` as its index.
2. For a brand-new project, `/project-bootstrap` scaffolds the skeleton plus one
   vertical slice end to end.

### What gets committed

The context tree is team-shared instructions, so it belongs in source control.
The generated `.gitignore` excludes only what is machine-local or a symlink
into this stack:

| Committed | Ignored |
|-----------|---------|
| `CLAUDE.md` | `.claude/commands` (symlink) |
| `.claude/business/`, `architecture/`, `domains/`, `engineering/` | `.claude/agents` (symlink) |
| `.claude/settings.json` | `.claude/settings.local.json` |
| | `docs/brain` (symlink to the Obsidian vault) |

> [!IMPORTANT]
> Projects initialized before this change have a bare `.claude/` line in their
> `.gitignore`, which keeps the whole tree out of git. The init script detects it
> and tells you, but cannot fix it — a `.gitignore` entry added later cannot
> override a broader one already there. Remove the `.claude/` line by hand, then
> `git add .claude`.

> The index lives in the root `CLAUDE.md`, not `.claude/CLAUDE.md`. Claude Code
> auto-loads a project CLAUDE.md from either location, so the rule is not about
> which one gets read — it is about keeping one file instead of two that drift
> apart. The root is the convention and the one visible on clone.
>
> The files it links to (`.claude/business/*.md`, etc.) are read on demand, when
> a task leads Claude to them.

## Tooling

Four tools sit around this stack. They solve different problems and none
replaces another.

| Tool | Version | What it does |
|------|---------|--------------|
| **rtk** | 0.47 | CLI proxy that filters and summarizes command output *before* it reaches the context. `git`, `ls`, `find`, `rg`, `docker`, `dotnet`, `pnpm` and friends get rewritten transparently by a hook. 60-90% fewer tokens on routine dev operations. |
| **headroom** | 0.37 | Context optimization layer for LLM applications — a proxy that compresses traffic to the model, plus stored memories and a savings dashboard (`headroom savings`, `headroom dashboard`). |
| **claude-mem** | — | Persistent memory across sessions, captured by hooks with nothing to call. Prior work is injected as context when a session opens. |
| **[graphify](https://github.com/Graphify-Labs/graphify)** | 0.8 | Turns a codebase into a queryable knowledge graph — tree-sitter AST parsing across 37 languages, plus docs, SQL and PDFs. Ask `graphify query "..."` instead of grepping; `path A B` traces how two things connect, `affected X` finds what a change breaks. |

`rtk` trims what the tools send; `headroom` trims what reaches the model;
`claude-mem` remembers across sessions; `graphify` answers questions the code
can already answer, so the context tree does not have to. See
`PERSISTENT-MEMORY.md` for how claude-mem pairs with Obsidian.

Graphify writes to `graphify-out/` (`graph.json`, `graph.html`, and a
`GRAPH_REPORT.md` naming the god nodes — the entities everything else touches).
Every edge is tagged `EXTRACTED` when it is explicit in the source or
`INFERRED` when graphify resolved it, so derived structure stays separable from
fact. It runs offline for code; LLM calls happen only for the semantic pass over
docs and media. Keep `graphify-out/` out of version control.

> [!IMPORTANT]
> claude-mem records what happened, not why you decided it. Run `/sum` at the
> end of each work session so the reasoning lands in Obsidian too.

## Skills

18 skills across 4 categories. Each category directory has its own README with
one-line descriptions.

### `engineering/` (13)
Layer audits per stack — **audit-layer-boundaries** (web), **dotnet-clean-architecture**,
**android-clean-architecture** — plus **sdd-apply**, **prd-to-github-backlog**,
**project-bootstrap**, **fill-context**, **tdd**, **diagnose**,
**grill-with-docs**, **improve-codebase-architecture**,
**prompt-rewrite**, **sdd-verify**.

### `productivity/` (3)
**caveman**, **grill-me**, **handoff**.

`ponytail` is no longer vendored here — it is installed as a Claude Code plugin.

### `misc/` (1), `personal/` (1)
See [misc/README.md](./skills/misc/README.md) and [personal/README.md](./skills/personal/README.md).

## Agents

Installed at user level by `install-global.sh` (`global/agents/`). The main
session always runs as `software-architect`, which writes the feature code and
dispatches the rest as subagents: one prompt in, one report back.

| Agent | Role |
|-------|------|
| **software-architect** | Main session. Designs, implements, routes work to the others |
| **business-analyst** | Vague ask to spec plus Given/When/Then acceptance criteria |
| **code-reviewer** | Read-only. Reviews a diff against the AC and a code-quality spec |
| **security-auditor** | Read-only. Critical/high issues on auth and untrusted input |
| **debugger** | Root cause of a failing test or wrong behavior, minimal fix |
| **test-writer** | Behavioral tests in the project's existing framework |

## Key Files

| File | Purpose |
|------|---------|
| `init-project.sh` | Project setup, `--stack` aware |
| `init-dotnet-project.sh` | Same, for .NET Clean Architecture (defaults to `dotnet`) |
| `global-rules.md` | Global engineering standards |
| `PERSISTENT-MEMORY.md` | claude-mem + Obsidian memory guide |
| `OBSIDIAN-INTEGRATION.md` | Obsidian vault symlink bridge |
