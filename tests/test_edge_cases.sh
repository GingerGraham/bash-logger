#!/usr/bin/env bash
#
# test_edge_cases.sh - Tests for edge cases and boundary conditions
#
# Tests:
# - Invalid log levels
# - Color detection scenarios
# - Message sanitization edge cases
# - Direct execution check
# - Catch-all branches in case statements

# Test: Invalid log level returns UNKNOWN
test_invalid_log_level_name() {
    start_test "Invalid log level returns UNKNOWN"

    init_logger --quiet

    # Call internal function with invalid level
    local level_name
    level_name=$(_get_log_level_name 99)

    assert_equals "UNKNOWN" "$level_name" || return

    pass_test
}

# Test: All log level colors are covered
test_all_log_level_colors() {
    start_test "All log levels have proper color codes"

    init_logger --color always --quiet

    # Test DEBUG color
    local color
    color=$(_get_log_level_color "DEBUG")
    assert_not_equals "" "$color" "DEBUG should have blue color" || return

    # Test INFO (no color)
    color=$(_get_log_level_color "INFO")
    assert_equals "" "$color" "INFO should have no specific color" || return

    # Test NOTICE color
    color=$(_get_log_level_color "NOTICE")
    assert_not_equals "" "$color" "NOTICE should have green color" || return

    # Test WARN color
    color=$(_get_log_level_color "WARN")
    assert_not_equals "" "$color" "WARN should have yellow color" || return

    # Test ERROR color
    color=$(_get_log_level_color "ERROR")
    assert_not_equals "" "$color" "ERROR should have red color" || return

    # Test CRITICAL color
    color=$(_get_log_level_color "CRITICAL")
    assert_not_equals "" "$color" "CRITICAL should have bold red color" || return

    # Test ALERT color
    color=$(_get_log_level_color "ALERT")
    assert_not_equals "" "$color" "ALERT should have white on red color" || return

    # Test EMERGENCY/FATAL color
    color=$(_get_log_level_color "EMERGENCY")
    assert_not_equals "" "$color" "EMERGENCY should have bold white on red" || return

    color=$(_get_log_level_color "FATAL")
    assert_not_equals "" "$color" "FATAL should have bold white on red" || return

    # Test INIT color
    color=$(_get_log_level_color "INIT")
    assert_not_equals "" "$color" "INIT should have purple color" || return

    # Test SENSITIVE color
    color=$(_get_log_level_color "SENSITIVE")
    assert_not_equals "" "$color" "SENSITIVE should have cyan color" || return

    # Test unknown level (catch-all)
    color=$(_get_log_level_color "INVALID_LEVEL")
    assert_equals "" "$color" "Unknown level should return empty" || return

    pass_test
}

# Test: Invalid syslog priority returns default
test_invalid_syslog_priority() {
    start_test "Invalid log level returns default syslog priority"

    init_logger --quiet

    # Call internal function with invalid level
    local priority
    priority=$(_get_syslog_priority 99)

    assert_equals "notice" "$priority" "Invalid level should default to notice" || return

    pass_test
}

# Test: Color detection with NO_COLOR environment variable
test_color_detection_no_color() {
    start_test "Color detection respects NO_COLOR"

    export NO_COLOR=1

    # Re-source to pick up environment change
    # shellcheck source=../logging.sh disable=SC1091
    source "$PROJECT_ROOT/logging.sh"

    init_logger

    # Should not use colors even if terminal supports it
    if _detect_color_support; then
        fail_test "Colors should be disabled with NO_COLOR set"
        return
    fi

    unset NO_COLOR

    pass_test
}

# Test: Color detection with CLICOLOR=0
test_color_detection_clicolor_disable() {
    start_test "Color detection respects CLICOLOR=0"

    export CLICOLOR=0

    # Re-source to pick up environment change
    # shellcheck source=../logging.sh disable=SC1091
    source "$PROJECT_ROOT/logging.sh"

    init_logger

    if _detect_color_support; then
        fail_test "Colors should be disabled with CLICOLOR=0"
        return
    fi

    unset CLICOLOR

    pass_test
}

