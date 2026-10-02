#!/usr/bin/env bash
# Installs the user-level layer once per machine: the agent team in
# global/agents/, the skills every session needs, and the main-session agent.
# Safe to re-run. Respects CLAUDE_CONFIG_DIR (defaults to ~/.claude).
set -euo pipefail

STACK_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$STACK_DIR/global/agents"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
AGENTS="$CLAUDE_DIR/agents"
SETTINGS="$CLAUDE_DIR/settings.json"
MAIN_AGENT="software-architect"

command -v jq >/dev/null || { echo "jq is required: brew install jq" >&2; exit 1; }
[ -f "$SRC/$MAIN_AGENT.md" ] || { echo "Missing $SRC/$MAIN_AGENT.md" >&2; exit 1; }
mkdir -p "$CLAUDE_DIR"

# 1. Agents: ~/.claude/agents -> global/agents (a real directory is backed up, never deleted)
if [ -L "$AGENTS" ] && [ "$(readlink "$AGENTS")" = "$SRC" ]; then
    echo "agents: already linked"
else
    if [ -e "$AGENTS" ] && [ ! -L "$AGENTS" ]; then
        BACKUP="$AGENTS.bak-$(date +%Y%m%d-%H%M%S)"
        mv "$AGENTS" "$BACKUP"
        echo "agents: existing directory moved to $BACKUP"
    fi
    ln -sfn "$SRC" "$AGENTS"
    echo "agents: $AGENTS -> $SRC"
fi

# 2. Skills available in every session, not only in init'ed projects.
#    A real directory with the same name is left alone (it is not ours to replace).
GLOBAL_SKILLS=(
    engineering/fill-context
    engineering/prd-to-github-backlog
    engineering/prompt-rewrite
    engineering/sdd-apply
    engineering/sdd-verify
    productivity/grill-me
    productivity/handoff
)
mkdir -p "$CLAUDE_DIR/skills"
LINKED=0
for s in "${GLOBAL_SKILLS[@]}"; do
    dest="$CLAUDE_DIR/skills/$(basename "$s")"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        echo "skills: $dest is a real directory, skipped"
        continue
    fi
    ln -sfn "$STACK_DIR/skills/$s" "$dest"
    LINKED=$((LINKED + 1))
done
echo "skills: $LINKED linked into $CLAUDE_DIR/skills"

# 3. Main-session agent: merge one key, keep everything else in settings.json
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
if [ "$(jq -r '.agent // empty' "$SETTINGS")" = "$MAIN_AGENT" ]; then
    echo "settings: agent already $MAIN_AGENT"
else
    TMP="$(mktemp)"
    jq --arg a "$MAIN_AGENT" '.agent = $a' "$SETTINGS" > "$TMP"
    cat "$TMP" > "$SETTINGS"   # write in place: keeps permissions and any symlink
    rm -f "$TMP"
    echo "settings: agent set to $MAIN_AGENT"
fi

# 4. MCP servers hold tokens in ~/.claude.json, so they are never scripted here.
cat <<'EOF'

MCP servers (run by hand, once per machine):

  # context7: an API key is optional (higher rate limits), add it with --header "CONTEXT7_API_KEY: <key>"
  claude mcp add --scope user --transport http context7 https://mcp.context7.com/mcp

  # GitHub: fine-grained PAT, read-only Contents/Issues/PRs. Do not use `read -s`, the paste breaks.
  read "GH?Paste PAT: " && [[ $GH == github_pat_* ]] && claude mcp add --scope user --transport http github https://api.githubcopilot.com/mcp --header "Authorization: Bearer ${GH//[[:space:]]/}"; unset GH; clear

  claude mcp list   # both should show Connected
EOF
