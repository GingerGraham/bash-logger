# Pre-commit Hooks Setup Guide

This guide helps contributors set up pre-commit hooks for the bash-logger project. Pre-commit
hooks automatically check your code before you commit, catching issues early and ensuring
pipeline checks pass before you submit pull requests.

## Quick Start (Recommended)

If you have Python 3 installed, the easiest way is to run our setup script:

```bash
./scripts/setup-precommit.sh
```

The script will:

- Check for required dependencies (Python and pip)
- Install the pre-commit framework
- Configure git hooks from `.pre-commit-config.yaml`
- Run checks on existing files (optional)
- Provide next steps and useful commands

That's it! You're done. Pre-commit hooks are now active.

## What Pre-commit Does

Pre-commit hooks run automatically before each commit. They check:

1. **ShellCheck** - Validates Bash script syntax and common errors

   - Catches syntax errors, undefined variables, incorrect quoting, and more
   - Runs on all `.sh` files

2. **MarkdownLint** - Checks and auto-fixes Markdown formatting

   - Automatically fixes formatting issues (blank lines, trailing spaces, etc.)
   - For issues that can't be auto-fixed (line length), you'll need to fix manually
   - Ensures consistent formatting, proper headings, and link validation
   - Runs on all `.md` files

3. **Bash Logger Tests** - Runs the test suite

   - Verifies all changes pass the test suite
   - Prevents committing broken code

4. **Commit Message Format** - Validates semantic versioning format
   - Ensures commit messages follow the pattern: `<type>(<scope>): <subject>`
   - Enables automated release and version management
   - Provides clear feedback if message format is incorrect
   - Examples: `feat(logging): add color support`, `fix: prevent race condition`

When hooks run and auto-fix formatting (like MarkdownLint), the modified files will be
staged and your commit will proceed. If any check fails and can't be auto-fixed, your
commit will be blocked until you address the issues.

## Manual Installation (Alternative)

If you prefer to install manually or the script doesn't work for your setup:

### Prerequisites

