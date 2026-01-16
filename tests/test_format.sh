#!/usr/bin/env bash
#
# test_format.sh - Tests for log message formatting
#
# Tests:
# - Default format
# - Custom formats with different placeholders
# - Format variables (%d, %l, %s, %m, %z)
# - UTC vs local time

# Test: Default format
test_default_format() {
    start_test "Default format is applied"

    init_logger --quiet
    local log_file="$TEST_DIR/format.log"
    LOG_FILE="$log_file"

    log_info "Test message"

    # Default format: "%d [%l] [%s] %m"
    # Should contain date, level, script name, and message
    assert_file_contains "$log_file" "[INFO]" || return
    assert_file_contains "$log_file" "Test message" || return

    # Should contain a date pattern (YYYY-MM-DD HH:MM:SS)
    local content
    content=$(cat "$log_file")
    assert_matches "$content" "[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}" || return

    pass_test
}

# Test: Custom format with message only
test_format_message_only() {
    start_test "Format with message only"

    init_logger --quiet --format "%m"
    local log_file="$TEST_DIR/msg_only.log"
    LOG_FILE="$log_file"

    log_info "Just the message"

    local content
    content=$(cat "$log_file")

    assert_equals "Just the message" "$content" || return

    pass_test
}

# Test: Format with level and message
test_format_level_message() {
    start_test "Format with level and message"

    init_logger --quiet --format "[%l] %m"
    local log_file="$TEST_DIR/level_msg.log"
    LOG_FILE="$log_file"

    log_warn "Warning message"

    assert_file_contains "$log_file" "[WARN] Warning message" || return

    pass_test
}

# Test: Format with all variables
test_format_all_variables() {
    start_test "Format with all variables"

    init_logger --quiet --format "%d %z [%l] [%s] %m"
    local log_file="$TEST_DIR/all_vars.log"
    LOG_FILE="$log_file"

    log_info "Complete format"

    local content
    content=$(cat "$log_file")

    # Should contain date
    assert_matches "$content" "[0-9]{4}-[0-9]{2}-[0-9]{2}" || return

    # Should contain timezone (LOCAL by default)
    assert_contains "$content" "LOCAL" || return

    # Should contain level
    assert_contains "$content" "[INFO]" || return

    # Should contain message
    assert_contains "$content" "Complete format" || return

    pass_test
}

# Test: UTC timezone in format
test_format_utc_timezone() {
    start_test "Format with UTC timezone"

    init_logger --quiet --utc --format "%d %z %m"
    local log_file="$TEST_DIR/utc.log"
    LOG_FILE="$log_file"

    log_info "UTC time test"

    assert_file_contains "$log_file" "UTC" || return

    pass_test
}

# Test: Local timezone in format
test_format_local_timezone() {
    start_test "Format with local timezone"

    init_logger --quiet --format "%d %z %m"
    local log_file="$TEST_DIR/local.log"
    LOG_FILE="$log_file"

    log_info "Local time test"

    assert_file_contains "$log_file" "LOCAL" || return

    pass_test
}

# Test: Script name in format
test_format_script_name() {
    start_test "Format includes script name"

    local log_file="$TEST_DIR/script_name.log"

    # Run in a named script
    cat > "$TEST_DIR/test_script.sh" << 'EOF'
#!/bin/bash
source "$1/logging.sh"
init_logger --quiet --format "[%s] %m"
LOG_FILE="$2"
log_info "From script"
EOF

    bash "$TEST_DIR/test_script.sh" "$PROJECT_ROOT" "$log_file"

    # Should contain the script name
    assert_file_contains "$log_file" "[test_script.sh]" || return

    pass_test
}

# Test: Custom format persists
test_format_persists() {
    start_test "Custom format persists across multiple logs"

    init_logger --quiet --format "%l: %m"
    local log_file="$TEST_DIR/persist.log"
    LOG_FILE="$log_file"

    log_info "First"
    log_warn "Second"
    log_error "Third"

    assert_file_contains "$log_file" "INFO: First" || return
    assert_file_contains "$log_file" "WARN: Second" || return
    assert_file_contains "$log_file" "ERROR: Third" || return

    pass_test
}

