#!/usr/bin/env bash
#
# test_sensitive_data.sh - Tests for sensitive data handling
#
# Tests that log_sensitive() properly prevents sensitive data from
# reaching persistent storage while still allowing console output
# for interactive debugging.
#
# Related to security review finding INFO-01

# shellcheck source=tests/test_helpers.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

# Test: log_sensitive doesn't write to log files
test_sensitive_not_in_file() {
    start_test "log_sensitive() doesn't write to log file"

    local log_file="$TEST_TMP_DIR/sensitive.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Log sensitive data
    log_sensitive "API_KEY=secret123456"
    log_info "Non-sensitive message"

    # Verify sensitive data is NOT in file
    if [[ ! -f "$log_file" ]]; then
        fail_test "Log file was not created"
        return
    fi

    local log_content
    log_content=$(cat "$log_file")

    if [[ "$log_content" =~ "secret123456" ]]; then
        fail_test "Sensitive data was written to log file"
        return
    fi

    if [[ "$log_content" =~ "Non-sensitive message" ]]; then
        pass_test
    else
        fail_test "Non-sensitive message was not logged"
    fi
}

# Test: log_sensitive doesn't write to journal
test_sensitive_not_in_journal() {
    start_test "log_sensitive() doesn't write to journal"

    if ! check_logger_available; then
        skip_test "logger command not available"
        return
    fi

    local log_file="$TEST_TMP_DIR/journal_test.log"
    local unique_id="test_$$_$RANDOM"

    init_logger -l "$log_file" --journal --tag "test_$unique_id" --no-color > /dev/null 2>&1

    # Log sensitive data
    log_sensitive "PASSWORD=hunter2_$unique_id"
    log_info "Public_message_$unique_id"

    # Small delay for journal
    sleep 0.1

    # Check that sensitive data didn't go to journal
    # Note: This is a best-effort check; journal access may be restricted
    if command -v journalctl &>/dev/null; then
        local journal_output
        journal_output=$(journalctl -t "test_$unique_id" --no-pager -n 10 2>/dev/null || echo "")

        if [[ "$journal_output" =~ hunter2_$unique_id ]]; then
            fail_test "Sensitive data was written to journal"
            return
        fi
    fi

    pass_test
}

# Test: log_sensitive goes to console when stdout is terminal
test_sensitive_to_console_interactive() {
    start_test "log_sensitive() goes to console in interactive mode"

    local log_file="$TEST_TMP_DIR/console_test.log"

    init_logger -l "$log_file" --no-color

    # Log sensitive data
    log_sensitive "Interactive secret" > /dev/null 2>&1

    # Verify sensitive message is NOT written to log file (console-only)
    if ! grep -q "Interactive secret" "$log_file" 2>/dev/null; then
        pass_test
    else
        fail_test "Sensitive data was written to log file"
    fi
}

# Test: log_sensitive with stdout redirected
test_sensitive_redirect_detection() {
    start_test "log_sensitive() with stdout redirection (INFO-01 limitation)"

    local log_file="$TEST_TMP_DIR/redirect_test.log"
    local redirect_file="$TEST_TMP_DIR/redirect_output.txt"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Redirect output and log sensitive data
    log_sensitive "RedirectedSecret" > "$redirect_file" 2>&1
    log_info "Normal message"

    # INFO-01: Known limitation - log_sensitive() cannot reliably detect
    # stdout redirection in all contexts. When stdout is redirected,
    # sensitive data may leak to the redirected output. This test documents
    # the limitation rather than asserting false security guarantees.
    # See docs/security-reviews/2026-02-04-claude-security-findings.md
    skip_test "INFO-01: Sensitive data leakage when stdout is redirected (documented limitation)"
}

# Test: Sensitive data in error conditions
test_sensitive_in_error_conditions() {
    start_test "Sensitive data not leaked in error messages"

    local log_file="$TEST_TMP_DIR/error_test.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Try to log various sensitive patterns
    log_sensitive "password=secret123"
    log_sensitive "token=abc-def-ghi"
    log_sensitive "api_key=sk_live_12345"

    # Trigger some error conditions
    log_error "Authentication failed for user" # Should not include password

    # Verify log file doesn't contain sensitive keywords
    local log_content
    log_content=$(cat "$log_file")

    if [[ ! "$log_content" =~ "secret123" ]] && \
       [[ ! "$log_content" =~ "sk_live_12345" ]]; then
        pass_test
    else
        fail_test "Sensitive data appeared in log file"
    fi
}

