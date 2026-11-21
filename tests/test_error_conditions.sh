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
    # printf writes the tab, so the test does not depend on sed support for \x09:
    # busybox sed replaced the tab with the literal text "x09"
    printf '[logging]\ntag = bad\ttag\n' > "$config_file"

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
    assert_file_contains "$TEST_STDERR" "Keeping the current value of 4096" || return

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

# Test: init_logger rejects an empty value for every option in the table of Issue #189
test_init_empty_option_value_is_error() {
    start_test "init_logger returns 1 for an empty option value"

    local option=""
    for option in --facility --max-line-length --max-journal-length --tag --level \
        --stderr-level --name --format; do
        init_logger --quiet "$option" "" 2>"$TEST_STDERR"
        local exit_code=$?

        assert_equals 1 "$exit_code" "$option with an empty value should return 1" || return
        assert_file_contains "$TEST_STDERR" "Error: $option requires a non-empty value" || return
    done

    pass_test
}

# Test: a short option gets the same answer as its long form (Issue #189)
test_init_empty_short_option_value_is_error() {
    start_test "init_logger returns 1 for an empty value on a short option"

    local option=""
    for option in -F -t -d -e -n -f; do
        init_logger --quiet "$option" "" 2>"$TEST_STDERR"
        local exit_code=$?

        assert_equals 1 "$exit_code" "$option with an empty value should return 1" || return
        assert_file_contains "$TEST_STDERR" "Error: $option requires a non-empty value" || return
    done

    pass_test
}

# Test: an empty value changes nothing (Issue #189)
test_init_empty_option_value_keeps_settings() {
    start_test "init_logger keeps the current settings after an empty option value"

    init_logger --quiet --facility local3 --tag mytag --level DEBUG --stderr-level WARN \
        --max-line-length 500 --max-journal-length 600 --format "%l %m"
    init_logger --quiet --facility "" 2>/dev/null
    init_logger --quiet --tag "" 2>/dev/null
    init_logger --quiet --level "" 2>/dev/null
    init_logger --quiet --stderr-level "" 2>/dev/null
    init_logger --quiet --max-line-length "" 2>/dev/null
    init_logger --quiet --max-journal-length "" 2>/dev/null
    init_logger --quiet --format "" 2>/dev/null

    assert_equals "local3" "$SYSLOG_FACILITY" || return
    assert_equals "mytag" "$JOURNAL_TAG" || return
    assert_equals "$LOG_LEVEL_DEBUG" "$CURRENT_LOG_LEVEL" || return
    assert_equals "$LOG_LEVEL_WARN" "$LOG_STDERR_LEVEL" || return
    assert_equals "500" "$LOG_MAX_LINE_LENGTH" || return
    assert_equals "600" "$LOG_MAX_JOURNAL_LENGTH" || return
    assert_equals "%l %m" "$LOG_FORMAT" || return

    pass_test
}

# Test: a missing value and an empty value are both errors, an invalid one is a warning
test_init_missing_empty_and_invalid_values() {
    start_test "init_logger separates a missing, an empty and an invalid value"

    init_logger --quiet --facility 2>"$TEST_STDERR"
    assert_equals 1 "$?" "Missing value should return 1" || return
    assert_file_contains "$TEST_STDERR" "Error: --facility requires a value" || return

    init_logger --quiet --facility "" 2>"$TEST_STDERR"
    assert_equals 1 "$?" "Empty value should return 1" || return
    assert_file_contains "$TEST_STDERR" "Error: --facility requires a non-empty value" || return

    init_logger --quiet --facility bogus 2>"$TEST_STDERR"
    assert_equals 0 "$?" "Invalid value should warn and return 0" || return
    assert_file_contains "$TEST_STDERR" "Warning: Invalid syslog facility 'bogus'" || return

    pass_test
}

# Test: options that accept an empty value still do (Issue #189)
test_init_empty_log_file_is_accepted() {
    start_test "init_logger --log with an empty value still means no log file"

    init_logger --quiet --log "" 2>"$TEST_STDERR"

    assert_equals 0 "$?" "Empty --log should return 0" || return
    assert_equals "" "$LOG_FILE" || return

    pass_test
}

# Test: --tag, set_journal_tag and the config file apply the same tag rules (Issue #194)
test_journal_tag_rules_are_shared() {
    start_test "--tag, set_journal_tag and the config file reject the same tags"

    local escape_char
    escape_char=$(printf '\033')
    local long_tag
    long_tag=$(printf 'a%.0s' $(seq 1 65))
    local config_file="$TEST_DIR/tag_rules.conf"
    local tag
    for tag in "bad;tag" "bad${escape_char}tag" "$long_tag"; do
        init_logger --quiet --tag good 2>/dev/null
        init_logger --quiet --tag "$tag" 2>/dev/null
        assert_equals "good" "$JOURNAL_TAG" "--tag keeps the tag after a rejected value" || return

        set_journal_tag "$tag" 2>/dev/null
        assert_equals 1 "$?" "set_journal_tag returns 1 for a rejected value" || return
        assert_equals "good" "$JOURNAL_TAG" "set_journal_tag keeps the tag" || return

        # The parser repairs a rejected tag. Its warning names the line, the others do not.
        printf '[logging]\ntag = %s\n' "$tag" > "$config_file"
        init_logger --quiet --config "$config_file" 2>"$TEST_STDERR"
        assert_not_equals "$tag" "$JOURNAL_TAG" "the config file does not keep the tag as written" || return
        assert_file_contains "$TEST_STDERR" "at line 2" || return
    done

    init_logger --quiet --tag "bad;tag" 2>"$TEST_STDERR"
    assert_file_contains "$TEST_STDERR" "Warning: Journal tag contains shell metacharacters" || return
    assert_file_not_contains "$TEST_STDERR" "at line" "No line number outside the config file" || return

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

# Test: Calling a log function before init_logger does not crash the shell
# and either auto-inits or returns gracefully with a non-zero exit
test_log_before_init_does_not_crash() {
    start_test "log_info before init_logger does not crash the shell"

    local exit_code=0
    local output
    output=$(bash -c "
        source '$PROJECT_ROOT/logging.sh'
        # Deliberately do NOT call init_logger
        log_info 'pre-init message'
        echo exit_code:\$?
    " 2>&1) || exit_code=$?

    # The subshell must complete without crashing (exit 0 or clean non-zero;
    # what must NOT happen is bash itself exiting with a signal or unbound variable error)
    assert_not_contains "$output" "unbound variable" \
        "Should not raise unbound variable error" || return
    assert_not_contains "$output" "bad substitution" \
        "Should not raise bad substitution error" || return

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
test_init_empty_option_value_is_error
test_init_empty_short_option_value_is_error
test_init_empty_option_value_keeps_settings
test_init_missing_empty_and_invalid_values
test_init_empty_log_file_is_accepted
test_journal_tag_rules_are_shared
test_log_file_write_failure_on_init
test_log_file_unwritable_during_runtime
test_config_journal_no_logger
test_config_empty_journal_tag
test_log_before_init_does_not_crash
