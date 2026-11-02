#!/usr/bin/env bash
# Regression coverage for suite accounting and crash containment (issue #140).
# Fixtures must live beside real suites for name-based discovery. RETURN traps
# remove them even when an assertion returns early; other I/O uses TEST_DIR.

# Run a fixture without letting its intentional failure end this regression test.
runner_invoke() {
    local jobs="$1"
    shift
    "$SCRIPT_DIR/run_tests.sh" -j "$jobs" --junit \
        --output-dir "$TEST_DIR/report-$jobs" "$@" >"$TEST_DIR/runner-output" 2>&1
    runner_status=$?
    runner_output=$(cat "$TEST_DIR/runner-output")
}

# Check the shared observable crash contract, including the normal final summary.
runner_assert_crash() {
    local suite_file="$1" status="$2"
    assert_equals "1" "$runner_status" "A suite crash must fail the runner" || return
    assert_contains "$runner_output" "Test Summary" || return
    assert_contains "$runner_output" "$(basename "$suite_file" .sh): suite exited with status $status" \
        || return
    assert_not_contains "$runner_output" "All tests passed!" || return
}

test_runner_crash_parallel_fails() {
    start_test "Parallel crash preserves a pass and reports status 3"
    local suite_file
    suite_file=$(mktemp "$SCRIPT_DIR/test_runner_fixture_XXXXXX.sh")
    trap 'rm -f "$suite_file"; trap - RETURN' RETURN
    printf '%s\n' 'start_test "before crash"; pass_test' 'exit 3' >"$suite_file"

    runner_invoke 2 "$(basename "$suite_file" .sh)"
    runner_assert_crash "$suite_file" 3 || return
    assert_contains "$runner_output" "Total Tests:   2" || return
    assert_contains "$runner_output" "Passed:        1" || return
    assert_contains "$runner_output" "Failed:        1" || return
    pass_test
}

test_runner_crash_sequential_reports() {
    start_test "Sequential crash prints summary and continues to a passing suite"
    local suite_file second_suite_file
    suite_file=$(mktemp "$SCRIPT_DIR/test_runner_fixture_XXXXXX.sh")
    second_suite_file=$(mktemp "$SCRIPT_DIR/test_runner_fixture_XXXXXX.sh")
    trap 'rm -f "$suite_file" "$second_suite_file"; trap - RETURN' RETURN
    printf '%s\n' 'start_test "before crash"; pass_test' 'exit 3' >"$suite_file"
    printf '%s\n' 'start_test "after crash"; pass_test' >"$second_suite_file"

    runner_invoke 1 "$(basename "$suite_file" .sh)" "$(basename "$second_suite_file" .sh)"
    runner_assert_crash "$suite_file" 3 || return
    assert_contains "$runner_output" "Total Tests:   3" || return
    assert_contains "$runner_output" "Passed:        2" || return
    assert_contains "$runner_output" "Failed:        1" || return
    pass_test
}

test_runner_crash_before_any_test() {
    start_test "A crash before any test fails in both modes"
    local suite_file jobs
    suite_file=$(mktemp "$SCRIPT_DIR/test_runner_fixture_XXXXXX.sh")
    trap 'rm -f "$suite_file"; trap - RETURN' RETURN
    printf '%s\n' 'exit 1' >"$suite_file"
    for jobs in 1 2; do
        runner_invoke "$jobs" "$(basename "$suite_file" .sh)"
        runner_assert_crash "$suite_file" 1 || return
        assert_contains "$runner_output" "Total Tests:   1" || return
        assert_contains "$runner_output" "Failed:        1" || return
    done
    pass_test
}

