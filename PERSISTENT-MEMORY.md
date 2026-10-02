# Persistent Memory Guide

This stack uses three memory layers. **claude-mem** captures what happens in the main session on its own. **engram** holds what subagents confirm and save. **Obsidian** holds what you deliberately write down. Between them, context survives across sessions.

---

## Overview

| Layer | System | Purpose | Trigger |
|-------|--------|---------|---------|
| **Automatic** | claude-mem | Main session: *"what we did last time"*, decisions, patterns | Hooks, with no action from you |
| **Subagent** | engram | Findings a subagent confirmed that outlive the diff (bugs in shared code, broken conventions) | The agent calls `mem_save` |
| **Deliberate** | Obsidian | ADRs, bug logs, domain knowledge | Human creates via `/mems` or `/sum` |

**The flow**: claude-mem records the main session on its own in the background. Subagents search engram before they work and save to it after. `/mems` and `/sum` write to Obsidian, which is the deliberate half — the notes you will actually reread.

---

## How They Complement Each Other

### claude-mem
- **Automatic**: observes the session through hooks — nothing to call, nothing to remember to do
- **Injected at startup**: prior work arrives as context when a session opens
- **Searchable**: earlier sessions can be queried by meaning, not just keywords
- **Not documented here**: it is a Claude Code plugin with its own docs. Run the
  `claude-mem:how-it-works` skill for how it captures and where it stores things.
  Duplicating that here would just rot.

### engram (subagents only)
- **Why it exists**: subagents can't write to claude-mem. Its MCP is read-only
  and it has no subagent hooks. engram exposes `mem_save` as an MCP tool, so a
  read-only reviewer (`disallowedTools: Write, Edit`) can still save.
- **Deliberate, not automatic**: nothing is captured unless the agent calls
  `mem_save`. Its `SubagentStop` passive capture stored nothing in testing, so
  don't count on it.
- **Who uses it**: only `code-reviewer` today. Its Memory section says: run
  `mem_search` (`match_mode: "any"`) before reviewing and treat hits as leads,
  not facts. After the verdict, `mem_save` each confirmed finding that outlives
  the diff, with a root-cause `topic_key`. Before saving under an existing key,
  read the full entry with `mem_get_observation` (search only returns previews)
  and keep every fact not re-verified as false.

**The split, on purpose**: the main session stays on claude-mem; subagents use
engram.
- For: nothing is lost (the claude-mem history stays), automatic capture keeps
  running, and it's cheap to reverse.
- Against: two memories, each knowing half. What the reviewer finds lives in
  engram, and the main session doesn't see it unless it searches there.

### Obsidian
- **Structured**: Notes organized in `ADR/`, `Bugs/`, `Learnings/`, etc.
- **Human-readable**: You can open Obsidian and read/write notes directly
- **Rich linking**: Wikilinks between notes, graphs, bidirectional references
- **Archival**: Long-term storage of architectural decisions

**Use both**: claude-mem catches what you would not have bothered to write down. Obsidian holds what deserves to be written down.

---

## Configuration

### 1. claude-mem

Installed as a Claude Code plugin; it needs no configuration here. See the
`claude-mem:how-it-works` skill.

### 2. engram

Not installed by `install-global.sh`; set it up once per machine:
```bash
brew install gentleman-programming/tap/engram
claude plugin enable engram@engram
engram setup claude-code      # registers the MCP: engram mcp --tools=agent
```
Tool names are `mcp__engram__mem_*`; that is what `code-reviewer.md` lists.

**Project resolution.** engram picks the project from the cwd, in this order:
`.engram/config.json` (source `config`), then the git remote name, then the git
root name. Watch out for:
- A folder holding several repos with no config resolves as **ambiguous**:
  searches error, and engram's hook denies every `mem_save`.
- A parent's config is **not inherited** by child repos. A child repo needs its
  own config, or it falls back to its remote name (e.g. a generic `api`).
- A session binds to a project on first use. A Bash `cd` elsewhere mid-session
  makes saves get denied or land in the wrong project. Use `git -C` and
  absolute paths instead.

For a product split across repos, use one project per product. Put the same
config in the root and in every child repo, and keep it out of git:
```bash
echo '{ "project_name": "<product>" }' > <root>/.engram/config.json   # and in each <root>/<repo>/
echo '.engram/' >> <root>/<repo>/.git/info/exclude                       # local, never committed
```
A repo added later needs both lines. Check the result with
`curl -s "http://127.0.0.1:7437/project/current?cwd=<dir>"`.

### 3. Obsidian vault

**Create the vault structure:**
```bash
# Your master vault location
~/Documents/Obsidian_Brain/

# Per-project structure
~/Documents/Obsidian_Brain/Projects/[Project-Name]/
├── ADR/           # Architecture Decision Records
├── Bugs/          # Bug logs with root causes
├── Docs/          # Technical documentation
├── Learnings/     # Insights and discoveries
├── Features/      # Feature implementations
├── Config/        # Environment and tool configurations
└── Index.md       # Hub file with links to all notes
```

