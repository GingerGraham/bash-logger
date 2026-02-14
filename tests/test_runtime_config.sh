#!/usr/bin/env bash
#
# test_runtime_config.sh - Tests for runtime configuration changes
#
# Tests:
# - set_log_level function
# - set_log_format function
# - set_timezone_utc function
# - set_journal_logging function
# - set_journal_tag function
# - set_color_mode function

# Test: set_log_level changes level at runtime
test_set_log_level() {
    start_test "set_log_level changes log level"

    init_logger --level INFO --quiet
    local log_file="$TEST_DIR/level_change.log"
    LOG_FILE="$log_file"

    log_debug "Should not appear"

    set_log_level DEBUG

    log_debug "Should appear"

    assert_file_not_contains "$log_file" "Should not appear" || return
    assert_file_contains "$log_file" "Should appear" || return

    pass_test
}

# Test: set_log_level with string
test_set_log_level_string() {
    start_test "set_log_level accepts level names"

    init_logger --quiet

    set_log_level ERROR
    assert_equals "$LOG_LEVEL_ERROR" "$CURRENT_LOG_LEVEL" || return

    set_log_level WARN
    assert_equals "$LOG_LEVEL_WARN" "$CURRENT_LOG_LEVEL" || return

    set_log_level INFO
    assert_equals "$LOG_LEVEL_INFO" "$CURRENT_LOG_LEVEL" || return

    pass_test
}

# Test: set_log_level with number
test_set_log_level_number() {
    start_test "set_log_level accepts numeric values"

    init_logger --quiet

    set_log_level 3
    assert_equals "$LOG_LEVEL_ERROR" "$CURRENT_LOG_LEVEL" || return

    set_log_level 7
    assert_equals "$LOG_LEVEL_DEBUG" "$CURRENT_LOG_LEVEL" || return

    pass_test
}

# Test: set_log_format changes format at runtime
test_set_log_format() {
    start_test "set_log_format changes log format"

    init_logger --quiet
    local log_file="$TEST_DIR/format_change.log"
    LOG_FILE="$log_file"

    log_info "Default format"

    set_log_format "%l: %m"

    log_info "New format"

    # First line should have brackets
    assert_file_contains "$log_file" "[INFO]" || return

    # Second line should have colon
    assert_file_contains "$log_file" "INFO: New format" || return

    pass_test
}

# Test: set_log_format persists
test_set_log_format_persists() {
    start_test "set_log_format persists for all subsequent logs"

    init_logger --quiet
    local log_file="$TEST_DIR/format_persist.log"
    LOG_FILE="$log_file"

    set_log_format "%m"

    log_info "First"
    log_warn "Second"
    log_error "Third"

    local content
    content=$(cat "$log_file")

    # Should just be the messages, no formatting
    assert_contains "$content" "First" || return
    assert_contains "$content" "Second" || return
    assert_contains "$content" "Third" || return

    # Should NOT contain level markers
    assert_not_contains "$content" "[INFO]" || return
    assert_not_contains "$content" "[WARN]" || return
    assert_not_contains "$content" "[ERROR]" || return

    pass_test
}

# Test: set_timezone_utc function
test_set_timezone_utc() {
    start_test "set_timezone_utc changes timezone"

    init_logger --quiet --format "%z"
    local log_file="$TEST_DIR/tz_change.log"
    LOG_FILE="$log_file"

    log_info "Local"

    set_timezone_utc true

    log_info "UTC"

    assert_file_contains "$log_file" "LOCAL" || return
    assert_file_contains "$log_file" "UTC" || return

    pass_test
}

# Test: set_timezone_utc with false
test_set_timezone_local() {
    start_test "set_timezone_utc can switch back to local"

    init_logger --quiet --utc --format "%z"
    local log_file="$TEST_DIR/tz_local.log"
    LOG_FILE="$log_file"

    log_info "UTC"

    set_timezone_utc false

    log_info "Local"

    assert_file_contains "$log_file" "UTC" || return
    assert_file_contains "$log_file" "LOCAL" || return

    pass_test
}

# Test: set_journal_logging function
test_set_journal_logging() {
    start_test "set_journal_logging changes journal setting"

    if ! check_logger_available; then
        skip_test "logger command not available"
        return
    fi

    init_logger --journal
    assert_equals "true" "$USE_JOURNAL" || return

    set_journal_logging false
    assert_equals "false" "$USE_JOURNAL" || return

    set_journal_logging true
    assert_equals "true" "$USE_JOURNAL" || return

    pass_test
}