test_runner_zero_tests_fails() {
    start_test "Empty suites fail in both modes"
    local suite_file jobs
    suite_file=$(mktemp "$SCRIPT_DIR/test_runner_fixture_XXXXXX.sh")
    trap 'rm -f "$suite_file"; trap - RETURN' RETURN
    printf '%s\n' 'defined_but_not_called() { :; }' >"$suite_file"
    for jobs in 1 2; do
        runner_invoke "$jobs" "$(basename "$suite_file" .sh)"
        assert_equals "1" "$runner_status" || return
        assert_contains "$runner_output" "reported 0 tests (exit status 0)" || return
        assert_contains "$runner_output" "Total Tests:   1" || return
        assert_not_contains "$runner_output" "All tests passed!" || return
        assert_file_contains "$TEST_DIR/report-$jobs/junit.xml" '<error message=' || return
    done
    pass_test
}

test_runner_crash_with_passing_suite() {
    start_test "Every dispatched PID is counted alongside a parallel crash"
    local suite_file second_suite_file
    suite_file=$(mktemp "$SCRIPT_DIR/test_runner_fixture_XXXXXX.sh")
    second_suite_file=$(mktemp "$SCRIPT_DIR/test_runner_fixture_XXXXXX.sh")
    trap 'rm -f "$suite_file" "$second_suite_file"; trap - RETURN' RETURN
    printf '%s\n' 'exit 3' >"$suite_file"
    printf '%s\n' 'start_test "passing fixture"; pass_test' >"$second_suite_file"

    # Repeated identities still have distinct dispatches/results and PIDs.
    runner_invoke 2 "$(basename "$second_suite_file" .sh)" \
        "$(basename "$suite_file" .sh)" "$(basename "$second_suite_file" .sh)"
    runner_assert_crash "$suite_file" 3 || return
    assert_contains "$runner_output" "Total Tests:   3" || return
    assert_contains "$runner_output" "Passed:        2" || return
    assert_contains "$runner_output" "Failed:        1" || return
    pass_test
}

test_runner_crash_junit() {
    start_test "Crash XML preserves passing cases and adds one error in both modes"
    local suite_file jobs report errors
    suite_file=$(mktemp "$SCRIPT_DIR/test_runner_fixture_XXXXXX.sh")
    trap 'rm -f "$suite_file"; trap - RETURN' RETURN
    printf '%s\n' 'start_test "before crash"; pass_test' 'exit 3' >"$suite_file"
    for jobs in 1 2; do
        runner_invoke "$jobs" "$(basename "$suite_file" .sh)"
        runner_assert_crash "$suite_file" 3 || return
        report="$TEST_DIR/report-$jobs/junit.xml"
        assert_file_contains "$report" "tests/$(basename "$suite_file")" || return
        assert_file_contains "$report" '<testCase name="before crash"' || return
        assert_file_contains "$report" '<error message=' || return
        assert_file_contains "$report" 'status 3' || return
        assert_file_not_contains "$report" '<failure' || return
        errors=$(grep -c '<error ' "$report")
        assert_equals "1" "$errors" || return
    done
    pass_test
}

test_runner_crash_shows_output_tail() {
    start_test "Crash diagnostics include a bounded stderr tail in both modes"
    local suite_file jobs
    suite_file=$(mktemp "$SCRIPT_DIR/test_runner_fixture_XXXXXX.sh")
    trap 'rm -f "$suite_file"; trap - RETURN' RETURN
    cat >"$suite_file" <<'SUITE_EOF'
for ((line=0; line<30; line++)); do printf 'noise-%s\n' "$line" >&2; done
echo marker-line >&2
exit 4
SUITE_EOF
    for jobs in 1 2; do
        runner_invoke "$jobs" "$(basename "$suite_file" .sh)"
        runner_assert_crash "$suite_file" 4 || return
        assert_contains "$runner_output" 'marker-line' || return
        assert_contains "$runner_output" 'Last 20 lines' || return
        assert_not_contains "$runner_output" $'noise-0\n' || return
        assert_file_contains "$TEST_DIR/report-$jobs/junit.xml" 'marker-line' || return
    done
    pass_test
}

