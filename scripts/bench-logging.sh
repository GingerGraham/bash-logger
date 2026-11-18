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
#   --count N            Log N messages per run in every scenario, instead of the count each
#                        scenario has (a small N makes a quick test run)
#   --logging FILE       logging.sh to measure (default: the one in this repository)
#   --baseline FILE      Also measure this logging.sh in every shell and compare
#   --max-ratio R        With --baseline, fail when candidate/baseline exceeds R and the
#                        difference is at least 100 microseconds (default: 1.15)
#   --max-scaling R      Fail when lines-256k / lines-16k per-message time exceeds R in a
#                        shell; linear growth is 16 (default: 32)
#   --summary FILE       Append the results as a markdown table to FILE, with the limits,
#                        the shell versions and the number of CPUs. The workflow passes
#                        $GITHUB_STEP_SUMMARY. The table is written when the run fails too.
#   --calibrate N        Do not compare releases. Compare logging.sh with a copy of itself N
#                        times per shell and scenario, and print the minimum, median and
#                        maximum ratio and how many comparisons were over the limit. The
#                        thresholds should sit well above the maximum. Exits 0 unless a run
#                        fails, so the numbers can be read after a bad result.
#   --calibration-file F With --calibrate, also write one tab-separated row per shell and
#                        scenario to F: shell, scenario, runs, min, median, max, over the
#                        limit, over the limit after measuring again
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
# With --baseline, each round times the candidate and the baseline one after the other, and
# swaps which goes first every round, so a change in machine load affects both. When a
# comparison or the scaling check is over its limit, the script says so and measures again
# with twice the rounds. It fails only when the second measurement is over the limit too.
# A baseline that cannot run (for example a release too old to source) is reported once per
# row as unavailable and does not fail the run.
#
# Examples:
#   scripts/bench-logging.sh bash dash "busybox sh" zsh
#   scripts/bench-logging.sh --scenario plain --scenario lines-64k dash
#   scripts/bench-logging.sh --baseline /tmp/main-logging.sh bash zsh
#
# The file can be sourced, as the tests do: it then defines its functions and runs nothing.
# The verdict functions (compute_ratio, is_slower, compute_scaling, scaling_too_steep and
# median) take plain numbers.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
round_count=5
# Empty means each scenario uses its own message count
count_override=""
logging_file="$script_dir/../logging.sh"
baseline_file=""
max_ratio="1.15"
max_scaling="32"
# A candidate/baseline difference smaller than this is timing noise, whatever the ratio
min_difference_us=100
# Empty means a normal run; a number makes it a calibration run of that many comparisons
calibrate_runs=""
calibration_file=""
summary_file=""
confirm_rounds=10
shells=()
selected_scenarios=()

all_scenarios=(plain filtered console format ansi long-line utf8 huge-line
    lines-4k lines-16k lines-64k lines-256k)

# Print the usage text at the top of this file
print_usage() {
    awk 'NR >= 3 && /^#/ { sub(/^# ?/, ""); print; next } NR >= 3 { exit }' \
        "${BASH_SOURCE[0]}"
}

# Read the command line into the settings above
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --scenario) selected_scenarios+=("$2"); shift 2 ;;
            --rounds) round_count="$2"; shift 2 ;;
            --count)
                case "$2" in
                    ''|*[!0-9]*|0)
                        echo "Error: --count needs a positive integer, not '$2'" >&2
                        exit 2
                        ;;
                esac
                count_override="$2"
                shift 2
                ;;
            --logging) logging_file="$2"; shift 2 ;;
            --baseline) baseline_file="$2"; shift 2 ;;
            --max-ratio) max_ratio="$2"; shift 2 ;;
            --max-scaling) max_scaling="$2"; shift 2 ;;
            --calibrate)
                case "$2" in
                    ''|*[!0-9]*|0)
                        echo "Error: --calibrate needs a positive integer, not '$2'" >&2
                        exit 2
                        ;;
                esac
                calibrate_runs="$2"
                shift 2
                ;;
            --calibration-file) calibration_file="$2"; shift 2 ;;
            --summary) summary_file="$2"; shift 2 ;;
            -h|--help) print_usage; exit 0 ;;
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
    if [[ -n "$calibrate_runs" && -n "$baseline_file" ]]; then
        echo "Error: --calibrate compares logging.sh with a copy of itself; do not use --baseline" >&2
        exit 2
    fi
    # A result over a limit is measured again with twice the rounds
    confirm_rounds=$((round_count * 2))
}