# Test: set_journal_tag function
test_set_journal_tag() {
    start_test "set_journal_tag changes tag"

    init_logger

    set_journal_tag "app1"
    assert_equals "app1" "$JOURNAL_TAG" || return

    set_journal_tag "app2"
    assert_equals "app2" "$JOURNAL_TAG" || return

    pass_test
}

# Test: set_color_mode function
test_set_color_mode() {
    start_test "set_color_mode changes color setting"

    init_logger

    set_color_mode always
    assert_equals "always" "$USE_COLORS" || return

    set_color_mode never
    assert_equals "never" "$USE_COLORS" || return

    set_color_mode auto
    assert_equals "auto" "$USE_COLORS" || return

    pass_test
}

# Test: Multiple runtime changes
test_multiple_runtime_changes() {
    start_test "Multiple runtime changes work together"

    init_logger --quiet
    local log_file="$TEST_DIR/multiple_changes.log"
    LOG_FILE="$log_file"

    set_log_level ERROR
    log_info "Not logged"
    log_error "Error 1"

    set_log_level INFO
    set_log_format "%m"
    log_info "Info message"

    set_log_format "[%l] %m"
    log_warn "Warning"

    # Check results
    assert_file_not_contains "$log_file" "Not logged" || return
    assert_file_contains "$log_file" "Error 1" || return
    assert_file_contains "$log_file" "Info message" || return
    assert_file_contains "$log_file" "[WARN] Warning" || return

    pass_test
}

# Test: Runtime changes don't affect previous logs
test_runtime_changes_dont_affect_history() {
    start_test "Runtime changes don't retroactively change logs"

    init_logger --quiet
    local log_file="$TEST_DIR/history.log"
    LOG_FILE="$log_file"

    log_info "Message 1"

    set_log_format "%m only"

    # Read the log file
    local content
    content=$(cat "$log_file")

    # First message should still have original format
    assert_contains "$content" "[INFO]" || return

    pass_test
}

# Test: set_log_level with verbose behavior
test_set_log_level_verbose_interaction() {
    start_test "set_log_level works with verbose mode"

    init_logger --verbose --quiet
    local log_file="$TEST_DIR/verbose_level.log"
    LOG_FILE="$log_file"

    # Verbose sets DEBUG
    assert_equals "$LOG_LEVEL_DEBUG" "$CURRENT_LOG_LEVEL" || return

    log_debug "Debug message"

    # Change level at runtime
    set_log_level ERROR

    log_debug "Should not appear"
    log_error "Should appear"

    assert_file_contains "$log_file" "Debug message" || return
    assert_file_not_contains "$log_file" "Should not appear" || return
    assert_file_contains "$log_file" "Should appear" || return

    pass_test
}

# Test: set_log_format with empty format
test_set_log_format_empty() {
    start_test "set_log_format accepts empty format"

    init_logger --quiet
    local log_file="$TEST_DIR/empty_format.log"
    LOG_FILE="$log_file"

    log_info "Normal"

    set_log_format ""

    log_info "Empty format"

    # First log should have content
    assert_file_contains "$log_file" "Normal" || return

    # File should exist and have content from first log
    assert_file_exists "$log_file" || return

    pass_test
}

# Test: Runtime config in subshells
test_runtime_config_isolation() {
    start_test "Runtime config changes are isolated to current shell"

    local log_file="$TEST_DIR/isolation.log"

    # Parent process
    (
        source "$PROJECT_ROOT/logging.sh"
        init_logger --quiet
        LOG_FILE="$log_file"
        set_log_level ERROR
        log_info "Parent info"  # Should not log
        log_error "Parent error"  # Should log
    )

    # New process should have default level
    (
        source "$PROJECT_ROOT/logging.sh"
        init_logger --quiet
        # shellcheck disable=SC2034
        LOG_FILE="$log_file"
        log_info "Child info"  # Should log (default is INFO)
    )

    assert_file_not_contains "$log_file" "Parent info" || return
    assert_file_contains "$log_file" "Parent error" || return
    assert_file_contains "$log_file" "Child info" || return

    pass_test
}

# Test: Invalid level name handling
test_set_log_level_invalid() {
    start_test "set_log_level handles invalid level gracefully"

    init_logger --level INFO

    # Try to set invalid level
    set_log_level "INVALID" 2>/dev/null || true

    # Level should remain valid (either unchanged or set to some default)
    # shellcheck disable=SC2031
    [[ $CURRENT_LOG_LEVEL -ge 0 && $CURRENT_LOG_LEVEL -le 7 ]] || {
        fail_test "Log level should remain valid after invalid input"
        return
    }

    pass_test
}