test_runner_error_xml_escaping() {
    start_test "Suite error XML escapes diagnostics and preserves literal pipes"
    local suite_file jobs report
    suite_file=$(mktemp "$SCRIPT_DIR/test_runner_fixture_XXXXXX.sh")
    trap 'rm -f "$suite_file"; trap - RETURN' RETURN
    printf '%s\n' "printf '\\033[31m<&>\\\"\\047|marker\\n' >&2" 'exit 4' >"$suite_file"
    for jobs in 1 2; do
        runner_invoke "$jobs" "$(basename "$suite_file" .sh)"
        runner_assert_crash "$suite_file" 4 || return
        report="$TEST_DIR/report-$jobs/junit.xml"
        assert_file_contains "$report" '&lt;&amp;&gt;&quot;&apos;|marker' || return
        assert_file_not_contains "$report" $'\033' || return
        assert_file_contains "$report" 'marker' || return
    done
    pass_test
}

test_runner_all_pass_control() {
    start_test "Two passing suites retain exact counts in both modes"
    local suite_file second_suite_file jobs
    suite_file=$(mktemp "$SCRIPT_DIR/test_runner_fixture_XXXXXX.sh")
    second_suite_file=$(mktemp "$SCRIPT_DIR/test_runner_fixture_XXXXXX.sh")
    trap 'rm -f "$suite_file" "$second_suite_file"; trap - RETURN' RETURN
    printf '%s\n' 'start_test "first pass"; pass_test' >"$suite_file"
    printf '%s\n' 'start_test "second pass"; pass_test' >"$second_suite_file"
    for jobs in 1 2; do
        runner_invoke "$jobs" "$(basename "$suite_file" .sh)" "$(basename "$second_suite_file" .sh)"
        assert_equals "0" "$runner_status" || return
        assert_contains "$runner_output" 'All tests passed!' || return
        assert_contains "$runner_output" 'Total Tests:   2' || return
        assert_contains "$runner_output" 'Passed:        2' || return
        assert_contains "$runner_output" 'Failed:        0' || return
        assert_file_not_contains "$TEST_DIR/report-$jobs/junit.xml" '<error' || return
    done
    pass_test
}

test_runner_all_skipped_passes() {
    start_test "All-skipped suites are nonempty and succeed in both modes"
    local suite_file jobs
    suite_file=$(mktemp "$SCRIPT_DIR/test_runner_fixture_XXXXXX.sh")
    trap 'rm -f "$suite_file"; trap - RETURN' RETURN
    printf '%s\n' 'start_test "skip one"; skip_test "synthetic skip"' >"$suite_file"
    for jobs in 1 2; do
        runner_invoke "$jobs" "$(basename "$suite_file" .sh)"
        assert_equals "0" "$runner_status" || return
        assert_contains "$runner_output" 'Total Tests:   1' || return
        assert_contains "$runner_output" 'Skipped:       1' || return
        assert_contains "$runner_output" 'Failed:        0' || return
        assert_file_contains "$TEST_DIR/report-$jobs/junit.xml" '<skipped ' || return
        assert_file_not_contains "$TEST_DIR/report-$jobs/junit.xml" '<error' || return
    done
    pass_test
}

test_runner_nounset_is_contained() {
    start_test "Fatal nounset retains diagnostics and partial counts in both modes"
    local suite_file jobs
    suite_file=$(mktemp "$SCRIPT_DIR/test_runner_fixture_XXXXXX.sh")
    trap 'rm -f "$suite_file"; trap - RETURN' RETURN
    printf '%s\n' 'start_test "before nounset"; pass_test' \
        'unset RUNNER_INTENTIONALLY_UNSET' 'echo "$RUNNER_INTENTIONALLY_UNSET"' >"$suite_file"
    for jobs in 1 2; do
        runner_invoke "$jobs" "$(basename "$suite_file" .sh)"
        runner_assert_crash "$suite_file" 1 || return
        assert_contains "$runner_output" 'RUNNER_INTENTIONALLY_UNSET: unbound variable' || return
        assert_contains "$runner_output" 'Passed:        1' || return
    done
    pass_test
}

