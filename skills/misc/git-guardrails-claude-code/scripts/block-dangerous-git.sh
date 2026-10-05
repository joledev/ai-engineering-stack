#!/bin/bash
# PreToolUse hook. Exit 2 blocks the Bash call; every path that can't read the
# command must exit 2 too, or the hook fails open.
INPUT=$(cat)

unreadable() {
  echo "BLOCKED: git-guardrails couldn't read the command from the hook input. $1" >&2
  exit 2
}

command -v jq >/dev/null || unreadable "It needs jq (macOS 15+ ships it; otherwise: brew install jq / apt install jq / winget install jqlang.jq)."
COMMAND=$(printf '%s' "$INPUT" | jq -er '.tool_input.command | strings' 2>/dev/null) || unreadable
[[ -n $COMMAND ]] || unreadable

block() {
  echo "BLOCKED: '$COMMAND' runs $1. The user has prevented you from doing this." >&2
  exit 2
}

# Normalize: join line continuations, drop quoting and escapes (\git, "git", pu\sh),
# then split on every shell separator so each git call starts its own segment.
flatten() { tr -d "\\\\\"'" | tr ';&|()`<>{}!\t' '\n\n\n\n\n\n\n\n\n\n\n '; }
JOINED=${COMMAND//$'\\\n'/}
JOINED=${JOINED//'${IFS}'/ }
JOINED=${JOINED//'$IFS'/ }
TEXT=$(printf '%s' "$JOINED" | flatten)
# Second view that keeps quoted words whole (git -C "/a b" push): spaces inside
# quotes become \001 before the quotes are dropped.
KEPT=$(printf '%s' "$JOINED" | awk '{
  out = ""
  for (i = 1; i <= length($0); i++) {
    c = substr($0, i, 1)
    if (q == "" && (c == "\"" || c == "\047")) { q = c; continue }
    if (c == q) { q = ""; continue }
    if (q != "" && (c == " " || c == "\t")) c = "\001"
    out = out c
  }
  print out
}' | flatten)

FLAG_F='[[:space:]](-[a-zA-Z]*f[a-zA-Z]*|--f|--fo|--for|--forc|--force)[[:space:]]'
ALL_FILES='[[:space:]](\.|\./|\.\.|:/|\*)[[:space:]]'

DEPTH=0
# aliases holds the -c alias.* values of the git call being checked; reset per call.
check() {
  local rest=$1 sub args a v
  while :; do
    if [[ $rest =~ ^[[:space:]]+(-C|-c)[[:space:]]+([^[:space:]]+)(.*)$ ]]; then
      [[ ${BASH_REMATCH[1]} == -c ]] && aliases+=("${BASH_REMATCH[2]}")
      rest=${BASH_REMATCH[3]}
    elif [[ $rest =~ ^[[:space:]]+--[^=[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)(.*)$ ]]; then
      # A long option followed by a word: the word is either its value
      # (--git-dir x, --shallow-file x) or the subcommand (--no-pager push).
      # Check the subcommand reading, then continue with the value reading.
      rest=${BASH_REMATCH[2]}
      check "${BASH_REMATCH[1]}$rest"
    elif [[ $rest =~ ^[[:space:]]+-[^[:space:]]*(.*)$ ]]; then
      rest=${BASH_REMATCH[1]}
    else
      break
    fi
  done
  read -r sub args <<< "$rest"
  args=" $args "

  for a in "${aliases[@]}"; do
    [[ $a == alias.$sub=* ]] || continue
    # A self-referencing alias would recurse until bash crashes, and a crash
    # exits non-2, which lets the command run. Git rejects such aliases anyway.
    (( ++DEPTH > 20 )) && block "a recursive git alias"
    v=${a#*=}
    v=${v//$'\001'/ }
    check " $v $args"
  done

  case "$sub" in
    push|send-pack) block "git push" ;;
    subtree) [[ $args =~ ^[[:space:]]push[[:space:]] ]] && block "git push" ;;
    reset) [[ $args =~ [[:space:]]--ha(r|rd)?[[:space:]] ]] && block "git reset --hard" ;;
    clean) [[ $args =~ $FLAG_F ]] && block "git clean -f" ;;
    branch)
      [[ $args =~ [[:space:]]-[a-zA-Z]*D[a-zA-Z]*[[:space:]] ]] && block "git branch -D"
      [[ $args =~ [[:space:]](-[a-zA-Z]*d[a-zA-Z]*|--de[a-z]*)[[:space:]] && $args =~ $FLAG_F ]] && block "git branch -D" ;;
    checkout) [[ $args =~ $ALL_FILES || $args =~ $FLAG_F ]] && block "a checkout that drops changes" ;;
    restore)
      # --staged alone only unstages; with --worktree it discards edits too.
      [[ $args =~ $ALL_FILES ]] || return 0
      [[ $args =~ [[:space:]](--staged|-S)[[:space:]] && ! $args =~ [[:space:]](--worktree|-W|-[a-zA-Z]*W[a-zA-Z]*)[[:space:]] ]] || block "git restore ." ;;
    switch) [[ $args =~ $FLAG_F || $args =~ [[:space:]]--di[a-z-]*[[:space:]] ]] && block "a switch that drops changes" ;;
    stash) [[ $args =~ ^[[:space:]](drop|clear)[[:space:]] ]] && block "git stash ${BASH_REMATCH[1]}" ;;
  esac
  return 0
}

# Check every git call in every segment, not only the first one.
for view in "$TEXT" "$KEPT"; do
  while IFS= read -r seg; do
    seg=" $seg "
    while [[ $seg =~ [[:space:]/]git([[:space:]].*)$ ]]; do
      seg=${BASH_REMATCH[1]}
      aliases=()
    check "$seg"
    done
  done <<< "$view"
done

# Floor: the plain substring patterns of the original hook, plus git config
# injection. Whatever the parser above misses, these still catch.
# ponytail: `g=git; $g push` and aliases from ~/.gitconfig still get through; a
# real shell parser is the upgrade path.
# Here-string, not a pipe: with a pipe, grep -q exits on the first match and a big
# command can make the writer's failure decide the result.
grep -qE 'git[[:space:]]+(push|clean[[:space:]]+-f|branch[[:space:]]+-D|checkout[[:space:]]+\.|restore[[:space:]]+\.)|push[[:space:]]+--force|reset[[:space:]]+--hard|--config-env|GIT_CONFIG_' <<< "$TEXT" \
  && block "a blocked git pattern"

exit 0
