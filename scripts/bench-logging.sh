#!/usr/bin/env bash
#
# bench-logging.sh - Measure the per-message cost of logging.sh (Issue #143)
#
# Usage:
#   scripts/bench-logging.sh [options] [shell...]
#
# Options:
#   --scenario NAME      Run only this scenario; repeat for more (default: all, see below)
#   --rounds N           Runs per shell and scenario; the median is reported (default: 5)
#   --logging FILE       logging.sh to measure (default: the one in this repository)
#   --baseline FILE      Also measure this logging.sh in every shell and compare
#   --max-ratio R        With --baseline, fail when candidate/baseline exceeds R and the
#                        difference is at least 100 microseconds (default: 1.15)
#   --max-scaling R      Fail when lines-256k / lines-16k per-message time exceeds R in a
#                        shell; linear growth is 16 (default: 32)
#
# Shells default to "bash". A shell command can include flags when quoted, e.g.
# "bash --posix" or "busybox sh".
#
# Scenarios (all use --quiet --no-color except console):
#   plain        60 ASCII characters, log_info
#   filtered     60 ASCII characters, log_debug below the level (filtered out)
#   console      60 ASCII characters to the console with --color
#   format       60 ASCII characters with --format %d:%z:%l:%s:%m
#   ansi         60 characters with \033[31m and \033[0m
#   long-line    4 KB, no control characters
#   utf8         4,000 two-byte characters
#   huge-line    100 KB, no control characters
#   lines-4k     4 KB, a newline every 64 bytes (also lines-16k, lines-64k, lines-256k)
#
# Each run sources logging.sh, calls init_logger, reads the message from a file and
# logs it in a loop. A run with zero messages is timed too and subtracted, so shell
# start-up, sourcing and init_logger are not counted per message; that cost is printed
# as an information row. A run that exits non-zero, or whose log file does not have the
# expected number of lines, prints FAIL and stops the script.
#
# Examples:
#   scripts/bench-logging.sh bash dash "busybox sh" zsh
#   scripts/bench-logging.sh --scenario plain --scenario lines-64k dash
#   scripts/bench-logging.sh --baseline /tmp/main-logging.sh bash zsh

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
round_count=5
logging_file="$script_dir/../logging.sh"
baseline_file=""
max_ratio="1.15"
max_scaling="32"
# A candidate/baseline difference smaller than this is timing noise, whatever the ratio
min_difference_us=100
shells=()
selected_scenarios=()

all_scenarios=(plain filtered console format ansi long-line utf8 huge-line
    lines-4k lines-16k lines-64k lines-256k)

while [[ $# -gt 0 ]]; do
    case "$1" in
        --scenario) selected_scenarios+=("$2"); shift 2 ;;
        --rounds) round_count="$2"; shift 2 ;;
        --logging) logging_file="$2"; shift 2 ;;
        --baseline) baseline_file="$2"; shift 2 ;;
        --max-ratio) max_ratio="$2"; shift 2 ;;
        --max-scaling) max_scaling="$2"; shift 2 ;;
        -h|--help) sed -n '3,44p' "$0"; exit 0 ;;
        -*) echo "Unknown option: $1" >&2; exit 2 ;;
        *) shells+=("$1"); shift ;;
    esac