# Test: Format with literal text
test_format_literal_text() {
    start_test "Format can include literal text"

    init_logger --quiet --format "LOG | %l | %m"
    local log_file="$TEST_DIR/literal.log"
    LOG_FILE="$log_file"

    log_info "Test"

    assert_file_contains "$log_file" "LOG | INFO | Test" || return

    pass_test
}

# Test: Format without placeholders
test_format_no_placeholders() {
    start_test "Format without any placeholders"

    init_logger --quiet --format "static text"
    local log_file="$TEST_DIR/static.log"
    LOG_FILE="$log_file"

    log_info "Ignored"

    # Should just have the static text
    local content
    content=$(cat "$log_file")
    assert_equals "static text" "$content" || return

    pass_test
}

# Test: set_log_format function
test_set_log_format_function() {
    start_test "set_log_format changes format at runtime"

    init_logger --quiet
    local log_file="$TEST_DIR/set_format.log"
    LOG_FILE="$log_file"

    log_info "Original format"

    set_log_format "%l: %m"

    log_info "New format"

    # First message should have default format with brackets
    assert_file_contains "$log_file" "[INFO]" || return

    # Second message should have new format
    assert_file_contains "$log_file" "INFO: New format" || return

    pass_test
}

# Test: Date format in output
test_date_format() {
    start_test "Date format is YYYY-MM-DD HH:MM:SS"

    init_logger --quiet --format "%d %m"
    local log_file="$TEST_DIR/date_format.log"
    LOG_FILE="$log_file"

    log_info "Date test"

    local content
    content=$(cat "$log_file")

    # Match full date pattern
    assert_matches "$content" "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}" || return

    pass_test
}

# Test: Multiple format variables in different order
test_format_variable_order() {
    start_test "Format variables can be in any order"

    init_logger --quiet --format "%m | %l | %d"
    local log_file="$TEST_DIR/order.log"
    LOG_FILE="$log_file"

    log_warn "Message first"

    local content
    content=$(cat "$log_file")

    # Message should come first, then level
    assert_matches "$content" "^Message first.*WARN" || return

    pass_test
}

# Test: Duplicate format variables
test_format_duplicate_variables() {
    start_test "Format can have duplicate variables"

    init_logger --quiet --format "%l %m %l"
    local log_file="$TEST_DIR/duplicate.log"
    LOG_FILE="$log_file"

    log_info "Duplicate test"

    local content
    content=$(cat "$log_file")

    # Should have INFO at beginning and end
    assert_matches "$content" "^INFO.*INFO$" || return

    pass_test
}

# Test: Format with special characters
test_format_special_chars() {
    start_test "Format handles special characters"

    init_logger --quiet --format "[%l] >> %m <<"
    local log_file="$TEST_DIR/special.log"
    LOG_FILE="$log_file"

    log_info "Test"

    assert_file_contains "$log_file" "[INFO] >> Test <<" || return

    pass_test
}

# Test: Empty format string
test_format_empty() {
    start_test "Empty format string produces minimal output"

    init_logger --quiet --format ""
    local log_file="$TEST_DIR/empty_format.log"
    # shellcheck disable=SC2034
    LOG_FILE="$log_file"

    log_info "This won't show much"

    # Empty format will still write a newline
    assert_file_exists "$log_file" || return

    # Content should be minimal (just newline)
    local size
    size=$(wc -c < "$log_file")
    [[ $size -le 1 ]] || {
        fail_test "Expected minimal output, got $size bytes"
        return
    }

    pass_test
}

# Run all tests
test_default_format
test_format_message_only
test_format_level_message
test_format_all_variables
test_format_utc_timezone
test_format_local_timezone
test_format_script_name
test_format_persists
test_format_literal_text
test_format_no_placeholders
test_set_log_format_function
test_date_format
test_format_variable_order
test_format_duplicate_variables
test_format_special_chars
test_format_empty
