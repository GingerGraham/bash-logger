#!/usr/bin/env bash
#
# test_junit_output.sh - Tests for JUnit XML output generation
#
# Tests:
# - XML escaping of special characters
# - Test duration calculation
# - Testcase accumulation with pipe delimiter
# - Generated XML structure and validity
# - --junit flag produces valid output

# shellcheck disable=SC2034
# Variables like current_test, TEST_START_TIME, JUNIT_OUTPUT, CURRENT_SUITE_TESTCASES
# are used by functions in test_helpers.sh

# Test XML escape function handles special characters
test_junit_xml_escape_ampersand() {
    start_test "XML escape handles ampersand"

    local result
    result=$(_junit_xml_escape "foo & bar")

    assert_equals "foo &amp; bar" "$result" || return

    pass_test
}

test_junit_xml_escape_less_than() {
    start_test "XML escape handles less than"

    local result
    result=$(_junit_xml_escape "foo < bar")

    assert_equals "foo &lt; bar" "$result" || return

    pass_test
}

test_junit_xml_escape_greater_than() {
    start_test "XML escape handles greater than"

    local result
    result=$(_junit_xml_escape "foo > bar")

    assert_equals "foo &gt; bar" "$result" || return

    pass_test
}

test_junit_xml_escape_single_quote() {
    start_test "XML escape handles single quote"

    local result
    result=$(_junit_xml_escape "foo ' bar")

    assert_equals "foo &apos; bar" "$result" || return

    pass_test
}

test_junit_xml_escape_double_quote() {
    start_test "XML escape handles double quote"

    local result
    result=$(_junit_xml_escape "foo \" bar")

    assert_equals "foo &quot; bar" "$result" || return

    pass_test
}

test_junit_xml_escape_multiple_special_chars() {
    start_test "XML escape handles multiple special characters"

    local result
    result=$(_junit_xml_escape "<test name=\"foo & bar\">")

    assert_equals "&lt;test name=&quot;foo &amp; bar&quot;&gt;" "$result" || return

    pass_test
}

test_junit_xml_escape_preserves_normal_text() {
    start_test "XML escape preserves normal text"

    local result
    result=$(_junit_xml_escape "normal text 123")

    assert_equals "normal text 123" "$result" || return

    pass_test
}

# Test duration calculation
test_junit_xml_escape_strips_control_characters() {
    start_test "XML escape strips control characters illegal in XML 1.0"

    local result
    result=$(_junit_xml_escape "$(printf 'red: \033[31mtext\033[0m bell:\007 end')")

    assert_equals "red: [31mtext[0m bell: end" "$result" || return

    pass_test
}

test_junit_xml_escape_keeps_tab_and_newline() {
    start_test "XML escape keeps tab and newline"

    local result expected
    result=$(_junit_xml_escape "$(printf 'a\tb\nc')")
    expected=$(printf 'a\tb\nc')

    assert_equals "$expected" "$result" || return

    pass_test
}

test_get_test_duration_returns_number() {
    start_test "Test duration returns a number"

    # Set a start time
    TEST_START_TIME=$(date +%s.%N 2>/dev/null || date +%s)
    sleep 0.1

    local duration
    duration=$(_get_test_duration)

    # Duration should be a number (possibly with decimal, may start with . for values < 1)
    assert_matches "$duration" "^[0-9.]" "Duration should be a numeric value" || return

    pass_test
}

test_get_test_duration_fallback_without_bc() {
    start_test "Test duration falls back to 0 without bc"

    # Save original PATH and remove bc
    local original_path="$PATH"
    PATH="/usr/bin:/bin"

    # Set start time
    TEST_START_TIME=$(date +%s)

    local duration
    # Test the fallback by calling the function in a subshell with modified PATH
    duration=$(PATH="/nonexistent" _get_test_duration 2>/dev/null)

    # Restore PATH
    PATH="$original_path"

    # Should return "0" as fallback
    assert_equals "0" "$duration" || return

    pass_test
}

