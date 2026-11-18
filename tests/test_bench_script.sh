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
# about 10 seconds. It runs the script under bash only, so it also works on macOS with bash
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
test_bench_reports_an_extra_process_as_slower
test_bench_run_without_a_baseline
