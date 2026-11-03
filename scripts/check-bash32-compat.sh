#!/usr/bin/env bash
#
# check-bash32-compat.sh - Fail when a file uses syntax that needs bash 4.0 or later
#
# macOS ships bash 3.2 as /bin/bash. ShellCheck does not flag bash 4+ features
# when the target shell is bash, so this script covers that gap.
#
# Usage:
#   scripts/check-bash32-compat.sh [file ...]
#
# With no arguments, logging.sh is checked. Comment-only lines are ignored. A line
# that must keep a flagged construct (for example a guarded fallback) can carry the
# marker "bash32-compat: ignore" in a trailing comment.
#
# Exit status: 0 when no bash 4+ syntax is found, 1 when it is, 2 on a usage error.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

IGNORE_MARKER="bash32-compat: ignore"

# Each rule is "description => extended regular expression".
# The description is separated from the expression at the first " => ".
NAME_CHARS='[A-Za-z_0-9@*]+(\[[^]]*\])?'
RULES=(
    "case-modification expansion: \${var,,} \${var^^} \${var,} \${var^} => \\\$\\{!?${NAME_CHARS}(,,?|\\^\\^?)"
    "parameter transformation: \${var@Q} and other @ operators => \\\$\\{!?${NAME_CHARS}@[A-Za-z]\\}"
    "associative array or nameref: declare/local -A, -n => (declare|local|typeset|readonly)[[:space:]]+-[a-zA-Z]*[An]([[:space:]]|\$)"
    "mapfile or readarray => (^|[^A-Za-z0-9_])(mapfile|readarray)([^A-Za-z0-9_]|\$)"
    "coproc => (^|[^A-Za-z0-9_])coproc([^A-Za-z0-9_]|\$)"
    "variable test: [[ -v name ]] => (\\[\\[|&&|\\|\\|)[[:space:]]+(![[:space:]]+)?-v[[:space:]]"
    "append redirection: &>> => &>>"
    "pipe stderr shorthand: |& => (^|[^|])\\|&([^&]|\$)"
    "negative array subscript => [A-Za-z_0-9]\\[-[0-9\$][^]]*\\]"
    "printf time formatting: %(format)T => %\\([^)]*\\)T"
    "EPOCHSECONDS or EPOCHREALTIME => (EPOCHSECONDS|EPOCHREALTIME)"
    "file descriptor allocation: {fd}> => (^|[^\$])\\{[A-Za-z_][A-Za-z_0-9]*\\}[<>]"
)

if [[ $# -gt 0 ]]; then
    files=("$@")
else
    files=("$PROJECT_ROOT/logging.sh")
fi

violations=0

for file in "${files[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "Error: file not found: $file" >&2
        exit 2
    fi

    for rule in "${RULES[@]}"; do
        description="${rule%% => *}"
        pattern="${rule#* => }"

        # -n gives "line:text"; the second grep drops comment-only and exempted lines.
        matches=$(grep -nE -e "$pattern" "$file" \
            | grep -vE -e '^[0-9]+:[[:space:]]*#' -e "$IGNORE_MARKER")

        if [[ -n "$matches" ]]; then
            while IFS= read -r match; do
                echo "$file:${match%%:*}: bash 4+ syntax: $description" >&2
                echo "    ${match#*:}" >&2
            done <<< "$matches"
            violations=$((violations + 1))
        fi
    done
done

if [[ $violations -gt 0 ]]; then
    echo "" >&2
    echo "Bash 3.2 (macOS /bin/bash) does not support the syntax above." >&2
    echo "Use a portable alternative, or see docs/testing.md for the supported versions." >&2
    exit 1
fi

exit 0
