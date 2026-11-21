#!/usr/bin/env bash
#
# test_log_levels.sh - Tests for log level functionality
#
# Tests:
# - Log level constants are defined correctly
# - Log level filtering works properly
# - All log level functions work
# - get_log_level_value and get_log_level_name work correctly

# Test: Log level constants are defined
test_log_level_constants() {
    start_test "Log level constants are defined"

    [[ $LOG_LEVEL_EMERGENCY -eq 0 ]] || { fail_test "EMERGENCY should be 0"; return; }
    [[ $LOG_LEVEL_ALERT -eq 1 ]] || { fail_test "ALERT should be 1"; return; }
    [[ $LOG_LEVEL_CRITICAL -eq 2 ]] || { fail_test "CRITICAL should be 2"; return; }
    [[ $LOG_LEVEL_ERROR -eq 3 ]] || { fail_test "ERROR should be 3"; return; }
    [[ $LOG_LEVEL_WARN -eq 4 ]] || { fail_test "WARN should be 4"; return; }
    [[ $LOG_LEVEL_NOTICE -eq 5 ]] || { fail_test "NOTICE should be 5"; return; }
    [[ $LOG_LEVEL_INFO -eq 6 ]] || { fail_test "INFO should be 6"; return; }
    [[ $LOG_LEVEL_DEBUG -eq 7 ]] || { fail_test "DEBUG should be 7"; return; }

    pass_test
}

# Test: FATAL is alias for EMERGENCY
test_fatal_alias() {
    start_test "FATAL is alias for EMERGENCY"

    assert_equals "$LOG_LEVEL_EMERGENCY" "$LOG_LEVEL_FATAL" || return

    pass_test
}

# Test: _get_log_level_value function (internal)
test_get_log_level_value() {
    start_test "get_log_level_value converts names to numbers"

    assert_equals "0" "$(_get_log_level_value "EMERGENCY")" || return
    assert_equals "1" "$(_get_log_level_value "ALERT")" || return
    assert_equals "2" "$(_get_log_level_value "CRITICAL")" || return
    assert_equals "3" "$(_get_log_level_value "ERROR")" || return
    assert_equals "4" "$(_get_log_level_value "WARN")" || return
    assert_equals "5" "$(_get_log_level_value "NOTICE")" || return
    assert_equals "6" "$(_get_log_level_value "INFO")" || return
    assert_equals "7" "$(_get_log_level_value "DEBUG")" || return

    # Test case insensitivity
    assert_equals "6" "$(_get_log_level_value "info")" || return
    assert_equals "3" "$(_get_log_level_value "ErRoR")" || return

    # Test FATAL alias
    assert_equals "0" "$(_get_log_level_value "FATAL")" || return

    pass_test
}

# Test: _get_log_level_value with numbers (internal)
test_get_log_level_value_numeric() {
    start_test "get_log_level_value accepts numeric values"

    assert_equals "0" "$(_get_log_level_value "0")" || return
    assert_equals "3" "$(_get_log_level_value "3")" || return
    assert_equals "7" "$(_get_log_level_value "7")" || return

    pass_test
}

# Test: _get_log_level_name function (internal)
test_get_log_level_name() {
    start_test "get_log_level_name converts numbers to names"

    assert_equals "EMERGENCY" "$(_get_log_level_name 0)" || return
    assert_equals "ALERT" "$(_get_log_level_name 1)" || return
    assert_equals "CRITICAL" "$(_get_log_level_name 2)" || return
    assert_equals "ERROR" "$(_get_log_level_name 3)" || return
    assert_equals "WARN" "$(_get_log_level_name 4)" || return
    assert_equals "NOTICE" "$(_get_log_level_name 5)" || return
    assert_equals "INFO" "$(_get_log_level_name 6)" || return
    assert_equals "DEBUG" "$(_get_log_level_name 7)" || return

    pass_test
}

# Test: Log filtering - DEBUG level allows all messages
test_log_filtering_debug() {
    start_test "DEBUG level allows all log messages"

    init_logger --level DEBUG --quiet
    local log_file="$TEST_DIR/test.log"
    LOG_FILE="$log_file"

    log_debug "Debug message"
    log_info "Info message"
    log_warn "Warn message"
    log_error "Error message"

    assert_file_contains "$log_file" "Debug message" || return
    assert_file_contains "$log_file" "Info message" || return
    assert_file_contains "$log_file" "Warn message" || return
    assert_file_contains "$log_file" "Error message" || return

    pass_test
}

