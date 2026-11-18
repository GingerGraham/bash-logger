#!/usr/bin/env bash
#
# test_bench_script.sh - Tests for scripts/bench-logging.sh (Issue #156)
#
# The per-message benchmark runs in CI and fails a pull request when logging gets slower. Its
# decisions have to be right, so this suite checks them:
#
# - the verdict functions, with fixed numbers: the ratio limit, the minimum difference that
#   separates a slowdown from timing noise, and the limit on how fast large messages may
#   grow
# - the failure paths: a missing logging.sh, a failing init_logger and a wrong number of log
#   lines each stop the script with a non-zero status and a clear message
# - a slow copy of logging.sh, with one extra process per call, is reported as SLOWER
#
# Every run of the script uses --count and --rounds to stay small, and the copies of logging.sh
# live in $TEST_DIR: the repository's logging.sh is never changed. The whole suite takes
# under 10 seconds. It runs the script under bash only, so it also works on macOS with bash
# 3.2 and the BSD tools.

BENCH_SCRIPT="$PROJECT_ROOT/scripts/bench-logging.sh"

# Run the benchmark script with the given arguments. Sets BENCH_OUTPUT (stdout and stderr)
# and BENCH_STATUS.
run_bench() {
    BENCH_OUTPUT=$(bash "$BENCH_SCRIPT" "$@" 2>&1)
    BENCH_STATUS=$?
}

# Run one verdict function from the script in a clean shell, so that sourcing it does not
# touch this suite's variables. The words are the function name and its arguments.
run_function() {
    bash -c 'source "$1"; shift; "$@"' bash "$BENCH_SCRIPT" "$@"
}

# Print "yes" or "no" for the status of a verdict function
function_verdict() {
    if run_function "$@" > /dev/null 2>&1; then
        printf 'yes\n'
    else
        printf 'no\n'
    fi
}

# Copy logging.sh into $TEST_DIR and print its path. The text given as an argument is
# appended, so a later definition replaces the library's own.
make_logging_copy() {
    local name="$1"
    local appended="$2"
    cp "$PROJECT_ROOT/logging.sh" "$TEST_DIR/$name"
    printf '\n%s\n' "$appended" >> "$TEST_DIR/$name"
    printf '%s\n' "$TEST_DIR/$name"
}

# ---------------------------------------------------------------------------
# Verdict functions
# ---------------------------------------------------------------------------

test_bench_ratio_is_candidate_over_baseline() {
    start_test "compute_ratio divides the candidate by the baseline, to three decimals"

    assert_equals "1.100" "$(run_function compute_ratio 110 100)" || return
    assert_equals "0.800" "$(run_function compute_ratio 80 100)" || return
    assert_equals "1.333" "$(run_function compute_ratio 400 300)" || return

    pass_test
}

test_bench_slower_over_the_ratio_limit() {
    start_test "is_slower reports a candidate over the ratio limit and over the minimum difference"

    # 600 against 500 is a ratio of 1.2 and 100 microseconds slower
    assert_equals "yes" "$(function_verdict is_slower 600 500 1.15 100)" || return
    assert_equals "yes" "$(function_verdict is_slower 5000 1000 1.15 100)" || return

    pass_test
}

test_bench_not_slower_under_the_ratio_limit() {
    start_test "is_slower accepts a candidate under the ratio limit, however large the difference"

    assert_equals "no" "$(function_verdict is_slower 510 500 1.15 100)" || return
    assert_equals "no" "$(function_verdict is_slower 500 500 1.15 100)" || return
    # Faster than the baseline
    assert_equals "no" "$(function_verdict is_slower 400 500 1.15 100)" || return
    # A large difference alone is not enough: 114 percent slower is under a limit of 3
    assert_equals "no" "$(function_verdict is_slower 214000 100000 3 100)" || return

    pass_test
}

test_bench_ratio_boundary() {
    start_test "is_slower accepts a ratio exactly at the limit and rejects one just over it"

    # The ratio is rounded to three decimals before it is compared with the limit
    assert_equals "1.150" "$(run_function compute_ratio 1150 1000)" || return
    assert_equals "no" "$(function_verdict is_slower 1150 1000 1.15 100)" || return
    assert_equals "yes" "$(function_verdict is_slower 1151 1000 1.15 100)" || return

    pass_test
}