# Build a single testCase element in a subshell and print it.
#
# These tests exercise _add_junit_testcase, which reads and writes the runner's globals
# (JUNIT_OUTPUT, CURRENT_SUITE_TESTCASES, current_test). When the suites run sequentially
# (-j 1, which "make coverage-junit" forces) they are sourced into the runner's own shell,
# so changing those globals here would switch off the runner's --junit report. The subshell
# keeps every change local.
_junit_testcase_xml() {
    local name="$1"
    local status="$2"
    local message="${3:-}"

    (
        JUNIT_OUTPUT=true
        CURRENT_SUITE_TESTCASES=""
        current_test="$name"
        TEST_START_TIME=$(date +%s.%N 2>/dev/null || date +%s)
        _add_junit_testcase "$status" "$message"
        printf '%s' "$CURRENT_SUITE_TESTCASES"
    )
}

# Test testcase accumulation
test_junit_testcase_accumulation_first_entry() {
    start_test "First testcase sets CURRENT_SUITE_TESTCASES"

    local testcases
    testcases=$(_junit_testcase_xml "test_one" "pass")

    assert_contains "$testcases" "testCase" || return
    assert_contains "$testcases" "test_one" || return
    # Should not start with pipe delimiter
    assert_matches "$testcases" "^<testCase" || return

    pass_test
}

test_junit_testcase_accumulation_multiple_entries() {
    start_test "Multiple testcases are pipe-delimited"

    local testcases
    testcases=$(
        JUNIT_OUTPUT=true
        CURRENT_SUITE_TESTCASES=""
        TEST_START_TIME=$(date +%s.%N 2>/dev/null || date +%s)

        current_test="test_one"
        _add_junit_testcase "pass"

        current_test="test_two"
        _add_junit_testcase "pass"

        printf '%s' "$CURRENT_SUITE_TESTCASES"
    )

    # Should contain pipe delimiter between entries
    assert_contains "$testcases" "|" "Should have pipe delimiter" || return
    assert_contains "$testcases" "test_one" || return
    assert_contains "$testcases" "test_two" || return

    pass_test
}

# Test different testcase status types
test_junit_testcase_pass_format() {
    start_test "Pass testcase has correct XML format"

    local testcases
    testcases=$(_junit_testcase_xml "passing_test" "pass")

    # Should be self-closing testCase element
    assert_matches "$testcases" '<testCase name="passing_test" duration="[0-9]+"/>' || return

    pass_test
}

test_junit_testcase_fail_format() {
    start_test "Fail testcase includes failure element"

    local testcases
    testcases=$(_junit_testcase_xml "failing_test" "fail" "Test failed because of X")

    assert_contains "$testcases" "<failure" || return
    assert_contains "$testcases" "Test failed because of X" || return
    assert_contains "$testcases" "</testCase>" || return

    pass_test
}

test_junit_testcase_skip_format() {
    start_test "Skip testcase includes skipped element"

    local testcases
    testcases=$(_junit_testcase_xml "skipped_test" "skip" "Missing dependency")

    assert_contains "$testcases" "<skipped" || return
    assert_contains "$testcases" "Missing dependency" || return
    assert_contains "$testcases" "</testCase>" || return

    pass_test
}

test_junit_testcase_unknown_status() {
    start_test "Unknown status produces error element"

    local testcases
    testcases=$(_junit_testcase_xml "unknown_status_test" "invalid_status")

    assert_contains "$testcases" "<error" || return
    assert_contains "$testcases" "Unknown status" || return

    pass_test
}

# Test special character escaping in testcase names and messages
test_junit_testcase_escapes_special_chars_in_name() {
    start_test "Testcase escapes special characters in name"

    local testcases
    testcases=$(_junit_testcase_xml "test with <special> & \"chars\"" "pass")

    assert_contains "$testcases" "&lt;special&gt;" || return
    assert_contains "$testcases" "&amp;" || return
    assert_contains "$testcases" "&quot;chars&quot;" || return

    pass_test
}

test_junit_testcase_escapes_special_chars_in_message() {
    start_test "Testcase escapes special characters in failure message"

    local testcases
    testcases=$(_junit_testcase_xml "test_failure" "fail" "Expected <foo> & got \"bar\"")

    assert_contains "$testcases" "&lt;foo&gt;" || return
    assert_contains "$testcases" "&amp;" || return
    assert_contains "$testcases" "&quot;bar&quot;" || return

    pass_test
}

