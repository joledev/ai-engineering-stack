#!/bin/bash

INPUT=$(cat)

unreadable() {
  echo "BLOCKED: couldn't read the command from the hook input." >&2
  exit 2
}

if command -v jq >/dev/null; then
  COMMAND=$(printf '%s' "$INPUT" | jq -er '.tool_input.command | if type == "string" then . else error end' 2>/dev/null) || unreadable
else
  KEYS=$(printf '%s' "$INPUT" | sed -zE 's/"command" *: *"/\x02/g; s/[^\x02]//g')
  [[ $KEYS == $'\x02' ]] || unreadable
  COMMAND=$(printf '%s' "$INPUT" | sed -zE 's/.*"command" *: *"(([^"\\]|\\.)*)".*/\1/; s/\\\\/\x01/g; s/\\n/\n/g; s/\\t/\t/g; s/\\r//g; s/\\"/"/g; s/\\\//\//g')
  [[ $COMMAND == *\\* ]] && unreadable
  COMMAND=${COMMAND//$'\x01'/\\}
fi

block() {
  echo "BLOCKED: '$COMMAND' runs $1. The user has prevented you from doing this." >&2
  exit 2
}

TEXT=${COMMAND//$'\\\n'/}
TEXT=$(printf '%s' "$TEXT" | sed -zE "s/(commit( +-[a-zA-Z-]+)*) +(-[a-zA-Z]*m|--message) *'[^'\`\$]*'/\1 -m x/g; s/(commit( +-[a-zA-Z-]+)*) +(-[a-zA-Z]*m|--message) *\"[^\"\`\$\\\\]*\"/\1 -m x/g")
TEXT=$(printf '%s' "$TEXT" | tr ';&|()`\t' '\n\n\n\n\n\n ')

FLAG_F='[[:space:]](-[a-zA-Z]*f[a-zA-Z]*|--f|--fo|--for|--forc|--force)[[:space:]]'
ALL_FILES='[[:space:]](\.|\./|\.\.|:/|\*)[[:space:]]'
VALUE='(([^[:space:]"'\'']|"[^"]*"|'\''[^'\'']*'\'')+)'

check() {
  local seg=" $1 " rest sub args a v aliases=()
  [[ $seg =~ [[:space:]/\"\']git[[:space:]]+(.*)$ ]] || return 0
  rest=" ${BASH_REMATCH[1]}"
  while :; do
    if [[ $rest =~ ^[[:space:]]+(-C|-c|--git-dir|--work-tree|--namespace|--config-env)[[:space:]]+$VALUE(.*)$ ]]; then
      [[ ${BASH_REMATCH[1]} == -c ]] && aliases+=("${BASH_REMATCH[2]//[\"\']/}")
      rest=${BASH_REMATCH[4]}
    elif [[ $rest =~ ^[[:space:]]+(--help|-h)[[:space:]] ]]; then
      return 0
    elif [[ $rest =~ ^[[:space:]]+-[^[:space:]]*(.*)$ ]]; then
      rest=${BASH_REMATCH[1]}
    else
      break
    fi
  done
  rest=${rest//[\"\']/}
  read -r sub args <<< "$rest"
  args=" $args "
  [[ $args =~ ^[[:space:]](--help|-h)[[:space:]] ]] && return 0

  for a in "${aliases[@]}"; do
    [[ $a == alias.$sub=* ]] || continue
    v=${a#*=}
    if [[ $v == !* ]]; then check "${v#!}"; else check "git $v $args"; fi
  done

  case "$sub" in
    push) block "git push" ;;
    reset) [[ $args =~ [[:space:]]--ha(r|rd)?[[:space:]] ]] && block "git reset --hard" ;;
    clean)
      [[ ${args%%[[:space:]]#*} =~ ^[[:space:]]*((-[a-df-zA-Z]*|--[a-z-]+)[[:space:]]+)*(-[a-df-zA-Z]*n[a-zA-Z]*|--dry-run)([[:space:]]|$) ]] && return 0
      [[ $args =~ $FLAG_F ]] && block "git clean -f" ;;
    branch)
      [[ $args =~ [[:space:]]-[a-zA-Z]*D[a-zA-Z]*[[:space:]] ]] && block "git branch -D"
      [[ $args =~ [[:space:]](-[a-zA-Z]*d[a-zA-Z]*|--de[a-z]*)[[:space:]] && $args =~ $FLAG_F ]] && block "git branch -D" ;;
    checkout) [[ $args =~ $ALL_FILES || $args =~ $FLAG_F ]] && block "a checkout that drops changes" ;;
    restore) [[ $args =~ $ALL_FILES ]] && block "git restore ." ;;
    switch) [[ $args =~ $FLAG_F || $args =~ [[:space:]]--di[a-z-]*[[:space:]] ]] && block "a switch that drops changes" ;;
    stash) [[ $args =~ ^[[:space:]](drop|clear)[[:space:]] ]] && block "git stash drop" ;;
  esac
  return 0
}

while IFS= read -r seg; do
  check "$seg"
done <<< "$TEXT"

exit 0
