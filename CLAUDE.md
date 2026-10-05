# ai-engineering-stack

The Claude Code harness itself: skills, agents, and the init scripts that wire
them into a project. There is no application here — it is markdown and bash.

## Layout

```
skills/<category>/<name>/SKILL.md   17 skills across 4 categories
global/agents/<name>.md             7-agent team, user-level (all projects)
init-project.sh                     project setup, --stack aware
init-dotnet-project.sh              same, for .NET (defaults to --stack=dotnet)
install-global.sh                   user-level setup, once per machine
global/statusline-command.sh        statusline, linked by install-global.sh
global/githooks/commit-msg          commit message hook; repos point at it via core.hooksPath, never copied
global-rules.md                     engineering standards shipped to projects
```

Each skill is symlinked into a target project as `.claude/skills/<skill>` by the init scripts. There are no per-project agents.

`global/agents/` is symlinked as `~/.claude/agents` by `install-global.sh`, which
also sets `"agent": "software-architect"` in `~/.claude/settings.json`. That
setting applies to every session, including folders never init'ed, so the
architect must live at user level.

## Commands

```bash
./init-project.sh <dir> --stack=all|web|dotnet|android|ios
./init-dotnet-project.sh <dir>
bash -n init-project.sh              # syntax check
```

There is no build, no test runner, and no package.json. To verify a change to
the init scripts, run them against a scratch directory and inspect the result —
they create real symlinks and set real git config, so use a throwaway path
and clean up after.

## Conventions

**Every skill declares `stacks:` in its frontmatter.** The init
scripts read it and link only what matches `--stack`, so a .NET project does
not receive `audit-layer-boundaries`. Valid values: `all`, `web`, `dotnet`, `android`, `ios`. `all`
is exclusive — never combine it with another value.

```yaml
---
name: my-skill
stacks: [web]
description: One line. This is what makes Claude load the skill, so say when to use it.
---
```

A skill with no `description` is never surfaced. A skill with no `stacks:` is
silently dropped from every filtered install.

Agents in `global/agents/` have no `stacks:`. Nothing filters them; every
machine gets the whole team.

**Claude Code only.** Support for Windsurf and OpenCode was removed; do not
reintroduce `.windsurf/`, `.opencode/` or their rules files.

**Category READMEs must match the directory.** `skills/engineering/`,
`productivity/`, `ui/` and `misc/` each have a README listing their skills. Adding or removing a
skill means updating it in the same commit.

## Context

This repo has no `.claude/` context tree — `/fill-context` has never run here,
and for a repo this small the file you are reading is the whole context.

Project-level docs: `README.md` (installation and inventory),
`PERSISTENT-MEMORY.md` (claude-mem + engram), `DESIGN-PIPELINE.md` (setting up `/design-loop`).
