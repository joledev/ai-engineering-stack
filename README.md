# AI Engineering Stack

A personal Claude Code harness: a 7-agent team, 17 skills and the scripts that
wire them into any project. Clone it once, run one script per machine and one
per project, and every Claude Code session works the same way, with the same
rules, the same reviewers and the same delivery loop.

There is no application here. It is markdown and bash.

**Claude Code only.** Support for Windsurf, OpenCode and other editors was
removed. Everything targets Claude Code's own conventions (`.claude/skills/`,
`~/.claude/agents/`, root `CLAUDE.md`).

```
  ~/.claude/  (global layer, once per machine)        your-project/  (per project)
  ┌──────────────────────────────────────┐            ┌──────────────────────────────────┐
  │ agents/   -> global/agents/          │            │ .claude/skills/<name> -> skills/  │
  │ skills/   -> 7 everyday skills       │            │   (filtered by --stack)           │
  │ settings.json  agent: architect      │            │ CLAUDE.md + .claude/ context tree │
  │ statusline-command.sh                │            │ core.hooksPath -> commit-msg hook │
  └──────────────────────────────────────┘            └──────────────────────────────────┘
          install-global.sh                                   init-project.sh
```

## Contents

- [Quick start](#quick-start)
- [What's inside](#whats-inside): agents, skills
- [Global layer](#global-layer-once-per-machine)
- [Per-project installation](#per-project-installation)
- [Tooling](#tooling)
- [Roadmap](#roadmap)
- [Credits and sources](#credits-and-sources)
- [Key files](#key-files)

## Quick start

```bash
git clone <this-repo> ~/dev/personal/ai-engineering-stack

# Once per machine
~/dev/personal/ai-engineering-stack/install-global.sh

# Once per project
~/dev/personal/ai-engineering-stack/init-project.sh ~/dev/my-app --stack=web
```

Then open Claude Code in the project and run `/fill-context`.

## What's inside

### Agents

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
| **design-auditor** | Read-only. Audits iOS screens (PNGs + tokens) for design-loop: Nielsen, HIG, computed contrast |

### Skills

17 skills across 4 categories. Each category directory has its own README:
[engineering](./skills/engineering/README.md),
[productivity](./skills/productivity/README.md),
[ui](./skills/ui/README.md), [misc](./skills/misc/README.md).
The **Origin** column is detailed in [Credits and sources](#credits-and-sources).

| Skill | Stacks | What it does | Origin |
|-------|--------|--------------|--------|
| **sdd-apply** | all | Implements a GitHub Story and its Tasks: explore, propose, apply, verify, commit, PR | Own |
| **sdd-verify** | all | Checks an implementation against its acceptance criteria in a fresh code-reviewer | Own |
| **prd-to-github-backlog** | all | PRD to GitHub Project: epics, stories, tasks, sprints, estimates | Own |
| **fill-context** | all | Scans the codebase and interviews you to write the `.claude/` context tree | Own |
| **prompt-rewrite** | all | Audits a skill, agent or prompt against Anthropic's prompting docs | Adapted |
| **tdd** | all | Red-green-refactor loop | mattpocock/skills |
| **diagnose** | all | Reproduce, minimise, hypothesise, instrument, fix, regression-test | mattpocock/skills |
| **improve-codebase-architecture** | all | Finds deepening opportunities using CONTEXT.md and ADRs | mattpocock/skills |
| **audit-layer-boundaries** | web | Scans for the three violations that break the layer contract | Own |
| **dotnet-clean-architecture** | dotnet | Scans a .NET Clean Architecture solution for dependency-rule violations | Own |
| **android-clean-architecture** | android | Clean Architecture patterns and a layer scan for Android/KMP | Own |
| **project-bootstrap** | dotnet, android | Skeleton plus one vertical slice end to end | Own |
| **design-loop** | ios | Claude Design style loop for screens: variants, iterate, audit, apply. Setup: [DESIGN-PIPELINE.md](./DESIGN-PIPELINE.md) | Own, rules adapted |
| **grill-me** | all | Interviews you about a plan until every branch is resolved | mattpocock/skills |
| **handoff** | all | Session handoff document, copied to the clipboard | Own |
| **caveman** | all | Ultra-compressed replies, ~75% fewer tokens | JuliusBrussee/caveman |
| **git-guardrails-claude-code** | all | Hooks that block destructive git commands. Not used (see Guardrails) | mattpocock/skills |

`ponytail` is no longer vendored here. It is installed as a Claude Code plugin.

## Global layer (once per machine)

```bash
~/dev/personal/ai-engineering-stack/install-global.sh
```

- Symlinks `~/.claude/agents` to `global/agents/`.
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
- Checks engram and ego-browser and prints their install commands when missing.

Safe to re-run. Agents update with `git pull`, since they are a symlink.

### Guardrails (user level, not installed by this repo)

These live in `~/.claude/` and are set by hand. `install-global.sh` does not touch them.

- **No Bash sandbox.** Removed: it broke `pbcopy` (`/handoff`) and other projects.
  Permission rules are the only barrier left.
- **Deny rules** in `~/.claude/settings.json`: `Read`/`Edit` of `.env*` anywhere
  (`//**/.env*`) and of `~/.ssh/**`; `git push --force`/`-f`, including the
  `git -C <dir>` form; `rm -rf /*` and `rm -rf ~*`.
- **Ask rules** for commands that destroy uncommitted work: `git reset --hard`,
  `clean -f`, `branch -D`, `checkout .`, `restore .`, each with its `git -C` form.
- Commit messages are checked by the git `commit-msg` hook that init installs
  per project (see "Commit message hook" below), not by a Claude Code hook.

Known gaps:

- `Read`/`Edit` rules cover only those tools. `cat .env` from Bash is not
  blocked; the risk is accepted.
- Bash rules match the start of the command text. Every rule needs a `git -C`
  variant, because the agent is told to use `git -C` instead of `cd`.
- `skills/misc/git-guardrails-claude-code` is not used: it blocks every
  `git push`, which `sdd-apply` needs to open PRs.

## Per-project installation

Use the init script rather than symlinking by hand. It wires the symlinks, the
context tree, the gitignore entries, and the commit-msg hook in one pass.

```bash
# Web / Next.js project
~/dev/personal/ai-engineering-stack/init-project.sh ~/dev/my-app --stack=web

# .NET Clean Architecture project
~/dev/personal/ai-engineering-stack/init-dotnet-project.sh ~/dev/my-api

# Android / Kotlin project
~/dev/personal/ai-engineering-stack/init-project.sh ~/dev/my-app --stack=android

# iOS / SwiftUI project
~/dev/personal/ai-engineering-stack/init-project.sh ~/dev/my-app --stack=ios
```

### `--stack`: install only what the project needs

Every skill declares a `stacks:` field in its frontmatter, and the init
script links only the matching ones. An Android project has no use for
`audit-layer-boundaries`. Agents are not per project: see Global layer.

| `--stack` | skills |
|-----------|--------|
| `web`     | 13 |
| `dotnet`  | 14 |
| `android` | 14 |
| `ios`     | 13 |
| `all`     | 17 |

Omitting the flag installs everything (`all`); `init-dotnet-project.sh` defaults
to `dotnet`.

### Commit message hook

The hook lives only here, in `global/githooks/commit-msg`. Init points the
project at it with local git config, so nothing is copied or committed into
the work repo:

```bash
git config core.hooksPath ~/dev/personal/ai-engineering-stack/global/githooks
```

The hook rejects a subject that is neither conventional (`fix(scope): ...`) nor
ticket-first (`OG-4703: ...`). It is POSIX `sh` plus `grep -E`.

- It enforces your own commits on this machine, not the team's. Teammates
  and CI never see it.
- For a repo not set up by init (client or team repo), run the `git config`
  line above in it. `git pull` here updates the hook for every repo at once.
- Init does not change `core.hooksPath` when the repo already sets one (husky)
  or has live scripts in `.git/hooks/`, since the switch would disable them.
- Not a git repo yet: init skips the hook. Run `git init`, then init again.
- Undo in a repo: `git config --unset core.hooksPath`.

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
| `CLAUDE.md` | `.claude/skills/<skill>` (one symlink per skill) |
| `.claude/business/`, `architecture/`, `domains/`, `engineering/` | |
| `.claude/settings.json` | `.claude/settings.local.json` |

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

Seven tools sit around this stack. They solve different problems and none
replaces another.

| Tool | Version | What it does |
|------|---------|--------------|
| **rtk** | 0.47 | CLI proxy that filters and summarizes command output *before* it reaches the context. `git`, `ls`, `find`, `rg`, `docker`, `dotnet`, `pnpm` and friends get rewritten transparently by a hook. 60-90% fewer tokens on routine dev operations. |
| **headroom** | 0.37 | Context optimization layer for LLM applications — a proxy that compresses traffic to the model, plus stored memories and a savings dashboard (`headroom savings`, `headroom dashboard`). |
| **claude-mem** | — | Persistent memory for the main session, captured by hooks with nothing to call. Prior work is injected as context when a session opens. |
| **[engram](https://github.com/Gentleman-Programming/engram)** | 3.0 | Memory for subagents. `code-reviewer`, `debugger` and `security-auditor` search it before working and save confirmed findings through MCP (`mem_search`, `mem_save`), since it can't write files and claude-mem is read-only to subagents. |
| **[ego-browser](https://github.com/citrolabs/ego-lite)** | 2.0 | Browser for agents (ego lite app + skill, macOS). `sdd-verify` uses it in web projects to check acceptance criteria that are visible in the UI; without it those criteria stay `~ PARTIAL`. Install: `npx skills add citrolabs/ego-lite -g -a claude-code`. |
| **[graphify](https://github.com/Graphify-Labs/graphify)** | 0.8 | Turns a codebase into a queryable knowledge graph — tree-sitter AST parsing across 37 languages, plus docs, SQL and PDFs. Ask `graphify query "..."` instead of grepping; `path A B` traces how two things connect, `affected X` finds what a change breaks. |
| **[ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)** | 2.13 | Local design database (font pairings, palettes, UX rules, SwiftUI guidelines) with a stdlib-only Python search script. `design-loop` calls its `--domain` lookups in the design phase; without it the loop runs and skips them. Install as a plugin, one command at a time: `/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill`, then `/plugin install ui-ux-pro-max@ui-ux-pro-max-skill`. |

`rtk` trims what the tools send; `headroom` trims what reaches the model;
`claude-mem` remembers the main session; `engram` remembers what subagents
found; `graphify` answers questions the code can already answer, so the context
tree does not have to. The two memories are split on purpose and don't see each
other. See `PERSISTENT-MEMORY.md` for the split and the engram setup.

Graphify writes to `graphify-out/` (`graph.json`, `graph.html`, and a
`GRAPH_REPORT.md` naming the god nodes — the entities everything else touches).
Every edge is tagged `EXTRACTED` when it is explicit in the source or
`INFERRED` when graphify resolved it, so derived structure stays separable from
fact. It runs offline for code; LLM calls happen only for the semantic pass over
docs and media. Keep `graphify-out/` out of version control.

## Roadmap

Pending, in order:

1. **Telemetry.** `tools/telemetry.py` (Python stdlib, no deps) reading
   `~/.claude/projects/*/*.jsonl`: skills fired (and never fired), agents
   dispatched, failed tool calls, tokens per project. Complements
   `claude-mem:agent-cost-report` (cost) and `rtk gain` (token savings). Its
   output decides which plugins and skills to prune.
2. **Evals.** A fixture repo with seeded bugs; run `code-reviewer` headless
   (`claude -p --output-format json`) three times and score bugs found against
   the bare model. Then `sdd-apply` on a task with pre-written tests. Re-run
   after every prompt rewrite of an agent.

Small cleanups:

- Remove `skills/misc/git-guardrails-claude-code`: it blocks every `git push`,
  which `sdd-apply` needs, so it is not used (see Guardrails).
- Decide whether the commit-msg hook accepts a `release:` type. Today it
  rejects it.
- Repos that use husky skip the stack hook (init leaves `core.hooksPath`
  alone). Wire `global/githooks/commit-msg` from `.husky/` where it matters.

## Credits and sources

This stack stands on other people's work. Vendored skills keep their upstream
structure; adapted ones say in their own file what changed and why.

### Skills taken from upstream

| Source | License | What we took |
|--------|---------|--------------|
| [mattpocock/skills](https://github.com/mattpocock/skills) | MIT | `tdd`, `diagnose` (upstream now `diagnosing-bugs`), `improve-codebase-architecture`, `grill-me`, `git-guardrails-claude-code` |
| [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) | MIT | `caveman`, copied in May 2026, before upstream moved to Apache-2.0 in 3.0.0. Its license ships in [skills/productivity/caveman/LICENSE](./skills/productivity/caveman/LICENSE). Only change: the `stacks:` field |

### Inspiration and adapted rules

| Source | Used in | What we took |
|--------|---------|--------------|
| [mattpocock/skills](https://github.com/mattpocock/skills) | The own skills | The skill format: one focused job, a trigger-first `description`, short imperative steps |
| [NeoLabHQ/context-engineering-kit](https://github.com/NeoLabHQ/context-engineering-kit/tree/master/agents) | `global/agents/` | Role split and reviewer discipline (architect, business-analyst, code-reviewer, security-auditor). Left out its threat prompting and its developer/tech-lead split. Details in `software-architect.md` |
| [rubentanahara/claude-code-config-devtalk](https://github.com/rubentanahara/claude-code-config-devtalk) | `prompt-rewrite` | Skill structure, minus two rules that conflict with Anthropic's docs |
| [Anthropic prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) | `prompt-rewrite`, all agents | The rules every prompt is checked against |
| [wondelai/skills](https://github.com/wondelai/skills), [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill), Apple HIG, [WCAG 2.1](https://www.w3.org/TR/WCAG21/) | `design-loop`, `design-auditor` | Audit rules rewritten for iOS. Full table, with what was left out and why: [skills/ui/README.md](./skills/ui/README.md#sources) |
| John Ousterhout, *A Philosophy of Software Design* | `improve-codebase-architecture` | "Design It Twice" for exploring alternative interfaces |

### Tools

[rtk](https://github.com/rtk-ai/rtk), headroom, claude-mem,
[engram](https://github.com/Gentleman-Programming/engram),
[ego-browser](https://github.com/citrolabs/ego-lite),
[graphify](https://github.com/Graphify-Labs/graphify),
[ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)
and the `ponytail` plugin. See [Tooling](#tooling).

## Key files

| File | Purpose |
|------|---------|
| `install-global.sh` | User-level setup, once per machine |
| `init-project.sh` | Project setup, `--stack` aware |
| `init-dotnet-project.sh` | Same, for .NET Clean Architecture (defaults to `dotnet`) |
| `global/agents/` | The 7-agent team |
| `global/githooks/commit-msg` | Commit message hook, referenced via `core.hooksPath` |
| `global-rules.md` | Global engineering standards |
| `PERSISTENT-MEMORY.md` | claude-mem + engram memory guide |
| `DESIGN-PIPELINE.md` | Setting up `/design-loop` in a project: OpenPencil, fonts, pipeline keys |