**Link to each project:**
```bash
cd /your/project
mkdir -p docs
ln -s ~/Documents/Obsidian_Brain/Projects/your-project ./docs/brain
```

**Add to `.gitignore`:**
```
docs/brain/
```

---

## Workflows

### `/mems` — Save Individual Observations

Used to record a specific learning, decision, or bugfix. Writes to Obsidian.

**Command:**
```
/mems --title "Fixed N+1 query in OrderList" --type bugfix --what "Added eager loading" --why "Query was loading 100+ records per order" --where "src/queries/orders.ts" --tags "ef-core,performance"
```

**Arguments:**
| Arg | Required | Description |
|-----|----------|-------------|
| `--title` | Yes | Short, searchable title (e.g., "Fixed N+1 query in OrderList") |
| `--type` | Yes | bugfix, decision, architecture, discovery, pattern, config, preference |
| `--what` | Yes | One sentence — what was done |
| `--why` | Yes | What motivated it |
| `--where` | Yes | Files or paths affected |
| `--learned` | No | Gotchas, edge cases, surprises |
| `--scope` | No | project (default) or personal |
| `--tags` | No | Comma-separated tags |

**What happens:**
1. Detects project from `git rev-parse --show-toplevel`
2. Maps type to Obsidian subdirectory:
   - bugfix → `Bugs/`
   - decision, architecture → `ADR/`
   - discovery, pattern, preference → `Learnings/`
   - config → `Config/`
3. Creates note with frontmatter at:
   ```
   ~/Documents/Obsidian_Brain/Projects/[Project]/[Subdirectory]/[Title].md
   ```
4. Updates project's `Index.md` with wikilink

---

### `/sum` — Session Close Protocol

Used at the end of a session to capture the full context. Writes to Obsidian.

**Command:**
```
/sum --goal "User authentication flow" --discoveries "NextAuth session handling, cookie config" --accomplished "Added auth middleware, configured providers" --next "Add logout, test OAuth flow" --files "src/middleware.ts src/auth/config.ts" --tags "auth,nextauth"
```

**Arguments:**
| Arg | Required | Description |
|-----|----------|-------------|
| `--goal` | Yes | What you were working on |
| `--discoveries` | Yes | Technical findings, gotchas (comma-separated) |
| `--accomplished` | Yes | Completed items with key details (comma-separated) |
| `--next` | Yes | What remains to be done (comma-separated) |
| `--files` | Yes | List of files changed (space-separated) |
| `--tags` | No | Optional tags |

**What happens:**
1. Creates note at:
   ```
   ~/Documents/Obsidian_Brain/Projects/[Project]/Learnings/Session - [Date].md
   ```
2. Updates project's `Index.md`

---

## Searching Memory

### claude-mem (Automatic)
Claude searches it on its own when you ask things like:
- *"What did we work on last time?"*
- *"What decisions were made about authentication?"*

It does not see engram. For what subagents found, search engram directly:
`mem_search` from the session, or `engram search "<query>" --project <p> --match any`,
or browse it with `engram tui`. Same-file findings get flagged as conflicts.
Resolve them there, since the reviewer has no `mem_judge`.

### Obsidian (Manual)
Search with the `mems` skill, or directly:
```bash
# Search within current project
grep -rl "keyword" "$PROJECT_PATH" --include="*.md"

# Search across all projects
grep -rl "keyword" "$HOME/Documents/Obsidian_Brain/" --include="*.md"
```

---

## Obsidian Frontmatter Template

All notes created via `/mems` or `/sum` follow this structure:

```markdown
---
id: {{uuid}}
type: {{type}}
project: {{project}}
scope: {{scope}}
topic_key: {{type}}/{{slugified-title}}
session_id: {{session-id}}
created_at: {{timestamp}}
updated_at: {{timestamp}}
tags: [{{tags}}]
aliases: []
---

**What**: ...

**Why**: ...

**Where**: ...

**Learned**: ...
```

---

## Best Practices

### Always run `/sum` at the end of every work session

A "work session" is a continuous period of collaboration — not necessarily a single prompt. Think of it as: *"I'm done with this task/feature/bug fix"*.

**When to run `/sum`:**
- After completing a feature or significant code change
- Before switching to a different task or context
- At the end of your coding session, even if you didn't finish
- Before ending the conversation or closing the editor

**Why this matters:**
- claude-mem records what happened, but not why you chose it — that part only
  exists if you write it
- `/sum` is what leaves a note you can reread months later
- Obsidian is the archival half: ADRs and bug logs outlive any session history

**Recommended frequency**: At least once per feature/task, not just once per day.

---

## Key Files

| File | Purpose |
|------|---------|
| `skills/personal/mems/SKILL.md` | Full skill definition with all workflows |
| `OBSIDIAN-INTEGRATION.md` | Legacy Obsidian setup guide |
| `global-rules.md` | Global rules including memory protocol |