# Regression: sequential runs source suites into the runner's shell, so a test that leaves
# JUNIT_OUTPUT or CURRENT_SUITE_TESTCASES changed silently disables the --junit report.
test_junit_testcase_helper_preserves_runner_state() {
    start_test "Testcase helper leaves runner JUnit state untouched"

    local original_flag="${JUNIT_OUTPUT:-}"
    local original_cases="${CURRENT_SUITE_TESTCASES:-}"
    local original_name="$current_test"

    JUNIT_OUTPUT="sentinel-flag"
    CURRENT_SUITE_TESTCASES="sentinel-cases"
    _junit_testcase_xml "other_test" "pass" >/dev/null

    local observed_flag="$JUNIT_OUTPUT"
    local observed_cases="$CURRENT_SUITE_TESTCASES"
    local observed_name="$current_test"

    # Restore before asserting so a failed assertion cannot leak the sentinels
    JUNIT_OUTPUT="$original_flag"
    CURRENT_SUITE_TESTCASES="$original_cases"

    assert_equals "sentinel-flag" "$observed_flag" "JUNIT_OUTPUT should be unchanged" || return
    assert_equals "sentinel-cases" "$observed_cases" "CURRENT_SUITE_TESTCASES should be unchanged" || return
    assert_equals "$original_name" "$observed_name" "current_test should be unchanged" || return

    pass_test
}

# Test full JUnit output file generation
test_junit_flag_creates_output_file() {
    start_test "JUnit flag creates output file"

    local output_dir="$TEST_DIR/junit-test"
    mkdir -p "$output_dir"

    # Run a minimal test with --junit flag
    (
        cd "$PROJECT_ROOT/tests" || exit 1
        ./run_tests.sh --junit --output-dir "$output_dir" test_log_levels >/dev/null 2>&1
    )

    assert_file_exists "$output_dir/junit.xml" "JUnit XML file should be created" || return

    pass_test
}

test_junit_output_has_valid_xml_structure() {
    start_test "JUnit output has valid XML structure"

    local output_dir="$TEST_DIR/junit-structure-test"
    mkdir -p "$output_dir"

    # Run tests with --junit flag
    (
        cd "$PROJECT_ROOT/tests" || exit 1
        ./run_tests.sh --junit --output-dir "$output_dir" test_log_levels >/dev/null 2>&1
    )

    local xml_file="$output_dir/junit.xml"
    assert_file_exists "$xml_file" || return

    # Check XML declaration
    assert_file_contains "$xml_file" '<?xml version="1.0"' || return

    # Check root element
    assert_file_contains "$xml_file" '<testExecutions' || return
    assert_file_contains "$xml_file" '</testExecutions>' || return

    # Check file element
    assert_file_contains "$xml_file" '<file path=' || return
    assert_file_contains "$xml_file" '</file>' || return

    # Check testCase elements exist
    assert_file_contains "$xml_file" '<testCase' || return

    pass_test
}

test_junit_output_contains_test_results() {
    start_test "JUnit output contains test results"

    local output_dir="$TEST_DIR/junit-results-test"
    mkdir -p "$output_dir"

    # Run tests with --junit flag
    (
        cd "$PROJECT_ROOT/tests" || exit 1
        ./run_tests.sh --junit --output-dir "$output_dir" test_log_levels >/dev/null 2>&1
    )

    local xml_file="$output_dir/junit.xml"
    assert_file_exists "$xml_file" || return

    # Should reference the test file
    assert_file_contains "$xml_file" 'tests/test_log_levels.sh' || return

    # Should have duration attributes
    assert_file_contains "$xml_file" 'duration=' || return

    pass_test
}

