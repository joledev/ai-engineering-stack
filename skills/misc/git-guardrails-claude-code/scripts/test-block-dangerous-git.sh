#!/bin/bash
# Runs the hook against a table of commands. B = must block (exit 2), A = must allow (exit 0).
# Usage: bash test-block-dangerous-git.sh   (exits 1 if any case fails)
HOOK="$(cd "$(dirname "$0")" && pwd)/block-dangerous-git.sh"
fail=0

run() { # expected-exit json-input label
  printf '%s' "$2" | /bin/bash "$HOOK" 2>/dev/null
  local got=$?
  [[ $got == "$1" ]] || { echo "FAIL (want $1, got $got): $3"; fail=1; }
}

while IFS= read -r line; do
  [[ -z $line || $line == \#* ]] && continue
  want=${line%%|*}; cmd=${line#*|}
  [[ $want == B ]] && code=2 || code=0
  run "$code" "$(jq -cn --arg c "$cmd" '{tool_input:{command:$c}}')" "$cmd"
done <<'CASES'
B|git push
B|git push origin main
B|git push --force
B|git -C /x push
B|git -C "/a b" push
B|git -c core.x=y push
B|git --no-pager push
B|git --git-dir=/x/.git push
B|git --git-dir /x/.git push
B|git clean -f
B|git clean -df
B|git clean -xfd
B|git clean --force
B|git clean -n --no-dry-run -fdx
B|git reset --hard
B|git reset --hard HEAD~3
B|git checkout .
B|git checkout -- .
B|git checkout -f
B|git restore .
B|git restore --staged --worktree .
B|git branch -D foo
B|git branch --delete --force foo
B|git switch -f main
B|git switch --discard-changes main
B|git stash drop
B|git stash clear
B|cd x && git push
B|git status; git push
B|git status && git push
B|git status | git push
B|(git push)
B|echo $(git push)
B|echo `git push`
B|sudo git push
B|/usr/bin/git push
B|env FOO=1 git push
B|bash -c "git push"
B|bash -c 'git push'
B|echo "git push"
B|if true; then git push; fi
B|for c in "git fetch" "git push"; do $c; done
B|git commit -m 'wip' && git push
B|echo "commit -m '"; git push --force origin main; echo "'"
B|echo 'commit -m "'; git reset --hard HEAD~5; echo '"'
B|\git push --force
B|"git" push --force
B|g\it reset --hard
B|git pu\sh --force
B|git push>/dev/null
B|git reset --hard>/dev/null
B|find . -exec git push \;
B|git status && echo ok; git -C /x status && git push
B|g=git; $g push --force
B|g=git; $g reset --hard
B|git -c alias.x=push x
B|git -c 'alias.x=!git push' x
B|git -c 'alias.x=!sh -c "git push origin main"' x -h
B|git -c "alias.x=reset --hard" x
B|X=push git --config-env alias.y=X y
B|GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=alias.p GIT_CONFIG_VALUE_0=push git p
B|git subtree push --prefix=dist origin gh-pages
B|git send-pack git@github.com:o/r.git main
B|git push -h
B|git -c "alias.x=checkout -f" x
B|git --attr-source HEAD push
B|git --shallow-file F clean -fdx
B|git --shallow-file /dev/null push origin main
B|git --shallow-file F branch -D foo
B|git --no-pager --shallow-file F checkout .
B|git --git-dir /x/.git --work-tree /x stash drop
B|git -c alias.x=push --no-pager x
B|git -c alias.x=push --shallow-file F x
B|git${IFS}push origin main
B|git$IFS push
B|git checkout ./src
B|git checkout .github/workflows/ci.yml
B|git clean -n -f
A|git status
A|git log --oneline -5
A|git diff
A|git -C /x status
A|git --no-pager log --oneline
A|git --git-dir /x/.git status
A|git fetch origin
A|git commit -m "fix: push the button"
A|git clean -n
A|git clean -nd
A|git restore --staged .
A|git restore src/app.ts
A|git checkout main
A|git branch -d merged-branch
A|git stash list
A|git reset HEAD~1
A|ls -la
A|cat .git/config
CASES

# Inputs the hook can't read must block, never allow.
run 2 'not json' "invalid JSON"
run 2 '{"tool_input":{"command":42}}' "non-string command"
run 2 '{"tool_input":{"command":""}}' "empty command"
run 2 '{"tool_input":{}}' "missing command"
run 2 '{"tool_input":{"command":"git \\\npush"}}' "line continuation: git \\<newline>push"

# Without jq the hook must block, not allow. PATH holds only cat, which runs before the jq check.
NOJQ=$(mktemp -d)
ln -s "$(command -v cat)" "$NOJQ/cat"
printf '%s' '{"tool_input":{"command":"git status"}}' | PATH=$NOJQ /bin/bash "$HOOK" 2>/dev/null
[[ $? == 2 ]] || { echo "FAIL: without jq the hook did not block"; fail=1; }
rm -rf "$NOJQ"

# A huge command must not change the result (grep -q + SIGPIPE once let this through).
PAD=$(head -c 200000 /dev/zero | tr '\0' a)
run 2 "$(jq -cn --arg c "g=git; \$g push --force; echo $PAD" '{tool_input:{command:$c}}')" "200 KB command with a floor-only match"

[[ $fail == 0 ]] && echo "all cases pass"
exit $fail