test_runner_errexit_is_preserved() {
    start_test "Suite errexit is honored in both modes"
    local suite_file jobs
    suite_file=$(mktemp "$SCRIPT_DIR/test_runner_fixture_XXXXXX.sh")
    trap 'rm -f "$suite_file"; trap - RETURN' RETURN
    printf '%s\n' 'set -e' 'false' 'echo SHOULD_NOT_RUN' >"$suite_file"
    for jobs in 1 2; do
        runner_invoke "$jobs" "$(basename "$suite_file" .sh)"
        runner_assert_crash "$suite_file" 1 || return
        assert_not_contains "$runner_output" 'SHOULD_NOT_RUN' || return
    done
    pass_test
}

test_runner_missing_results_fails() {
    start_test "A worker without a result file still fails in both modes"
    local suite_file jobs
    suite_file=$(mktemp "$SCRIPT_DIR/test_runner_fixture_XXXXXX.sh")
    trap 'rm -f "$suite_file"; trap - RETURN' RETURN
    printf '%s\n' "trap 'cleanup_test_suite' EXIT" 'exit 7' >"$suite_file"
    for jobs in 1 2; do
        runner_invoke "$jobs" "$(basename "$suite_file" .sh)"
        runner_assert_crash "$suite_file" 7 || return
        assert_contains "$runner_output" 'before reporting results' || return
        assert_file_contains "$TEST_DIR/report-$jobs/junit.xml" '<error message=' || return
    done
    pass_test
}

test_runner_incomplete_results_fails() {
    start_test "An incomplete snapshot cannot contribute partial passes or XML"
    local suite_file jobs report
    suite_file=$(mktemp "$SCRIPT_DIR/test_runner_fixture_XXXXXX.sh")
    trap 'rm -f "$suite_file"; trap - RETURN' RETURN
    cat >"$suite_file" <<'SUITE_EOF'
trap 'cleanup_test_suite' EXIT
cat >"$results_file" <<'RESULT_EOF'
SUITE_TESTS=1
SUITE_PASSED=1
SUITE_TESTCASES_START
<testCase name="unreliable pass" duration="0"/>
SUITE_TESTCASES_END
FAILED_DETAILS_START
UNRELIABLE_FAILURE_DETAIL
FAILED_DETAILS_END
RESULT_EOF
exit 0
SUITE_EOF
    for jobs in 1 2; do
        runner_invoke "$jobs" "$(basename "$suite_file" .sh)"
        runner_assert_crash "$suite_file" 0 || return
        assert_contains "$runner_output" 'before reporting results' || return
        assert_contains "$runner_output" 'Total Tests:   1' || return
        assert_contains "$runner_output" 'Passed:        0' || return
        assert_contains "$runner_output" 'Failed:        1' || return
        assert_not_contains "$runner_output" 'UNRELIABLE_FAILURE_DETAIL' || return
        report="$TEST_DIR/report-$jobs/junit.xml"
        assert_file_contains "$report" '<error message=' || return
        assert_file_not_contains "$report" 'unreliable pass' || return
    done
    pass_test
}

test_runner_nonzero_source_status() {
    start_test "A normally returned nonzero suite status is accounted for"
    local suite_file jobs
    suite_file=$(mktemp "$SCRIPT_DIR/test_runner_fixture_XXXXXX.sh")
    trap 'rm -f "$suite_file"; trap - RETURN' RETURN
    printf '%s\n' 'start_test "before return"; pass_test' 'return 6' >"$suite_file"
    for jobs in 1 2; do
        runner_invoke "$jobs" "$(basename "$suite_file" .sh)"
        runner_assert_crash "$suite_file" 6 || return
        assert_contains "$runner_output" 'Passed:        1' || return
    done
    pass_test
}

