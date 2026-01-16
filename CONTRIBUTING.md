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

1. **Fork the repository** and create a branch from `main`
2. **Make your changes**
   - Keep changes focused on a single issue/feature
   - Follow existing code style (see below)
   - Add comments for complex logic
3. **Test your changes**
   - Test with bash 4.x and 5.x if possible
   - Verify existing functionality still works
4. **Submit a PR** linking to any related issues

### Coding Style

- Use 4 spaces for indentation (no tabs)
- Keep lines under 100 characters where reasonable
- Use meaningful variable names
- Prefer `[[ ]]` over `[ ]` for conditionals
- Quote variables unless you specifically need word splitting
- Follow existing naming conventions in the codebase

### Commit Messages

- Use clear, descriptive commit messages
- Start with a verb in present tense: "Add feature" not "Added feature"
- Reference issue numbers where applicable: "Fix log rotation (#42)"

## 📋 Code of Conduct

Please be respectful and professional in all interactions. Treat others with kindness and courtesy.

## ❓ Questions?

Feel free to [open a question issue](../../issues/new?template=question.md) or start a discussion. Response times may vary, but all contributions are appreciated!

## 📄 License

By contributing, you agree that your contributions will be licensed under the same license as the project.
