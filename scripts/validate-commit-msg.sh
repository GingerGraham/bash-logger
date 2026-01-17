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
# Matches: type(optional-scope)(optional-!): subject
# The ! indicates a breaking change (BREAKING CHANGE)
# Example: feat(config): add support for custom format
# Example: fix: prevent initialization without level
# Example: feat!: declare stable 1.0 API (breaking change)
# Example: feat(config)!: breaking change with scope
PATTERN='^(feat|fix|docs|style|refactor|perf|test|chore|ci)(\(.+\))?!?: .+$'

if ! [[ "$SUBJECT" =~ $PATTERN ]]; then
    echo "❌ Commit message does not follow semantic versioning format"
    echo ""
    echo "Expected format:"
    echo "  <type>(<scope>): <subject>"
    echo "  <type>!: <subject>                    (breaking change)"
    echo "  <type>(<scope>)!: <subject>           (breaking change with scope)"
    echo ""
    echo "Types: feat, fix, docs, style, refactor, perf, test, chore, ci"
    echo "Scope: optional, e.g. (logging), (config), (tests)"
    echo "Breaking change: optional !, indicates BREAKING CHANGE"
    echo ""
    echo "Examples:"
    echo "  feat(config): add support for custom log format"
    echo "  fix: prevent logger initialization without level"
    echo "  docs: update contributing guidelines"
    echo "  feat!: declare stable 1.0 API"
    echo "  feat(config)!: breaking config change"
    echo ""
    echo "Your commit message:"
    echo "  $SUBJECT"
    echo ""
    exit 1
fi

exit 0