test_bench_minimum_difference_boundary() {
    start_test "is_slower ignores a difference under 100 microseconds, and counts exactly 100"

    # A ratio of 1.198 is over the limit, but 99 microseconds is timing noise
    assert_equals "no" "$(function_verdict is_slower 599 500 1.15 100)" || return
    assert_equals "yes" "$(function_verdict is_slower 600 500 1.15 100)" || return

    pass_test
}

test_bench_large_ratio_under_the_floor() {
    start_test "is_slower ignores a ratio of 5 when the difference is under 100 microseconds"

    assert_equals "5.000" "$(run_function compute_ratio 50 10)" || return
    assert_equals "no" "$(function_verdict is_slower 50 10 1.15 100)" || return
    # The same ratio at a size where the difference matters
    assert_equals "yes" "$(function_verdict is_slower 5000 1000 1.15 100)" || return

    pass_test
}

test_bench_median() {
    start_test "median handles an odd count, an even count and unsorted input"

    assert_equals "2.0" "$(printf '3\n1\n2\n' | run_function median)" || return
    assert_equals "2.5" "$(printf '4\n1\n3\n2\n' | run_function median)" || return
    assert_equals "7.0" "$(printf '7\n' | run_function median)" || return
    # One slow outlier does not move the median
    assert_equals "10.0" "$(printf '10\n10\n900\n10\n11\n' | run_function median)" || return

    pass_test
}

test_bench_scaling() {
    start_test "scaling is accepted under and at the limit and rejected over it"

    assert_equals "16.0" "$(run_function compute_scaling 1600 100)" || return
    assert_equals "32.0" "$(run_function compute_scaling 3200 100)" || return
    assert_equals "189.0" "$(run_function compute_scaling 18900 100)" || return

    assert_equals "no" "$(function_verdict scaling_too_steep 16.0 32)" || return
    assert_equals "no" "$(function_verdict scaling_too_steep 32.0 32)" || return
    assert_equals "yes" "$(function_verdict scaling_too_steep 32.1 32)" || return
    # The quadratic sanitizer that this check was written for
    assert_equals "yes" "$(function_verdict scaling_too_steep 189.0 32)" || return

    pass_test
}

test_bench_sourcing_changes_nothing() {
    start_test "sourcing the script defines functions and does not run it or change shell options"

    local output
    output=$(bash -c 'before=$-; source "$1"; printf "%s|%s\n" "$before" "$-"' bash "$BENCH_SCRIPT" 2>&1)
    # The options before and after are the same, whatever bash adds to them (for example
    # errexit would add "e", and nounset "u")
    assert_equals "${output%|*}" "${output#*|}" "shell options before and after sourcing" || return
    assert_not_contains "$output" "e|" || return

    pass_test
}

test_bench_count_must_be_a_positive_integer() {
    start_test "--count rejects zero, text and an empty value"

    local value
    for value in 0 abc 1.5 -3; do
        run_bench --count "$value" --scenario plain
        assert_equals "2" "$BENCH_STATUS" "status for --count $value" || return
        assert_contains "$BENCH_OUTPUT" "--count needs a positive integer" || return
    done

    pass_test
}

# ---------------------------------------------------------------------------
# Failure paths
# ---------------------------------------------------------------------------

test_bench_missing_logging_file() {
    start_test "a missing logging.sh stops the script with a message"

    run_bench --logging "$TEST_DIR/does-not-exist.sh" --count 3 --rounds 1 --scenario plain bash
    assert_equals "1" "$BENCH_STATUS" || return
    assert_contains "$BENCH_OUTPUT" "FAIL bash plain" || return
    assert_contains "$BENCH_OUTPUT" "exit status 90" || return
    assert_contains "$BENCH_OUTPUT" "does-not-exist.sh: No such file or directory" || return

    pass_test
}

test_bench_failing_init_logger() {
    start_test "a logging.sh whose init_logger fails stops the script with a message"

    local broken
    broken=$(make_logging_copy broken-init.sh 'init_logger() { return 3; }')

    run_bench --logging "$broken" --count 3 --rounds 1 --scenario plain bash
    assert_equals "1" "$BENCH_STATUS" || return
    assert_contains "$BENCH_OUTPUT" "FAIL bash plain" || return
    assert_contains "$BENCH_OUTPUT" "exit status 91" || return

    pass_test
}

