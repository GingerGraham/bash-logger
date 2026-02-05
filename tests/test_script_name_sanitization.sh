#!/usr/bin/env bash
#
# test_script_name_sanitization.sh - Tests for script name sanitization
#
# Tests for defense-in-depth script name sanitization to prevent
# potential shell metacharacter injection attacks (Issue #39)

# shellcheck source=tests/test_helpers.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

# Test: Basic sanitization function
test_sanitize_basic() {
    start_test "Script name sanitization removes shell metacharacters"

    init_logger --quiet

    # Test the internal sanitization function directly
    local result
    result=$(_sanitize_script_name "normal-script.sh")
    assert_equals "normal-script.sh" "$result" || return

    # Test with shell metacharacters
    result=$(_sanitize_script_name "script\$bad.sh")
    assert_equals "script_bad.sh" "$result" || return

    result=$(_sanitize_script_name "script;rm.sh")
    assert_equals "script_rm.sh" "$result" || return

    result=$(_sanitize_script_name "script\`cmd\`.sh")
    assert_equals "script_cmd_.sh" "$result" || return

    pass_test
}

# Test: Sanitization of common attack patterns
test_sanitize_attack_patterns() {
    start_test "Script name sanitization handles common attack patterns"

    init_logger --quiet

    # Test command substitution patterns
    local result
    result=$(_sanitize_script_name "script\$(evil).sh")
    assert_equals "script__evil_.sh" "$result" || return

    # Test pipe and redirection
    result=$(_sanitize_script_name "script|cmd.sh")
    assert_equals "script_cmd.sh" "$result" || return

    result=$(_sanitize_script_name "script>file.sh")
    assert_equals "script_file.sh" "$result" || return

    result=$(_sanitize_script_name "script<file.sh")
    assert_equals "script_file.sh" "$result" || return

    # Test semicolon command separator
    result=$(_sanitize_script_name "script;evil;cmd.sh")
    assert_equals "script_evil_cmd.sh" "$result" || return

    # Test ampersand background
    result=$(_sanitize_script_name "script&evil.sh")
    assert_equals "script_evil.sh" "$result" || return

    # Test wildcards
    result=$(_sanitize_script_name "script*.sh")
    assert_equals "script_.sh" "$result" || return

    result=$(_sanitize_script_name "script?.sh")
    assert_equals "script_.sh" "$result" || return

    pass_test
}

# Test: Sanitization preserves valid characters
test_sanitize_preserves_valid() {
    start_test "Script name sanitization preserves valid characters"

    init_logger --quiet

    # Test alphanumeric characters
    local result
    result=$(_sanitize_script_name "MyScript123.sh")
    assert_equals "MyScript123.sh" "$result" || return

    # Test underscores
    result=$(_sanitize_script_name "my_test_script.sh")
    assert_equals "my_test_script.sh" "$result" || return

    # Test hyphens
    result=$(_sanitize_script_name "my-test-script.sh")
    assert_equals "my-test-script.sh" "$result" || return

    # Test periods (for file extensions)
    result=$(_sanitize_script_name "script.test.sh")
    assert_equals "script.test.sh" "$result" || return

    # Test combination
    result=$(_sanitize_script_name "My_Test-Script.v1.2.sh")
    assert_equals "My_Test-Script.v1.2.sh" "$result" || return

    pass_test
}

# Test: Auto-detection from BASH_SOURCE
test_sanitize_from_bash_source() {
    start_test "Script name is sanitized when auto-detected from BASH_SOURCE"

    # Create a test script with shell metacharacters in the name
    local test_script="$TEST_DIR/test\$script.sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
source "$PROJECT_ROOT/logging.sh"
init_logger --quiet
echo "$SCRIPT_NAME"
EOF
    chmod +x "$test_script"

    # Run the script and capture output
    local output
    output=$(PROJECT_ROOT="$PROJECT_ROOT" bash "$test_script" 2>&1)

    # Should have sanitized the $ to _
    assert_equals "test_script.sh" "$output" || return

    pass_test
}

# Test: CLI option --name sanitization
test_sanitize_cli_option() {
    start_test "Script name is sanitized when set via CLI option"

    init_logger --quiet --name "evil\$(cmd).sh"

    assert_equals "evil__cmd_.sh" "$SCRIPT_NAME" || return

    pass_test
}

