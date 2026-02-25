# GitHub Copilot Guidance for bash-logger

This document provides guidance for GitHub Copilot when contributing to the bash-logger project. Please follow these instructions when generating, modifying, or reviewing code.

## Linting and Code Quality

All code changes **MUST** pass the linting requirements defined in `.pre-commit-config.yaml`:

### ShellCheck Linting

* **Tool**: ShellCheck v0.11.0.1
* **Configuration**: `--severity=warning --external-sources`
* **Scope**: All shell scripts (`.sh` files)
* **Requirements**:
  * All shell scripts must pass ShellCheck with no warnings or errors
  * External sources should be analyzed properly
  * When ShellCheck flags an issue, fix it or add a justified `shellcheck disable` comment with explanation
  * Example: `# shellcheck disable=SC2034` with comment explaining why

### MarkdownLint

* **Tool**: MarkdownLint v0.47.0
* **Scope**: All Markdown documentation files
* **Requirements**:
  * All Markdown files must follow MarkdownLint rules
  * Auto-fix formatting issues when possible
  * Maintain consistent formatting across documentation
  * **CRITICAL: Use asterisks (*) for all unordered lists, never dashes (-)**

### Test Suite

* **Tool**: `tests/run_tests.sh`
* **Requirement**: All changes must not break existing tests
* **Scope**: Any code changes affecting core functionality must have tests added or updated
* **Contributor guide**: [docs/writing-tests.md](../docs/writing-tests.md) — read this before writing tests

#### Test lifecycle

Every test follows the same three-step lifecycle:

```bash
test_feature_name() {
    start_test "Human-readable description"  # registers test, calls setup_test, re-sources logging.sh

    init_logger --level DEBUG --quiet
    local log_file="$TEST_DIR/test.log"
    LOG_FILE="$log_file"

    log_info "expected message"

    assert_file_contains "$log_file" "expected message" || return  # || return is mandatory

    pass_test  # only reached if all assertions passed
}

test_feature_name  # functions must be called explicitly at the bottom of the suite file
```

#### The `|| return` requirement

`|| return` after every assertion is **not optional**. Without it, execution continues past a
failing assertion, later assertions run against an already-failed test, and `pass_test` may be
reached despite failures — masking the real problem.

```bash
# CORRECT
assert_file_contains "$log_file" "text" || return

# WRONG — execution continues after failure
assert_file_contains "$log_file" "text"
```

#### `$TEST_DIR` — always use it for file paths

`$TEST_DIR` is a unique per-test subdirectory created by `setup_test`. The runner executes
suites in parallel; using a fixed path like `/tmp/test.log` causes races between parallel jobs.

```bash
# CORRECT
local log_file="$TEST_DIR/test.log"

# WRONG — shared path breaks parallel execution
local log_file="/tmp/test.log"
```

#### When to use file assertions vs output capture

**Prefer `assert_file_contains`** for verifying log output. Point `LOG_FILE` at a path under
`$TEST_DIR` and assert against that file. This tests the real output path and leaves the file
available for inspection on failure.

**Use subshell with stream redirects** only when testing *which stream* a message appears on
(e.g., stderr vs stdout):

```bash
bash -c "
    source '$PROJECT_ROOT/logging.sh'
    init_logger
    log_error 'message'
" >"$TEST_DIR/stdout" 2>"$TEST_DIR/stderr"

assert_file_contains "$TEST_DIR/stderr" "message" || return
assert_file_not_contains "$TEST_DIR/stdout" "message" || return
```

#### Isolation: why `logging.sh` is re-sourced on every test

`start_test` calls `setup_test`, which re-sources `logging.sh`. This resets all global logger
state (`LOG_FILE`, `LOG_LEVEL`, `QUIET_MODE`, etc.) before each test. Do not source
`logging.sh` at the top of a suite file — that runs before `$TEST_DIR` exists and before
per-test isolation is established.

## Commit Message Standards

All commit messages **MUST** comply with **Semantic Versioning (Semantic Release)** formatting to enable automated version management and release notes generation.

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type (Required)

Must be one of:

* `feat`: A new feature (triggers minor version bump)
* `fix`: A bug fix (triggers patch version bump)
* `docs`: Documentation-only changes
* `style`: Code style changes (formatting, whitespace, missing semicolons)
* `refactor`: Code refactoring without feature or bug fix changes
* `perf`: Performance improvements
* `test`: Test additions or updates
* `chore`: Build, dependency, or tooling changes
* `ci`: CI/CD configuration changes

### Scope (Optional)

Indicate the area of the codebase affected. Common examples:

* `logging`: Changes to core logging functionality
* `config`: Configuration-related changes
* `tests`: Test files and test infrastructure
* `docs`: Documentation changes
* `scripts`: Utility scripts or demo scripts

### Subject (Required)

Brief, descriptive summary:

