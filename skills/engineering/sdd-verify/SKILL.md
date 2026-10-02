---
name: sdd-verify
stacks: [all]
context: fork
agent: code-reviewer
argument-hint: "[task-id | story-id | issue# | path to spec]"
description: >
  Verify an implementation against its Story's acceptance criteria and the
  code-quality spec, in a fresh code-reviewer subagent. Delivers PASS/FAIL per
  criterion with file:line evidence, after running the project's own tests.
  Report only: never fixes, never closes issues. Use after implementing a task,
  when the user says "verify this", "does this match the spec", "sdd-verify",
  and from sdd-apply Phase 4.
---

# SDD Verify

Verify `$ARGUMENTS` against its acceptance criteria. You start with no
conversation history: everything you need is in this file, the repo, and GitHub.

## 1. Resolve the acceptance criteria

`$ARGUMENTS` is one of:

- **A path to a spec file**: read the acceptance criteria from it.
- **A Task ID** (`BE-AUTH-1-T1`), **Story ID** (`BE-AUTH-1`) or **issue number** (`#42`),
  from a backlog made by `prd-to-github-backlog`. Titles are `"<ID>: <title>"`;
  a Task's Story is its ID without the trailing `-T<k>`.

```bash
gh repo view --json nameWithOwner,defaultBranchRef \
  --jq '.nameWithOwner + " " + .defaultBranchRef.name'
gh issue list --label type:story --state all --search "in:title <STORY_ID>" \
  --json number,title --jq '.[] | select(.title | startswith("<STORY_ID>:")) | .number'
gh issue view <story#>       # Given/When/Then acceptance criteria live here
gh issue view <task#>        # for a Task: its scope narrows which criteria apply
```

For a raw `#N`, check its `type:*` label; a `type:task` walks up to its parent
Story (`gh api repos/<owner/repo>/issues/<N>/parent --jq '.number'`).

If no acceptance criteria can be found, or they are not testable (no observable
outcome), stop and report exactly that. Do not invent criteria.

## 2. Identify the change under review

```bash
git status --porcelain
git diff HEAD                  # uncommitted: the task in progress
git diff <BASE>...HEAD         # committed on this branch
```

If the working tree has changes, review those (the current task). If it is
clean, review `<BASE>...HEAD`. Read every changed file in full, not only the hunks.

## 3. Load the project's rules

Read the root `CLAUDE.md` and the files it links under Engineering and Business,
mainly `engineering/standards.md`, `engineering/testing.md`, `business/rules.md`.

## 4. Run the tests

Use the commands from `engineering/testing.md`; otherwise the project's own
(`npm test`, `pnpm test`, `dotnet test`, `./gradlew test`). Record what actually
ran and the result. If they could not run, say why. Never report "tests pass"
without running them.

## 5. Verify

- **Spec 1, acceptance criteria:** only the criteria this change is due to
  satisfy. Check behavior, not that some code exists for it. A criterion with no
  test proving it is at most PARTIAL.
- **Spec 2, code quality:** duplication, naming, architecture boundaries,
  control flow, error handling, function size, dead code, tests that exercise
  the real path instead of a mock of it.

Write the reasoning before each verdict.

## 6. Report

```
VERDICT: PASS | FAIL   <ID> — <title>
Tests: <command> → <result>

Acceptance criteria
  ✓ AC1 <criterion>: <evidence, file:line>
  ✗ AC2 <criterion>: <what is missing, file:line>
  ~ AC3 <criterion>: PARTIAL, <why>

Code quality (blocking first)
  [blocking] file:line — <issue>
  [minor]    file:line — <issue>
```

FAIL if any criterion is ✗ or ~, tests fail or could not run, or there is a
blocking quality finding.

## Hard rules

- Report only. No edits, no commits, no issue comments, no closing issues.
- Every ✗ and every finding cites file:line.
- Never guess. If the implementation cannot be found, say so.