test_bench_wrong_log_line_count() {
    start_test "a run that logs the wrong number of lines stops the script with a message"

    # log_info writes nothing, so the log file has the init line and no message lines
    local silent
    silent=$(make_logging_copy silent-log-info.sh 'log_info() { return 0; }')

    run_bench --logging "$silent" --count 4 --rounds 1 --scenario plain bash
    assert_equals "1" "$BENCH_STATUS" || return
    assert_contains "$BENCH_OUTPUT" "FAIL bash plain" || return
    assert_contains "$BENCH_OUTPUT" "log has 1 lines, expected 5" || return

    pass_test
}

test_bench_unknown_scenario() {
    start_test "an unknown scenario name is rejected with the valid names"

    run_bench --scenario nonsense --count 3 --rounds 1 bash
    assert_equals "2" "$BENCH_STATUS" || return
    assert_contains "$BENCH_OUTPUT" "Unknown scenario: nonsense" || return
    assert_contains "$BENCH_OUTPUT" "Valid scenarios:" || return

    pass_test
}

# ---------------------------------------------------------------------------
# Rounds, counts and confirming a slowdown
# ---------------------------------------------------------------------------

test_bench_large_scenarios_run_about_a_second() {
    start_test "the large scenarios log enough messages for about a second of work per run"

    local counts
    counts=$(bash -c 'source "$1"
        for name in huge-line lines-64k lines-256k lines-16k plain; do
            scenario_settings "$name"
            printf "%s=%s " "$name" "$scenario_count"
        done' bash "$BENCH_SCRIPT")
    assert_equals "huge-line=100 lines-64k=100 lines-256k=50 lines-16k=50 plain=300 " "$counts" || return

    pass_test
}

test_bench_alternates_candidate_and_baseline() {
    start_test "each round runs the candidate and the baseline, and swaps which goes first"

    # run_round is replaced by a function that records which logging.sh it was given
    local order_file="$TEST_DIR/round-order"
    ORDER_FILE="$order_file" bash -c 'source "$1"
        logging_file=CANDIDATE
        baseline_file=BASELINE
        run_round() { printf "%s\n" "$2" >> "$ORDER_FILE"; round_per_message_us=1; round_init_us=1; }
        scenario_count=1
        measure_pair bash plain 4' bash "$BENCH_SCRIPT"

    assert_equals "CANDIDATE BASELINE BASELINE CANDIDATE CANDIDATE BASELINE BASELINE CANDIDATE" \
        "$(tr '\n' ' ' < "$order_file" | sed 's/ $//')" || return

    pass_test
}

# Run main with the measuring functions replaced by fixed results, so the decision to measure
# again does not depend on timing. The stub definitions come in the STUBS variable. The
# arguments go to main.
run_main_with_stubs() {
    BENCH_OUTPUT=$(bash -c 'source "$1"; shift; eval "$STUBS"; main "$@"' bash \
        "$BENCH_SCRIPT" "$@" 2>&1 < /dev/null)
    BENCH_STATUS=$?
}

test_bench_confirms_a_slowdown_before_failing() {
    start_test "a result over the limit is measured again with twice the rounds"

    # The first measurement is 2 times slower, the second is not
    local stubs='
time_one_run() { printf "0.001\n"; }
pair_calls=0
measure_pair() {
    pair_calls=$((pair_calls + 1))
    measured_init_us=1000
    if [ "$pair_calls" -eq 1 ]; then
        measured_us=1000; baseline_measured_us=500
    else
        measured_us=520; baseline_measured_us=500
    fi
}'
    STUBS="$stubs" run_main_with_stubs --baseline "$TEST_DIR/unused-baseline.sh" \
        --rounds 5 --scenario plain bash
    assert_equals "0" "$BENCH_STATUS" "a slowdown that does not repeat passes" || return
    assert_contains "$BENCH_OUTPUT" "ratio 2.000 SLOWER, measuring again with 10 rounds" || return
    assert_contains "$BENCH_OUTPUT" "ratio 1.040 ok (second measurement, 10 rounds)" || return
    assert_not_contains "$BENCH_OUTPUT" "FAIL" || return

    pass_test
}

test_bench_fails_when_the_slowdown_repeats() {
    start_test "a result that is over the limit twice fails, and both ratios are printed"

    local stubs='
time_one_run() { printf "0.001\n"; }
pair_calls=0
measure_pair() {
    pair_calls=$((pair_calls + 1))
    measured_init_us=1000
    measured_us=1000; baseline_measured_us=500
    if [ "$pair_calls" -eq 2 ]; then measured_us=900; fi
}'
    STUBS="$stubs" run_main_with_stubs --baseline "$TEST_DIR/unused-baseline.sh" \
        --rounds 5 --scenario plain bash
    assert_equals "1" "$BENCH_STATUS" "a slowdown that repeats fails" || return
    assert_contains "$BENCH_OUTPUT" "ratio 2.000 SLOWER, measuring again with 10 rounds" || return
    assert_contains "$BENCH_OUTPUT" "ratio 1.800 SLOWER (second measurement, 10 rounds)" || return
    assert_contains "$BENCH_OUTPUT" "FAIL bash plain: ratio 2.000, then 1.800 with 10 rounds, > 1.15" || return

    pass_test
}

test_bench_does_not_repeat_a_result_under_the_limit() {
    start_test "a result under the limit is measured once"

    local stubs='
time_one_run() { printf "0.001\n"; }
pair_calls=0
measure_pair() {
    pair_calls=$((pair_calls + 1))
    measured_init_us=1000; measured_us=520; baseline_measured_us=500
    printf "pair call %s\n" "$pair_calls" >&2
}'
    STUBS="$stubs" run_main_with_stubs --baseline "$TEST_DIR/unused-baseline.sh" \
        --rounds 5 --scenario plain bash
    assert_equals "0" "$BENCH_STATUS" || return
    assert_contains "$BENCH_OUTPUT" "ratio 1.040 ok" || return
    assert_not_contains "$BENCH_OUTPUT" "measuring again" || return

    pass_test
}

test_bench_confirms_steep_scaling_before_failing() {
    start_test "scaling over the limit is measured again, and fails only if it is over again"

    # First measurement: 40, over 32. Second: 30, which passes
    local stubs='
measure_calls=0
measure() {
    measure_calls=$((measure_calls + 1))
    measured_init_us=1000
    case "$3" in
        lines-16k) measured_us=100 ;;
        lines-256k)
            if [ "$measure_calls" -le 2 ]; then measured_us=4000; else measured_us=3000; fi ;;
    esac
}'
    STUBS="$stubs" run_main_with_stubs --rounds 5 \
        --scenario lines-16k --scenario lines-256k bash
    assert_equals "0" "$BENCH_STATUS" "steep scaling that does not repeat passes" || return
    assert_contains "$BENCH_OUTPUT" "40.0 (lines-256k / lines-16k, linear is 16) TOO STEEP, measuring again with 10 rounds" || return
    assert_contains "$BENCH_OUTPUT" "30.0 (lines-256k / lines-16k, linear is 16) ok (second measurement, 10 rounds)" || return

    # Over the limit in both measurements
    stubs='