* Use **imperative mood** ("add" not "adds" or "added")
* **Do not capitalize** the first letter
* **No period** at the end
* Keep under **50 characters**

### Body (Optional)

Detailed explanation of the change:

* Explain **why** the change was made
* Explain **what** the change does
* Describe any side effects or related issues

### Footer (Optional)

Reference issue numbers and breaking changes:

* `Fixes #123` or `Closes #456` to link to issues
* `BREAKING CHANGE: description` for backwards-incompatible changes

### Examples

**Simple feature:**

```
feat(config): add support for custom log format

Allow users to specify custom log format strings via configuration files.
This enables better integration with existing logging systems.
```

**Bug fix:**

```
fix(logging): prevent logger initialization without level

Previously, init_logger could be called without a level parameter,
causing undefined behavior. Now it properly validates required parameters.

Fixes #42
```

**Documentation only:**

```
docs: update getting started guide with zsh example
```

**Performance improvement:**

```
perf(output): cache color code lookups

Reduce overhead of color code resolution by caching common patterns.
Benchmarks show 15% improvement on large log files.
```

## Shell Compatibility Guidelines

The bash-logger project aims to support common Linux/Unix shells while maintaining code quality and clarity.

### Shell-Agnostic Approach (Preferred)

When possible, write code compatible with multiple shells:

**Supported shells** (in order of priority):

1. POSIX shell (`sh`) - Most compatible
2. Bash (4.x and 5.x)
3. Zsh
4. Fish
5. Other POSIX-compatible shells

## Markdown Formatting Standards

* **Unordered lists**: Always use `*` (asterisk), never `-` (dash)
* **List indentation**: 2 spaces per level
* **Line length**: Maximum 200 characters (configured in .markdownlint.yaml)
* **Consistency**: Match existing documentation patterns

### Guidance for Shell-Agnostic Code

**DO:**

* Use POSIX-compatible syntax whenever possible
* Use `[ ]` instead of `[[ ]]` for maximum compatibility
* Use `$(...)` instead of backticks (works everywhere)
* Use `.` or `source` for sourcing files (both POSIX)
* Avoid bash-specific features like arrays, associative arrays, etc.
* Test code across multiple shells if significant changes are made
* Document shell requirements in comments

**DON'T:**

* Use bash-only features like `[[ ]]`, `(( ))`, or `=~` unless necessary
* Use bash arrays or associative arrays unless truly needed
* Rely on bash-specific string manipulation
* Use `<<` heredocs without considering portability

### Bash-Specific Code Exception

When conflicts are unavoidable and shell-agnostic code is not feasible:

* **Default to Bash** as the target shell
* Clearly document why POSIX compatibility is not possible
* Add a comment explaining the Bash-specific requirement
* Use ShellCheck directives to suppress non-critical warnings
* Example: `# shellcheck disable=SC3010 -- Bash-specific feature required for performance`

### Current Project Approach

The main `logging.sh` file uses:

* Shebang: `#!/usr/bin/env bash` - explicitly targets Bash
* This allows for some Bash-specific optimizations while remaining readable
* Configuration and demo scripts should maintain broader compatibility

### Testing Across Shells

When making significant changes:

* Test with at least Bash 4.x and Bash 5.x
* Ideally test with `sh` and `zsh` if modifying shared functionality
* Use the test suite: `./tests/run_tests.sh`
* Document any shell-specific behavior differences

## Code Style Standards

In addition to linting requirements, follow these style guidelines:

* **Indentation**: 4 spaces (no tabs)
* **Line length**: Keep under 100 characters where reasonable
* **Variable names**: Use meaningful, descriptive names
* **Comments**: Add comments for complex logic or non-obvious behavior
* **Naming conventions**: Follow existing patterns in the codebase
  * Constants: `UPPERCASE_WITH_UNDERSCORES`
  * Functions: `lowercase_with_underscores`
  * Local variables: `lowercase_with_underscores`

## Summary Checklist for Copilot

Before proposing or generating code:

* [ ] Code passes ShellCheck (`--severity=warning --external-sources`)
* [ ] Markdown passes MarkdownLint
* [ ] Existing tests still pass
* [ ] New tests added for new functionality
* [ ] Commit message follows Semantic Versioning format
* [ ] Code is shell-agnostic when possible, with Bash as fallback
* [ ] Lines are under 100 characters where reasonable
* [ ] Comments explain complex logic
* [ ] Variable names are meaningful
* [ ] 4-space indentation is used throughout

## Questions?

For more information, see:

* [CONTRIBUTING.md](../CONTRIBUTING.md) - General contribution guidelines
* [docs/PRE-COMMIT.md](../docs/PRE-COMMIT.md) - Pre-commit hooks setup
* [docs/testing.md](../docs/testing.md) - Testing guidelines
* [.pre-commit-config.yaml](../.pre-commit-config.yaml) - Linting configuration