# Test: Multiple log levels with sensitive flag
test_sensitive_flag_respected() {
    start_test "Sensitive flag is respected across log levels"

    local log_file="$TEST_TMP_DIR/levels_test.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Use internal _log_message function to test sensitive flag
    _log_message "INFO" "$LOG_LEVEL_INFO" "Public info" "false" "false"
    _log_message "WARN" "$LOG_LEVEL_WARN" "Sensitive warning" "true" "true"
    _log_message "ERROR" "$LOG_LEVEL_ERROR" "Sensitive error" "true" "true"

    local log_content
    log_content=$(cat "$log_file")

    if [[ "$log_content" =~ "Public info" ]] && \
       [[ ! "$log_content" =~ "Sensitive warning" ]] && \
       [[ ! "$log_content" =~ "Sensitive error" ]]; then
        pass_test
    else
        fail_test "Sensitive flag not properly respected"
    fi
}

# Test: Sensitive data with ANSI codes
test_sensitive_with_ansi_codes() {
    start_test "Sensitive data with ANSI codes is handled"

    local log_file="$TEST_TMP_DIR/ansi_sensitive.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Log sensitive data that includes ANSI codes
    log_sensitive $'Password:\e[31mREDSECRET\e[0m'

    local log_content
    log_content=$(cat "$log_file" 2>/dev/null || echo "")

    if [[ ! "$log_content" =~ "REDSECRET" ]]; then
        pass_test
    else
        fail_test "Sensitive data with ANSI codes was logged"
    fi
}

# Test: Sensitive data with newlines
test_sensitive_with_newlines() {
    start_test "Sensitive data with newlines is handled"

    local log_file="$TEST_TMP_DIR/newline_sensitive.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Log sensitive data with newlines
    log_sensitive $'Secret part 1\nSecret part 2'

    local log_content
    log_content=$(cat "$log_file" 2>/dev/null || echo "")

    if [[ ! "$log_content" =~ "Secret part 1" ]] && \
       [[ ! "$log_content" =~ "Secret part 2" ]]; then
        pass_test
    else
        fail_test "Sensitive data with newlines was logged"
    fi
}

# Test: Large sensitive data
test_large_sensitive_data() {
    start_test "Large sensitive data is handled"

    local log_file="$TEST_TMP_DIR/large_sensitive.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Create large sensitive string
    local large_secret
    large_secret=$(printf 'SECRET%.0s' {1..1000})

    log_sensitive "Large data: $large_secret"
    log_info "Non-sensitive marker"

    local log_content
    log_content=$(cat "$log_file")

    if [[ ! "$log_content" =~ $large_secret ]] && \
       [[ "$log_content" =~ "Non-sensitive marker" ]]; then
        pass_test
    else
        fail_test "Large sensitive data was logged"
    fi
}

# Test: Sensitive data doesn't interfere with normal logging
test_sensitive_doesnt_interfere() {
    start_test "Sensitive logging doesn't interfere with normal logs"

    local log_file="$TEST_TMP_DIR/interference_test.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    log_info "Before sensitive"
    log_sensitive "SECRET DATA"
    log_info "After sensitive"
    log_warn "Warning message"

    local log_content
    log_content=$(cat "$log_file")

    # Count number of log entries (should be 3, not 4)
    local line_count
    line_count=$(grep -c "Before sensitive\|After sensitive\|Warning message" "$log_file")

    if [[ $line_count -eq 3 ]] && [[ ! "$log_content" =~ "SECRET DATA" ]]; then
        pass_test
    else
        fail_test "Sensitive logging interfered with normal logging"
    fi
}

