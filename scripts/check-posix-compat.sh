#!/usr/bin/env bash
#
# check-posix-compat.sh - Fail on shell syntax that dash and busybox ash do not support
#
# Usage: scripts/check-posix-compat.sh [file...]   (default: logging.sh)
#
# logging.sh is written for POSIX sh plus "local" (Issue #143). ShellCheck run with
# --shell=dash reports every construct outside that target as an SC3xxx finding.
# Constructs that are only reached in bash or zsh carry a "shellcheck disable"
# directive with the reason on the line above.

set -euo pipefail

if ! command -v shellcheck >/dev/null 2>&1; then
    echo "Error: shellcheck is not installed" >&2
    exit 2
fi

if [[ $# -eq 0 ]]; then
    set -- "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/logging.sh"
fi

status=0
for file in "$@"; do
    # Exit status 1 means findings; 2 or more means ShellCheck could not check
    # the file, which is an error here
    shellcheck_status=0
    shellcheck_output=$(shellcheck --shell=dash --format=gcc "$file" 2>&1) || shellcheck_status=$?
    if [[ $shellcheck_status -gt 1 ]]; then
        echo "$shellcheck_output" >&2
        echo "Error: shellcheck could not check $file (exit status $shellcheck_status)" >&2
        exit 2
    fi
    findings=$(printf '%s\n' "$shellcheck_output" | grep -E '\[SC3[0-9]{3}\]' || true)
    if [[ -n "$findings" ]]; then
        echo "$findings"
        status=1
    fi
done

if [[ $status -ne 0 ]]; then
    echo "" >&2
    echo "Error: syntax that dash and busybox ash do not support (see above)" >&2
    echo "  Hint: use a POSIX form, or guard bash-only code and add a justified disable" >&2
fi
exit "$status"