measure() {
    measured_init_us=1000
    case "$3" in
        lines-16k) measured_us=100 ;;
        lines-256k) measured_us=4000 ;;
    esac
}'
    STUBS="$stubs" run_main_with_stubs --rounds 5 \
        --scenario lines-16k --scenario lines-256k bash
    assert_equals "1" "$BENCH_STATUS" "steep scaling that repeats fails" || return
    assert_contains "$BENCH_OUTPUT" "FAIL bash scaling: lines-256k / lines-16k = 40.0, then 40.0 with 10 rounds, > 32" || return

    pass_test
}

# ---------------------------------------------------------------------------
# The filtered scenario's own floor
# ---------------------------------------------------------------------------

test_bench_filtered_scenario_has_its_own_floor() {
    start_test "the filtered scenario uses a 2 microsecond floor and the others use 100"

    local settings
    settings=$(bash -c 'source "$1"
        for name in filtered plain huge-line; do
            scenario_settings "$name"
            printf "%s=%s/%s " "$name" "$scenario_count" "$scenario_floor_us"
        done' bash "$BENCH_SCRIPT")
    assert_equals "filtered=10000/2 plain=300/100 huge-line=100/100 " "$settings" || return

    settings=$(bash -c 'source "$1"; min_difference_us=250; scenario_settings plain
        printf "%s" "$scenario_floor_us"' bash "$BENCH_SCRIPT")
    assert_equals "250" "$settings" "--min-difference changes the general floor" || return

    pass_test
}

test_bench_min_difference_needs_a_whole_number() {
    start_test "--min-difference rejects text and an empty value"

    run_bench --min-difference abc --scenario plain
    assert_equals "2" "$BENCH_STATUS" || return
    assert_contains "$BENCH_OUTPUT" "--min-difference needs a whole number of microseconds, not 'abc'" || return

    run_bench --min-difference "" --scenario plain
    assert_equals "2" "$BENCH_STATUS" || return

    pass_test
}

test_bench_filtered_slowdown_of_a_few_microseconds_fails() {
    start_test "a 7 to 10 microsecond slowdown fails in filtered and is ignored in plain"

    # 10 against 7 microseconds is ratio 1.429 and a 3 microsecond difference, over the
    # filtered floor of 2 and under the general floor of 100
    local stubs='
time_one_run() { printf "0.001\n"; }
measure_pair() {
    measured_init_us=1000; measured_us=10; baseline_measured_us=7
}'
    STUBS="$stubs" run_main_with_stubs --baseline "$TEST_DIR/unused-baseline.sh" \
        --rounds 5 --scenario filtered bash
    assert_equals "1" "$BENCH_STATUS" "filtered fails" || return
    assert_contains "$BENCH_OUTPUT" "FAIL bash filtered: ratio 1.429, then 1.429 with 10 rounds" || return

    STUBS="$stubs" run_main_with_stubs --baseline "$TEST_DIR/unused-baseline.sh" \
        --rounds 5 --scenario plain bash
    assert_equals "0" "$BENCH_STATUS" "plain passes" || return
    assert_contains "$BENCH_OUTPUT" "ratio 1.429 ok" || return

    # 7 against 6 microseconds is ratio 1.167, over the limit, but a 1 microsecond difference
    # is under the filtered floor
    stubs='
time_one_run() { printf "0.001\n"; }
measure_pair() {
    measured_init_us=1000; measured_us=7; baseline_measured_us=6
}'
    STUBS="$stubs" run_main_with_stubs --baseline "$TEST_DIR/unused-baseline.sh" \
        --rounds 5 --scenario filtered bash
    assert_equals "0" "$BENCH_STATUS" "a 1 microsecond difference is ignored" || return
    assert_contains "$BENCH_OUTPUT" "ratio 1.167 ok" || return

    pass_test
}

# ---------------------------------------------------------------------------
# Markdown summary
# ---------------------------------------------------------------------------

test_bench_summary_lists_limits_versions_and_results() {
    start_test "--summary appends the limits, CPUs, shell versions and a row per result"

    local summary_file="$TEST_DIR/summary.md"
    printf 'existing line\n' > "$summary_file"
    local stubs='
time_one_run() { printf "0.001\n"; }
measure_pair() {
    measured_init_us=1000; measured_us=520; baseline_measured_us=500
}'
    STUBS="$stubs" run_main_with_stubs --baseline "$TEST_DIR/unused-baseline.sh" \
        --summary "$summary_file" --rounds 5 --scenario plain bash
    assert_equals "0" "$BENCH_STATUS" || return

    local summary
    summary=$(cat "$summary_file")
    assert_contains "$summary" "existing line" "the summary is appended, not replaced" || return
    assert_contains "$summary" "## Per-message benchmark: passed" || return
    assert_contains "$summary" "above 1.15 with a difference of at least 100 us" || return
    assert_contains "$summary" "lines-256k / lines-16k above 32" || return
    assert_contains "$summary" "CPUs: " || return
    assert_contains "$summary" '* `bash`: bash ' || return
    assert_contains "$summary" "| Shell | Scenario | us/message | Baseline | Ratio | Result |" || return
    assert_contains "$summary" '| `bash` | plain | 520 | 500 | 1.040 | ok |' || return

    pass_test
}

test_bench_summary_is_written_when_the_run_fails() {
    start_test "--summary is written when a comparison fails, and says so"

    local summary_file="$TEST_DIR/summary-failed.md"
    local stubs='
time_one_run() { printf "0.001\n"; }
measure_pair() {
    measured_init_us=1000; measured_us=1000; baseline_measured_us=500
}'
    STUBS="$stubs" run_main_with_stubs --baseline "$TEST_DIR/unused-baseline.sh" \
        --summary "$summary_file" --rounds 5 --scenario plain bash
    assert_equals "1" "$BENCH_STATUS" || return

    local summary
    summary=$(cat "$summary_file")
    assert_contains "$summary" "## Per-message benchmark: failed (exit status 1)" || return
    assert_contains "$summary" "SLOWER (second measurement, 10 rounds; first ratio 2.000)" || return

    pass_test
}

test_bench_summary_is_written_when_a_run_fails() {
    start_test "--summary is written when a run itself fails"

    local summary_file="$TEST_DIR/summary-run-failed.md"
    run_bench --logging "$TEST_DIR/does-not-exist.sh" --summary "$summary_file" \
        --rounds 1 --count 2 --scenario plain bash
    assert_equals "1" "$BENCH_STATUS" || return
    assert_contains "$(cat "$summary_file")" "failed (exit status 1)" || return

    pass_test
}

test_bench_no_summary_without_the_option() {
    start_test "no summary is written unless --summary is given"

    run_bench --rounds 1 --count 2 --scenario plain bash
    assert_equals "0" "$BENCH_STATUS" || return
    assert_not_contains "$BENCH_OUTPUT" "Per-message benchmark" || return

    pass_test
}

# ---------------------------------------------------------------------------
# Calibration
# ---------------------------------------------------------------------------

test_bench_ratio_statistics() {
    start_test "ratio_statistics prints the minimum, median and maximum to three decimals"

    assert_equals "0.900 1.000 1.250" "$(printf '1.25\n0.9\n1.0\n' | run_function ratio_statistics)" || return
    assert_equals "1.000 1.500 2.000" "$(printf '2\n1\n' | run_function ratio_statistics)" \
        "an even count averages the middle two" || return

    pass_test
}

test_bench_calibrate_rejects_bad_arguments() {
    start_test "--calibrate needs a positive integer and cannot be combined with --baseline"

    run_bench --calibrate 0 --scenario plain
    assert_equals "2" "$BENCH_STATUS" || return
    assert_contains "$BENCH_OUTPUT" "--calibrate needs a positive integer, not '0'" || return

    run_bench --calibrate abc --scenario plain
    assert_equals "2" "$BENCH_STATUS" || return

    run_bench --calibrate 2 --baseline "$PROJECT_ROOT/logging.sh" --scenario plain
    assert_equals "2" "$BENCH_STATUS" || return
    assert_contains "$BENCH_OUTPUT" "do not use --baseline" || return

    pass_test
}

test_bench_calibration_counts_runs_over_the_limit() {
    start_test "a calibration run reports the spread, the runs over the limit and those still over"

    # Candidate/baseline ratios of the first measurement of each run: 1.0, 2.0, 2.0. The
    # second and third runs are over the limit and are measured again: the first of them
    # stays over (2.0), the other does not (1.0). Calls: 1 | 2, 3 (again) | 4, 5 (again).
    local stubs='
pair_calls=0
measure_pair() {
    pair_calls=$((pair_calls + 1))
    measured_init_us=1000
    baseline_measured_us=500
    case "$pair_calls" in
        1|5) measured_us=500 ;;
        *) measured_us=1000 ;;
    esac
}'
    local tsv_file="$TEST_DIR/calibration.tsv"
    STUBS="$stubs" run_main_with_stubs --calibrate 3 --calibration-file "$tsv_file" \
        --scenario plain bash
    assert_equals "0" "$BENCH_STATUS" "a calibration run exits 0 whatever the ratios" || return
    assert_contains "$BENCH_OUTPUT" \
        "bash           plain          3 runs, min 1.000, median 2.000, max 2.000, largest slowdown 500.0 us, over the limit 2, still over after measuring again 1" || return
    assert_equals "$(printf 'bash\tplain\t3\t1.000\t2.000\t2.000\t500.0\t2\t1')" "$(cat "$tsv_file")" || return

    pass_test
}

