#!/bin/bash

# Resolves the absolute path to the directory containing this script
STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTNET_SKILLS_DIR="$HOME/dev/dotnet-clean-architecture-skills"
# Parse args: optional target dir, plus --stack=all|web|dotnet|android
STACK="dotnet"
POSITIONAL=()
for arg in "$@"; do
    case "$arg" in
        --stack=*) STACK="${arg#--stack=}" ;;
        -h|--help)
            echo "usage: init-dotnet-project.sh [target-dir] [--stack=all|web|dotnet|android]"
            exit 0 ;;
        *) POSITIONAL+=("$arg") ;;
    esac
done
case "$STACK" in
    all|web|dotnet|android) ;;
    *) echo "ERROR: Unknown stack '$STACK'. Use: all, web, dotnet, android"; exit 1 ;;
esac

TARGET_DIR="${POSITIONAL[0]:-$(pwd)}"
PROJECT_NAME="$(basename "$TARGET_DIR")"

# --- stack filtering -------------------------------------------------------
# Returns 0 if the file's `stacks:` frontmatter includes $STACK (or "all").
stack_match() {
    [ "$STACK" = "all" ] && return 0
    local line
    # -a: some SKILL.md files contain stray control bytes, and without it grep
    # answers "Binary file ... matches" instead of the line.
    line="$(grep -a -m1 '^stacks: \[' "$1")" || return 1
    case "$line" in
        *all*|*"$STACK"*) return 0 ;;
        *) return 1 ;;
    esac
}

# Symlinks every matching skill into $1.
link_stack_skills() {
    local dest="$1" cat skill name
    LINKED_SKILLS=0
    STACK_SKILLS=()
    if [ -L "$dest" ]; then
        echo "WARNING: $dest is your own symlink, not linking stack skills into it."
        return
    fi
    mkdir -p "$dest"
    for cat in "$STACK_DIR/skills"/*/; do
        for skill in "$cat"*/; do
            [ -f "${skill}SKILL.md" ] || continue
            stack_match "${skill}SKILL.md" || continue
            name="$(basename "$skill")"
            case " ${STACK_SKILLS[*]} " in
                *" $dest/$name "*)
                    echo "WARNING: two skills named '$name', skipping ${skill%/}."
                    continue ;;
            esac
            if { [ -e "$dest/$name" ] || [ -L "$dest/$name" ]; } && ! is_stack_link "$dest/$name"; then
                echo "WARNING: $dest/$name is yours, not a stack link, skipping."
                if grep -qxF -- "$dest/$name" .gitignore 2>/dev/null; then
                    echo "    It is still in .gitignore, remove that line to commit it."
                fi
                continue
            fi
            ln -sfn "${skill%/}" "$dest/$name"
            STACK_SKILLS+=("$dest/$name")
            LINKED_SKILLS=$((LINKED_SKILLS + 1))
        done
    done
}

