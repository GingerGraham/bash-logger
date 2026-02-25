#!/usr/bin/env bash
#
# test_example.sh - Example test suite for bash-logger contributors
#
# Copy this file as a starting point for a new test suite.
# Rename it to test_<feature>.sh and replace the example tests with your own.
#
# How this file is used:
#   The test runner (run_tests.sh) auto-discovers test_*.sh files in this
#   directory, but explicitly excludes test_example.sh and test_helpers.sh.
#   This file is a template and is only sourced when you request it, e.g.:
#       ./tests/run_tests.sh test_example
#
#   For real suites (your copied/renamed test_*.sh files), the runner sources
#   the file and each test function must be called explicitly at the bottom of
#   the file — defining the function is not enough.
#
# Run only this suite:
#   ./tests/run_tests.sh test_example
#
# Run the full suite:
#   ./tests/run_tests.sh
#
# Prerequisites provided by the runner before this file is sourced:
#   - test_helpers.sh is already sourced (start_test, pass_test, fail_test,
#     skip_test, and all assert_* functions are available)
#   - $PROJECT_ROOT points to the repository root
#   - $TEST_DIR is a unique per-test directory created by setup_test; use it
#     for all files your test reads or writes
#   - logging.sh is re-sourced before each test via start_test → setup_test,
#     so every test starts with fresh logger state
#
# See docs/writing-tests.md for a full contributor guide.
# See docs/testing.md for the complete assertion API reference.

# ---------------------------------------------------------------------------
# Example test 1: A message appears in the log file
#
# This is the most common pattern. When testing logging behaviour, point the
# logger at a file in $TEST_DIR and assert against that file's contents.
# ---------------------------------------------------------------------------
test_example_message_in_log_file() {
    # start_test registers the test with the runner, sets the display name used
    # in output and JUnit reports, and calls setup_test to re-source logging.sh
    # and create a fresh $TEST_DIR. Always the first line of a test function.
    start_test "Example: INFO message is written to the log file"

    # --quiet suppresses console output so test output stays clean.
    # --level DEBUG enables all severity levels for this test.
    init_logger --level DEBUG --quiet

    # Use a path under $TEST_DIR — it is unique per test and safe for parallel
    # runs. Never write to a fixed path like /tmp/test.log.
    local log_file="$TEST_DIR/example.log"

    # LOG_FILE tells the logger where to write. The logger creates the file on
    # the first log call. Set this after init_logger.
    LOG_FILE="$log_file"

    # Call the code under test exactly as a real script would.
    log_info "example info message"

    # assert_file_contains uses grep -F (fixed-string match, not a regex).
    # The || return is mandatory: if the assertion fails, it calls fail_test
    # and returns non-zero. || return exits this function immediately so that
    # execution does not continue past a failed assertion.
    assert_file_contains "$log_file" "example info message" || return

    # Also verify that the level label appears in the output.
    assert_file_contains "$log_file" "[INFO]" || return

    # pass_test records a success. If any || return above fired first,
    # pass_test is never reached — that is correct behaviour.
    pass_test
}

# ---------------------------------------------------------------------------
# Example test 2: Output goes to stderr, not stdout
#
# Use a subshell with explicit stream redirects when testing which file
# descriptor a message appears on. Write both streams to files under $TEST_DIR
# so you can use the same assert_file_contains style and inspect them on
# failure.
# ---------------------------------------------------------------------------
test_example_error_goes_to_stderr() {
    start_test "Example: ERROR messages go to stderr, not stdout"

    # Run the logger in a separate bash process so we can capture its streams
    # cleanly. $PROJECT_ROOT is exported by the runner and always available.
    bash -c "
        source '$PROJECT_ROOT/logging.sh'
        init_logger
        log_error 'example error message'
    " >"$TEST_DIR/stdout" 2>"$TEST_DIR/stderr"

    # The error message must appear on stderr.
    assert_file_contains "$TEST_DIR/stderr" "example error message" || return

    # It must not also appear on stdout.
    assert_file_not_contains "$TEST_DIR/stdout" "example error message" || return

    pass_test
}

# ---------------------------------------------------------------------------
# Example test 3: A configuration option is respected
#
# Test the observable effect of a flag, not the internal variable it sets.
# Here we verify that --level INFO causes DEBUG messages to be suppressed.
# ---------------------------------------------------------------------------
test_example_level_filtering() {
    start_test "Example: --level INFO suppresses DEBUG messages"

    init_logger --level INFO --quiet
    local log_file="$TEST_DIR/filtered.log"
    # shellcheck disable=SC2034
    LOG_FILE="$log_file"

    # This message is below the INFO threshold and must not be written.
    log_debug "debug message that should be filtered"

    # This message meets the threshold and must be written.
    log_info "info message that should appear"

    # Verify absence first — a wrong positive is a more dangerous failure.
    assert_file_not_contains "$log_file" "debug message that should be filtered" || return
    assert_file_contains     "$log_file" "info message that should appear"       || return

    pass_test
}

# ---------------------------------------------------------------------------
# Every test function defined above must be called here.
# The runner sources this file and relies on these calls to execute the tests.
# Defining a function without calling it means the test never runs.
# ---------------------------------------------------------------------------
test_example_message_in_log_file
test_example_error_goes_to_stderr
test_example_level_filtering
