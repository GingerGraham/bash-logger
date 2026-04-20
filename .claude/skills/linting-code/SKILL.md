---
name: linting-code
description: Lints shell scripts and Markdown files in the bash-logger repository using the project's configured toolchain. Use this skill whenever checking code quality, fixing linting errors, or running lint as part of a pre-commit or pre-PR workflow.
---

# Linting Code

## Tools and where configuration lives

| Tool | Checks | Config |
| --- | --- | --- |
| ShellCheck | Shell syntax, quoting, portability, common bugs | `.pre-commit-config.yaml` (args: `--severity=warning --external-sources`) |
| MarkdownLint | Markdown formatting, list style, line length | `.markdownlint.yaml` |

Both run through `pre-commit` so versions are pinned. Always use the Make targets or `pre-commit` directly — do not invoke `shellcheck` or `markdownlint` as standalone commands.

## Commands

### Lint everything (shell + Markdown)

```bash
make lint
```

### Shell scripts only

```bash
make lint-shell
```

### Markdown only

```bash
make lint-markdown
```

### Run all pre-commit hooks including tests

```bash
make pre-commit
```

### Run a single hook by name

```bash
pre-commit run shellcheck --all-files
pre-commit run markdownlint --all-files
```

## Key rules — write clean code from the start

### Shell scripts

* 4-space indentation, no tabs
* Lines ≤ 100 characters
* Quote all variable expansions: `"$var"` not `$var`
* `[[ ]]` for bash conditionals; `[ ]` only when POSIX portability is needed
* `$(...)` not backticks
* `UPPERCASE` for constants/exported vars; `lowercase` for locals and functions
* When suppressing a ShellCheck warning, add an explanation comment:

  ```bash
  # shellcheck disable=SC3010 -- bash-specific syntax required for performance here
  ```

### Markdown

* Unordered list markers: `*` only — **never** `-` (MD004)
* 2-space list indentation (MD007)
* Maximum line length: 200 characters; code blocks and tables are exempt (MD013)
* Blank line above and below every heading (MD022)
* Ordered lists: use `1.` for every item, or true sequential numbers; never an arbitrary
  starting number (MD029)
* Table separator rows: always `| --- | --- |`, **never** `|---|---|` — MD060 compact style
  requires a space to the left and right of every `---` cell (MD060)
* Specify a language on all fenced code blocks where possible (optional but preferred)

## Interpreting failures

### ShellCheck

Format: `file.sh:LINE:COL: severity: message [SCXXX]`

Look up unknown codes at `https://www.shellcheck.net/wiki/SCXXX`.

Most common codes in this project:

| Code | Cause | Fix |
| --- | --- | --- |
| SC2086 | Unquoted variable | Wrap in `"$var"` |
| SC2155 | Combined `local`/assign | Split: `local x; x=$(...)` |
| SC2181 | Check `$?` instead of direct `if` | Use `if command; then` directly |

### MarkdownLint

MarkdownLint runs with `--fix` — most formatting issues auto-correct and the file is re-staged. Violations that cannot be auto-fixed (long lines, wrong list markers) require manual edits.
