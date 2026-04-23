---
name: writing-commits
description: >
  Generates correctly formatted commit messages and pull request descriptions for this repository.
  Uses Conventional Commits / semantic-release format with issue references. Use this skill
  whenever writing, reviewing, or amending a commit message or drafting a PR title and body.
---

# Writing Commits and Pull Requests

## Commit message format

```
<type>(<scope>): <subject>

<body>

<footer>
```

Commit history drives automated versioning via `semantic-release`. Incorrect format means wrong or missing version bumps and changelog entries.

## Type — required

| Type       | Version bump | Use for                                     |
| ---------- | ------------ | ------------------------------------------- |
| `feat`     | minor        | New user-visible functionality              |
| `fix`      | patch        | Bug fixes                                   |
| `perf`     | patch        | Performance improvements                    |
| `revert`   | patch        | Reverting a prior commit                    |
| `refactor` | patch        | Internal restructuring, no behaviour change |
| `docs`     | none         | Documentation-only changes                  |
| `style`    | none         | Whitespace/formatting, no logic change      |
| `test`     | none         | Adding or updating tests                    |
| `chore`    | none         | Build, tooling, dependency changes          |
| `ci`       | none         | GitHub Actions or CI config changes         |

A `BREAKING CHANGE` footer triggers a **major** bump regardless of type.

## Scope — optional but strongly preferred

| Scope     | Use for                                   |
| --------- | ----------------------------------------- |
| `logging` | Core `logging.sh` functions               |
| `config`  | Configuration file handling               |
| `install` | `install.sh` and Makefile install targets |
| `tests`   | Test files or test infrastructure         |
| `docs`    | Documentation files                       |
| `scripts` | Utility or demo scripts                   |
| `ci`      | GitHub Actions workflows                  |
| `deps`    | Dependency / Dependabot changes           |

## Subject — required

* Imperative mood: "add", "fix", "remove" — not "adds", "fixed"
* No capital first letter
* No trailing period
* 50 characters or fewer

## Body — optional

Explain **why**, not just what. Wrap at 72 characters.

## Footer — issue references

Always include when the commit addresses a tracked issue:

```
Fixes #123
Closes #456
Refs #789
```

* `Fixes` / `Closes` — auto-closes the issue on merge
* `Refs` — links without closing
* Each reference on its own line
* Multiple references are all included

Breaking changes:

```
BREAKING CHANGE: <what broke and migration path>
```

## Examples

```
feat(logging): add structured JSON output format

Adds --format json to init_logger. JSON output goes to the log file only;
console output keeps the human-readable format.

Closes #87
```

```
fix(install): prevent path traversal in custom prefix validation

validate_prefix now rejects paths containing '..' sequences.

Fixes #102
```

```
docs: add configuration guide for systemd and cron environments
```

```
test(logging): add regression test for empty message handling

Refs #95
```

```
feat(logging): replace level array with associative map

BREAKING CHANGE: LOG_LEVELS is now an associative array. Scripts that
reference LOG_LEVELS by numeric index must switch to name-based keys
(e.g. LOG_LEVELS[INFO] instead of LOG_LEVELS[1]).
```

## Pull request conventions

### Title

Use `<type>(<scope>): <subject>` — same format as the primary commit. If the PR contains multiple commits of the same type, use the highest-impact one.

### Body structure

```markdown
## Summary

One paragraph explaining what this PR does and why.

## Changes

* Notable change one
* Notable change two

## Testing

Commands run and manual steps taken to verify.

## Related issues

Fixes #NNN
Refs #NNN
```

Always include issue links in the body even when they also appear in individual commit footers.

## Mistakes to avoid

* Past tense ("fixed") instead of imperative ("fix")
* Capitalised subject
* Missing issue reference when one exists
* Generic subjects like "update logging.sh" or "fixes"
* Mixing unrelated changes in one commit
