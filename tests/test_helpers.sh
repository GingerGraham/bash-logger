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

# Create a unique empty file whose name ends in a suffix, and print its path.
# Arguments: name prefix (including directory), suffix such as .sh
# BSD mktemp (macOS) only randomizes Xs at the very end of the template, so a template
# like name_XXXXXX.sh would create a file with that literal name and fail on the second
# call. Create the file without the suffix, then rename it.
make_temp_file_with_suffix() {
    local name_prefix="$1" suffix="$2" base_file
    base_file=$(mktemp "${name_prefix}XXXXXX") || return 1
    if ! mv "$base_file" "${base_file}${suffix}"; then
        rm -f "$base_file"
        return 1
    fi
    echo "${base_file}${suffix}"
}

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
    # mktemp gives a unique name on GNU and BSD systems; date +%s%N does not on macOS
    TEST_DIR=$(mktemp -d "$TEST_TMP_DIR/test.XXXXXX")

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

# Print the current time in seconds, with a fractional part where date supports %N.
# BSD date (macOS) accepts %N but prints a literal N, which breaks the bc arithmetic,
# so the output is checked and whole seconds are used when it is not a number.
_get_timestamp() {
    local now
    now=$(date +%s.%N 2>/dev/null)
    if [[ "$now" =~ ^[0-9]+\.[0-9]+$ ]]; then
        echo "$now"
    else
        date +%s
    fi
}

# Start a new test
start_test() {
    local test_name="$1"
    current_test="$test_name"
    suite_tests=$((suite_tests + 1))
    # Record test start time for JUnit
    TEST_START_TIME=$(_get_timestamp)
    setup_test
}

# XML escape helper for JUnit output
_junit_xml_escape() {
    local str="$1"
    # XML 1.0 forbids control characters other than tab (\011), newline (\012) and
    # carriage return (\015). Failure messages can contain raw ANSI escape bytes (\033),
    # which make SonarQube reject the whole report, so strip them before escaping.
    # Use sed for reliable XML entity escaping
    # Order matters: & must be escaped first
    printf '%s' "$str" \
        | LC_ALL=C tr -d '\000-\010\013\014\016-\037' \
        | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e "s/'/\&apos;/g" -e 's/"/\&quot;/g'
}

# Calculate test duration
_get_test_duration() {
    local end_time
    end_time=$(_get_timestamp)
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
        *)
            # Fallback for unexpected status values to keep XML consistent
            local escaped_status
            escaped_status=$(_junit_xml_escape "$status")
            testcase="<testCase name=\"$escaped_name\" duration=\"$duration_ms\"><error message=\"Unknown status: $escaped_status\"/></testCase>"
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

# Run a snippet with logging.sh sourced, under the given shell command.
# The shell command may include flags, e.g. "bash --posix".
# Usage: run_with_logger_in_shell "zsh" "init_logger --quiet; log_info hi"
run_with_logger_in_shell() {
    local shell_command="$1"
    shift
    # shellcheck disable=SC2086  # word splitting of shell_command is intended
    $shell_command -c ". '$PROJECT_ROOT/logging.sh'; $*"
}

# Skip the current test if a shell is not installed, unless it is required.
# TEST_REQUIRE_SHELLS is a space-separated list of shells that must be present
# (set in CI so cross-shell tests fail rather than silently skip).
# Returns 0 if the shell is available; otherwise records a skip or failure and
# returns 1, so callers use: require_shell zsh || return 0
# (return 0, not a bare return: the result is already recorded, and a non-zero
# status from the last test in a suite is reported by the runner as a crash)
require_shell() {
    local shell_name="$1"
    if command -v "$shell_name" >/dev/null 2>&1; then
        return 0
    fi
    case " ${TEST_REQUIRE_SHELLS:-} " in
        *" $shell_name "*)
            fail_test "$shell_name is required (TEST_REQUIRE_SHELLS) but not installed"
            ;;
        *)
            skip_test "$shell_name not installed"
            ;;
    esac
    return 1
}

# Print the shell commands from TEST_SHELLS, one per line (Issue #143).
# Commas separate commands, so a command can include flags:
#   TEST_SHELLS="bash,bash --posix,zsh,dash,busybox sh"
# Without commas, each word is a command. Default: bash
test_shell_list() {
    local shell_list="${TEST_SHELLS:-bash}"
    case "$shell_list" in
        *,*)
            printf '%s\n' "$shell_list" | tr ',' '\n'
            ;;
        *)
            printf '%s\n' "$shell_list" | tr ' ' '\n'
            ;;
    esac | sed -e 's/^ *//' -e 's/ *$//' -e '/^$/d'
}

# Return 0 if a shell command runs logging.sh with character-based string
# operations (bash and zsh); dash and busybox ash work on bytes
shell_counts_characters() {
    case "${1%% *}" in
        bash|zsh) return 0 ;;
    esac
    return 1
}

# Run a command, stopping it after a number of seconds.
# macOS has no timeout command, so this uses a background watchdog.
# The watchdog's output goes to /dev/null so it never holds the runner's pipes open.
run_with_timeout() {
    local seconds="$1"
    shift
    "$@" &
    local command_pid=$!
    ( sleep "$seconds" && kill -TERM "$command_pid" ) >/dev/null 2>&1 &
    local watchdog_pid=$!
    wait "$command_pid"
    local command_status=$?
    kill "$watchdog_pid" >/dev/null 2>&1
    wait "$watchdog_pid" 2>/dev/null
    return "$command_status"
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
