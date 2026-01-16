#!/usr/bin/env bash
#
# test_output.sh - Tests for output functionality
#
# Tests:
# - Console output
# - File output
# - Stdout/stderr stream separation
# - Color output

# Test: Console output enabled by default
test_console_output_default() {
    start_test "Console output is enabled by default"

    local output
    output=$(bash -c "
        source '$PROJECT_ROOT/logging.sh'
        init_logger
        log_info 'Console test'
    " 2>&1)

    assert_contains "$output" "Console test" || return

    pass_test
}

# Test: Console output can be disabled
test_console_output_quiet() {
    start_test "Quiet mode disables console output"

    local output
    output=$(bash -c "
        source '$PROJECT_ROOT/logging.sh'
        init_logger --quiet
        log_info 'Should not appear'
    " 2>&1)

    assert_not_contains "$output" "Should not appear" || return

    pass_test
}

# Test: File output works
test_file_output() {
    start_test "Log messages are written to file"

    init_logger --quiet
    local log_file="$TEST_DIR/output.log"
    LOG_FILE="$log_file"

    log_info "File test message"
    log_error "Error in file"

    assert_file_exists "$log_file" || return
    assert_file_contains "$log_file" "File test message" || return
    assert_file_contains "$log_file" "Error in file" || return

    pass_test
}

# Test: Both console and file output
test_console_and_file() {
    start_test "Console and file output work together"

    local log_file="$TEST_DIR/both.log"
    local output
    output=$(bash -c "
        source '$PROJECT_ROOT/logging.sh'
        init_logger --log '$log_file'
        log_info 'Dual output test'
    " 2>&1)

    assert_contains "$output" "Dual output test" "Should appear in console" || return
    assert_file_exists "$log_file" || return
    assert_file_contains "$log_file" "Dual output test" "Should appear in file" || return

    pass_test
}

# Test: Stderr routing for errors
test_stderr_routing_error() {
    start_test "ERROR messages go to stderr by default"

    local stdout stderr

    bash -c "
        source '$PROJECT_ROOT/logging.sh'
        init_logger
        log_error 'Error message'
    " >"$TEST_DIR/stdout" 2>"$TEST_DIR/stderr"

    stdout=$(cat "$TEST_DIR/stdout")
    stderr=$(cat "$TEST_DIR/stderr")

    assert_not_contains "$stdout" "Error message" "Should not be in stdout" || return
    assert_contains "$stderr" "Error message" "Should be in stderr" || return

    pass_test
}

# Test: Stdout routing for info
test_stdout_routing_info() {
    start_test "INFO messages go to stdout by default"

    local stdout stderr

    bash -c "
        source '$PROJECT_ROOT/logging.sh'
        init_logger
        log_info 'Info message'
    " >"$TEST_DIR/stdout" 2>"$TEST_DIR/stderr"

    stdout=$(cat "$TEST_DIR/stdout")
    stderr=$(cat "$TEST_DIR/stderr")

    assert_contains "$stdout" "Info message" "Should be in stdout" || return
    assert_not_contains "$stderr" "Info message" "Should not be in stderr" || return

    pass_test
}

# Test: Custom stderr level
test_custom_stderr_level() {
    start_test "Custom stderr level threshold works"

    local stdout stderr

    bash -c "
        source '$PROJECT_ROOT/logging.sh'
        init_logger --stderr-level WARN
        log_info 'Info message'
        log_warn 'Warn message'
        log_error 'Error message'
    " >"$TEST_DIR/stdout" 2>"$TEST_DIR/stderr"

    stdout=$(cat "$TEST_DIR/stdout")
    stderr=$(cat "$TEST_DIR/stderr")

    # INFO (6) should go to stdout (> WARN=4)
    assert_contains "$stdout" "Info message" || return

    # WARN (4) and ERROR (3) should go to stderr (<= WARN=4)
    assert_contains "$stderr" "Warn message" || return
    assert_contains "$stderr" "Error message" || return

    pass_test
}

# Test: All errors go to stderr
test_all_severity_levels_stderr() {
    start_test "High severity messages go to stderr"

    local stderr

    bash -c "
        source '$PROJECT_ROOT/logging.sh'
        init_logger
        log_emergency 'Emergency'
        log_alert 'Alert'
        log_critical 'Critical'
        log_error 'Error'
    " 2>"$TEST_DIR/stderr" >/dev/null

    stderr=$(cat "$TEST_DIR/stderr")

    assert_contains "$stderr" "Emergency" || return
    assert_contains "$stderr" "Alert" || return
    assert_contains "$stderr" "Critical" || return
    assert_contains "$stderr" "Error" || return

    pass_test
}

# Test: File output preserves all messages regardless of stream
test_file_output_all_levels() {
    start_test "File output includes all log levels"

    local log_file="$TEST_DIR/all_levels.log"

    bash -c "
        source '$PROJECT_ROOT/logging.sh'
        init_logger --log '$log_file' --quiet --level DEBUG
        log_debug 'Debug'
        log_info 'Info'
        log_warn 'Warn'
        log_error 'Error'
    "

    assert_file_contains "$log_file" "Debug" || return
    assert_file_contains "$log_file" "Info" || return
    assert_file_contains "$log_file" "Warn" || return
    assert_file_contains "$log_file" "Error" || return

    pass_test
}

# Test: Color output in auto mode
test_color_auto_terminal() {
    start_test "Color defaults to auto mode"

    # Default should be auto
    init_logger

    assert_equals "auto" "$USE_COLORS" || return

    pass_test
}

# Test: Color never mode
test_color_never() {
    start_test "Color never mode disables colors"

    local output
    output=$(bash -c "
        source '$PROJECT_ROOT/logging.sh'
        init_logger --color never
        log_error 'No color error'
    " 2>&1)

    # Should not contain ANSI escape codes
    if [[ "$output" =~ $'\033'\\[ ]]; then
        fail_test "Output contains ANSI escape codes"
        return
    fi

    pass_test
}

# Test: Color always mode (skip if ANSI codes not in output - depends on terminal)
test_color_always() {
    start_test "Color always mode forces colors"

    init_logger --color always

    assert_equals "always" "$USE_COLORS" || return

    pass_test
}

# Test: Multiple messages to same file
test_multiple_messages_file() {
    start_test "Multiple messages append to log file"

    init_logger --quiet
    local log_file="$TEST_DIR/multiple.log"
    # shellcheck disable=SC2034
    LOG_FILE="$log_file"

    log_info "Message 1"
    log_info "Message 2"
    log_info "Message 3"

    local line_count
    line_count=$(wc -l < "$log_file")

    [[ $line_count -eq 3 ]] || {
        fail_test "Expected 3 lines, got $line_count"
        return
    }

    pass_test
}

# Test: Log file permissions
test_log_file_permissions() {
    start_test "Log file is created with correct permissions"

    local log_file="$TEST_DIR/perms.log"

    bash -c "
        source '$PROJECT_ROOT/logging.sh'
        init_logger --log '$log_file' --quiet
        log_info 'Permission test'
    "

    assert_file_exists "$log_file" || return

    # File should be readable and writable by owner
    [[ -r "$log_file" && -w "$log_file" ]] || {
        fail_test "Log file should be readable and writable"
        return
    }

    pass_test
}

# Test: Empty message handling
test_empty_message() {
    start_test "Empty messages are handled gracefully"

    local log_file="$TEST_DIR/empty.log"

    bash -c "
        source '$PROJECT_ROOT/logging.sh'
        init_logger --log '$log_file' --quiet
        log_info ''
        log_info 'Not empty'
    "

    # File should exist and contain the non-empty message
    assert_file_exists "$log_file" || return
    assert_file_contains "$log_file" "Not empty" || return

    pass_test
}

# Test: Multiline message handling
test_multiline_message() {
    start_test "Multiline messages are logged correctly"

    local log_file="$TEST_DIR/multiline.log"

    bash -c "
        source '$PROJECT_ROOT/logging.sh'
        init_logger --log '$log_file' --quiet
        log_info 'Line 1
Line 2
Line 3'
    "

    assert_file_exists "$log_file" || return
    assert_file_contains "$log_file" "Line 1" || return
    assert_file_contains "$log_file" "Line 2" || return
    assert_file_contains "$log_file" "Line 3" || return

    pass_test
}

# Test: Special characters in message
test_special_characters() {
    start_test "Special characters are logged correctly"

    local log_file="$TEST_DIR/special.log"

    bash -c "
        source '$PROJECT_ROOT/logging.sh'
        init_logger --log '$log_file' --quiet
        log_info 'Special: \$VAR @#\$% & | > <'
    "

    assert_file_exists "$log_file" || return
    assert_file_contains "$log_file" "Special:" || return

    pass_test
}

# Run all tests
test_console_output_default
test_console_output_quiet
test_file_output
test_console_and_file
test_stderr_routing_error
test_stdout_routing_info
test_custom_stderr_level
test_all_severity_levels_stderr
test_file_output_all_levels
test_color_auto_terminal
test_color_never
test_color_always
test_multiple_messages_file
test_log_file_permissions
test_empty_message
test_multiline_message
test_special_characters
