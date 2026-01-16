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

# Test: get_log_level_value function
test_get_log_level_value() {
    start_test "get_log_level_value converts names to numbers"

    assert_equals "0" "$(get_log_level_value "EMERGENCY")" || return
    assert_equals "1" "$(get_log_level_value "ALERT")" || return
    assert_equals "2" "$(get_log_level_value "CRITICAL")" || return
    assert_equals "3" "$(get_log_level_value "ERROR")" || return
    assert_equals "4" "$(get_log_level_value "WARN")" || return
    assert_equals "5" "$(get_log_level_value "NOTICE")" || return
    assert_equals "6" "$(get_log_level_value "INFO")" || return
    assert_equals "7" "$(get_log_level_value "DEBUG")" || return

    # Test case insensitivity
    assert_equals "6" "$(get_log_level_value "info")" || return
    assert_equals "3" "$(get_log_level_value "ErRoR")" || return

    # Test FATAL alias
    assert_equals "0" "$(get_log_level_value "FATAL")" || return

    pass_test
}

# Test: get_log_level_value with numbers
test_get_log_level_value_numeric() {
    start_test "get_log_level_value accepts numeric values"

    assert_equals "0" "$(get_log_level_value "0")" || return
    assert_equals "3" "$(get_log_level_value "3")" || return
    assert_equals "7" "$(get_log_level_value "7")" || return

    pass_test
}

# Test: get_log_level_name function
test_get_log_level_name() {
    start_test "get_log_level_name converts numbers to names"

    assert_equals "EMERGENCY" "$(get_log_level_name 0)" || return
    assert_equals "ALERT" "$(get_log_level_name 1)" || return
    assert_equals "CRITICAL" "$(get_log_level_name 2)" || return
    assert_equals "ERROR" "$(get_log_level_name 3)" || return
    assert_equals "WARN" "$(get_log_level_name 4)" || return
    assert_equals "NOTICE" "$(get_log_level_name 5)" || return
    assert_equals "INFO" "$(get_log_level_name 6)" || return
    assert_equals "DEBUG" "$(get_log_level_name 7)" || return

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

# Test: get_syslog_priority function
test_get_syslog_priority() {
    start_test "get_syslog_priority returns correct priorities"

    assert_equals "emerg" "$(get_syslog_priority 0)" || return
    assert_equals "alert" "$(get_syslog_priority 1)" || return
    assert_equals "crit" "$(get_syslog_priority 2)" || return
    assert_equals "err" "$(get_syslog_priority 3)" || return
    assert_equals "warning" "$(get_syslog_priority 4)" || return
    assert_equals "notice" "$(get_syslog_priority 5)" || return
    assert_equals "info" "$(get_syslog_priority 6)" || return
    assert_equals "debug" "$(get_syslog_priority 7)" || return

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
