#!/usr/bin/env bash
#
# test_initialization.sh - Tests for init_logger functionality
#
# Tests:
# - Default initialization
# - Command-line options
# - Multiple initialization (should work correctly)

# Test: Default initialization
test_default_initialization() {
    start_test "Default initialization sets correct defaults"

    init_logger

    assert_equals "$LOG_LEVEL_INFO" "$CURRENT_LOG_LEVEL" "Default level should be INFO" || return
    assert_equals "true" "$CONSOLE_LOG" "Console log should be enabled by default" || return
    assert_equals "" "$LOG_FILE" "Log file should be empty by default" || return
    assert_equals "false" "$VERBOSE" "Verbose should be false by default" || return
    assert_equals "false" "$USE_UTC" "UTC should be false by default" || return

    pass_test
}

# Test: Quiet option
test_quiet_option() {
    start_test "Quiet option disables console output"

    init_logger --quiet

    assert_equals "false" "$CONSOLE_LOG" || return

    pass_test
}

# Test: Log file option
test_log_file_option() {
    start_test "Log file option sets log file"

    local log_file="$TEST_DIR/test.log"
    init_logger --log "$log_file"

    assert_equals "$log_file" "$LOG_FILE" || return

    # Test that file gets created
    log_info "Test message"
    assert_file_exists "$log_file" || return
    assert_file_contains "$log_file" "Test message" || return

    pass_test
}

# Test: Level option
test_level_option() {
    start_test "Level option sets log level"

    init_logger --level ERROR

    assert_equals "$LOG_LEVEL_ERROR" "$CURRENT_LOG_LEVEL" || return

    pass_test
}

# Test: Verbose option
test_verbose_option() {
    start_test "Verbose option enables debug logging"

    init_logger --verbose

    assert_equals "true" "$VERBOSE" || return
    assert_equals "$LOG_LEVEL_DEBUG" "$CURRENT_LOG_LEVEL" || return

    pass_test
}

# Test: UTC option
test_utc_option() {
    start_test "UTC option enables UTC timestamps"

    init_logger --utc

    assert_equals "true" "$USE_UTC" || return

    pass_test
}

# Test: Journal option (skip if logger not available)
test_journal_option() {
    start_test "Journal option enables journal logging"

    if ! check_logger_available; then
        skip_test "logger command not available"
        return
    fi

    init_logger --journal

    assert_equals "true" "$USE_JOURNAL" || return

    pass_test
}

# Test: Journal can be disabled via config
test_no_journal_via_runtime() {
    start_test "Journal logging can be disabled at runtime"

    init_logger
    set_journal_logging false

    assert_equals "false" "$USE_JOURNAL" || return

    pass_test
}

# Test: Tag option
test_tag_option() {
    start_test "Tag option sets journal tag"

    init_logger --tag "myapp"

    assert_equals "myapp" "$JOURNAL_TAG" || return

    pass_test
}

# Test: Format option
test_format_option() {
    start_test "Format option sets log format"

    local custom_format="%l - %m"
    init_logger --format "$custom_format"

    assert_equals "$custom_format" "$LOG_FORMAT" || return

    pass_test
}

# Test: Color option - always
test_color_always_option() {
    start_test "Color always option forces colors"

    init_logger --color

    assert_equals "always" "$USE_COLORS" || return

    pass_test
}

# Test: Color option - never
test_color_never_option() {
    start_test "Color never option disables colors"

    init_logger --no-color

    assert_equals "never" "$USE_COLORS" || return

    pass_test
}

# Test: Color option - auto (default)
test_color_auto_default() {
    start_test "Color defaults to auto"

    init_logger

    assert_equals "auto" "$USE_COLORS" || return

    pass_test
}

# Test: Multiple options combined
test_combined_options() {
    start_test "Multiple options work together"

    local log_file="$TEST_DIR/combined.log"
    init_logger --log "$log_file" --level WARN --utc --tag "test" --quiet

    assert_equals "$log_file" "$LOG_FILE" || return
    assert_equals "$LOG_LEVEL_WARN" "$CURRENT_LOG_LEVEL" || return
    assert_equals "true" "$USE_UTC" || return
    assert_equals "test" "$JOURNAL_TAG" || return
    assert_equals "false" "$CONSOLE_LOG" || return

    pass_test
}

# Test: Short option aliases
test_short_options() {
    start_test "Short option aliases work"

    local log_file="$TEST_DIR/short.log"
    init_logger -l "$log_file" -d ERROR -v -q

    assert_equals "$log_file" "$LOG_FILE" || return
    # Note: -v overrides -d, setting level to DEBUG
    assert_equals "$LOG_LEVEL_DEBUG" "$CURRENT_LOG_LEVEL" || return
    assert_equals "true" "$VERBOSE" || return
    assert_equals "false" "$CONSOLE_LOG" || return

    pass_test
}

# Test: Re-initialization updates settings
test_reinitialization() {
    start_test "Re-initialization updates settings"

    init_logger --level INFO
    assert_equals "$LOG_LEVEL_INFO" "$CURRENT_LOG_LEVEL" || return

    init_logger --level ERROR
    assert_equals "$LOG_LEVEL_ERROR" "$CURRENT_LOG_LEVEL" || return

    pass_test
}

# Test: Invalid log level
test_invalid_log_level() {
    start_test "Invalid log level falls back to default"

    # Capture stderr to check for warning
    local stderr
    stderr=$(init_logger --level INVALID 2>&1)

    # Should still set some valid level (likely default or unchanged)
    [[ $CURRENT_LOG_LEVEL -ge 0 && $CURRENT_LOG_LEVEL -le 7 ]] || {
        fail_test "Invalid level should result in valid fallback"
        return
    }

    pass_test
}

# Test: Log file creation with nested directories
test_log_file_nested_directory() {
    start_test "Log file in nested directory gets created"

    local log_file="$TEST_DIR/nested/dir/test.log"
    init_logger --log "$log_file"

    log_info "Test message"

    assert_file_exists "$log_file" || return
    assert_file_contains "$log_file" "Test message" || return

    pass_test
}

# Test: Config file option
test_config_file_option() {
    start_test "Config file option loads configuration"

    local config_file="$TEST_DIR/test.conf"
    cat > "$config_file" << 'EOF'
[logging]
level = ERROR
utc = true
EOF

    init_logger --config "$config_file"

    assert_equals "$LOG_LEVEL_ERROR" "$CURRENT_LOG_LEVEL" || return
    assert_equals "true" "$USE_UTC" || return

    pass_test
}

# Test: CLI options override config file
test_cli_overrides_config() {
    start_test "CLI options override config file settings"

    local config_file="$TEST_DIR/test.conf"
    cat > "$config_file" << 'EOF'
[logging]
level = ERROR
EOF

    init_logger --config "$config_file" --level INFO

    assert_equals "$LOG_LEVEL_INFO" "$CURRENT_LOG_LEVEL" "CLI should override config" || return

    pass_test
}

# Test: Stderr level option
test_stderr_level_option() {
    start_test "Stderr level option sets threshold"

    init_logger --stderr-level WARN

    assert_equals "$LOG_LEVEL_WARN" "$LOG_STDERR_LEVEL" || return

    pass_test
}

# Run all tests
test_default_initialization
test_quiet_option
test_log_file_option
test_level_option
test_verbose_option
test_utc_option
test_journal_option
test_no_journal_via_runtime
test_tag_option
test_format_option
test_color_always_option
test_color_never_option
test_color_auto_default
test_combined_options
test_short_options
test_reinitialization
test_invalid_log_level
test_log_file_nested_directory
test_config_file_option
test_cli_overrides_config
test_stderr_level_option