# Test: Config file script name sanitization
test_sanitize_config_file() {
    start_test "Script name is sanitized when set via config file"

    local config_file="$TEST_DIR/test.conf"
    cat > "$config_file" << 'EOF'
[general]
script_name = evil;cmd.sh
EOF

    init_logger --quiet --config "$config_file"

    assert_equals "evil_cmd.sh" "$SCRIPT_NAME" || return

    pass_test
}

# Test: set_script_name function sanitization
test_sanitize_set_script_name() {
    start_test "Script name is sanitized when changed via set_script_name"

    init_logger --quiet --name "original.sh"

    assert_equals "original.sh" "$SCRIPT_NAME" || return

    set_script_name "new\$(evil).sh"

    assert_equals "new__evil_.sh" "$SCRIPT_NAME" || return

    pass_test
}

# Test: Sanitization in log output
test_sanitize_in_log_output() {
    start_test "Sanitized script name appears correctly in log output"

    local log_file="$TEST_DIR/sanitize.log"
    init_logger --quiet --name "evil\$script.sh" --file "$log_file" --format "[%s] %m"

    log_info "Test message"

    # Sanitized name should appear in log
    assert_file_contains "$log_file" "[evil_script.sh] Test message" || return

    # Original name with $ should NOT appear
    if grep -q "evil\$script.sh" "$log_file"; then
        fail_test "Unsanitized script name found in log output"
        return 1
    fi

    pass_test
}

# Test: Sanitization with journal tag
test_sanitize_journal_tag() {
    start_test "Sanitized script name is used as default journal tag"

    if ! check_logger_available; then
        skip_test "logger command not available"
        return
    fi

    init_logger --quiet --name "evil;script.sh" --journal

    # Check that JOURNAL_TAG was set to sanitized name
    assert_equals "evil_script.sh" "$JOURNAL_TAG" || return

    pass_test
}

# Test: Multiple sanitization passes (idempotent)
test_sanitize_idempotent() {
    start_test "Script name sanitization is idempotent"

    init_logger --quiet

    local result
    result=$(_sanitize_script_name "script\$test.sh")
    assert_equals "script_test.sh" "$result" || return

    # Sanitizing again should produce same result
    result=$(_sanitize_script_name "$result")
    assert_equals "script_test.sh" "$result" || return

    pass_test
}

# Test: Empty and whitespace handling
test_sanitize_empty_whitespace() {
    start_test "Script name sanitization handles edge cases"

    init_logger --quiet

    # Whitespace should be replaced
    local result
    result=$(_sanitize_script_name "script test.sh")
    assert_equals "script_test.sh" "$result" || return

    # Tab should be replaced
    result=$(_sanitize_script_name "script"$'\t'"test.sh")
    assert_equals "script_test.sh" "$result" || return

    # Newline should be replaced
    result=$(_sanitize_script_name "script"$'\n'"test.sh")
    assert_equals "script_test.sh" "$result" || return

    pass_test
}

# Test: Quote characters
test_sanitize_quotes() {
    start_test "Script name sanitization handles quote characters"

    init_logger --quiet

    # Single quotes
    local result
    result=$(_sanitize_script_name "script'test.sh")
    assert_equals "script_test.sh" "$result" || return

    # Double quotes
    result=$(_sanitize_script_name "script\"test.sh")
    assert_equals "script_test.sh" "$result" || return

    # Backticks
    result=$(_sanitize_script_name "script\`test.sh")
    assert_equals "script_test.sh" "$result" || return

    pass_test
}

# Test: Complex real-world attack scenario
test_sanitize_complex_attack() {
    start_test "Script name sanitization handles complex attack patterns"

    init_logger --quiet

    # Simulated attack attempting command injection and log injection
    local malicious_name
    malicious_name='script$(rm -rf /)'"[ERROR].sh"
    local result
    result=$(_sanitize_script_name "$malicious_name")

    # All special chars should be replaced with underscores
    # Should not contain: $ ( ) space / [ ]
    if [[ "$result" =~ [\$\(\)\ /\[\]] ]]; then
        fail_test "Dangerous characters not fully sanitized: $result"
        return 1
    fi

    pass_test
}

# Run all tests
test_sanitize_basic
test_sanitize_attack_patterns
test_sanitize_preserves_valid
test_sanitize_from_bash_source
test_sanitize_cli_option
test_sanitize_config_file
test_sanitize_set_script_name
test_sanitize_in_log_output
test_sanitize_journal_tag
test_sanitize_idempotent
test_sanitize_empty_whitespace
test_sanitize_quotes
test_sanitize_complex_attack