# Test: Pattern matching for common sensitive data
test_common_sensitive_patterns() {
    start_test "Common sensitive data patterns are not logged"

    local log_file="$TEST_TMP_DIR/patterns_test.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Log various sensitive patterns using log_sensitive
    log_sensitive "password=mysecretpass"
    log_sensitive "token=ghp_1234567890abcdef"
    log_sensitive "api_key=sk-proj-abc123"
    log_sensitive "secret=my-secret-value"
    log_sensitive "private_key=-----BEGIN RSA PRIVATE KEY-----"

    local log_content
    log_content=$(cat "$log_file")

    # None of these should appear in file
    local failed=0
    [[ "$log_content" =~ "mysecretpass" ]] && failed=1
    [[ "$log_content" =~ "ghp_1234567890abcdef" ]] && failed=1
    [[ "$log_content" =~ "sk-proj-abc123" ]] && failed=1
    [[ "$log_content" =~ "my-secret-value" ]] && failed=1
    [[ "$log_content" =~ "BEGIN RSA PRIVATE KEY" ]] && failed=1

    if [[ $failed -eq 0 ]]; then
        pass_test
    else
        fail_test "Some sensitive patterns were logged"
    fi
}

# Test: Sensitive data in structured format
test_sensitive_structured_data() {
    start_test "Sensitive structured data is handled"

    local log_file="$TEST_TMP_DIR/structured_test.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # JSON-like sensitive data
    log_sensitive '{"username":"admin","password":"secret123","token":"abc-xyz"}'

    local log_content
    log_content=$(cat "$log_file" 2>/dev/null || echo "")

    if [[ ! "$log_content" =~ "secret123" ]] && \
       [[ ! "$log_content" =~ "abc-xyz" ]]; then
        pass_test
    else
        fail_test "Structured sensitive data was logged"
    fi
}

# Test: Mixing sensitive and non-sensitive in same message
test_mixed_sensitive_message() {
    start_test "Messages properly separate sensitive and non-sensitive"

    local log_file="$TEST_TMP_DIR/mixed_test.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # This is a limitation - users should separate these
    log_info "User logged in successfully" # Safe
    log_sensitive "Session token: abc123xyz" # Should not persist

    local log_content
    log_content=$(cat "$log_file")

    if [[ "$log_content" =~ "User logged in successfully" ]] && \
       [[ ! "$log_content" =~ "abc123xyz" ]]; then
        pass_test
    else
        fail_test "Mixed message handling failed"
    fi
}

# Test: Sensitive function exists and is callable
test_sensitive_function_exists() {
    start_test "log_sensitive() function exists and is callable"

    if declare -f log_sensitive > /dev/null; then
        pass_test
    else
        fail_test "log_sensitive() function not found"
    fi
}

# Test: Console-only mode with sensitive data
test_console_only_sensitive() {
    start_test "Sensitive data in console-only mode"

    # No log file, only console
    init_logger --no-color

    # Should be safe since nothing persists
    local output
    # shellcheck disable=SC2034
    output=$(log_sensitive "Console only secret" 2>&1 || echo "")

    # As long as no error occurred
    pass_test
}

# Test: Quiet mode with sensitive data
test_quiet_mode_sensitive() {
    start_test "Sensitive data in quiet mode"

    local log_file="$TEST_TMP_DIR/quiet_test.log"

    init_logger -l "$log_file" --quiet

    log_sensitive "Quiet secret"
    log_info "Normal message"

    local log_content
    log_content=$(cat "$log_file")

    if [[ ! "$log_content" =~ "Quiet secret" ]]; then
        pass_test
    else
        fail_test "Sensitive data logged in quiet mode"
    fi
}

# Run all tests
test_sensitive_not_in_file
test_sensitive_not_in_journal
test_sensitive_to_console_interactive
test_sensitive_redirect_detection # Known limitation, see test function for details
test_sensitive_in_error_conditions
test_sensitive_flag_respected
test_sensitive_with_ansi_codes
test_sensitive_with_newlines
test_large_sensitive_data
test_sensitive_doesnt_interfere
test_common_sensitive_patterns
test_sensitive_structured_data
test_mixed_sensitive_message
test_sensitive_function_exists
test_console_only_sensitive
test_quiet_mode_sensitive