# Print a path as an absolute path. "." searches PATH for a name without a slash, so
# the benchmarked file must always be given with its directory.
absolute_path() {
    local path="$1"
    case "$path" in
        /*) printf '%s\n' "$path" ;;
        *) printf '%s/%s\n' "$PWD" "$path" ;;
    esac
}

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
        huge-line) scenario_count=100 ;;
        lines-4k) scenario_count=100 ;;
        lines-16k) scenario_count=50 ;;
        lines-64k) scenario_count=100 ;;
        lines-256k) scenario_count=50 ;;
        *)
            echo "Unknown scenario: $scenario" >&2
            echo "  Valid scenarios: ${all_scenarios[*]}" >&2
            exit 2
            ;;
    esac
    if [[ -n "$count_override" ]]; then
        scenario_count="$count_override"
    fi
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

# Write the timed program to $work_dir/bench.sh, in POSIX sh so every shell runs the same
# code. BENCH_INIT_ARGS is split with eval because zsh does not split an unquoted variable.
write_bench_program() {
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
}

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

# Print candidate / baseline, to three decimals.
# Arguments: candidate microseconds, baseline microseconds
compute_ratio() {
    awk -v c="$1" -v b="$2" 'BEGIN { printf "%.3f\n", c / b }'
}

# Return 0 when the candidate is slower than the baseline: its ratio is above the limit and it
# is at least the minimum difference slower, because a smaller difference is timing noise.
# Arguments: candidate microseconds, baseline microseconds, maximum ratio, minimum difference
is_slower() {
    local ratio
    ratio=$(compute_ratio "$1" "$2")
    awk -v c="$1" -v b="$2" -v r="$ratio" -v m="$3" -v floor="$4" \
        'BEGIN { exit !(c - b >= floor && r > m) }'
}

# Print the growth from the 16 KB to the 256 KB scenario, to one decimal (linear is 16).
# Arguments: lines-256k microseconds, lines-16k microseconds
compute_scaling() {
    awk -v a="$1" -v b="$2" 'BEGIN { printf "%.1f\n", a / b }'
}

# Return 0 when the growth is above the limit.
# Arguments: scaling, maximum scaling
scaling_too_steep() {
    awk -v s="$1" -v m="$2" 'BEGIN { exit !(s > m) }'
}

# Run one round for one logging.sh: a zero-message run, a run with the scenario's messages,
# and the bare shell. Sets round_per_message_us (the cost of one message) and round_init_us
# (source + init_logger, less the bare shell start-up). Returns 1 if a run failed.
run_round() {
    local shell_command="$1"
    local logging_path="$2"
    local scenario="$3"
    local zero_seconds=""
    local full_seconds=""
    local bare_seconds=""

    zero_seconds=$(time_one_run "$shell_command" "$logging_path" "$scenario" 0) || return 1
    full_seconds=$(time_one_run "$shell_command" "$logging_path" "$scenario" \
        "$scenario_count") || return 1
    round_per_message_us=$(awk -v zero="$zero_seconds" -v full="$full_seconds" \
        -v n="$scenario_count" 'BEGIN { printf "%.3f\n", (full - zero) * 1000000 / n }')
    TIMEFORMAT='%3R'
    # shellcheck disable=SC2086  # word splitting of shell_command is intended
    bare_seconds=$( { time $shell_command -c : >/dev/null 2>&1; } 2>&1 )
    round_init_us=$(awk -v zero="$zero_seconds" -v bare="$bare_seconds" \
        'BEGIN { printf "%.3f\n", (zero - bare) * 1000000 }')
}

# Measure one logging.sh under one shell and scenario.
# Arguments: shell command, logging.sh, scenario, and optionally the number of rounds
# (default: round_count).
# Sets measured_us (median per message) and measured_init_us (median of the
# zero-message runs, less the bare shell start-up). Returns 1 if a run failed.
measure() {
    local shell_command="$1"
    local logging_path="$2"
    local scenario="$3"
    local rounds="${4:-$round_count}"
    local round=0
    local per_message=""
    local init_costs=""

    while [[ $round -lt $rounds ]]; do
        run_round "$shell_command" "$logging_path" "$scenario" || return 1
        per_message="$per_message
$round_per_message_us"
        init_costs="$init_costs
$round_init_us"
        round=$((round + 1))
    done
    measured_us=$(printf '%s\n' "$per_message" | sed '/^$/d' | median)
    measured_init_us=$(printf '%s\n' "$init_costs" | sed '/^$/d' | median)
}

# Measure the candidate and the baseline under one shell and scenario, one after the other in
# every round, and swap which one goes first each round. A slow minute on the runner then
# lands on both, where measuring all candidate rounds before all baseline rounds put drift
# on one side only.
# Arguments: shell command, scenario, and optionally the number of rounds (default:
# round_count).
# Sets measured_us and measured_init_us for the candidate, and baseline_measured_us.
# Returns 1 if a candidate run failed and 2 if a baseline run failed.
measure_pair() {
    local shell_command="$1"
    local scenario="$2"
    local rounds="${3:-$round_count}"
    local round=0
    local candidate_samples=""
    local baseline_samples=""
    local init_costs=""
    local order=""
    local side=""

    while [[ $round -lt $rounds ]]; do
        if [[ $((round % 2)) -eq 0 ]]; then
            order="candidate baseline"
        else
            order="baseline candidate"
        fi
        for side in $order; do
            if [[ "$side" == "candidate" ]]; then
                run_round "$shell_command" "$logging_file" "$scenario" || return 1
                candidate_samples="$candidate_samples
$round_per_message_us"
                init_costs="$init_costs
$round_init_us"
            else
                run_round "$shell_command" "$baseline_file" "$scenario" || return 2
                baseline_samples="$baseline_samples
$round_per_message_us"
            fi
        done
        round=$((round + 1))
    done
    measured_us=$(printf '%s\n' "$candidate_samples" | sed '/^$/d' | median)
    measured_init_us=$(printf '%s\n' "$init_costs" | sed '/^$/d' | median)
    baseline_measured_us=$(printf '%s\n' "$baseline_samples" | sed '/^$/d' | median)
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

# Measure lines-16k and lines-256k again, candidate only, and set remeasured_scaling to the
# growth between them. Stops the script if a run fails.
# Arguments: shell command, number of rounds
remeasure_scaling() {
    local shell_command="$1"
    local rounds="$2"
    local small_us=""
    local large_us=""

    scenario_settings "lines-16k"
    measure "$shell_command" "$logging_file" "lines-16k" "$rounds" 2>"$work_dir/reason" \
        || fail_run "$shell_command" "lines-16k" "$(cat "$work_dir/reason")"
    small_us="$measured_us"
    scenario_settings "lines-256k"
    measure "$shell_command" "$logging_file" "lines-256k" "$rounds" 2>"$work_dir/reason" \
        || fail_run "$shell_command" "lines-256k" "$(cat "$work_dir/reason")"
    large_us="$measured_us"
    remeasured_scaling=$(compute_scaling "$large_us" "$small_us")
}

# Print the minimum, median and maximum of the numbers given one per line on stdin, to three
# decimals, on one line
ratio_statistics() {
    sort -n | awk '{ value[NR] = $1 }
        END {
            if (NR % 2) { middle = value[(NR + 1) / 2] }
            else { middle = (value[NR / 2] + value[NR / 2 + 1]) / 2 }
            printf "%.3f %.3f %.3f\n", value[1], middle, value[NR]
        }'
}

# Print one calibration row, and append it to the calibration file when there is one.
# Arguments: shell command, scenario, runs, ratios (one per line), runs over the limit,
# runs over the limit after measuring again
report_calibration() {
    local shell_command="$1"
    local scenario="$2"
    local runs="$3"
    local ratios="$4"
    local over_first="$5"
    local over_confirmed="$6"
    local statistics=""
    local minimum=""
    local middle=""
    local maximum=""

    statistics=$(printf '%s\n' "$ratios" | sed '/^$/d' | ratio_statistics)
    read -r minimum middle maximum <<< "$statistics"
    printf '%-14s %-12s %3s runs, min %s, median %s, max %s, over the limit %s, still over after measuring again %s\n' \
        "$shell_command" "$scenario" "$runs" "$minimum" "$middle" "$maximum" \
        "$over_first" "$over_confirmed"
    if [[ -n "$calibration_file" ]]; then
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$shell_command" "$scenario" "$runs" \
            "$minimum" "$middle" "$maximum" "$over_first" "$over_confirmed" >> "$calibration_file"
    fi
}

# Compare logging.sh with a copy of itself, calibrate_runs times, for one shell and scenario,
# and report the spread of the ratio. The candidate time of each run is kept in
# $work_dir/samples.<scenario> for the scaling report.
# Arguments: shell command, scenario
calibrate_scenario() {
    local shell_command="$1"
    local scenario="$2"
    local run=0
    local ratios=""
    local ratio=""
    local over_first=0
    local over_confirmed=0
    local pair_status=0

    scenario_settings "$scenario"
    write_message "$scenario"
    : > "$work_dir/samples.$scenario"
    while [[ $run -lt $calibrate_runs ]]; do
        pair_status=0
        measure_pair "$shell_command" "$scenario" 2>"$work_dir/reason" || pair_status=$?
        if [[ $pair_status -ne 0 ]]; then
            fail_run "$shell_command" "$scenario" "$(cat "$work_dir/reason")"
        fi
        printf '%s\n' "$measured_us" >> "$work_dir/samples.$scenario"
        ratio=$(compute_ratio "$measured_us" "$baseline_measured_us")
        ratios="$ratios
$ratio"
        if is_slower "$measured_us" "$baseline_measured_us" "$max_ratio" "$min_difference_us"; then
            over_first=$((over_first + 1))
            measure_pair "$shell_command" "$scenario" "$confirm_rounds" 2>"$work_dir/reason" \
                || fail_run "$shell_command" "$scenario" "$(cat "$work_dir/reason")"
            if is_slower "$measured_us" "$baseline_measured_us" "$max_ratio" "$min_difference_us"; then
                over_confirmed=$((over_confirmed + 1))
            fi
        fi
        run=$((run + 1))
    done
    report_calibration "$shell_command" "$scenario" "$calibrate_runs" "$ratios" \
        "$over_first" "$over_confirmed"
}

# Report the growth from lines-16k to lines-256k for each calibration run, from the samples
# calibrate_scenario kept. Both scenarios must have been calibrated for this shell.
# Arguments: shell command
calibrate_scaling() {
    local shell_command="$1"
    local small_us=""
    local large_us=""
    local scaling=""
    local scalings=""
    local over_first=0
    local over_confirmed=0
    local runs=0

    while read -r small_us large_us; do
        scaling=$(compute_scaling "$large_us" "$small_us")
        scalings="$scalings
$scaling"
        if scaling_too_steep "$scaling" "$max_scaling"; then
            over_first=$((over_first + 1))
            remeasure_scaling "$shell_command" "$confirm_rounds"
            if scaling_too_steep "$remeasured_scaling" "$max_scaling"; then
                over_confirmed=$((over_confirmed + 1))
            fi
        fi
        runs=$((runs + 1))
    done < <(paste -d' ' "$work_dir/samples.lines-16k" "$work_dir/samples.lines-256k")
    report_calibration "$shell_command" "scaling" "$runs" "$scalings" \
        "$over_first" "$over_confirmed"
}

# Calibration run: every shell and scenario compares logging.sh with a copy of itself
run_calibration() {
    local shell_command=""
    local scenario=""
    local has_16k=""
    local has_256k=""

    baseline_file="$work_dir/identical-copy.sh"
    cp "$logging_file" "$baseline_file"
    if [[ -n "$calibration_file" ]]; then
        : > "$calibration_file"
    fi
    printf 'Calibration: %s comparisons of logging.sh with a copy of itself per shell and scenario,\n' \
        "$calibrate_runs"
    printf '%s rounds each, limits: ratio %s with a difference of at least %s us, scaling %s\n' \
        "$round_count" "$max_ratio" "$min_difference_us" "$max_scaling"

    for shell_command in "${shells[@]}"; do
        has_16k="false"
        has_256k="false"
        for scenario in "${selected_scenarios[@]}"; do
            calibrate_scenario "$shell_command" "$scenario"
            case "$scenario" in
                lines-16k) has_16k="true" ;;
                lines-256k) has_256k="true" ;;
            esac
        done
        if [[ "$has_16k" == "true" && "$has_256k" == "true" ]]; then
            calibrate_scaling "$shell_command"
        fi
    done
}

# Keep one result row for the markdown summary.
# Arguments: shell command, scenario, candidate, baseline, ratio, result text. Use - for a
# column that does not apply.
record_row() {
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" >> "$work_dir/rows.tsv"
}

# Print the number of CPUs, or "unknown"
cpu_count() {
    nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || printf 'unknown\n'
}

# Print the version of a shell command ("bash --posix", "busybox sh"), or "unknown". dash has
# no version option, so its package version is used where dpkg is available.
shell_version() {
    local shell_command="$1"
    local program="${shell_command%% *}"
    local version=""

    case "$program" in
        bash|zsh)
            # shellcheck disable=SC2086  # word splitting of shell_command is intended
            version=$($shell_command -c 'printf "%s" "${BASH_VERSION:-}${ZSH_VERSION:-}"' \
                2>/dev/null) || version=""
            version="$program $version"
            ;;
        dash)
            version=$(dpkg-query -W -f='dash ${Version}' dash 2>/dev/null) || version=""
            ;;
        busybox)
            version=$("$program" 2>&1 | sed -n '1p') || version=""
            ;;
    esac
    if [[ -z "${version// /}" || "$version" == "$program " ]]; then
        version="unknown"
    fi
    printf '%s\n' "$version"
}

# Append the markdown summary to the summary file: the limits, where it ran, the shell
# versions and one table row for every result that was recorded.
# Arguments: exit status of the run
write_summary() {
    local run_status="$1"
    local shell_command=""
    local result="passed"

    if [[ "$run_status" -ne 0 ]]; then
        result="failed (exit status $run_status)"
    fi
    {
        printf '## Per-message benchmark: %s\n\n' "$result"
        printf 'Limits: candidate/baseline above %s with a difference of at least %s us, and\n' \
            "$max_ratio" "$min_difference_us"
        printf 'lines-256k / lines-16k above %s (linear is 16). A result over a limit is measured\n' \
            "$max_scaling"
        printf 'again with %s rounds instead of %s, and fails only if it is over again.\n\n' \
            "$confirm_rounds" "$round_count"
        printf 'CPUs: %s\n\n' "$(cpu_count)"
        printf 'Shells:\n\n'
        for shell_command in "${shells[@]}"; do
            printf '* `%s`: %s\n' "$shell_command" "$(shell_version "$shell_command")"
        done
        printf '\n| Shell | Scenario | us/message | Baseline | Ratio | Result |\n'
        printf '| --- | --- | ---: | ---: | ---: | --- |\n'
        if [[ -f "$work_dir/rows.tsv" ]]; then
            awk -F '\t' '{ printf "| `%s` | %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5, $6 }' \
                "$work_dir/rows.tsv"
        fi
        printf '\n'
    } >> "$summary_file"
}

# Runs when the script exits, whatever the reason: write the summary and remove the work files
cleanup() {
    local run_status=$?
    if [[ -n "$summary_file" && -n "${work_dir:-}" && -z "$calibrate_runs" ]]; then
        write_summary "$run_status" || true
    fi
    if [[ -n "${work_dir:-}" ]]; then
        rm -rf "$work_dir"
    fi
}

# Print one result row of a comparison with the baseline
# Arguments: shell command, scenario, candidate, baseline, ratio, verdict text
print_comparison() {
    printf '%-14s %-12s %10s us/message, baseline %10s, ratio %s %s\n' "$1" "$2" "$3" "$4" "$5" "$6"
}

main() {
    set -euo pipefail

    parse_arguments "$@"
    logging_file=$(absolute_path "$logging_file")
    if [[ -n "$baseline_file" ]]; then
        baseline_file=$(absolute_path "$baseline_file")
    fi

    work_dir=$(mktemp -d)
    trap cleanup EXIT
    write_bench_program

    local check_failures=()
    local shell_command=""
    local scenario=""
    local baseline_available=""
    local baseline_note=""
    local lines_16k_us=""
    local lines_256k_us=""
    local init_reported=""
    local candidate_us=""
    local baseline_us=""
    local ratio=""
    local first_ratio=""
    local scaling=""
    local first_scaling=""
    local verdict=""
    local pair_status=0

    if [[ -n "$calibrate_runs" ]]; then
        run_calibration
        exit 0
    fi

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

            # The baseline may not run in every shell (main is bash/zsh only before
            # Issue #143); that is reported once and is not a failure. A run of zero
            # messages is enough to find out.
            baseline_note=""
            if [[ "$baseline_available" == "true" ]]; then
                if ! time_one_run "$shell_command" "$baseline_file" "$scenario" 0 \
                    >/dev/null 2>"$work_dir/reason"; then
                    baseline_note="$(cat "$work_dir/reason")"
                    baseline_available="false"
                fi
            fi

            if [[ "$baseline_available" == "true" ]]; then
                pair_status=0
                measure_pair "$shell_command" "$scenario" 2>"$work_dir/reason" || pair_status=$?
                if [[ $pair_status -eq 1 ]]; then
                    fail_run "$shell_command" "$scenario" "$(cat "$work_dir/reason")"
                elif [[ $pair_status -ne 0 ]]; then
                    fail_run "$shell_command" "$scenario" "baseline: $(cat "$work_dir/reason")"
                fi
            elif ! measure "$shell_command" "$logging_file" "$scenario" 2>"$work_dir/reason"; then
                fail_run "$shell_command" "$scenario" "$(cat "$work_dir/reason")"
            fi
            candidate_us="$measured_us"

            if [[ "$init_reported" == "false" ]]; then
                printf '%-14s %-12s %10s us (source + init_logger, information only)\n' \
                    "$shell_command" "init" "$measured_init_us"
                record_row "$shell_command" "init" "$measured_init_us" "-" "-" \
                    "information only (source + init_logger)"
                init_reported="true"
            fi

            case "$scenario" in
                lines-16k) lines_16k_us="$candidate_us" ;;
                lines-256k) lines_256k_us="$candidate_us" ;;
            esac

            if [[ "$baseline_available" != "true" ]]; then
                if [[ -n "$baseline_note" ]]; then
                    printf '%-14s %-12s %10s us/message, baseline unavailable (%s)\n' \
                        "$shell_command" "$scenario" "$candidate_us" "$baseline_note"
                    record_row "$shell_command" "$scenario" "$candidate_us" "-" "-" \
                        "baseline unavailable ($baseline_note)"
                else
                    printf '%-14s %-12s %10s us/message\n' "$shell_command" "$scenario" \
                        "$candidate_us"
                    record_row "$shell_command" "$scenario" "$candidate_us" "-" "-" \
                        "no baseline"
                fi
                continue
            fi

            baseline_us="$baseline_measured_us"
            ratio=$(compute_ratio "$candidate_us" "$baseline_us")
            if ! is_slower "$candidate_us" "$baseline_us" "$max_ratio" "$min_difference_us"; then
                print_comparison "$shell_command" "$scenario" "$candidate_us" "$baseline_us" \
                    "$ratio" "ok"
                record_row "$shell_command" "$scenario" "$candidate_us" "$baseline_us" \
                    "$ratio" "ok"
                continue
            fi

            # A result over the limit is often noise on a shared runner. Measure this shell
            # and scenario again with twice the rounds, and fail only if it is over again.
            print_comparison "$shell_command" "$scenario" "$candidate_us" "$baseline_us" \
                "$ratio" "SLOWER, measuring again with $confirm_rounds rounds"
            first_ratio="$ratio"
            pair_status=0
            measure_pair "$shell_command" "$scenario" "$confirm_rounds" 2>"$work_dir/reason" \
                || pair_status=$?
            if [[ $pair_status -ne 0 ]]; then
                fail_run "$shell_command" "$scenario" "$(cat "$work_dir/reason")"
            fi
            candidate_us="$measured_us"
            baseline_us="$baseline_measured_us"
            ratio=$(compute_ratio "$candidate_us" "$baseline_us")
            if is_slower "$candidate_us" "$baseline_us" "$max_ratio" "$min_difference_us"; then
                verdict="SLOWER"
                check_failures+=("$shell_command $scenario: ratio $first_ratio, then $ratio with $confirm_rounds rounds, > $max_ratio")
            else
                verdict="ok"
            fi
            print_comparison "$shell_command" "$scenario" "$candidate_us" "$baseline_us" \
                "$ratio" "$verdict (second measurement, $confirm_rounds rounds)"
            record_row "$shell_command" "$scenario" "$candidate_us" "$baseline_us" "$ratio" \
                "$verdict (second measurement, $confirm_rounds rounds; first ratio $first_ratio)"
        done

        # Growth from 16 KB to 256 KB messages: 16 is linear
        if [[ -n "$lines_16k_us" && -n "$lines_256k_us" ]]; then
            scaling=$(compute_scaling "$lines_256k_us" "$lines_16k_us")
            if ! scaling_too_steep "$scaling" "$max_scaling"; then
                printf '%-14s %-12s %10s (lines-256k / lines-16k, linear is 16) ok\n' \
                    "$shell_command" "scaling" "$scaling"
                record_row "$shell_command" "scaling lines-256k / lines-16k" "-" "-" "$scaling" "ok"
            else
                printf '%-14s %-12s %10s (lines-256k / lines-16k, linear is 16) TOO STEEP, measuring again with %s rounds\n' \
                    "$shell_command" "scaling" "$scaling" "$confirm_rounds"
                first_scaling="$scaling"
                remeasure_scaling "$shell_command" "$confirm_rounds"
                scaling="$remeasured_scaling"
                if scaling_too_steep "$scaling" "$max_scaling"; then
                    verdict="TOO STEEP"
                    check_failures+=("$shell_command scaling: lines-256k / lines-16k = $first_scaling, then $scaling with $confirm_rounds rounds, > $max_scaling")
                else
                    verdict="ok"
                fi
                printf '%-14s %-12s %10s (lines-256k / lines-16k, linear is 16) %s (second measurement, %s rounds)\n' \
                    "$shell_command" "scaling" "$scaling" "$verdict" "$confirm_rounds"
                record_row "$shell_command" "scaling lines-256k / lines-16k" "-" "-" "$scaling" \
                    "$verdict (second measurement, $confirm_rounds rounds; first value $first_scaling)"
            fi
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
}

# Run only when executed, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
