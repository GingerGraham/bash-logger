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
#!/usr/bin/env bash
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

# Test: Custom format does not affect journal message content
# Journal output is the raw message; format templates are file/console-only.
test_format_does_not_affect_journal_output() {
    start_test "Custom format does not bleed into journal message content"

    local stub_capture="$TEST_DIR/journal_capture.txt"
    local stub_logger="$TEST_DIR/stub_logger.sh"
    cat > "$stub_logger" << 'STUB'
#!/usr/bin/env bash
echo "$*" >> "$STUB_CAPTURE_FILE"
STUB
    chmod +x "$stub_logger"

    local result
    # shellcheck disable=SC2034
    result=$(bash -c "
        export STUB_CAPTURE_FILE='$stub_capture'
        source '$PROJECT_ROOT/logging.sh'
        LOGGER_PATH='$stub_logger'; readonly LOGGER_PATH
        _find_and_validate_logger() { return 0; }
        check_logger_available() { return 0; }
        init_logger --no-color --quiet --format 'PREFIX: %l :: %m' --journal
        USE_JOURNAL='false'
        log_to_journal INFO 'journal_format_test_marker'
    " 2>&1)

    assert_file_exists "$stub_capture" \
        "Stub logger was not called" || return
    assert_file_contains "$stub_capture" "journal_format_test_marker" \
        "Journal message body not found in stub output" || return
    assert_file_not_contains "$stub_capture" "PREFIX:" \
        "Format template prefix should not appear in journal output" || return

    pass_test
}

# Test: %s token when script name sanitisation replaces all characters with underscores
test_format_script_name_token_sanitised_to_underscores() {
    start_test "Format %s token shows sanitised name when all chars are replaced with underscores"

    local log_file="$TEST_DIR/sanitised_name_format.log"
    init_logger --quiet --format "[%s] %m" --name $'$$$'

    # shellcheck disable=SC2034
    LOG_FILE="$log_file"
    log_info "sanitised name test"

    # The entry must still be written — the logger must not crash or skip the line
    assert_file_exists "$log_file" || return
    assert_file_contains "$log_file" "sanitised name test" || return

    # The %s token must expand to the sanitised script name ($$$ -> ___)
    assert_file_contains "$log_file" "[___]" \
        "%s token should show sanitised script name '___'" || return

    pass_test
}

# ---------------------------------------------------------------------------
# Issue #137: '&' in a message must not be treated as replacement syntax
# (bash 5.2+ enables patsub_replacement by default)
# ---------------------------------------------------------------------------

# Test: Ampersand in message is logged unchanged
test_format_message_with_ampersand() {
    start_test "Ampersand in message is logged unchanged (Issue #137)"

    init_logger --quiet
    local log_file="$TEST_DIR/ampersand.log"
    LOG_FILE="$log_file"

    log_info "Tom & Jerry"

    assert_file_contains "$log_file" "Tom & Jerry" || return
    assert_file_not_contains "$log_file" "%m" "'&' must not expand to the matched token" || return

    pass_test
}

# Test: URL query string with several ampersands is logged unchanged
test_format_message_with_query_string() {
    start_test "URL query string with ampersands is logged unchanged (Issue #137)"

    init_logger --quiet
    local log_file="$TEST_DIR/query.log"
    LOG_FILE="$log_file"

    log_info "https://example.com/?a=1&b=2&c=3"

    assert_file_contains "$log_file" "https://example.com/?a=1&b=2&c=3" || return

    pass_test
}

# Test: Messages made only of ampersands are logged unchanged
test_format_message_ampersand_only() {
    start_test "Ampersand-only messages are logged unchanged (Issue #137)"

    init_logger --quiet --format "%m"
    local log_file="$TEST_DIR/ampersand_only.log"
    LOG_FILE="$log_file"

    log_info "&"
    log_info "&&"
    log_info "& &"

    local expected
    expected=$(printf '%s\n' "&" "&&" "& &")
    assert_equals "$expected" "$(cat "$log_file")" || return

    pass_test
}

# Test: Backslash before an ampersand is not consumed
test_format_message_with_escaped_ampersand() {
    start_test "Backslash before ampersand is preserved (Issue #137)"

    init_logger --quiet --format "%m"
    local log_file="$TEST_DIR/escaped_ampersand.log"
    LOG_FILE="$log_file"

    log_info 'a\&b'

    assert_equals 'a\&b' "$(cat "$log_file")" || return

    pass_test
}

# Test: Message-only format with an ampersand gives the exact message
test_format_message_ampersand_message_only_format() {
    start_test "Message-only format keeps ampersand exactly (Issue #137)"

    init_logger --quiet --format "%m"
    local log_file="$TEST_DIR/ampersand_msg_only.log"
    LOG_FILE="$log_file"

    log_info "x&y"

    assert_equals "x&y" "$(cat "$log_file")" || return

    pass_test
}

# Test: Ampersand is preserved on console output
test_format_message_ampersand_console() {
    start_test "Ampersand is preserved on console output (Issue #137)"

    bash -c "
        source '$PROJECT_ROOT/logging.sh'
        init_logger --no-color
        log_info 'Tom & Jerry'
    " >"$TEST_DIR/stdout" 2>"$TEST_DIR/stderr"

    assert_file_contains "$TEST_DIR/stdout" "Tom & Jerry" || return
    assert_file_not_contains "$TEST_DIR/stdout" "%m" || return

    pass_test
}

# Test: Ampersand is preserved under bash, bash --posix and zsh
test_format_message_with_ampersand_cross_shell() {
    start_test "Ampersand is preserved in bash, bash --posix and zsh (Issue #137)"

    require_shell zsh || return 0

    local shell_command
    local output
    for shell_command in "bash" "bash --posix" "zsh"; do
        output=$(run_with_logger_in_shell "$shell_command" \
            "init_logger --no-color --format '%m'; log_info 'Tom & Jerry a\\&b'" 2>&1)
        assert_equals 'Tom & Jerry a\&b' "$output" "shell: $shell_command" || return
    done

    pass_test
}

# ---------------------------------------------------------------------------
# Issue #138: format tokens inside a message must not be expanded
# ---------------------------------------------------------------------------

# Test: Token-like text in a message is kept literally
test_format_message_tokens_not_expanded() {
    start_test "Format tokens inside a message are not expanded (Issue #138)"

    init_logger --quiet
    local log_file="$TEST_DIR/tokens.log"
    LOG_FILE="$log_file"

    log_info "literal %d %l %s %m %z %%"

    local content
    content=$(cat "$log_file")
    case "$content" in
        *"] literal %d %l %s %m %z %%")
            ;;
        *)
            fail_test "Message tokens were expanded: $content"
            return
            ;;
    esac

    pass_test
}