done
if [[ ${#shells[@]} -eq 0 ]]; then
    shells=("bash")
fi
if [[ ${#selected_scenarios[@]} -eq 0 ]]; then
    selected_scenarios=("${all_scenarios[@]}")
fi

# Print a path as an absolute path. "." searches PATH for a name without a slash, so
# the benchmarked file must always be given with its directory.
absolute_path() {
    local path="$1"
    case "$path" in
        /*) printf '%s\n' "$path" ;;
        *) printf '%s/%s\n' "$PWD" "$path" ;;
    esac
}
logging_file=$(absolute_path "$logging_file")
if [[ -n "$baseline_file" ]]; then
    baseline_file=$(absolute_path "$baseline_file")
fi

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

# Scenario settings: message count, log function, extra init_logger arguments
scenario_settings() {
    local scenario="$1"
    scenario_count=""
    scenario_function="log_info"
    scenario_args="--quiet --no-color"
    case "$scenario" in
        plain) scenario_count=300 ;;
        filtered) scenario_count=2000; scenario_function="log_debug" ;;
        console) scenario_count=300; scenario_args="--color" ;;
        format) scenario_count=300; scenario_args="--quiet --no-color --format '%d:%z:%l:%s:%m'" ;;
        ansi) scenario_count=200 ;;
        long-line) scenario_count=200 ;;
        utf8) scenario_count=100 ;;
        huge-line) scenario_count=30 ;;
        lines-4k) scenario_count=100 ;;
        lines-16k) scenario_count=50 ;;
        lines-64k) scenario_count=10 ;;
        lines-256k) scenario_count=3 ;;
        *)
            echo "Unknown scenario: $scenario" >&2
            echo "  Valid scenarios: ${all_scenarios[*]}" >&2
            exit 2
            ;;
    esac
}

# Write the message for a scenario to $work_dir/message.<scenario>, once
write_message() {
    local scenario="$1"
    local message_file="$work_dir/message.$scenario"
    [[ -f "$message_file" ]] && return 0
    case "$scenario" in
        plain|filtered|console|format)
            printf '%s' "benchmark message with some ordinary text, sixty chars long" ;;
        ansi)
            printf 'benchmark \033[31mred\033[0m message with ordinary text, sixty' ;;
        long-line)
            awk 'BEGIN { for (i = 0; i < 4096; i++) printf "%c", 97 + i % 26 }' ;;
        utf8)
            awk 'BEGIN { for (i = 0; i < 4000; i++) printf "\303\251" }' ;;
        huge-line)
            awk 'BEGIN { for (i = 0; i < 102400; i++) printf "%c", 97 + i % 26 }' ;;
        lines-*)
            # 63 characters and a newline, repeated to the size; no final newline
            local kilobytes="${scenario#lines-}"
            kilobytes="${kilobytes%k}"
            awk -v lines=$((kilobytes * 1024 / 64)) 'BEGIN {
                for (i = 0; i < lines; i++) {
                    for (j = 0; j < 63; j++) printf "%c", 97 + (i + j) % 26
                    if (i < lines - 1) printf "\n"
                }
            }' ;;
    esac > "$message_file"
}

# The timed program, in POSIX sh so every shell runs the same code.
# BENCH_INIT_ARGS is split with eval because zsh does not split an unquoted variable.
cat > "$work_dir/bench.sh" <<'BENCH'
. "$BENCH_LOGGING" || exit 90
eval "set -- $BENCH_INIT_ARGS"
init_logger "$@" --log "$BENCH_DIR/bench.log" || exit 91
message=$(cat "$BENCH_MESSAGE_FILE")
iteration=0
while [ "$iteration" -lt "$BENCH_COUNT" ]; do
    "$BENCH_FUNCTION" "$message"
    iteration=$((iteration + 1))
done
BENCH

# Run the benchmark program once, check the result and print its elapsed seconds.
# Returns 1 (after printing the reason to stderr) if the run failed.
time_one_run() {
    local shell_command="$1"
    local logging_path="$2"
    local scenario="$3"
    local count="$4"
    local elapsed=""
    local run_status=0

    rm -f "$work_dir/bench.log"
    TIMEFORMAT='%3R'
    # shellcheck disable=SC2086  # word splitting of shell_command is intended
    elapsed=$( { time BENCH_LOGGING="$logging_path" BENCH_DIR="$work_dir" \
        BENCH_COUNT="$count" BENCH_FUNCTION="$scenario_function" \
        BENCH_INIT_ARGS="$scenario_args" BENCH_MESSAGE_FILE="$work_dir/message.$scenario" \
        $shell_command "$work_dir/bench.sh" >/dev/null 2>"$work_dir/stderr"; } 2>&1 ) \
        || run_status=$?

    if [[ $run_status -ne 0 ]]; then
        echo "exit status $run_status" >&2
        return 1
    fi

    # init_logger writes one line; each logged message adds one (newlines are replaced)
    local expected_lines=$((count + 1))
    if [[ "$scenario_function" == "log_debug" ]]; then
        expected_lines=1
    fi
    local actual_lines=0
    if [[ -f "$work_dir/bench.log" ]]; then
        actual_lines=$(wc -l < "$work_dir/bench.log" | tr -d ' ')
    fi
    if [[ "$actual_lines" -ne "$expected_lines" ]]; then
        echo "log has $actual_lines lines, expected $expected_lines" >&2
        return 1
    fi

    printf '%s\n' "$elapsed"
}

# Print the median of numbers given one per line on stdin
median() {
    sort -n | awk '{ value[NR] = $1 }
        END {
            if (NR % 2) { printf "%.1f\n", value[(NR + 1) / 2] }
            else { printf "%.1f\n", (value[NR / 2] + value[NR / 2 + 1]) / 2 }
        }'
}

# Measure one logging.sh under one shell and scenario.
# Sets measured_us (median per message) and measured_init_us (median of the
# zero-message runs, less the bare shell start-up). Returns 1 if a run failed.
measure() {
    local shell_command="$1"
    local logging_path="$2"
    local scenario="$3"
    local round=0
    local zero_seconds=""
    local full_seconds=""
    local bare_seconds=""
    local per_message=""
    local init_costs=""

    while [[ $round -lt $round_count ]]; do
        zero_seconds=$(time_one_run "$shell_command" "$logging_path" "$scenario" 0) || return 1
        full_seconds=$(time_one_run "$shell_command" "$logging_path" "$scenario" \
            "$scenario_count") || return 1
        per_message="$per_message
$(awk -v zero="$zero_seconds" -v full="$full_seconds" -v n="$scenario_count" \
            'BEGIN { printf "%.3f\n", (full - zero) * 1000000 / n }')"
        TIMEFORMAT='%3R'
        # shellcheck disable=SC2086  # word splitting of shell_command is intended
        bare_seconds=$( { time $shell_command -c : >/dev/null 2>&1; } 2>&1 )
        init_costs="$init_costs
$(awk -v zero="$zero_seconds" -v bare="$bare_seconds" \
            'BEGIN { printf "%.3f\n", (zero - bare) * 1000000 }')"
        round=$((round + 1))
    done
    measured_us=$(printf '%s\n' "$per_message" | sed '/^$/d' | median)
    measured_init_us=$(printf '%s\n' "$init_costs" | sed '/^$/d' | median)
}

# Print the end of the last run's stderr and stop
fail_run() {
    local shell_command="$1"
    local scenario="$2"
    local label="$3"
    printf 'FAIL %s %s (%s)\n' "$shell_command" "$scenario" "$label"
    if [[ -s "$work_dir/stderr" ]]; then
        echo "  stderr (last 5 lines):"
        tail -5 "$work_dir/stderr" | sed 's/^/    /'
    fi
    exit 1
}

check_failures=()
for shell_command in "${shells[@]}"; do
    baseline_available="false"
    if [[ -n "$baseline_file" ]]; then
        baseline_available="true"
    fi
    lines_16k_us=""
    lines_256k_us=""
    init_reported="false"

    for scenario in "${selected_scenarios[@]}"; do
        scenario_settings "$scenario"
        write_message "$scenario"

        if ! measure "$shell_command" "$logging_file" "$scenario" 2>"$work_dir/reason"; then
            fail_run "$shell_command" "$scenario" "$(cat "$work_dir/reason")"
        fi
        candidate_us="$measured_us"

        if [[ "$init_reported" == "false" ]]; then
            printf '%-14s %-12s %10s us (source + init_logger, information only)\n' \
                "$shell_command" "init" "$measured_init_us"
            init_reported="true"
        fi

        case "$scenario" in
            lines-16k) lines_16k_us="$candidate_us" ;;
            lines-256k) lines_256k_us="$candidate_us" ;;
        esac

        if [[ "$baseline_available" != "true" ]]; then
            printf '%-14s %-12s %10s us/message\n' "$shell_command" "$scenario" "$candidate_us"
            continue
        fi

        # The baseline may not run in every shell (main is bash/zsh only before
        # Issue #143); that is reported once and is not a failure
        if ! measure "$shell_command" "$baseline_file" "$scenario" 2>"$work_dir/reason"; then
            printf '%-14s %-12s %10s us/message, baseline unavailable (%s)\n' \
                "$shell_command" "$scenario" "$candidate_us" "$(cat "$work_dir/reason")"
            baseline_available="false"
            continue
        fi
        baseline_us="$measured_us"
        ratio=$(awk -v c="$candidate_us" -v b="$baseline_us" 'BEGIN { printf "%.3f\n", c / b }')
        verdict="ok"
        if awk -v c="$candidate_us" -v b="$baseline_us" -v r="$ratio" -v m="$max_ratio" \
            -v floor="$min_difference_us" 'BEGIN { exit !(c - b >= floor && r > m) }'; then
            verdict="SLOWER"
            check_failures+=("$shell_command $scenario: ratio $ratio > $max_ratio")
        fi
        printf '%-14s %-12s %10s us/message, baseline %10s, ratio %s %s\n' \
            "$shell_command" "$scenario" "$candidate_us" "$baseline_us" "$ratio" "$verdict"
    done

    # Growth from 16 KB to 256 KB messages: 16 is linear
    if [[ -n "$lines_16k_us" && -n "$lines_256k_us" ]]; then
        scaling=$(awk -v a="$lines_256k_us" -v b="$lines_16k_us" 'BEGIN { printf "%.1f\n", a / b }')
        verdict="ok"
        if awk -v s="$scaling" -v m="$max_scaling" 'BEGIN { exit !(s > m) }'; then
            verdict="TOO STEEP"
            check_failures+=("$shell_command scaling: lines-256k / lines-16k = $scaling > $max_scaling")
        fi
        printf '%-14s %-12s %10s (lines-256k / lines-16k, linear is 16) %s\n' \
            "$shell_command" "scaling" "$scaling" "$verdict"
    fi
done

if [[ ${#check_failures[@]} -gt 0 ]]; then
    echo "" >&2
    for failure in "${check_failures[@]}"; do
        echo "FAIL $failure" >&2
    done
    exit 1
fi
exit 0
