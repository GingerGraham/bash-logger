# bash-logger Agent Instructions

This document provides guidance for AI agents contributing to the bash-logger project.
Follow these standards when generating, modifying, or reviewing code.

## Agent Skills

This repository provides skills in `.claude/skills/`. Supporting agents (GitHub Copilot,
Claude Code, and others implementing the Agent Skills open standard) load these automatically.
Each skill contains the authoritative, step-by-step workflow for its domain:

* **[linting-code](.claude/skills/linting-code/SKILL.md)** — run ShellCheck and MarkdownLint,
  interpret failures, fix common issues
* **[running-tests](.claude/skills/running-tests/SKILL.md)** — discover available suites,
  choose targeted vs full runs, read test output
* **[writing-tests](.claude/skills/writing-tests/SKILL.md)** — create test suites, write
  correctly isolated test functions, use assertions
* **[writing-commits](.claude/skills/writing-commits/SKILL.md)** — format commit messages and
  PR descriptions with Conventional Commits / semantic-release
* **[pre-pr-checks](.claude/skills/pre-pr-checks/SKILL.md)** — full gate sequence before
  opening a pull request
* **[security-review](.claude/skills/security-review/SKILL.md)** — review changes for input
  sanitization, file system safety, config injection, and other security domains

When a skill covers a task (linting, testing, committing, security review), defer to it for
the detailed procedure. The sections below state the standards; the skills explain the how.

## Linting and Code Quality

All code changes **MUST** pass the linting requirements defined in `.pre-commit-config.yaml`.

* **ShellCheck** — all `.sh` files, severity `warning`, `--external-sources`
* **MarkdownLint** — all `.md` files, rules from `.markdownlint.yaml`

See the `linting-code` skill for commands and how to fix common failures.

## Test Suite

* **Tool**: `tests/run_tests.sh`
* **Requirement**: all changes must not break existing tests; new functionality must have tests
* **Contributor guide**: [docs/writing-tests.md](docs/writing-tests.md)

See the `running-tests` and `writing-tests` skills for invocation syntax and test patterns.

## Commit Message Standards

All commits **MUST** follow **Conventional Commits / semantic-release** format to drive
automated versioning and changelog generation:

```
<type>(<scope>): <subject>
```

Common types: `feat` (minor bump), `fix`/`perf`/`refactor` (patch bump), `docs`/`style`/
`test`/`chore`/`ci` (no bump). A `BREAKING CHANGE` footer triggers a major bump.

See the `writing-commits` skill for the full type/scope table, subject rules, footer
conventions, and PR description format.

## Shell Compatibility Guidelines

