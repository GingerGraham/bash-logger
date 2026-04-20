---
name: pre-pr-checks
description: >
  Runs the full gate sequence before raising a pull request on bash-logger. Covers linting,
  targeted tests, full test suite, code review checklist, commit message audit, PR description
  requirements, and branch hygiene. Use this skill before pushing to a shared branch or opening
  a PR.
---

# Pre-PR Checks

Work through these steps in order. Each builds on the last.

## 1. Lint

```bash
make lint
```

Fix all ShellCheck and MarkdownLint failures. MarkdownLint auto-fixes most issues in-place, but does not re-stage the files — run `git add` on any modified files and re-run `make lint` before
continuing.

## 2. Targeted tests

Identify relevant suites (see `running-tests` skill) and run them:

```bash
./tests/run_tests.sh <suite_name>
```

All must pass before continuing.

## 3. Full test suite

```bash
./tests/run_tests.sh
```

Zero failures required. Investigate all regressions before pushing.

## 4. Code review checklist

### Shell scripts (`logging.sh`, `install.sh`, scripts)

* [ ] Every exit path assigns the correct return/exit code — passing tests do not guarantee all exit paths are correct
* [ ] Variables quoted throughout: `"$var"`
* [ ] No hardcoded paths that break portability
* [ ] New functions have comments explaining purpose and parameters
* [ ] Shell-agnostic where possible; bash-specific constructs commented with ShellCheck suppressions
* [ ] Lines ≤ 100 characters
* [ ] No leftover debug `echo` or `set -x` calls

### Test files

* [ ] Every new test function called at the bottom of its suite file
* [ ] `|| return` follows every assertion
* [ ] All I/O uses `$TEST_DIR`

### Documentation

* [ ] New flags, functions, or behaviour documented in the relevant `.md` file
* [ ] If `logging.sh` public API changed, `README.md` and `docs/` updated
* [ ] Markdown uses `*` list markers, 2-space indent, ≤ 200 char lines

## 5. Commit message audit

```bash
git log origin/main..HEAD --oneline
```

Every commit must follow `<type>(<scope>): <subject>` format. Amend any that do not:

```bash
git rebase -i origin/main   # reword the offending commits
```

If a commit addresses a tracked issue, confirm `Fixes #NNN` or `Refs #NNN` is in the footer. See the `writing-commits` skill for the full specification.

## 6. PR description

* Title: `<type>(<scope>): <subject>` matching the primary intent of the PR
* Body must include: summary, list of changes, testing steps taken, and issue links
* All related issues linked — at minimum the issue that prompted the work

## 7. Branch hygiene

```bash
git fetch origin
git rebase origin/main
```

Resolve conflicts, then re-run the full test suite.

## Quick-reference: common pre-PR failures

| Symptom | Cause | Fix |
| --- | --- | --- |
| ShellCheck SC2086 | Unquoted variable | `"$var"` |
| ShellCheck SC2155 | Combined declare/assign | `local x; x=$(...)` |
| MarkdownLint MD004 | List marker is `-` | Change to `*` |
| Test not run | Call missing at bottom of suite | Add the call |
| Assertion not reached | Missing `\|\| return` on prior assertion | Add `\|\| return` |
| No release triggered | Commit type not release-triggering | Check `.releaserc.json` |