# A link belongs to the stack when it points into this repo, or when it is
# broken (left behind after the stack repo moved). Anything else is the user's.
is_stack_link() {
    [ -L "$1" ] || return 1
    case "$(readlink "$1")" in
        "$STACK_DIR"/*) return 0 ;;
    esac
    [ ! -e "$1" ]
}

drop_stack_links() {
    local path="$1" link
    if [ -L "$path" ]; then
        if is_stack_link "$path"; then
            rm -f "$path"
        else
            echo "WARNING: $path is your own symlink, leaving it."
        fi
        return
    fi
    [ -d "$path" ] || return 0
    find "$path" -type l -print0 | while IFS= read -r -d '' link; do
        is_stack_link "$link" || continue
        rm -f "$link"
        rmdir -p "$(dirname "$link")" 2>/dev/null || true
    done
}


echo "Initializing .NET AI Stack for project: $PROJECT_NAME at $TARGET_DIR"

mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR" || { echo "Failed to cd to $TARGET_DIR"; exit 1; }

# 1. Setup Claude Code symlinks
mkdir -p .claude .agents

# Remove old links, including names used before the Claude-Code-only migration.
# .claude/agents held per-project agent links; agents now live at user level (install-global.sh).
drop_stack_links .claude/commands
drop_stack_links .claude/agents
drop_stack_links .claude/skills
drop_stack_links .agents/skills
rm -f .claude/personas .claude/recipes
rm -f .agents/personas .agents/agents .agents/recipes

link_stack_skills ".claude/skills"

# The external .NET skills repo carries no stacks: frontmatter — it is all .NET
# by definition, so it links wholesale.
mkdir -p .claude/commands
if [ -e .claude/commands/dotnet ] && [ ! -L .claude/commands/dotnet ]; then
    echo "WARNING: .claude/commands/dotnet is not a symlink, skipping."
else
    ln -sfn "$DOTNET_SKILLS_DIR/skills" ".claude/commands/dotnet"
fi
ln -s "$DOTNET_SKILLS_DIR/recipes" ".claude/recipes"
echo "OK: Linked $LINKED_SKILLS skills for stack '$STACK', plus the .NET skills repo"

# 2. Setup .claude/ context subdirectories
for context_dir in .claude/business .claude/architecture .claude/domains .claude/engineering; do
    mkdir -p "$context_dir"
done
echo "OK: Created .claude/ context subdirectories"

# 5. Gitignore
# Ignore only what is machine-local or a symlink into the stack. The context
# tree (.claude/business, architecture, domains, engineering) and the root
# CLAUDE.md are team-shared instructions and MUST stay in source control.
GITIGNORE_ENTRIES=(
    ".claude/commands/dotnet"
    ".claude/recipes"
    ".claude/settings.local.json"
    ".agents/"
    "graphify-out/"
    "GEMINI.md"
    "${STACK_SKILLS[@]}"
)

if [ ! -f ".gitignore" ]; then
    touch ".gitignore"
    echo "OK: Created .gitignore"
fi

# Add header only if it doesn't exist
HEADER="# AI Engineering Stack"
if ! grep -q "$HEADER" ".gitignore"; then
    echo -e "\n$HEADER" >> ".gitignore"
fi

for entry in "${GITIGNORE_ENTRIES[@]}"; do
    if ! grep -qxF -- "$entry" ".gitignore"; then
        echo "$entry" >> ".gitignore"
        echo "OK: Added $entry to .gitignore"
    else
        echo "WARNING: $entry already in .gitignore, skipping."
    fi
done
# Clean up potential double newlines
sed -i '' '/^$/N;/^\n$/D' ".gitignore" 2>/dev/null || true

if grep -qxE '\.claude/(commands|agents)/?' ".gitignore"; then
    echo "WARNING: .gitignore still has '.claude/commands' or '.claude/agents' from an"
    echo "    older init. Skills now live in .claude/skills, so remove those lines if"
    echo "    you keep your own commands or agents there."
fi

# A project initialized before the context tree was versioned still has a bare
# ".claude/" line, which keeps ignoring everything under it. Say so — the entries
# added above cannot override it.
if grep -qE '^\.claude/?$' ".gitignore"; then
    echo "WARNING: .gitignore still has a bare '.claude/' entry — it ignores the whole"
    echo "    context tree. Remove that line so .claude/business, architecture,"
    echo "    domains and engineering get committed."
fi

# 6. Global & Editor Rules
RULE_CONTENT="Always adhere to the global engineering standards defined in the symlinked AI stack, and read the root CLAUDE.md before proceeding. Note: This project uses .NET Clean Architecture skills and recipes."

# General Agents Rules
if [ -d ".agents" ] && [ ! -f ".agents/rules.md" ]; then
    echo "$RULE_CONTENT" > ".agents/rules.md"
    echo "OK: Created .agents/rules.md"
fi

# 7. Setup Claude Code settings.json
# Claude Code auto-loads the root CLAUDE.md natively — no hook needed for context
if [ ! -f ".claude/settings.json" ]; then
    cat > ".claude/settings.json" <<'EOF'
{
  "hooks": {}
}
EOF
    echo "OK: Created .claude/settings.json"
else
    echo "WARNING: .claude/settings.json already exists, skipping."
fi

# 8. Setup GEMINI.md (auto-loaded by Gemini CLI, imports CLAUDE.md)
if [ ! -f "GEMINI.md" ]; then
    cat > "GEMINI.md" <<'EOF'
@CLAUDE.md
EOF
    echo "OK: Created GEMINI.md"
else
    echo "WARNING: GEMINI.md already exists, skipping."
fi

# 9. Setup root CLAUDE.md as context index
# Claude Code auto-loads a project CLAUDE.md from ./CLAUDE.md OR ./.claude/CLAUDE.md.
# Both work; the root keeps it to a single instruction file, and it is the convention.
if [ ! -f "CLAUDE.md" ]; then
    cat > "CLAUDE.md" <<EOF
# $PROJECT_NAME — Claude Code Instructions

> Read the linked files for domain, architecture, and business context before proposing changes or adding new entities.
> **Context not yet generated.** Run \`/fill-context\` in Claude Code to populate the sections below.
> **.NET Clean Architecture**: Refer to \`.claude/recipes\` for backend workflows.

## Business
- [Overview](.claude/business/overview.md) — Purpose, users, success metrics
- [Rules](.claude/business/rules.md) — Non-negotiable business rules
- [Glossary](.claude/business/glossary.md) — Ubiquitous language

## Architecture
- [Overview](.claude/architecture/overview.md) — Stack, patterns, layer boundaries
- [Integrations](.claude/architecture/integrations.md) — External services and APIs

## Domains
*(Generated by \`/fill-context\`)*

## Engineering
- [Standards](.claude/engineering/standards.md) — Coding conventions and patterns
- [Testing](.claude/engineering/testing.md) — Test strategy and commands

---

## Commands

\`\`\`bash
dotnet build         # Build project
dotnet test          # Run tests
\`\`\`
EOF
    echo "OK: Created CLAUDE.md"
else
    echo "WARNING: CLAUDE.md already exists, skipping."
fi

# 10. Commit message hook. It lives only in this stack: the repo gets local,
# untracked config pointing at it, and no file is copied into the project.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    HOOKS_DIR="$STACK_DIR/global/githooks"
    HOOKS_PATH="$(git config --local core.hooksPath)"
    # core.hooksPath replaces .git/hooks entirely, so never switch it over live hooks.
    LIVE_HOOK="$(find "$(git rev-parse --git-path hooks)" -type f ! -name '*.sample' 2>/dev/null | head -1)"
    if [ "$HOOKS_PATH" = "$HOOKS_DIR" ]; then
        echo "OK: core.hooksPath already points to the stack hooks"
    elif [ -n "$HOOKS_PATH" ]; then
        echo "WARNING: core.hooksPath is '$HOOKS_PATH' (husky?). Not overriding it; call $HOOKS_DIR/commit-msg from there."
    elif [ -n "$LIVE_HOOK" ]; then
        echo "WARNING: .git/hooks has live hooks that core.hooksPath would disable. Not enabling the commit-msg hook."
    else
        git config core.hooksPath "$HOOKS_DIR"
        echo "OK: Enabled commit-msg hook (core.hooksPath -> $HOOKS_DIR)"
    fi
else
    echo "WARNING: Not a git repository, skipping the commit-msg hook. Run git init, then re-run this script."
fi

echo ""
echo ".NET Initialization complete for $PROJECT_NAME!"
echo ""
echo "Next step: open Claude Code in this project and run:"
echo "   /fill-context"
echo "   The AI will scan the codebase and ask 3 questions to generate your context tree."
