#!/usr/bin/env bash
#
# bench-logging.sh - Measure the per-message cost of logging.sh (Issue #143)
#
# Usage:
#   scripts/bench-logging.sh [options] [shell...]
#
# Options:
#   --count N            Messages logged per run (default: 500)
#   --rounds N           Runs per shell; the fastest run is reported (default: 3)
#   --logging FILE       logging.sh to measure (default: the one in this repository)
#   --baseline FILE      Also measure this logging.sh and compare (bash only)
#   --max-ratio R        With --baseline, fail when candidate/baseline exceeds R
#                        (default: 1.05, a 5% allowance for timing noise)
#
# Shells default to "bash". A shell command can include flags when quoted,
# e.g. "bash --posix" or "busybox sh".
#
# Each run sources logging.sh, logs to a file with console output off, and times
# only the logging loop. Output is one line per shell:
#   <shell>  <microseconds per message>
#
# Examples:
#   scripts/bench-logging.sh bash dash "busybox sh"
#   scripts/bench-logging.sh --baseline /tmp/main-logging.sh bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
message_count=500
round_count=3
logging_file="$script_dir/../logging.sh"
baseline_file=""
max_ratio="1.05"
shells=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --count) message_count="$2"; shift 2 ;;
        --rounds) round_count="$2"; shift 2 ;;
        --logging) logging_file="$2"; shift 2 ;;
        --baseline) baseline_file="$2"; shift 2 ;;
        --max-ratio) max_ratio="$2"; shift 2 ;;
        -h|--help) sed -n '3,26p' "$0"; exit 0 ;;
        -*) echo "Unknown option: $1" >&2; exit 2 ;;
        *) shells+=("$1"); shift ;;
    esac
done
if [[ ${#shells[@]} -eq 0 ]]; then
    shells=("bash")
fi

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

# The timed loop, in POSIX sh so every shell runs the same code
cat > "$work_dir/bench.sh" <<'BENCH'
. "$BENCH_LOGGING"
init_logger --quiet --no-color --log "$BENCH_DIR/bench.log"
iteration=0
while [ "$iteration" -lt "$BENCH_COUNT" ]; do
    log_info "benchmark message number $iteration with some ordinary text"
    iteration=$((iteration + 1))
done
BENCH

# Print elapsed seconds for one run of the loop under a shell
time_one_run() {
    local shell_command="$1"
    local logging_path="$2"
    local elapsed
    # Time a run with zero messages too, and subtract it, so startup and init_logger
    # are not counted
    local timed_runs=""
    local count
    for count in 0 "$message_count"; do
        rm -f "$work_dir/bench.log"
        TIMEFORMAT='%R'
        # shellcheck disable=SC2086  # word splitting of shell_command is intended
        elapsed=$( { time BENCH_LOGGING="$logging_path" BENCH_DIR="$work_dir" \
            BENCH_COUNT="$count" $shell_command "$work_dir/bench.sh" >/dev/null 2>&1; } 2>&1 )
        timed_runs="$timed_runs $elapsed"
    done
    # shellcheck disable=SC2086
    set -- $timed_runs
    awk -v startup="$1" -v total="$2" 'BEGIN { printf "%.6f\n", total - startup }'
}

# Print microseconds per message, the fastest of round_count runs
measure() {
    local shell_command="$1"
    local logging_path="$2"
    local best=""
    local round=0
    local seconds
    while [[ $round -lt $round_count ]]; do
        seconds=$(time_one_run "$shell_command" "$logging_path")
        if [[ -z "$best" ]] || awk -v a="$seconds" -v b="$best" 'BEGIN { exit !(a < b) }'; then
            best="$seconds"
        fi
        round=$((round + 1))
    done
    awk -v s="$best" -v n="$message_count" 'BEGIN { printf "%.1f\n", s * 1000000 / n }'
}

status=0
for shell_command in "${shells[@]}"; do
    candidate_us=$(measure "$shell_command" "$logging_file")
    printf '%-14s %10s us/message\n' "$shell_command" "$candidate_us"

    if [[ -n "$baseline_file" && "${shell_command%% *}" == "bash" ]]; then
        baseline_us=$(measure "$shell_command" "$baseline_file")
        ratio=$(awk -v c="$candidate_us" -v b="$baseline_us" 'BEGIN { printf "%.3f\n", c / b }')
        printf '%-14s %10s us/message (baseline), ratio %s\n' "$shell_command" "$baseline_us" "$ratio"
        if awk -v r="$ratio" -v m="$max_ratio" 'BEGIN { exit !(r > m) }'; then
            echo "FAIL: $shell_command is slower than the baseline (ratio $ratio > $max_ratio)" >&2
            status=1
        fi
    fi
done
exit "$status"