# Test: Log filtering - INFO level filters DEBUG
test_log_filtering_info() {
    start_test "INFO level filters out DEBUG messages"

    init_logger --level INFO --quiet
    local log_file="$TEST_DIR/test.log"
    LOG_FILE="$log_file"

    log_debug "Debug message"
    log_info "Info message"
    log_warn "Warn message"
    log_error "Error message"

    assert_file_not_contains "$log_file" "Debug message" || return
    assert_file_contains "$log_file" "Info message" || return
    assert_file_contains "$log_file" "Warn message" || return
    assert_file_contains "$log_file" "Error message" || return

    pass_test
}

# Test: Log filtering - ERROR level filters INFO and WARN
test_log_filtering_error() {
    start_test "ERROR level filters out INFO and WARN"

    init_logger --level ERROR --quiet
    local log_file="$TEST_DIR/test.log"
    LOG_FILE="$log_file"

    log_debug "Debug message"
    log_info "Info message"
    log_warn "Warn message"
    log_error "Error message"
    log_critical "Critical message"

    assert_file_not_contains "$log_file" "Debug message" || return
    assert_file_not_contains "$log_file" "Info message" || return
    assert_file_not_contains "$log_file" "Warn message" || return
    assert_file_contains "$log_file" "Error message" || return
    assert_file_contains "$log_file" "Critical message" || return

    pass_test
}

# Test: All log level functions exist and work
test_all_log_functions() {
    start_test "All log level functions work"

    init_logger --level DEBUG --quiet
    local log_file="$TEST_DIR/test.log"
    LOG_FILE="$log_file"

    log_emergency "Emergency message"
    log_alert "Alert message"
    log_critical "Critical message"
    log_error "Error message"
    log_warn "Warn message"
    log_notice "Notice message"
    log_info "Info message"
    log_debug "Debug message"
    log_fatal "Fatal message"  # Alias test

    assert_file_contains "$log_file" "Emergency message" || return
    assert_file_contains "$log_file" "Alert message" || return
    assert_file_contains "$log_file" "Critical message" || return
    assert_file_contains "$log_file" "Error message" || return
    assert_file_contains "$log_file" "Warn message" || return
    assert_file_contains "$log_file" "Notice message" || return
    assert_file_contains "$log_file" "Info message" || return
    assert_file_contains "$log_file" "Debug message" || return
    assert_file_contains "$log_file" "Fatal message" || return

    pass_test
}

# Test: Log level appears in output
test_log_level_in_output() {
    start_test "Log level name appears in output"

    init_logger --level DEBUG --quiet
    local log_file="$TEST_DIR/test.log"
    LOG_FILE="$log_file"

    log_info "Test message"
    log_error "Error message"
    log_debug "Debug message"

    assert_file_contains "$log_file" "[INFO]" || return
    assert_file_contains "$log_file" "[ERROR]" || return
    assert_file_contains "$log_file" "[DEBUG]" || return

    pass_test
}

# Test: Verbose mode enables DEBUG
test_verbose_enables_debug() {
    start_test "Verbose mode enables DEBUG level"

    init_logger --verbose --quiet
    local log_file="$TEST_DIR/test.log"
    # shellcheck disable=SC2034
    LOG_FILE="$log_file"

    log_debug "Debug in verbose mode"

    assert_file_contains "$log_file" "Debug in verbose mode" || return

    pass_test
}

# Test: _get_syslog_priority function (internal)
test_get_syslog_priority() {
    start_test "get_syslog_priority returns correct priorities"

    assert_equals "emerg" "$(_get_syslog_priority 0)" || return
    assert_equals "alert" "$(_get_syslog_priority 1)" || return
    assert_equals "crit" "$(_get_syslog_priority 2)" || return
    assert_equals "err" "$(_get_syslog_priority 3)" || return
    assert_equals "warning" "$(_get_syslog_priority 4)" || return
    assert_equals "notice" "$(_get_syslog_priority 5)" || return
    assert_equals "info" "$(_get_syslog_priority 6)" || return
    assert_equals "debug" "$(_get_syslog_priority 7)" || return

    pass_test
}

