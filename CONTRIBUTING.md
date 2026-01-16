# Contributing to bash-logger

Thank you for considering contributing to bash-logger! This logging module aims to be a reliable, easy-to-use tool for bash script developers.

## 🐛 Found a Bug?

Please [open a bug report issue](../../issues/new?template=bug_report.md) with:

- A clear description of the problem
- Steps to reproduce
- Your bash version (`bash --version`)
- Expected vs actual behavior

## 💡 Have a Feature Idea?

[Open a feature request](../../issues/new?template=feature_request.md) describing:

- Your use case
- Why this would be useful
- Any implementation ideas (optional)

## 🔧 Want to Submit a Pull Request?

Great! Here's the process:

1. **Set up pre-commit hooks** (recommended)

   - Pre-commit hooks automatically validate your code before committing
   - This ensures your changes pass checks before you push
   - See [Pre-commit Setup Guide](docs/PRE-COMMIT.md) for instructions
   - Quick start: `./scripts/setup-precommit.sh`
   - Note: The CI lint workflow runs the same pre-commit hooks, so ShellCheck and MarkdownLint versions are centralized in `.pre-commit-config.yaml`

2. **Fork the repository** and create a branch from `main`

3. **Make your changes**

   - Keep changes focused on a single issue/feature
   - Follow existing code style (see below)
   - Add comments for complex logic

4. **Test your changes**

   - Test with bash 4.x and 5.x if possible
   - Verify existing functionality still works
   - Run tests locally: `./tests/run_tests.sh`

5. **Submit a PR** linking to any related issues

### Coding Style

- Use 4 spaces for indentation (no tabs)
- Keep lines under 100 characters where reasonable
- Use meaningful variable names
- Prefer `[[ ]]` over `[ ]` for conditionals
- Quote variables unless you specifically need word splitting
- Follow existing naming conventions in the codebase

### Commit Messages

We follow **Semantic Versioning** commit message patterns to enable automated release management. This
ensures proper version bumping and release notes generation.

**Format:**

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Type** - Required. One of:

- `feat`: A new feature (minor version bump)
- `fix`: A bug fix (patch version bump)
- `docs`: Documentation changes
- `style`: Code style changes (formatting, missing semicolons, etc.)
- `refactor`: Code refactoring without feature changes
- `perf`: Performance improvements
- `test`: Test additions or updates
- `chore`: Build, dependency, or tooling changes
- `ci`: CI/CD configuration changes

**Scope** - Optional. The area affected (e.g., `logging`, `config`, `tests`)

**Subject** - Required. Brief description in present tense:

- Use imperative mood: "add" not "adds" or "added"
- Don't capitalize the first letter
- No period at the end
- Keep it under 50 characters

**Examples:**

```
feat(config): add support for custom log format
fix(logging): prevent logger initialization without level
docs: update contributing guidelines
refactor(tests): simplify test runner logic
```

The pre-commit hooks will validate your commit message format automatically.

## 📋 Code of Conduct

Please be respectful and professional in all interactions. Treat others with kindness and courtesy.

## ❓ Questions?

Feel free to [open a question issue](../../issues/new?template=question.md) or start a discussion. Response times may vary, but all contributions are appreciated!

## 📄 License

By contributing, you agree that your contributions will be licensed under the same license as the project.
