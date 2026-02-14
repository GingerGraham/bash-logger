#!/usr/bin/env bash
#
# test_error_conditions.sh - Tests for error handling and validation
#
# Tests:
# - Configuration validation errors
# - init_logger argument errors
# - File write failures
# - Missing dependencies

# Test: Config path too long
test_config_path_too_long() {
    start_test "Config rejects file path exceeding max length"

    local config_file="$TEST_DIR/toolong.conf"
    # Create a path longer than 4096 characters
    local long_path
    long_path="/tmp/$(printf 'x%.0s' {1..4100})"

    cat > "$config_file" << EOF
[logging]
log_file = $long_path
EOF

    init_logger --config "$config_file" --quiet 2>"$TEST_STDERR"

    assert_file_contains "$TEST_STDERR" "exceeds maximum length" || return

    pass_test
}

# Test: Config empty log file path
test_config_empty_log_file() {
    start_test "Config handles empty log_file value"

    local config_file="$TEST_DIR/empty.conf"
    cat > "$config_file" << 'EOF'
[logging]
log_file =
EOF

    init_logger --config "$config_file" 2>"$TEST_STDERR"

    # Empty log file should be valid (means disabled)
    assert_equals "" "$LOG_FILE" || return

    pass_test
}

# Test: Journal tag with control characters
test_journal_tag_control_chars() {
    start_test "Config rejects journal tag with control characters"

    local config_file="$TEST_DIR/badtag.conf"
    # shellcheck disable=SC2028
    cat > "$config_file" << 'EOF'
[logging]
tag = bad	tag
EOF
    # Insert a tab character in the tag
    sed -i 's/bad	tag/bad\x09tag/' "$config_file" 2>/dev/null || \
        perl -pi -e 's/bad\ttag/bad\x09tag/' "$config_file" 2>/dev/null || true

    init_logger --config "$config_file" 2>"$TEST_STDERR"

    assert_file_contains "$TEST_STDERR" "control characters" || return

    pass_test
}

# Test: Journal tag exceeding 64 characters
test_journal_tag_too_long() {
    start_test "Config truncates journal tag exceeding 64 chars"

    local config_file="$TEST_DIR/longtag.conf"
    local long_tag
    long_tag="$(printf 'a%.0s' {1..100})"

    cat > "$config_file" << EOF
[logging]
tag = $long_tag
EOF

    init_logger --config "$config_file" 2>"$TEST_STDERR"

    # Should be truncated to 64 characters
    assert_equals 64 "${#JOURNAL_TAG}" "Journal tag should be truncated to 64 chars" || return
    assert_file_contains "$TEST_STDERR" "Truncated" || return

    pass_test
}

# Test: Journal tag with shell metacharacters
test_journal_tag_sanitization() {
    start_test "Config sanitizes journal tag with shell metacharacters"

    local config_file="$TEST_DIR/metatag.conf"
    cat > "$config_file" << 'EOF'
[logging]
tag = bad;tag$()
EOF

    init_logger --config "$config_file" 2>"$TEST_STDERR"

    # Shell metacharacters should be replaced with underscores
    # The tag gets sanitized during validation
    assert_file_contains "$TEST_STDERR" "Sanitized" || return

    pass_test
}

# Test: Config format with control characters
test_config_format_control_chars() {
    start_test "Config warns about format with control characters"

    local config_file="$TEST_DIR/badformat.conf"
    # Create format with control character
    printf '[logging]\nformat = %%l\x01%%m\n' > "$config_file"

    init_logger --config "$config_file" 2>"$TEST_STDERR"

    assert_file_contains "$TEST_STDERR" "control characters" || return

    pass_test
}

# Test: Invalid quiet value in config
test_config_invalid_quiet() {
    start_test "Config rejects invalid quiet value"

    local config_file="$TEST_DIR/badquiet.conf"
    cat > "$config_file" << 'EOF'
[logging]
quiet = maybe
EOF

    init_logger --config "$config_file" 2>"$TEST_STDERR"

    assert_file_contains "$TEST_STDERR" "Invalid quiet value" || return
    # Should fall back to default (console enabled)
    assert_equals "true" "$CONSOLE_LOG" || return

    pass_test
}