**Core library (`logging.sh`):** written for **POSIX sh plus `local`**, one implementation for
bash 3.2+, bash `--posix`, zsh, dash and busybox ash (Issue #143). This replaces the earlier
bash-forward preference for `logging.sh`. In that file:

* Use `[ ]`, `case` and parameter expansion; no `[[ ]]`, `=~`, arrays, `$'...'`,
  `${var//}`, `${var:offset:length}` or `&>`
* Print data with `printf '%s\n'`, never `echo` (dash and zsh `echo` expand backslashes)
* Initialise every local: `local name=""` (dash's `local` keeps the outer value)
* Shell-specific code only where no POSIX form gives the same result, behind a
  `_LOGGER_SHELL_FAMILY` check, with a `shellcheck disable` directive and the reason
  on the line above
* `scripts/check-posix-compat.sh` must pass (zero `SC3xxx` findings from `--shell=dash`)
* Document any behaviour that differs between shells in
  [docs/shell-compatibility.md](docs/shell-compatibility.md)

The guidelines below apply to the other scripts in the repository.

The test suite and `scripts/` target bash 3.2 or later. Fish is supported only for surrounding
repository tooling, never for `logging.sh`.

**DO:**

* Use `[[ ]]` in Bash-targeted files (such as the test suite and `scripts/`); reserve `[ ]`
  for scripts where POSIX portability is explicitly required
* Use `$(...)` instead of backticks (works everywhere)
* Use `.` for POSIX sh; `source` is Bash/Zsh/Ksh-specific (but widely supported)
* Document shell requirements in comments

**DON'T:**

* Use `[[ ]]`, `(( ))`, or `=~` in scripts that must be POSIX-portable
* Use bash arrays or associative arrays unless truly needed
* Rely on bash-specific string manipulation in portable scripts
* Use `<<` heredocs without considering portability

**Bash-specific exception:** when POSIX compatibility is not feasible, default to Bash,
add a comment explaining why, and use ShellCheck suppressions with justification:

```bash
# shellcheck disable=SC3010 -- bash-specific syntax required for performance here
```

`logging.sh` keeps a `#!/usr/bin/env bash` line, so running it directly in bash prints its
usage message; its code is POSIX sh plus `local`. Configuration and demo scripts should
maintain broader compatibility.

## Markdown Formatting Standards

All Markdown files must satisfy the rules in `.markdownlint.yaml`:

* **MD004** — unordered list markers: always `*`, never `-`
* **MD007** — list indentation: 2 spaces per level
* **MD013** — line length: maximum 200 characters; code blocks and tables are exempt
* **MD022** — headings: one blank line above and below every heading
* **MD029** — ordered list style: use `1.` for every item, or true sequential numbers
* **MD060** — table column style: `"aligned"` — all column widths must be padded uniformly so
  every pipe is vertically aligned; separator dashes must span the full column width

Rules explicitly disabled (permitted in this project): raw HTML (MD033), duplicate headings
across sections (MD024), emphasis as heading (MD036), language tag on fenced blocks (MD040),
trailing punctuation in headings (MD026), first-line heading (MD041).

## Code Style Standards

* **Indentation**: 4 spaces, no tabs
* **Line length**: under 100 characters where reasonable
* **Variable names**: meaningful and descriptive
* **Comments**: explain complex logic or non-obvious constraints; not needed elsewhere
* **Naming conventions**:
  * Constants: `UPPERCASE_WITH_UNDERSCORES`
  * Functions: `lowercase_with_underscores`
  * Local variables: `lowercase_with_underscores`

## Runtime Configuration Functions

Every `set_*` function in `logging.sh` reports its change as a `CONFIG` notice. Build the entry
with `_format_log_message "CONFIG" "$message"`, then send it through the shared helpers instead
of writing `printf` blocks in the function:

* `_log_set_config_to_console "$log_entry" [color]` — console copy, routed like a NOTICE message
  so it follows `LOG_STDERR_LEVEL`. The color defaults to purple; pass `$COLOR_RED` to warn when
  enabling an unsafe mode.
* `_log_set_config_to_file "$log_entry"` — log file copy, without colors. Does nothing when
  `LOG_FILE` is empty.
* `_write_to_journal "notice" ...` — journal copy, when journal logging is enabled.

When adding a `set_*` function, add it to the `CONFIG` notice tests in
`tests/test_runtime_config.sh`, which check every function's console stream and log file line.

## Pre-PR Checklist

Before proposing or generating code, verify:

* [ ] Code passes ShellCheck (`--severity=warning --external-sources`) — see `linting-code` skill
* [ ] Markdown passes MarkdownLint — see `linting-code` skill
* [ ] Existing tests still pass — see `running-tests` skill
* [ ] New tests added for new functionality — see `writing-tests` skill
* [ ] Commit message follows Conventional Commits format — see `writing-commits` skill
* [ ] Security implications reviewed for changes touching input, files, config, or external
  commands — see `security-review` skill
* [ ] `logging.sh` passes `scripts/check-posix-compat.sh`; other code is shell-agnostic where
  possible, with Bash as fallback
* [ ] Lines are under 100 characters where reasonable
* [ ] 4-space indentation throughout

## Reference

* [CONTRIBUTING.md](CONTRIBUTING.md) — general contribution guidelines
* [docs/PRE-COMMIT.md](docs/PRE-COMMIT.md) — pre-commit hooks setup
* [docs/testing.md](docs/testing.md) — testing guidelines
* [.pre-commit-config.yaml](.pre-commit-config.yaml) — linting configuration