# Test: %z in a message is not replaced with UTC
test_format_message_percent_z_utc() {
    start_test "%z in a message is not replaced in UTC mode (Issue #138)"

    init_logger --quiet --utc
    local log_file="$TEST_DIR/percent_z.log"
    LOG_FILE="$log_file"

    log_info "5%z off"

    assert_file_contains "$log_file" "5%z off" || return
    assert_file_not_contains "$log_file" "5UTC off" || return

    pass_test
}

# Test: A message that is only a token is kept literally
test_format_message_token_as_whole_message() {
    start_test "Message consisting only of a token is kept literally (Issue #138)"

    init_logger --quiet --format "[%l] %m"
    local log_file="$TEST_DIR/token_whole.log"
    LOG_FILE="$log_file"

    log_info "%z"

    assert_equals "[INFO] %z" "$(cat "$log_file")" || return

    pass_test
}

# Test: Unknown tokens and a trailing % in the format are kept (regression guard)
test_format_unknown_token_kept() {
    start_test "Unknown format tokens and trailing % are kept literally"

    init_logger --quiet --format "<%l|%q|end%"
    local log_file="$TEST_DIR/unknown_token.log"
    LOG_FILE="$log_file"

    log_info "ignored"

    assert_equals "<INFO|%q|end%" "$(cat "$log_file")" || return

    pass_test
}

# Test: %% in the format is kept as written (regression guard)
test_format_double_percent_kept() {
    start_test "Double percent in the format is kept as written"

    init_logger --quiet --format "%l 100%% %m"
    local log_file="$TEST_DIR/double_percent.log"
    LOG_FILE="$log_file"

    log_info "done"

    assert_equals "INFO 100%% done" "$(cat "$log_file")" || return

    pass_test
}

# Test: %% before a token letter is a literal pair and suppresses the token
test_format_double_percent_before_token() {
    start_test "Double percent before a token letter is kept literally (Issue #138)"

    init_logger --quiet --format "A%%mB"
    local log_file="$TEST_DIR/double_percent_token.log"
    LOG_FILE="$log_file"

    log_info "message"

    assert_equals "A%%mB" "$(cat "$log_file")" || return

    pass_test
}

# Test: Token expansion does not depend on token order
test_format_token_order_independent() {
    start_test "Token expansion is independent of token order (Issue #138)"

    init_logger --quiet --format "%z %m %d"
    local log_file="$TEST_DIR/token_order.log"
    # shellcheck disable=SC2034  # LOG_FILE is read by logging.sh
    LOG_FILE="$log_file"

    log_info "%z"

    local content
    content=$(cat "$log_file")
    assert_matches "$content" "^LOCAL %z [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$" || return

    pass_test
}

# Test: Message tokens are not expanded under bash, bash --posix and zsh
test_format_message_tokens_not_expanded_cross_shell() {
    start_test "Message tokens are not expanded in bash, bash --posix and zsh (Issue #138)"

    require_shell zsh || return 0

    local shell_command
    local output
    for shell_command in "bash" "bash --posix" "zsh"; do
        output=$(run_with_logger_in_shell "$shell_command" \
            "init_logger --no-color --format '[%l] %m'; log_info 'literal %d %l %s %m %z %%'" 2>&1)
        assert_equals "[INFO] literal %d %l %s %m %z %%" "$output" "shell: $shell_command" || return
    done

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
test_format_does_not_affect_journal_output
test_format_script_name_token_sanitised_to_underscores
test_format_message_with_ampersand
test_format_message_with_query_string
test_format_message_ampersand_only
test_format_message_with_escaped_ampersand
test_format_message_ampersand_message_only_format
test_format_message_ampersand_console
test_format_message_with_ampersand_cross_shell
test_format_message_tokens_not_expanded
test_format_message_percent_z_utc
test_format_message_token_as_whole_message
test_format_unknown_token_kept
test_format_double_percent_kept
test_format_double_percent_before_token
test_format_token_order_independent
test_format_message_tokens_not_expanded_cross_shell