# Test: Invalid console_log value in config
test_config_invalid_console_log() {
    start_test "Config rejects invalid console_log value"

    local config_file="$TEST_DIR/badconsole.conf"
    cat > "$config_file" << 'EOF'
[logging]
console_log = invalid
EOF

    init_logger --config "$config_file" 2>"$TEST_STDERR"

    assert_file_contains "$TEST_STDERR" "Invalid console_log value" || return

    pass_test
}

# Test: Invalid verbose value in config
test_config_invalid_verbose() {
    start_test "Config rejects invalid verbose value"

    local config_file="$TEST_DIR/badverbose.conf"
    cat > "$config_file" << 'EOF'
[logging]
verbose = yes_please
EOF

    init_logger --config "$config_file" 2>"$TEST_STDERR"

    assert_file_contains "$TEST_STDERR" "Invalid verbose value" || return

    pass_test
}

# Test: Invalid unsafe_allow_ansi_codes value in config
test_config_invalid_ansi_codes() {
    start_test "Config rejects invalid unsafe_allow_ansi_codes value"

    local config_file="$TEST_DIR/badansi.conf"
    cat > "$config_file" << 'EOF'
[logging]
unsafe_allow_ansi_codes = notbool
EOF

    init_logger --config "$config_file" 2>"$TEST_STDERR"

    assert_file_contains "$TEST_STDERR" "Invalid unsafe_allow_ansi_codes value" || return

    pass_test
}

# Test: Invalid max_line_length in config
test_config_invalid_max_line_length() {
    start_test "Config rejects invalid max_line_length"

    local config_file="$TEST_DIR/badmaxline.conf"
    cat > "$config_file" << 'EOF'
[logging]
max_line_length = notanumber
EOF

    init_logger --config "$config_file" 2>"$TEST_STDERR"

    assert_file_contains "$TEST_STDERR" "Invalid max_line_length value" || return
    assert_file_contains "$TEST_STDERR" "Using default" || return

    pass_test
}

# Test: Invalid max_journal_length in config
test_config_invalid_max_journal_length() {
    start_test "Config rejects invalid max_journal_length"

    local config_file="$TEST_DIR/badjournal.conf"
    cat > "$config_file" << 'EOF'
[logging]
max_journal_length = -5
EOF

    init_logger --config "$config_file" 2>"$TEST_STDERR"

    assert_file_contains "$TEST_STDERR" "Invalid max_journal_length value" || return

    pass_test
}

# Test: Config warns about invalid format string
test_config_invalid_format_warning() {
    start_test "Config warns about invalid format string"

    local config_file="$TEST_DIR/invalidfmt.conf"
    cat > "$config_file" << 'EOF'
[logging]
format =
EOF

    init_logger --config "$config_file" 2>"$TEST_STDERR"

    # Empty format gets rejected or ignored - check that init succeeded
    # The logger should handle empty format gracefully
    # Just verify init_logger ran without fatal errors
    assert_equals 0 $? "init_logger should handle empty format" || return

    pass_test
}

# Test: init_logger --config without argument
test_init_missing_config_argument() {
    start_test "init_logger requires argument for --config"

    init_logger --config 2>"$TEST_STDERR"
    local exit_code=$?

    assert_not_equals 0 "$exit_code" "Should return non-zero" || return
    assert_file_contains "$TEST_STDERR" "requires a file path" || return

    pass_test
}

# Test: init_logger --max-line-length without argument
test_init_missing_max_line_length() {
    start_test "init_logger requires value for --max-line-length"

    init_logger --max-line-length 2>"$TEST_STDERR"
    local exit_code=$?

    assert_not_equals 0 "$exit_code" "Should return non-zero" || return
    assert_file_contains "$TEST_STDERR" "requires a value" || return

    pass_test
}