# Test that --fail-fast stops the runner after the first failing suite
test_fail_fast_stops_after_first_failure() {
    start_test "--fail-fast stops after first suite with failures"

    local unique_suffix failing_suite_name second_suite_name
    local failing_suite_path second_suite_path
    local failing_marker second_marker
    local output exit_code second_marker_count

    unique_suffix="fail_fast_$$"
    failing_suite_name="test_${unique_suffix}_failing"
    second_suite_name="test_${unique_suffix}_second"
    failing_suite_path="$PROJECT_ROOT/tests/${failing_suite_name}.sh"
    second_suite_path="$PROJECT_ROOT/tests/${second_suite_name}.sh"
    failing_marker="FAIL_FAST_TEMP_FAILURE_MARKER_${unique_suffix}"
    second_marker="FAIL_FAST_TEMP_SECOND_MARKER_${unique_suffix}"

    cat >"$failing_suite_path" <<EOF
#!/usr/bin/env bash
echo "${failing_marker}"
current_test="temp failing test"
suite_tests=\$((suite_tests + 1))
fail_test "intentional failure for fail-fast test"
EOF

    cat >"$second_suite_path" <<EOF
#!/usr/bin/env bash
echo "${second_marker}"
EOF

    chmod +x "$failing_suite_path" "$second_suite_path"

    output=$(cd "$PROJECT_ROOT" && ./tests/run_tests.sh --fail-fast "$failing_suite_name" "$second_suite_name" 2>&1)
    exit_code=$?

    rm -f "$failing_suite_path" "$second_suite_path"

    assert_equals "1" "$exit_code" "--fail-fast should exit non-zero after the first failing suite" || return
    assert_contains "$output" "$failing_marker" "The failing suite should run before execution stops" || return

    second_marker_count=$(printf '%s\n' "$output" | grep -F -c "$second_marker" || true)
    assert_equals "0" "$second_marker_count" "The second suite should not run when --fail-fast is enabled" || return

    pass_test
}

# Test that --fail-fast message is shown when enabled
test_fail_fast_banner_shown() {
    start_test "--fail-fast banner is printed when flag is set"

    local output
    output=$(cd "$PROJECT_ROOT" && ./tests/run_tests.sh --fail-fast test_log_levels 2>&1)

    assert_contains "$output" "Fail-fast enabled" || return

    pass_test
}

# Test that failed test details appear in summary for parallel runs
test_parallel_failed_details_in_summary() {
    start_test "Failed test details are shown in summary for parallel runs"

    local suite_file suite_name output
    suite_file=$(mktemp "$PROJECT_ROOT/tests/test_parallel_failed_details_XXXXXX.sh") || {
        fail_test "Failed to create temp suite file"
        return
    }
    suite_name=$(basename "${suite_file%.sh}")

    cat > "$suite_file" <<'SUITE_EOF'
#!/usr/bin/env bash
current_test="Intentional parallel failure"
suite_tests=$((suite_tests + 1))
fail_test "expected parallel failure details"
SUITE_EOF
    chmod +x "$suite_file"

    output=$(cd "$PROJECT_ROOT" && ./tests/run_tests.sh -j 2 "$suite_name" 2>&1 || true)

    rm -f "$suite_file"

    assert_contains "$output" "Failed Tests" "Summary should include Failed Tests section" || return
    assert_contains "$output" "Intentional parallel failure" "Summary should include the failed test name" || return
    assert_contains "$output" "expected parallel failure details" "Summary should include the propagated failure details" || return

    pass_test
}

# Run all tests
test_junit_xml_escape_ampersand
test_junit_xml_escape_less_than
test_junit_xml_escape_greater_than
test_junit_xml_escape_single_quote
test_junit_xml_escape_double_quote
test_junit_xml_escape_multiple_special_chars
test_junit_xml_escape_preserves_normal_text
test_junit_xml_escape_strips_control_characters
test_junit_xml_escape_keeps_tab_and_newline
test_get_test_duration_returns_number
test_get_test_duration_fallback_without_bc
test_junit_testcase_accumulation_first_entry
test_junit_testcase_accumulation_multiple_entries
test_junit_testcase_pass_format
test_junit_testcase_fail_format
test_junit_testcase_skip_format
test_junit_testcase_unknown_status
test_junit_testcase_escapes_special_chars_in_name
test_junit_testcase_escapes_special_chars_in_message
test_junit_testcase_helper_preserves_runner_state
test_junit_flag_creates_output_file
test_junit_output_has_valid_xml_structure
test_junit_output_contains_test_results
test_fail_fast_stops_after_first_failure
test_fail_fast_banner_shown
test_parallel_failed_details_in_summary
