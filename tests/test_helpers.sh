#!/usr/bin/env bash
#
# test_helpers.sh - Helper functions for testing bash-logger
#
# This file provides assertion functions and test utilities
# for the bash-logger test suite.

# Test counters (managed by run_tests.sh)
suite_tests=0
suite_passed=0
suite_failed=0
suite_skipped=0

# Current test name
current_test=""

# Temporary directory for test files
TEST_TMP_DIR=""

# Setup function - called before each test suite
setup_test_suite() {
    # Create temporary directory
    TEST_TMP_DIR="$(mktemp -d -t bash-logger-tests.XXXXXX)"
    export TEST_TMP_DIR
}

# Cleanup function - called after each test suite
cleanup_test_suite() {
    if [[ -n "${TEST_TMP_DIR:-}" && -d "$TEST_TMP_DIR" ]]; then
        rm -rf "$TEST_TMP_DIR"
    fi
}

# Setup function - called before each test
setup_test() {
    # Reset logging module state by re-sourcing
    # shellcheck source=../logging.sh disable=SC1091
    source "$PROJECT_ROOT/logging.sh"

    # Create test-specific temp directory
    TEST_DIR="$TEST_TMP_DIR/$(date +%s%N)"
    mkdir -p "$TEST_DIR"

    # Redirect stderr/stdout to files for capturing
    TEST_STDOUT="$TEST_DIR/stdout"
    TEST_STDERR="$TEST_DIR/stderr"
    export TEST_STDOUT TEST_STDERR
}

# Teardown function - called after each test
teardown_test() {
    local test_failed="${1:-0}"
    # Clean up test directory if it exists
    if [[ -n "${TEST_DIR:-}" && -d "$TEST_DIR" ]]; then
        # Keep it around for debugging if test failed
        if [[ "$test_failed" -ne 0 ]]; then
            echo "Test artifacts in: $TEST_DIR" >&2
        fi
    fi
}

# Start a new test
start_test() {
    local test_name="$1"
    current_test="$test_name"
    suite_tests=$((suite_tests + 1))
    # Record test start time for JUnit
    TEST_START_TIME=$(date +%s.%N 2>/dev/null || date +%s)
    setup_test
}

# XML escape helper for JUnit output
_junit_xml_escape() {
    local str="$1"
    # Use sed for reliable XML entity escaping
    # Order matters: & must be escaped first
    printf '%s' "$str" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e "s/'/\&apos;/g" -e 's/"/\&quot;/g'
}

# Calculate test duration
_get_test_duration() {
    local end_time
    end_time=$(date +%s.%N 2>/dev/null || date +%s)
    echo "$end_time - ${TEST_START_TIME:-$end_time}" | bc 2>/dev/null || echo "0"
}

# Add testcase to SonarQube Generic Test Execution report
_add_junit_testcase() {
    local status="$1"
    local message="${2:-}"
    local duration_sec duration_ms
    duration_sec=$(_get_test_duration)
    # Convert to milliseconds (integer) for SonarQube
    duration_ms=$(echo "($duration_sec * 1000)/1" | bc 2>/dev/null || echo "0")
    local escaped_name
    escaped_name=$(_junit_xml_escape "$current_test")

    local testcase

    case "$status" in
        pass)
            testcase="<testCase name=\"$escaped_name\" duration=\"$duration_ms\"/>"
            ;;
        fail)
            local escaped_msg
            escaped_msg=$(_junit_xml_escape "$message")
            testcase="<testCase name=\"$escaped_name\" duration=\"$duration_ms\"><failure message=\"$escaped_msg\"/></testCase>"
            ;;
        skip)
            local escaped_msg
            escaped_msg=$(_junit_xml_escape "$message")
            testcase="<testCase name=\"$escaped_name\" duration=\"$duration_ms\"><skipped message=\"$escaped_msg\"/></testCase>"
            ;;
    esac

    # Append to current suite's testcases (pipe-delimited)
    if [[ -n "${CURRENT_SUITE_TESTCASES:-}" ]]; then
        CURRENT_SUITE_TESTCASES+="|$testcase"
    else
        CURRENT_SUITE_TESTCASES="$testcase"
    fi
}

# Record test result
pass_test() {
    suite_passed=$((suite_passed + 1))
    echo "  ✓ $current_test"

    # Record for JUnit if enabled
    if [[ "${JUNIT_OUTPUT:-false}" == "true" ]]; then
        _add_junit_testcase "pass"
    fi

    teardown_test 0
}

fail_test() {
    local message="$1"
    suite_failed=$((suite_failed + 1))
    echo "  ✗ $current_test"
    echo "    Reason: $message"

    # Store for summary
    FAILED_TEST_DETAILS+=("$current_test: $message")

    # Record for JUnit if enabled
    if [[ "${JUNIT_OUTPUT:-false}" == "true" ]]; then
        _add_junit_testcase "fail" "$message"
    fi

    teardown_test 1
}

skip_test() {
    local reason="$1"
    suite_skipped=$((suite_skipped + 1))
    echo "  ⊘ $current_test (skipped: $reason)"

    # Record for JUnit if enabled
    if [[ "${JUNIT_OUTPUT:-false}" == "true" ]]; then
        _add_junit_testcase "skip" "$reason"
    fi

    teardown_test 0
}