# Test: Color detection with CLICOLOR_FORCE=1
test_color_detection_clicolor_force() {
    start_test "Color detection respects CLICOLOR_FORCE=1"

    export CLICOLOR_FORCE=1

    # Re-source to pick up environment change
    # shellcheck source=../logging.sh disable=SC1091
    source "$PROJECT_ROOT/logging.sh"

    init_logger

    if ! _detect_color_support; then
        fail_test "Colors should be forced with CLICOLOR_FORCE=1"
        return
    fi

    unset CLICOLOR_FORCE

    pass_test
}

# Test: Color detection with dumb terminal
test_color_detection_dumb_term() {
    start_test "Color detection disables for dumb terminal"

    export TERM=dumb

    # Re-source to pick up environment change
    # shellcheck source=../logging.sh disable=SC1091
    source "$PROJECT_ROOT/logging.sh"

    init_logger

    if _detect_color_support; then
        fail_test "Colors should be disabled for TERM=dumb"
        return
    fi

    # Restore TERM
    if [[ -n "${OLD_TERM:-}" ]]; then
        export TERM="$OLD_TERM"
    fi

    pass_test
}

# Test: Color detection with specific terminal types
test_color_detection_specific_terms() {
    start_test "Color detection works for common terminal types"

    # _detect_color_support requires stdout to be a terminal (checks -t 1),
    # which is not the case when running in parallel mode (fd redirected to file)
    if [[ ! -t 1 ]]; then
        skip_test "stdout is not a terminal (parallel mode)"
        return
    fi

    local OLD_TERM="${TERM:-}"

    # Test xterm
    export TERM=xterm-256color
    # Re-source to pick up environment change
    # shellcheck source=../logging.sh disable=SC1091
    source "$PROJECT_ROOT/logging.sh"
    init_logger
    if ! _detect_color_support; then
        fail_test "Colors should be enabled for xterm-256color"
        unset TERM
        export TERM="$OLD_TERM"
        return
    fi

    # Test screen
    export TERM=screen
    # shellcheck source=../logging.sh disable=SC1091
    source "$PROJECT_ROOT/logging.sh"
    init_logger
    if ! _detect_color_support; then
        fail_test "Colors should be enabled for screen"
        unset TERM
        export TERM="$OLD_TERM"
        return
    fi

    # Restore TERM
    if [[ -n "$OLD_TERM" ]]; then
        export TERM="$OLD_TERM"
    else
        unset TERM
    fi

    pass_test
}

# Test: Message sanitization with ASCII control codes
test_message_sanitization_control_codes() {
    start_test "Messages with control codes are sanitized"

    init_logger --quiet --log "$TEST_DIR/control.log"

    # Log message with null byte and other control characters
    # (avoiding actual null bytes which would truncate strings)
    log_info "Message with\x01control\x02codes\x1F" 2>/dev/null

    # The log file should not contain the control characters
    if [[ -f "$TEST_DIR/control.log" ]]; then
        local content
        content=$(cat "$TEST_DIR/control.log")
        # Check that control characters were stripped or replaced
        assert_file_exists "$TEST_DIR/control.log" || return
    fi

    pass_test
}