test_bench_calibration_reports_scaling() {
    start_test "a calibration run reports the lines-256k / lines-16k growth and measures it again"

    local stubs='
measure_pair() {
    measured_init_us=1000
    baseline_measured_us=100
    case "$2" in
        lines-16k) measured_us=100 ;;
        lines-256k) measured_us=4000 ;;
    esac
}
measure() {
    measured_init_us=1000
    case "$3" in
        lines-16k) measured_us=100 ;;
        lines-256k) measured_us=3000 ;;
    esac
}'
    local tsv_file="$TEST_DIR/calibration-scaling.tsv"
    STUBS="$stubs" run_main_with_stubs --calibrate 2 --calibration-file "$tsv_file" \
        --scenario lines-16k --scenario lines-256k bash
    assert_equals "0" "$BENCH_STATUS" || return
    # 4000 / 100 = 40 is over 32 in both runs; measured again it is 30, which is under
    assert_contains "$BENCH_OUTPUT" \
        "bash           scaling        2 runs, min 40.000, median 40.000, max 40.000, largest slowdown n/a, over the limit 2, still over after measuring again 0" || return
    assert_contains "$(cat "$tsv_file")" "$(printf 'bash\tscaling\t2\t40.000\t40.000\t40.000\t-\t2\t0')" || return

    pass_test
}