# Assertion functions
# shellcheck disable=SC2016

# Assert that two values are equal
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Expected '$expected' but got '$actual'}"

    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        fail_test "$message"
        return 1
    fi
}

# Assert that two values are not equal
assert_not_equals() {
    local unexpected="$1"
    local actual="$2"
    local message="${3:-Expected value different from '$unexpected' but got '$actual'}"

    if [[ "$unexpected" != "$actual" ]]; then
        return 0
    else
        fail_test "$message"
        return 1
    fi
}

# Assert that a string contains a substring
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Expected to find '$needle' in '$haystack'}"

    if [[ "$haystack" == *"$needle"* ]]; then
        return 0
    else
        fail_test "$message"
        return 1
    fi
}

# Assert that a string does not contain a substring
assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Did not expect to find '$needle' in '$haystack'}"

    if [[ "$haystack" != *"$needle"* ]]; then
        return 0
    else
        fail_test "$message"
        return 1
    fi
}

# Assert that a string matches a regex pattern
assert_matches() {
    local string="$1"
    local pattern="$2"
    local message="${3:-Expected '$string' to match pattern '$pattern'}"

    if [[ "$string" =~ $pattern ]]; then
        return 0
    else
        fail_test "$message"
        return 1
    fi
}

# Assert that a file exists
assert_file_exists() {
    local file="$1"
    local message="${2:-Expected file '$file' to exist}"

    if [[ -f "$file" ]]; then
        return 0
    else
        fail_test "$message"
        return 1
    fi
}

# Assert that a file does not exist
assert_file_not_exists() {
    local file="$1"
    local message="${2:-Expected file '$file' to not exist}"

    if [[ ! -f "$file" ]]; then
        return 0
    else
        fail_test "$message"
        return 1
    fi
}

# Assert that a file contains a string
assert_file_contains() {
    local file="$1"
    local needle="$2"
    local message="${3:-Expected file '$file' to contain '$needle'}"

    if [[ ! -f "$file" ]]; then
        fail_test "File '$file' does not exist"
        return 1
    fi

    if grep -qF "$needle" "$file"; then
        return 0
    else
        fail_test "$message"
        return 1
    fi
}

# Assert that a file does not contain a string
assert_file_not_contains() {
    local file="$1"
    local needle="$2"
    local message="${3:-Expected file '$file' to not contain '$needle'}"

    if [[ ! -f "$file" ]]; then
        fail_test "File '$file' does not exist"
        return 1
    fi

    if ! grep -qF "$needle" "$file"; then
        return 0
    else
        fail_test "$message"
        return 1
    fi
}

# Assert that a file is empty
assert_file_empty() {
    local file="$1"
    local message="${2:-Expected file '$file' to be empty}"

    if [[ ! -f "$file" ]]; then
        fail_test "File '$file' does not exist"
        return 1
    fi

    if [[ ! -s "$file" ]]; then
        return 0
    else
        fail_test "$message (size: $(wc -c < "$file") bytes)"
        return 1
    fi
}

# Assert that a file is not empty
assert_file_not_empty() {
    local file="$1"
    local message="${2:-Expected file '$file' to not be empty}"

    if [[ ! -f "$file" ]]; then
        fail_test "File '$file' does not exist"
        return 1
    fi

    if [[ -s "$file" ]]; then
        return 0
    else
        fail_test "$message"
        return 1
    fi
}

# Assert that a command succeeds (exit code 0)
assert_success() {
    local command="$*"

    if eval "$command" >/dev/null 2>&1; then
        return 0
    else
        fail_test "Expected command to succeed: $command"
        return 1
    fi
}

# Assert that a command fails (non-zero exit code)
assert_failure() {
    local command="$*"

    if ! eval "$command" >/dev/null 2>&1; then
        return 0
    else
        fail_test "Expected command to fail: $command"
        return 1
    fi
}

# Helper function to capture output from a function/command
capture_output() {
    local output_var="$1"
    shift
    local output
    # shellcheck disable=SC2034
    output="$("$@" 2>&1)"
    eval "$output_var=\"\$output\""
}

# Helper function to capture stdout and stderr separately
capture_streams() {
    local stdout_var="$1"
    local stderr_var="$2"
    shift 2

    local stdout_file stderr_file
    stdout_file="$(mktemp)"
    stderr_file="$(mktemp)"

    "$@" >"$stdout_file" 2>"$stderr_file" || true

    eval "$stdout_var=\"\$(cat '$stdout_file')\""
    eval "$stderr_var=\"\$(cat '$stderr_file')\""

    rm -f "$stdout_file" "$stderr_file"
}

# Helper to run a subshell with logging module
run_with_logger() {
    bash -c "
        source '$PROJECT_ROOT/logging.sh'
        $*
    "
}

# Helper to run script and capture its output
run_script() {
    local script="$1"
    bash "$script"
}

# Setup test suite on source
if [[ -z "${TEST_TMP_DIR:-}" ]]; then
    setup_test_suite
fi