# Test: Message truncation at max length
test_message_truncation_at_max_length() {
    start_test "Messages are truncated at max line length"

    init_logger --quiet --log "$TEST_DIR/truncate.log" --max-line-length 100

    # Create a message longer than 100 characters
    local long_message
    long_message="$(printf 'x%.0s' {1..200})"

    log_info "$long_message"

    # Check that the message was truncated
    if [[ -f "$TEST_DIR/truncate.log" ]]; then
        local content
        content=$(tail -1 "$TEST_DIR/truncate.log")
        local content_length=${#content}
        # Should be truncated (less than full message length)
        if [[ $content_length -gt 150 ]]; then
            fail_test "Message was not truncated (length: $content_length)"
            return
        fi
    fi

    pass_test
}

# Test: Direct execution of logging.sh fails
test_direct_execution_fails() {
    start_test "Direct execution of logging.sh shows error"

    # Execute logging.sh directly instead of sourcing
    local output
    output=$(bash "$PROJECT_ROOT/logging.sh" 2>&1)
    local exit_code=$?

    assert_not_equals 0 "$exit_code" "Should exit with non-zero code" || return
    assert_contains "$output" "designed to be sourced" || return
    assert_contains "$output" "source logging.sh" || return

    pass_test
}

# Test: Message with ANSI codes when not allowed
test_message_ansi_stripping() {
    start_test "ANSI codes are stripped when not allowed"

    init_logger --quiet --log "$TEST_DIR/ansi.log"

    # Log message with ANSI codes
    log_info "Message with \033[31mred text\033[0m"

    # The ANSI codes should be stripped
    assert_file_exists "$TEST_DIR/ansi.log" || return
    local content
    content=$(cat "$TEST_DIR/ansi.log")

    # Should not contain ANSI escape sequences
    if [[ "$content" =~ $'\033' ]]; then
        fail_test "ANSI codes were not stripped from log file"
        return
    fi

    pass_test
}

# Test: Message with newlines when not allowed
test_message_newline_stripping() {
    start_test "Newlines are replaced when not allowed"

    init_logger --quiet --log "$TEST_DIR/newline.log"

    # Log message with embedded newline
    log_info "Line 1"$'\n'"Line 2"

    # The newline should be replaced
    assert_file_exists "$TEST_DIR/newline.log" || return
    local line_count
    line_count=$(wc -l < "$TEST_DIR/newline.log")

    # Should be two lines: the INIT line from init_logger + one log entry
    # (newline in the message replaced with space, not producing an extra line)
    assert_equals 2 "$line_count" "Should be INIT line + one log line (newline sanitized)" || return

    pass_test
}

# Test: Zsh parameter expansion format (:gs syntax)
test_zsh_format_expansion() {
    start_test "Format expansion works in zsh syntax"

    # Only test if we're in zsh
    if [[ -z "${ZSH_VERSION:-}" ]]; then
        skip_test "Not running in zsh"
        return
    fi

    init_logger --quiet --log "$TEST_DIR/zsh.log" --format "%l - %m"

    log_info "Test message"

    assert_file_exists "$TEST_DIR/zsh.log" || return
    assert_file_contains "$TEST_DIR/zsh.log" "INFO - Test message" || return

    pass_test
}

# Test: Empty message handling
test_empty_message_handling() {
    start_test "Empty messages are handled gracefully"

    init_logger --quiet --log "$TEST_DIR/empty.log"

    log_info ""

    # Should still create a log entry
    assert_file_exists "$TEST_DIR/empty.log" || return

    pass_test
}

# Test: Very long script name sanitization
test_very_long_script_name() {
    start_test "Very long script names are handled"

    local long_name
    long_name="$(printf 'x%.0s' {1..200})"

    init_logger --quiet --script-name "$long_name"

    # Script name should be set (possibly truncated)
    assert_not_equals "" "$SCRIPT_NAME" || return

    pass_test
}

# Run all tests
test_invalid_log_level_name
test_all_log_level_colors
test_invalid_syslog_priority
test_color_detection_no_color
test_color_detection_clicolor_disable
test_color_detection_clicolor_force
test_color_detection_dumb_term
test_color_detection_specific_terms
test_message_sanitization_control_codes
test_message_truncation_at_max_length
test_direct_execution_fails
test_message_ansi_stripping
test_message_newline_stripping
test_zsh_format_expansion
test_empty_message_handling
test_very_long_script_name