test_runner_early_success_exit_fails() {
    start_test "An early exit 0 cannot conceal an incomplete suite"
    local suite_file jobs
    suite_file=$(mktemp "$SCRIPT_DIR/test_runner_fixture_XXXXXX.sh")
    trap 'rm -f "$suite_file"; trap - RETURN' RETURN
    printf '%s\n' 'start_test "before exit"; pass_test' 'exit 0' >"$suite_file"
    for jobs in 1 2; do
        runner_invoke "$jobs" "$(basename "$suite_file" .sh)"
        runner_assert_crash "$suite_file" 0 || return
        assert_contains "$runner_output" 'before completing' || return
    done
    pass_test
}

test_runner_completed_counters_survive() {
    start_test "Crash retains pass, failure and skip without double-counting an unfinished test"
    local suite_file jobs report
    suite_file=$(mktemp "$SCRIPT_DIR/test_runner_fixture_XXXXXX.sh")
    trap 'rm -f "$suite_file"; trap - RETURN' RETURN
    cat >"$suite_file" <<'SUITE_EOF'
start_test "completed pass"; pass_test
start_test "completed fail"; fail_test "expected assertion failure"
start_test "completed skip"; skip_test "synthetic skip"
start_test "interrupted test"
exit 3
SUITE_EOF
    for jobs in 1 2; do
        runner_invoke "$jobs" "$(basename "$suite_file" .sh)"
        runner_assert_crash "$suite_file" 3 || return
        assert_contains "$runner_output" 'Total Tests:   4' || return
        assert_contains "$runner_output" 'Passed:        1' || return
        assert_contains "$runner_output" 'Failed:        2' || return
        assert_contains "$runner_output" 'Skipped:       1' || return
        assert_contains "$runner_output" 'expected assertion failure' || return
        report="$TEST_DIR/report-$jobs/junit.xml"
        assert_file_contains "$report" '<failure message=' || return
        assert_file_contains "$report" '<skipped message=' || return
        assert_file_contains "$report" '<error message=' || return
    done
    pass_test
}

test_runner_fail_fast_crash() {
    start_test "Fail-fast stops after a crash and still generates summary and XML"
    local suite_file second_suite_file
    suite_file=$(mktemp "$SCRIPT_DIR/test_runner_fixture_XXXXXX.sh")
    second_suite_file=$(mktemp "$SCRIPT_DIR/test_runner_fixture_XXXXXX.sh")
    trap 'rm -f "$suite_file" "$second_suite_file"; trap - RETURN' RETURN
    printf '%s\n' 'exit 3' >"$suite_file"
    printf '%s\n' 'echo SHOULD_NOT_RUN' >"$second_suite_file"
    runner_invoke 2 --fail-fast "$(basename "$suite_file" .sh)" \
        "$(basename "$second_suite_file" .sh)"
    runner_assert_crash "$suite_file" 3 || return
    assert_contains "$runner_output" 'Fail-fast: stopping' || return
    assert_not_contains "$runner_output" 'SHOULD_NOT_RUN' || return
    assert_file_contains "$TEST_DIR/report-2/junit.xml" '<error message=' || return
    pass_test
}

test_runner_crash_parallel_fails
test_runner_crash_sequential_reports
test_runner_crash_before_any_test
test_runner_zero_tests_fails
test_runner_crash_with_passing_suite
test_runner_crash_junit
test_runner_crash_shows_output_tail
test_runner_error_xml_escaping
test_runner_all_pass_control
test_runner_all_skipped_passes
test_runner_nounset_is_contained
test_runner_errexit_is_preserved
test_runner_missing_results_fails
test_runner_incomplete_results_fails
test_runner_nonzero_source_status
test_runner_early_success_exit_fails
test_runner_completed_counters_survive
test_runner_fail_fast_crash
