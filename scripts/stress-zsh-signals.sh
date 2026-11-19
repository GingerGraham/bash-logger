#!/usr/bin/env bash
#
# stress-zsh-signals.sh - Check that a trap handler that logs does not crash zsh (Issue #153)
#
# zsh 5.9 can crash when a signal handler runs while the interrupted code is in pattern
# matching or a "[" test. This script runs the library the way that crashes it: a handler
# that logs (log_warn) on about 50 USR1 signals per second, and a main loop that logs
# (log_info). A crash ends the shell with a status of 128 or more.
#
# It is not part of the test suite, because each run lasts the full duration (8 seconds by
# default) and a crash is only likely, not certain, within it. On the main branch without the
# guard in _log_message, about half the runs crash within 1 second and none last 5 seconds.
# A pass is not proof that the crash cannot happen: 0 crashes in 30 runs is consistent with a
# true rate of up to about 10 percent.
#
# Usage:
#   scripts/stress-zsh-signals.sh [options]
#   make stress-zsh [STRESS_ARGS='--runs 5']
#
# Options:
#   --duration N   Seconds per run (default: 8)
#   --runs N       Runs per zsh mode (default: 1)
#   --logging FILE logging.sh to test (default: the one in this repository)
#
# Each run is made in plain zsh and in "zsh --emulate sh", where the zsh/parameter module is
# not loaded unless the library loads it. Both modes must pass.
#
# Exit status: 0 when no run crashed or hung, 1 when one did, 2 on a usage error or when zsh
# is not installed.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

duration=8
runs=1
logging_file="$PROJECT_ROOT/logging.sh"

usage_error() {
    echo "Error: $1" >&2
    echo "Usage: scripts/stress-zsh-signals.sh [--duration N] [--runs N] [--logging FILE]" >&2
    exit 2
}

require_number() {
    case "$2" in
        ''|*[!0123456789]*) usage_error "$1 needs a whole number, not '$2'" ;;
    esac
    if [[ "$2" -lt 1 ]]; then
        usage_error "$1 must be at least 1"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --duration)
            [[ $# -ge 2 ]] || usage_error "--duration needs a value"
            require_number "--duration" "$2"
            duration="$2"
            shift 2
            ;;
        --runs)
            [[ $# -ge 2 ]] || usage_error "--runs needs a value"
            require_number "--runs" "$2"
            runs="$2"
            shift 2
            ;;
        --logging)
            [[ $# -ge 2 ]] || usage_error "--logging needs a value"
            logging_file="$2"
            shift 2
            ;;
        *)
            usage_error "unknown option '$1'"
            ;;
    esac
done

if ! command -v zsh >/dev/null 2>&1; then
    echo "Error: zsh is not installed" >&2
    exit 2
fi
if [[ ! -r "$logging_file" ]]; then
    usage_error "cannot read $logging_file"
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

# The script under test. It is zsh syntax, and "until (( ))" is used for the loop because a
# "[" test in the main loop would make the main code itself a trigger, which no library code
# can guard. The signal sender is a plain loop that stops when the shell has gone.
cat > "$work_dir/stress.zsh" << 'EOF'
. "$LOGGER_FILE"
init_logger --no-color --quiet
trap 'log_warn "signal received"' USR1
( while kill -USR1 $$ 2>/dev/null; do sleep 0.02; done ) &
sender=$!
SECONDS=0
until (( SECONDS >= STRESS_SECONDS )); do
    log_info "loop message"
done
kill $sender 2>/dev/null
EOF

failures=0
for mode in "zsh -f" "zsh --emulate sh -f"; do
    crashed=0
    for ((run = 1; run <= runs; run++)); do
        status=0
        # The limit is generous, so that a hang is reported, not waited on forever. The group
        # redirection also hides the shell's own "Segmentation fault" notice, because the
        # status is reported below.
        {
            # shellcheck disable=SC2086  # word splitting of the mode is intended
            LOGGER_FILE="$logging_file" STRESS_SECONDS="$duration" \
                timeout -k 5 "$((duration + 30))" $mode "$work_dir/stress.zsh" \
                > /dev/null 2>&1 < /dev/null || status=$?
        } 2> /dev/null
        if [[ "$status" -ne 0 ]]; then
            crashed=$((crashed + 1))
            if [[ "$status" -ge 128 ]]; then
                echo "  run $run in [$mode] ended with status $status (a signal, 139 is a crash)"
            else
                echo "  run $run in [$mode] ended with status $status"
            fi
        fi
    done
    if [[ "$crashed" -eq 0 ]]; then
        echo "✓ [$mode]: $runs run(s) of $duration s, no crash"
    else
        echo "✗ [$mode]: $crashed of $runs run(s) of $duration s failed"
        failures=$((failures + crashed))
    fi
done

if [[ "$failures" -ne 0 ]]; then
    exit 1
fi
exit 0