# Test: log_init function works
test_log_init_function() {
    start_test "log_init function logs with INIT level"

    init_logger --level DEBUG --quiet
    local log_file="$TEST_DIR/test.log"
    # shellcheck disable=SC2034
    LOG_FILE="$log_file"

    log_init "Initialization message"

    assert_file_contains "$log_file" "Initialization message" || return
    assert_file_contains "$log_file" "INIT" || return

    pass_test
}

# Test: --level falls back to INFO with a warning for an invalid name (Issue #192)
test_init_invalid_level_warns() {
    start_test "init_logger --level warns when an invalid name falls back to INFO"

    init_logger --quiet --level DEBUG
    init_logger --quiet --level WARNNING 2>"$TEST_STDERR"

    assert_equals 0 "$?" "An invalid level should still return 0" || return
    assert_equals "$LOG_LEVEL_INFO" "$CURRENT_LOG_LEVEL" "Fallback should be INFO" || return
    assert_file_contains "$TEST_STDERR" "Warning: Invalid log level 'WARNNING' for --level, using INFO" || return
    assert_file_contains "$TEST_STDERR" "Hint: Valid levels are: DEBUG, INFO" || return

    pass_test
}

# Test: --stderr-level falls back to INFO with a warning for an invalid name (Issue #192)
test_init_invalid_stderr_level_warns() {
    start_test "init_logger --stderr-level warns when an invalid name falls back to INFO"

    init_logger --quiet -e bogus 2>"$TEST_STDERR"

    assert_equals 0 "$?" "An invalid level should still return 0" || return
    assert_equals "$LOG_LEVEL_INFO" "$LOG_STDERR_LEVEL" "Fallback should be INFO" || return
    assert_file_contains "$TEST_STDERR" "Warning: Invalid log level 'BOGUS' for -e, using INFO" || return

    pass_test
}

# Test: set_log_level falls back to INFO with a warning for an invalid name (Issue #192)
test_set_log_level_invalid_warns() {
    start_test "set_log_level warns when an invalid name falls back to INFO"

    init_logger --quiet --level DEBUG
    set_log_level WARNNING 2>"$TEST_STDERR"

    assert_equals 0 "$?" "An invalid level should still return 0" || return
    assert_equals "$LOG_LEVEL_INFO" "$CURRENT_LOG_LEVEL" "Fallback should be INFO" || return
    assert_file_contains "$TEST_STDERR" "Warning: Invalid log level 'WARNNING' for set_log_level, using INFO" || return

    pass_test
}

# Test: an escape sequence in a rejected level name cannot reach the terminal
test_invalid_level_warning_is_sanitized() {
    start_test "The invalid level warning does not pass control characters through"

    local escape_char=""
    escape_char=$(printf '\033')

    set_log_level "bad${escape_char}[31mred" 2>"$TEST_STDERR" >/dev/null

    assert_file_contains "$TEST_STDERR" "Warning: Invalid log level" || return
    assert_file_not_contains "$TEST_STDERR" "$escape_char" || return

    pass_test
}

# Test: valid names, aliases and numbers print no warning (Issue #192)
test_valid_levels_print_no_warning() {
    start_test "Valid level names and numbers print no warning"

    local level_name=""
    for level_name in DEBUG info Notice WARN warning ERR crit ALERT fatal 0 7; do
        init_logger --quiet --level "$level_name" --stderr-level "$level_name" 2>"$TEST_STDERR"
        assert_file_not_contains "$TEST_STDERR" "Invalid log level" "$level_name via init_logger" || return
        set_log_level "$level_name" 2>"$TEST_STDERR" >/dev/null
        assert_file_not_contains "$TEST_STDERR" "Invalid log level" "$level_name via set_log_level" || return
    done

    pass_test
}

# Run all tests
test_log_level_constants
test_fatal_alias
test_get_log_level_value
test_get_log_level_value_numeric
test_get_log_level_name
test_log_filtering_debug
test_log_filtering_info
test_log_filtering_error
test_all_log_functions
test_log_level_in_output
test_verbose_enables_debug
test_get_syslog_priority
test_log_init_function
test_init_invalid_level_warns
test_init_invalid_stderr_level_warns
test_set_log_level_invalid_warns
test_invalid_level_warning_is_sanitized
test_valid_levels_print_no_warning
