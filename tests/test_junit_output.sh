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

# Test testcase accumulation
test_junit_testcase_accumulation_first_entry() {
    start_test "First testcase sets CURRENT_SUITE_TESTCASES"

    # Enable JUnit and reset accumulator
    JUNIT_OUTPUT=true
    CURRENT_SUITE_TESTCASES=""
    current_test="test_one"
    TEST_START_TIME=$(date +%s.%N 2>/dev/null || date +%s)

    _add_junit_testcase "pass"

    assert_contains "$CURRENT_SUITE_TESTCASES" "testCase" || return
    assert_contains "$CURRENT_SUITE_TESTCASES" "test_one" || return
    # Should not start with pipe delimiter
    assert_matches "$CURRENT_SUITE_TESTCASES" "^<testCase" || return

    # Cleanup
    JUNIT_OUTPUT=false
    CURRENT_SUITE_TESTCASES=""

    pass_test
}

test_junit_testcase_accumulation_multiple_entries() {
    start_test "Multiple testcases are pipe-delimited"

    # Enable JUnit and reset accumulator
    JUNIT_OUTPUT=true
    CURRENT_SUITE_TESTCASES=""
    TEST_START_TIME=$(date +%s.%N 2>/dev/null || date +%s)

    current_test="test_one"
    _add_junit_testcase "pass"

    current_test="test_two"
    _add_junit_testcase "pass"

    # Should contain pipe delimiter between entries
    assert_contains "$CURRENT_SUITE_TESTCASES" "|" "Should have pipe delimiter" || return
    assert_contains "$CURRENT_SUITE_TESTCASES" "test_one" || return
    assert_contains "$CURRENT_SUITE_TESTCASES" "test_two" || return

    # Cleanup
    JUNIT_OUTPUT=false
    CURRENT_SUITE_TESTCASES=""

    pass_test
}

# Test different testcase status types
test_junit_testcase_pass_format() {
    start_test "Pass testcase has correct XML format"

    JUNIT_OUTPUT=true
    CURRENT_SUITE_TESTCASES=""
    current_test="passing_test"
    TEST_START_TIME=$(date +%s.%N 2>/dev/null || date +%s)

    _add_junit_testcase "pass"

    # Should be self-closing testCase element
    assert_matches "$CURRENT_SUITE_TESTCASES" '<testCase name="passing_test" duration="[0-9]+"/>' || return

    JUNIT_OUTPUT=false
    CURRENT_SUITE_TESTCASES=""

    pass_test
}

test_junit_testcase_fail_format() {
    start_test "Fail testcase includes failure element"

    JUNIT_OUTPUT=true
    CURRENT_SUITE_TESTCASES=""
    current_test="failing_test"
    TEST_START_TIME=$(date +%s.%N 2>/dev/null || date +%s)

    _add_junit_testcase "fail" "Test failed because of X"

    assert_contains "$CURRENT_SUITE_TESTCASES" "<failure" || return
    assert_contains "$CURRENT_SUITE_TESTCASES" "Test failed because of X" || return
    assert_contains "$CURRENT_SUITE_TESTCASES" "</testCase>" || return

    JUNIT_OUTPUT=false
    CURRENT_SUITE_TESTCASES=""

    pass_test
}

test_junit_testcase_skip_format() {
    start_test "Skip testcase includes skipped element"

    JUNIT_OUTPUT=true
    CURRENT_SUITE_TESTCASES=""
    current_test="skipped_test"
    TEST_START_TIME=$(date +%s.%N 2>/dev/null || date +%s)

    _add_junit_testcase "skip" "Missing dependency"

    assert_contains "$CURRENT_SUITE_TESTCASES" "<skipped" || return
    assert_contains "$CURRENT_SUITE_TESTCASES" "Missing dependency" || return
    assert_contains "$CURRENT_SUITE_TESTCASES" "</testCase>" || return

    JUNIT_OUTPUT=false
    CURRENT_SUITE_TESTCASES=""

    pass_test
}

test_junit_testcase_unknown_status() {
    start_test "Unknown status produces error element"

    JUNIT_OUTPUT=true
    CURRENT_SUITE_TESTCASES=""
    current_test="unknown_status_test"
    TEST_START_TIME=$(date +%s.%N 2>/dev/null || date +%s)

    _add_junit_testcase "invalid_status"

    assert_contains "$CURRENT_SUITE_TESTCASES" "<error" || return
    assert_contains "$CURRENT_SUITE_TESTCASES" "Unknown status" || return

    JUNIT_OUTPUT=false
    CURRENT_SUITE_TESTCASES=""

    pass_test
}

# Test special character escaping in testcase names and messages
test_junit_testcase_escapes_special_chars_in_name() {
    start_test "Testcase escapes special characters in name"

    JUNIT_OUTPUT=true
    CURRENT_SUITE_TESTCASES=""
    current_test="test with <special> & \"chars\""
    TEST_START_TIME=$(date +%s.%N 2>/dev/null || date +%s)

    _add_junit_testcase "pass"

    assert_contains "$CURRENT_SUITE_TESTCASES" "&lt;special&gt;" || return
    assert_contains "$CURRENT_SUITE_TESTCASES" "&amp;" || return
    assert_contains "$CURRENT_SUITE_TESTCASES" "&quot;chars&quot;" || return

    JUNIT_OUTPUT=false
    CURRENT_SUITE_TESTCASES=""

    pass_test
}

test_junit_testcase_escapes_special_chars_in_message() {
    start_test "Testcase escapes special characters in failure message"

    JUNIT_OUTPUT=true
    CURRENT_SUITE_TESTCASES=""
    current_test="test_failure"
    TEST_START_TIME=$(date +%s.%N 2>/dev/null || date +%s)

    _add_junit_testcase "fail" "Expected <foo> & got \"bar\""

    assert_contains "$CURRENT_SUITE_TESTCASES" "&lt;foo&gt;" || return
    assert_contains "$CURRENT_SUITE_TESTCASES" "&amp;" || return
    assert_contains "$CURRENT_SUITE_TESTCASES" "&quot;bar&quot;" || return

    JUNIT_OUTPUT=false
    CURRENT_SUITE_TESTCASES=""

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

# Run all tests
test_junit_xml_escape_ampersand
test_junit_xml_escape_less_than
test_junit_xml_escape_greater_than
test_junit_xml_escape_single_quote
test_junit_xml_escape_double_quote
test_junit_xml_escape_multiple_special_chars
test_junit_xml_escape_preserves_normal_text
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
test_junit_flag_creates_output_file
test_junit_output_has_valid_xml_structure
test_junit_output_contains_test_results