- **Python 3.6+** - [Download here](https://www.python.org/)
- **pip** - Usually comes with Python 3

### Installation Steps

1. Install pre-commit framework:

   ```bash
   pip install --user pre-commit
   ```

2. Make sure pre-commit is in your PATH. If not found, add it:

   ```bash
   export PATH="$HOME/.local/bin:$PATH"
   ```

3. Install the git hooks:

   ```bash
   cd /path/to/gist-bash-logging
   pre-commit install
   ```

4. (Optional) Run hooks on all existing files:

   ```bash
   pre-commit run --all-files
   ```

## Common Commands

### Run all hooks on all files

```bash
pre-commit run --all-files
```

### Run a specific hook

```bash
pre-commit run shellcheck --all-files
pre-commit run markdownlint --all-files
pre-commit run bash-logger-tests --all-files
```

### Skip hooks for a single commit

If you need to commit without running hooks (not recommended):

```bash
git commit --no-verify
```

### Update pre-commit hooks to latest versions

```bash
pre-commit autoupdate
```

### Temporarily disable hooks

```bash
pre-commit uninstall
```

### Re-enable hooks after disabling

```bash
pre-commit install
```

## Troubleshooting

### "command not found: pre-commit"

The pre-commit command is not in your PATH. Try:

```bash
# Run as a module instead
python -m pre-commit run --all-files
```

Or add the user bin directory to your PATH. Common locations:

- Linux/Mac: `~/.local/bin`
- Windows with Python: `%APPDATA%\Python\Python3x\Scripts`

### "MarkdownLint failed to find Node.js"

MarkdownLint requires Node.js. Install it from [nodejs.org](https://nodejs.org/)

### "ShellCheck not found"

ShellCheck is installed via pip as part of pre-commit setup, but sometimes it needs the Python environment. Try:

```bash
python -m pip install --upgrade shellcheck-py
```

### Hooks are running but I want to skip them temporarily

For a single commit:

```bash
git commit --no-verify
```

To fully disable hooks temporarily:

```bash
pre-commit uninstall
# ... make your commits ...
pre-commit install
```

## Understanding Hook Failures

### ShellCheck Failures

ShellCheck finds potential issues in Bash scripts. Review its output and fix the issues. Common ones:

- Undefined variables - use quotes: `"$var"` instead of `$var`
- Unquoted variables in conditions
- Using `[` instead of `[[`

See [ShellCheck wiki](https://www.shellcheck.net/wiki/) for detailed explanations.

### MarkdownLint Failures

MarkdownLint automatically fixes many formatting issues (blank lines, trailing spaces, etc.). If it fixes issues, the modified files will be staged and your commit will proceed.

However, some issues require manual fixes:

- **Line length** - Lines exceeding 120 characters must be reworded or restructured
- **Content-related issues** - Problems that can't be fixed without changing your content

When MarkdownLint blocks your commit due to unfixable issues:

1. Review the error messages in the output
2. Manually fix the mentioned issues
3. Run `pre-commit run markdownlint --all-files` to verify fixes
4. Try committing again

See [MarkdownLint docs](https://github.com/igorshubovych/markdownlint-cli#rules) for detailed rule explanations.

### Test Suite Failures

If tests fail, it means your changes broke existing functionality. Run tests locally:

```bash
./tests/run_tests.sh
```

Check the output to understand what's failing and fix accordingly.

### Commit Message Format Failures

If your commit message doesn't follow semantic versioning format, the commit will be blocked
with a helpful error message.

**Common issues:**

- Missing type: Use `feat:`, `fix:`, `docs:`, etc. at the start
- Missing colon: Ensure format is `type(scope): message`
- Invalid type: Must be one of: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`,
  `chore`, `ci`

**To fix:**

1. Review the error message and examples provided
2. Reword your commit message to match the format
3. Amend the commit: `git commit --amend`
4. Try committing again

**Examples of valid commit messages:**

```
feat(config): add support for custom log format
fix: prevent logger initialization without level
docs: update contribution guidelines
refactor(tests): simplify test runner
chore: update dependencies
```

See [CONTRIBUTING.md](../CONTRIBUTING.md#commit-messages) for more details on the commit
message format and why we use semantic versioning.

## Hook Configuration

The hooks are configured in `.pre-commit-config.yaml` at the project root.

### Understanding the config

```yaml
repos:
  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.10.0
    hooks:
      - id: shellcheck
        args: [--severity=warning] # Only fail on warnings and above
```

- `repo` - Source of the hook
- `rev` - Version to use (update with `pre-commit autoupdate`)
- `hooks` - Specific hooks from that repo
- `args` - Arguments passed to the tool (configuration)

### Updating hooks

Pre-commit hooks get updates periodically. Keep them current:

```bash
pre-commit autoupdate
```

This updates `.pre-commit-config.yaml` to use newer versions.

## Integration with CI/CD

These same checks run in GitHub Actions on every pull request. Setting up pre-commit locally means:

- You catch issues before pushing
- Faster feedback cycle
- Fewer failed pipeline runs
- Better code quality overall

It's a win-win!

## For Maintainers: Managing Pre-commit

### Adding a new hook

Edit `.pre-commit-config.yaml` and add a new repo/hook section, then commit. Contributors will get the new hook on their next `pre-commit install`.

### Updating hook versions

```bash
pre-commit autoupdate
```

Commits the updated versions to git.

### Skipping a hook for specific files

In `.pre-commit-config.yaml`, add `exclude` patterns:

```yaml
- id: shellcheck
  exclude: |
    (?x)^(
      scripts/legacy.*|
      demo-scripts/.*
    )$
```

## Additional Resources

- [Pre-commit Documentation](https://pre-commit.com/)
- [ShellCheck Documentation](https://www.shellcheck.net/)
- [MarkdownLint Rules](https://github.com/igorshubovych/markdownlint-cli#rules)
- [Getting Started with Contributing](CONTRIBUTING.md)

## Questions?

If you have issues with pre-commit setup, please:

1. Check the troubleshooting section above
2. Review the [GitHub Issues](https://github.com/GingerGraham/gist-bash-logging/issues)
3. Run with verbose output: `pre-commit run --all-files -v`
4. Open a new issue if you find a bug or have a feature request

Happy contributing! 🚀