# Test: set_script_name function
test_set_script_name() {
    start_test "set_script_name changes script name"

    init_logger --name "original"

    assert_equals "original" "$SCRIPT_NAME" || return

    set_script_name "new-name"

    assert_equals "new-name" "$SCRIPT_NAME" || return

    pass_test
}

# Test: set_script_name affects log output
test_set_script_name_in_output() {
    start_test "set_script_name affects log output"

    init_logger --quiet --name "first-name" --format "[%s] %m"
    local log_file="$TEST_DIR/script_name_change.log"
    LOG_FILE="$log_file"

    log_info "First message"

    set_script_name "second-name"

    log_info "Second message"

    assert_file_contains "$log_file" "[first-name] First message" || return
    assert_file_contains "$log_file" "[second-name] Second message" || return

    pass_test
}

# Test: set_script_name multiple changes
test_set_script_name_multiple() {
    start_test "set_script_name can be called multiple times"

    init_logger

    set_script_name "name1"
    assert_equals "name1" "$SCRIPT_NAME" || return

    set_script_name "name2"
    assert_equals "name2" "$SCRIPT_NAME" || return

    set_script_name "name3"
    assert_equals "name3" "$SCRIPT_NAME" || return

    pass_test
}

# Test: set_script_name with empty string
test_set_script_name_empty() {
    start_test "set_script_name accepts empty string"

    init_logger --name "test"

    set_script_name ""

    assert_equals "" "$SCRIPT_NAME" || return

    pass_test
}

# Test: set_script_name logs config change
test_set_script_name_logs_change() {
    start_test "set_script_name logs the configuration change"

    init_logger --quiet
    local log_file="$TEST_DIR/script_name_config.log"
    LOG_FILE="$log_file"

    set_script_name "new-script"

    # The config change message should be in the log
    assert_file_contains "$log_file" "Script name changed" || return
    assert_file_contains "$log_file" "new-script" || return

    pass_test
}

# Test: set_journal_logging fails when logger unavailable
test_set_journal_logging_no_logger() {
    start_test "set_journal_logging fails gracefully when logger unavailable"

    # Skip if logger is available
    if check_logger_available; then
        skip_test "logger command is available"
        return
    fi

    init_logger --quiet 2>/dev/null

    set_journal_logging true 2>"$TEST_STDERR"
    local exit_code=$?

    # Should fail or warn
    assert_not_equals 0 "$exit_code" "Should return non-zero when logger unavailable" || return
    assert_file_contains "$TEST_STDERR" "logger command not found" || return

    pass_test
}

# Test: set_journal_tag with journal logging
test_set_journal_tag_runtime() {
    start_test "set_journal_tag changes tag during runtime"

    init_logger --quiet
    local log_file="$TEST_DIR/tag_change.log"
    LOG_FILE="$log_file"

    set_journal_tag "initial-tag"

    log_info "First message"

    set_journal_tag "updated-tag"

    log_info "Second message"

    # Config changes should be logged
    assert_file_contains "$log_file" "Journal tag" || return

    pass_test
}

# Test: set_unsafe_allow_newlines function
test_set_unsafe_allow_newlines() {
    start_test "set_unsafe_allow_newlines changes setting"

    init_logger --quiet

    set_unsafe_allow_newlines true
    assert_equals "true" "$LOG_UNSAFE_ALLOW_NEWLINES" || return

    set_unsafe_allow_newlines false
    assert_equals "false" "$LOG_UNSAFE_ALLOW_NEWLINES" || return

    pass_test
}

# Test: set_unsafe_allow_ansi_codes function
test_set_unsafe_allow_ansi_codes() {
    start_test "set_unsafe_allow_ansi_codes changes setting"

    init_logger --quiet

    set_unsafe_allow_ansi_codes true
    assert_equals "true" "$LOG_UNSAFE_ALLOW_ANSI_CODES" || return

    set_unsafe_allow_ansi_codes false
    assert_equals "false" "$LOG_UNSAFE_ALLOW_ANSI_CODES" || return

    pass_test
}

# Run all tests
test_set_log_level
test_set_log_level_string
test_set_log_level_number
test_set_log_format
test_set_log_format_persists
test_set_timezone_utc
test_set_timezone_local
test_set_journal_logging
test_set_journal_tag
test_set_color_mode
test_multiple_runtime_changes
test_runtime_changes_dont_affect_history
test_set_log_level_verbose_interaction
test_set_log_format_empty
test_runtime_config_isolation
test_set_log_level_invalid
test_set_script_name
test_set_script_name_in_output
test_set_script_name_multiple
test_set_script_name_empty
test_set_script_name_logs_change
test_set_journal_logging_no_logger
test_set_journal_tag_runtime
test_set_unsafe_allow_newlines
test_set_unsafe_allow_ansi_codes
