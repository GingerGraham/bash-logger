#!/usr/bin/env bash
#
# Validate commit message follows semantic versioning format
#
# This script enforces commit messages follow the format:
#   <type>(<scope>): <subject>
#
# Where type is one of: feat, fix, docs, style, refactor, perf, test, chore, ci

set -euo pipefail

# Get the commit message
if [[ $# -gt 0 ]]; then
    # If argument is provided, read from file (pre-commit commit-msg hook)
    COMMIT_MSG=$(cat "$1")
else
    # Otherwise read from stdin
    COMMIT_MSG=$(cat)
fi

# Get the first line (subject line)
SUBJECT=$(echo "$COMMIT_MSG" | head -n1)

# Regex pattern for semantic versioning commit format
# Matches: type(optional-scope): subject
# Example: feat(config): add support for custom format
# Example: fix: prevent initialization without level
PATTERN='^(feat|fix|docs|style|refactor|perf|test|chore|ci)(\(.+\))?: .+$'

if ! [[ "$SUBJECT" =~ $PATTERN ]]; then
    echo "❌ Commit message does not follow semantic versioning format"
    echo ""
    echo "Expected format:"
    echo "  <type>(<scope>): <subject>"
    echo ""
    echo "Types: feat, fix, docs, style, refactor, perf, test, chore, ci"
    echo "Scope: optional, e.g. (logging), (config), (tests)"
    echo ""
    echo "Examples:"
    echo "  feat(config): add support for custom log format"
    echo "  fix: prevent logger initialization without level"
    echo "  docs: update contributing guidelines"
    echo ""
    echo "Your commit message:"
    echo "  $SUBJECT"
    echo ""
    exit 1
fi

exit 0