test_bench_calibration_compares_the_file_with_a_copy() {
    start_test "a real calibration run compares logging.sh with itself and finds no slowdown"

    run_bench --calibrate 2 --rounds 2 --count 20 --scenario plain bash
    assert_equals "0" "$BENCH_STATUS" "$BENCH_OUTPUT" || return
    assert_contains "$BENCH_OUTPUT" "Calibration: 2 comparisons of logging.sh with a copy of itself" || return
    assert_contains "$BENCH_OUTPUT" "plain          2 runs, min" || return

    pass_test
}

# ---------------------------------------------------------------------------
# End to end
# ---------------------------------------------------------------------------

test_bench_reports_an_extra_process_as_slower() {
    start_test "one extra process per call is reported as SLOWER and fails the run"

    # The canary from #156: a process is started on every call. It runs on a copy of
    # logging.sh in $TEST_DIR, never on the repository's file.
    local canary
    canary=$(make_logging_copy canary-extra-process.sh \
        'log_info() {
    awk "BEGIN { exit }"
    _log_message "INFO" "$LOG_LEVEL_INFO" "$1"
}')

    run_bench --logging "$canary" --baseline "$PROJECT_ROOT/logging.sh" \
        --count 30 --rounds 3 --scenario plain bash
    assert_equals "1" "$BENCH_STATUS" "exit status of a slower candidate" || return
    assert_contains "$BENCH_OUTPUT" "SLOWER" || return
    assert_contains "$BENCH_OUTPUT" "FAIL bash plain: ratio" || return

    pass_test
}

