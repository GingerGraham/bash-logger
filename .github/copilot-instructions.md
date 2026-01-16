# GitHub Copilot Guidance for bash-logger

This document provides guidance for GitHub Copilot when contributing to the bash-logger project. Please follow these instructions when generating, modifying, or reviewing code.

## Linting and Code Quality

All code changes **MUST** pass the linting requirements defined in `.pre-commit-config.yaml`:

### ShellCheck Linting

- **Tool**: ShellCheck v0.11.0.1
- **Configuration**: `--severity=warning --external-sources`
- **Scope**: All shell scripts (`.sh` files)
- **Requirements**:
  - All shell scripts must pass ShellCheck with no warnings or errors
  - External sources should be analyzed properly
  - When ShellCheck flags an issue, fix it or add a justified `shellcheck disable` comment with explanation
  - Example: `# shellcheck disable=SC2034` with comment explaining why

### MarkdownLint

- **Tool**: MarkdownLint v0.47.0
- **Scope**: All Markdown documentation files
- **Requirements**:
  - All Markdown files must follow MarkdownLint rules
  - Auto-fix formatting issues when possible
  - Maintain consistent formatting across documentation

### Test Suite

- **Tool**: `tests/run_tests.sh`
- **Requirement**: All changes must not break existing tests
- **Scope**: Any code changes affecting core functionality must have tests added or updated

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

- `feat`: A new feature (triggers minor version bump)
- `fix`: A bug fix (triggers patch version bump)
- `docs`: Documentation-only changes
- `style`: Code style changes (formatting, whitespace, missing semicolons)
- `refactor`: Code refactoring without feature or bug fix changes
- `perf`: Performance improvements
- `test`: Test additions or updates
- `chore`: Build, dependency, or tooling changes
- `ci`: CI/CD configuration changes

### Scope (Optional)

Indicate the area of the codebase affected. Common examples:

- `logging`: Changes to core logging functionality
- `config`: Configuration-related changes
- `tests`: Test files and test infrastructure
- `docs`: Documentation changes
- `scripts`: Utility scripts or demo scripts

### Subject (Required)

Brief, descriptive summary:

- Use **imperative mood** ("add" not "adds" or "added")
- **Do not capitalize** the first letter
- **No period** at the end
- Keep under **50 characters**

### Body (Optional)

Detailed explanation of the change:

- Explain **why** the change was made
- Explain **what** the change does
- Describe any side effects or related issues

### Footer (Optional)

Reference issue numbers and breaking changes:

- `Fixes #123` or `Closes #456` to link to issues
- `BREAKING CHANGE: description` for backwards-incompatible changes

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

### Guidance for Shell-Agnostic Code

**DO:**

- Use POSIX-compatible syntax whenever possible
- Use `[ ]` instead of `[[ ]]` for maximum compatibility
- Use `$(...)` instead of backticks (works everywhere)
- Use `.` or `source` for sourcing files (both POSIX)
- Avoid bash-specific features like arrays, associative arrays, etc.
- Test code across multiple shells if significant changes are made
- Document shell requirements in comments

**DON'T:**

- Use bash-only features like `[[ ]]`, `(( ))`, or `=~` unless necessary
- Use bash arrays or associative arrays unless truly needed
- Rely on bash-specific string manipulation
- Use `<<` heredocs without considering portability

### Bash-Specific Code Exception

When conflicts are unavoidable and shell-agnostic code is not feasible:

- **Default to Bash** as the target shell
- Clearly document why POSIX compatibility is not possible
- Add a comment explaining the Bash-specific requirement
- Use ShellCheck directives to suppress non-critical warnings
- Example: `# shellcheck disable=SC3010 -- Bash-specific feature required for performance`

### Current Project Approach

The main `logging.sh` file uses:

- Shebang: `#!/usr/bin/env bash` - explicitly targets Bash
- This allows for some Bash-specific optimizations while remaining readable
- Configuration and demo scripts should maintain broader compatibility

### Testing Across Shells

When making significant changes:

- Test with at least Bash 4.x and Bash 5.x
- Ideally test with `sh` and `zsh` if modifying shared functionality
- Use the test suite: `./tests/run_tests.sh`
- Document any shell-specific behavior differences

## Code Style Standards

In addition to linting requirements, follow these style guidelines:

- **Indentation**: 4 spaces (no tabs)
- **Line length**: Keep under 100 characters where reasonable
- **Variable names**: Use meaningful, descriptive names
- **Comments**: Add comments for complex logic or non-obvious behavior
- **Naming conventions**: Follow existing patterns in the codebase
  - Constants: `UPPERCASE_WITH_UNDERSCORES`
  - Functions: `lowercase_with_underscores`
  - Local variables: `lowercase_with_underscores`

## Summary Checklist for Copilot

Before proposing or generating code:

- [ ] Code passes ShellCheck (`--severity=warning --external-sources`)
- [ ] Markdown passes MarkdownLint
- [ ] Existing tests still pass
- [ ] New tests added for new functionality
- [ ] Commit message follows Semantic Versioning format
- [ ] Code is shell-agnostic when possible, with Bash as fallback
- [ ] Lines are under 100 characters where reasonable
- [ ] Comments explain complex logic
- [ ] Variable names are meaningful
- [ ] 4-space indentation is used throughout

## Questions?

For more information, see:

- [CONTRIBUTING.md](../CONTRIBUTING.md) - General contribution guidelines
- [docs/PRE-COMMIT.md](../docs/PRE-COMMIT.md) - Pre-commit hooks setup
- [docs/testing.md](../docs/testing.md) - Testing guidelines
- [.pre-commit-config.yaml](../.pre-commit-config.yaml) - Linting configuration