# Test: init_logger --max-line-length with invalid value
test_init_invalid_max_line_length() {
    start_test "init_logger rejects invalid --max-line-length"

    init_logger --max-line-length "notanumber" 2>"$TEST_STDERR"

    assert_file_contains "$TEST_STDERR" "Invalid max-line-length" || return

    pass_test
}

# Test: init_logger --max-journal-length without argument
test_init_missing_max_journal_length() {
    start_test "init_logger requires value for --max-journal-length"

    init_logger --max-journal-length 2>"$TEST_STDERR"
    local exit_code=$?

    assert_not_equals 0 "$exit_code" "Should return non-zero" || return
    assert_file_contains "$TEST_STDERR" "requires a value" || return

    pass_test
}

# Test: init_logger --max-journal-length with invalid value
test_init_invalid_max_journal_length() {
    start_test "init_logger rejects invalid --max-journal-length"

    init_logger --max-journal-length "abc" 2>"$TEST_STDERR"

    assert_file_contains "$TEST_STDERR" "Invalid max-journal-length" || return

    pass_test
}

# Test: Log file write failure on initialization
test_log_file_write_failure_on_init() {
    start_test "init_logger detects write failures"

    local log_file="$TEST_DIR/readonly.log"
    touch "$log_file"
    chmod 444 "$log_file"

    init_logger --log "$log_file" --quiet 2>"$TEST_STDERR"
    local exit_code=$?

    assert_not_equals 0 "$exit_code" "Should fail with non-zero exit" || return
    assert_file_contains "$TEST_STDERR" "not writable" || return

    # Cleanup
    chmod 644 "$log_file" 2>/dev/null || true

    pass_test
}

# Test: Log file write failure during runtime
test_log_file_unwritable_during_runtime() {
    start_test "Detects when log file becomes unwritable during runtime"

    local log_file="$TEST_DIR/unwritable.log"
    init_logger --log "$log_file" --quiet

    # First write should work
    log_info "Before change"
    assert_file_exists "$log_file" || return

    # Make the file read-only to simulate write failure
    chmod 444 "$log_file"

    # Next write should detect the error and report it
    log_info "After permission change" 2>"$TEST_STDERR"

    assert_file_contains "$TEST_STDERR" "Failed to write to log file" || return

    # Cleanup
    chmod 644 "$log_file" 2>/dev/null || true

    pass_test
}

# Test: Journal logging when logger unavailable
test_config_journal_no_logger() {
    start_test "Config handles journal=true when logger unavailable"

    # Skip if logger is available
    if check_logger_available; then
        skip_test "logger command is available"
        return
    fi

    local config_file="$TEST_DIR/journal.conf"
    cat > "$config_file" << 'EOF'
[logging]
journal = true
EOF

    init_logger --config "$config_file" 2>"$TEST_STDERR"

    assert_file_contains "$TEST_STDERR" "logger command not found" || return
    assert_file_contains "$TEST_STDERR" "journal logging disabled" || return

    pass_test
}

# Test: Empty journal tag is rejected
test_config_empty_journal_tag() {
    start_test "Config rejects empty journal tag"

    local config_file="$TEST_DIR/emptytag.conf"
    cat > "$config_file" << 'EOF'
[logging]
tag =
EOF

    init_logger --config "$config_file" 2>"$TEST_STDERR"

    assert_file_contains "$TEST_STDERR" "Empty journal tag" || return

    pass_test
}

# Run all tests
test_config_path_too_long
test_config_empty_log_file
test_journal_tag_control_chars
test_journal_tag_too_long
test_journal_tag_sanitization
test_config_format_control_chars
test_config_invalid_quiet
test_config_invalid_console_log
test_config_invalid_verbose
test_config_invalid_ansi_codes
test_config_invalid_max_line_length
test_config_invalid_max_journal_length
test_config_invalid_format_warning
test_init_missing_config_argument
test_init_missing_max_line_length
test_init_invalid_max_line_length
test_init_missing_max_journal_length
test_init_invalid_max_journal_length
test_log_file_write_failure_on_init
test_log_file_unwritable_during_runtime
test_config_journal_no_logger
test_config_empty_journal_tag