test_bench_run_without_a_baseline() {
    start_test "a run without a baseline prints each scenario and exits 0"

    run_bench --count 5 --rounds 1 --scenario plain --scenario filtered bash
    assert_equals "0" "$BENCH_STATUS" "exit status without a baseline" || return
    assert_contains "$BENCH_OUTPUT" "us (source + init_logger, information only)" || return
    assert_contains "$BENCH_OUTPUT" "plain" || return
    assert_contains "$BENCH_OUTPUT" "filtered" || return
    assert_not_contains "$BENCH_OUTPUT" "FAIL" || return

    pass_test
}

# Run all tests
test_bench_ratio_is_candidate_over_baseline
test_bench_slower_over_the_ratio_limit
test_bench_not_slower_under_the_ratio_limit
test_bench_ratio_boundary
test_bench_minimum_difference_boundary
test_bench_large_ratio_under_the_floor
test_bench_median
test_bench_scaling
test_bench_sourcing_changes_nothing
test_bench_count_must_be_a_positive_integer
test_bench_missing_logging_file
test_bench_failing_init_logger
test_bench_wrong_log_line_count
test_bench_unknown_scenario
test_bench_large_scenarios_run_about_a_second
test_bench_alternates_candidate_and_baseline
test_bench_confirms_a_slowdown_before_failing
test_bench_fails_when_the_slowdown_repeats
test_bench_does_not_repeat_a_result_under_the_limit
test_bench_confirms_steep_scaling_before_failing
test_bench_filtered_scenario_has_its_own_floor
test_bench_min_difference_needs_a_whole_number
test_bench_filtered_slowdown_of_a_few_microseconds_fails
test_bench_summary_lists_limits_versions_and_results
test_bench_summary_is_written_when_the_run_fails
test_bench_summary_is_written_when_a_run_fails
test_bench_no_summary_without_the_option
test_bench_ratio_statistics
test_bench_calibrate_rejects_bad_arguments
test_bench_calibration_counts_runs_over_the_limit
test_bench_calibration_reports_scaling
test_bench_calibration_compares_the_file_with_a_copy
test_bench_reports_an_extra_process_as_slower
test_bench_run_without_a_baseline
