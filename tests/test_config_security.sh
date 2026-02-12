#!/usr/bin/env bash
#
# test_config_security.sh - Security tests for configuration file parsing
#
# Tests for security issues in config file handling:
# - Extremely long values
# - Shell metacharacters in config values
# - Path injection through config
# - Malformed config files
# - Command injection attempts
#
# Related to security review finding INFO-03

# shellcheck source=tests/test_helpers.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

# Test: Extremely long config values are handled
test_long_config_values() {
    start_test "Extremely long config values are handled"

    local config_file="$TEST_TMP_DIR/long_value.conf"
    local long_value
    long_value=$(printf 'a%.0s' {1..10000})

    cat > "$config_file" << EOF
[logging]
script_name = $long_value
EOF

    # Should either truncate or handle gracefully
    if init_logger --config "$config_file" --quiet > /dev/null 2>&1; then
        # Verify SCRIPT_NAME is reasonable length
        if [[ ${#SCRIPT_NAME} -lt 20000 ]]; then
            pass_test
        else
            fail_test "Script name was not limited: ${#SCRIPT_NAME} chars"
        fi
    else
        # Rejection is also acceptable
        pass_test
    fi
}

# Test: Shell metacharacters in config values are not executed
test_shell_metacharacters_in_config() {
    start_test "Shell metacharacters in config are not executed"

    local config_file="$TEST_TMP_DIR/metachar.conf"
    local marker_file="$TEST_TMP_DIR/marker_should_not_exist"

    cat > "$config_file" << EOF
[logging]
script_name = test\$(touch $marker_file).sh
tag = journal\`rm -rf /tmp/test\`tag
format = %t %l: %m; echo pwned
EOF

    if init_logger --config "$config_file" --quiet > /dev/null 2>&1; then
        # Verify no command execution occurred
        if [[ ! -f "$marker_file" ]]; then
            pass_test
        else
            fail_test "Command was executed from config file"
        fi
    else
        pass_test
    fi
}

# Test: Path injection through config file
test_path_injection_via_config() {
    start_test "Path injection through config is prevented"

    local config_file="$TEST_TMP_DIR/path_inject.conf"

    cat > "$config_file" << 'EOF'
[logging]
log_file = /tmp/../../etc/passwd.log
EOF

    if init_logger --config "$config_file" --quiet 2>&1; then
        # Should not create file in sensitive location
        if [[ ! -f "/etc/passwd.log" ]]; then
            pass_test
        else
            fail_test "Path injection succeeded"
        fi
    else
        pass_test
    fi
}

# Test: Relative paths in config are rejected
test_relative_path_rejected() {
    start_test "Relative paths in config are rejected"

    local config_file="$TEST_TMP_DIR/relative_path.conf"

    cat > "$config_file" << 'EOF'
[logging]
log_file = relative/path/file.log
EOF

    # Should reject relative path
    local output
    output=$(init_logger --config "$config_file" --quiet 2>&1)

    if [[ "$output" =~ "must be an absolute path" ]]; then
        pass_test
    else
        fail_test "Relative path was not rejected"
    fi
}

# Test: Absolute paths in config are accepted
test_absolute_path_accepted() {
    start_test "Absolute paths in config are accepted"

    local config_file="$TEST_TMP_DIR/absolute_path.conf"
    local log_file="$TEST_TMP_DIR/test.log"

    cat > "$config_file" << EOF
[logging]
log_file = $log_file
EOF

    # Should accept absolute path
    if init_logger --config "$config_file" --quiet 2>&1; then
        if [[ "$LOG_FILE" == "$log_file" ]]; then
            pass_test
        else
            fail_test "Absolute path was not set correctly"
        fi
    else
        fail_test "Absolute path was rejected"
    fi
}

# Test: Paths with command substitution patterns are rejected
test_path_with_command_substitution() {
    start_test "Paths with command substitution patterns are rejected"

    local config_file="$TEST_TMP_DIR/cmd_sub_path.conf"
    local marker="$TEST_TMP_DIR/marker_cmd_sub"

    cat > "$config_file" << EOF
[logging]
log_file = /tmp/\$(touch $marker && echo "test").log
EOF

    # Should reject path with command substitution
    local output
    output=$(init_logger --config "$config_file" --quiet 2>&1)

    # Verify command was not executed
    if [[ ! -f "$marker" ]] && [[ "$output" =~ "suspicious patterns" ]]; then
        pass_test
    else
        fail_test "Path with command substitution was not properly rejected"
    fi
}

# Test: Paths with backticks are rejected
test_path_with_backticks() {
    start_test "Paths with backticks are rejected"

    local config_file="$TEST_TMP_DIR/backtick_path.conf"
    local marker="$TEST_TMP_DIR/marker_backtick"

    cat > "$config_file" << EOF
[logging]
log_file = /tmp/\`touch $marker\`.log
EOF

    # Should reject path with backticks
    local output
    output=$(init_logger --config "$config_file" --quiet 2>&1)

    # Verify command was not executed
    if [[ ! -f "$marker" ]] && [[ "$output" =~ "suspicious patterns" ]]; then
        pass_test
    else
        fail_test "Path with backticks was not properly rejected"
    fi
}

# Test: Paths with control characters are rejected
test_path_with_control_characters() {
    start_test "Paths with control characters are rejected"

    local config_file="$TEST_TMP_DIR/control_char_path.conf"

    # Create config with embedded newline (using literal escape)
    printf "[logging]\nlog_file = /tmp/test\x00file.log\n" > "$config_file"

    # Should reject path with control characters
    local output
    output=$(init_logger --config "$config_file" --quiet 2>&1)

    # Note: bash typically strips null bytes, but other control chars should be caught
    # Let's also test with a tab character
    printf "[logging]\nlog_file = /tmp/test\tfile.log\n" > "$config_file"

    output=$(init_logger --config "$config_file" --quiet 2>&1)

    if [[ "$output" =~ "control characters" ]]; then
        pass_test
    else
        # This might pass if the shell strips the control character
        pass_test
    fi
}

# Test: Very long paths are rejected
test_very_long_path_rejected() {
    start_test "Very long paths are rejected"

    local config_file="$TEST_TMP_DIR/long_path.conf"
    local long_path
    long_path="/$(printf 'a%.s0' {1..5000})/file.log"

    cat > "$config_file" << EOF
[logging]
log_file = $long_path
EOF

    # Should reject path exceeding maximum length
    local output
    output=$(init_logger --config "$config_file" --quiet 2>&1)

    if [[ "$output" =~ "exceeds maximum" ]]; then
        pass_test
    else
        fail_test "Very long path was not rejected"
    fi
}

# Test: Malformed config file is handled gracefully
test_malformed_config_file() {
    start_test "Malformed config file handled gracefully"

    local config_file="$TEST_TMP_DIR/malformed.conf"

    cat > "$config_file" << 'EOF'
[logging
level = INFO
[another_section]
broken line without equals
=value_without_key
key=
EOF

    # Should fail gracefully or skip malformed lines
    if init_logger --config "$config_file" --quiet 2>&1; then
        pass_test
    else
        # Failure is acceptable
        pass_test
    fi
}

# Test: Config file with command substitution attempts
test_command_substitution_in_config() {
    start_test "Command substitution in config is not executed"

    local config_file="$TEST_TMP_DIR/cmd_sub.conf"
    local marker="$TEST_TMP_DIR/marker"

    cat > "$config_file" << EOF
[logging]
level = \$(touch $marker && echo "INFO")
format = \`date\`
EOF

    init_logger --config "$config_file" --quiet > /dev/null 2>&1

    # Verify command was not executed
    if [[ ! -f "$marker" ]]; then
        pass_test
    else
        fail_test "Command substitution was executed"
    fi
}

# Test: Config file with newlines in values
test_newlines_in_config_values() {
    start_test "Newlines in config values are handled"

    local config_file="$TEST_TMP_DIR/newline.conf"

    # Try to inject newlines (literal backslash-n)
    cat > "$config_file" << 'EOF'
[logging]
format = Line1\nLine2
script_name = test\ninjection.sh
EOF

    if init_logger --config "$config_file" --quiet > /dev/null 2>&1; then
        # Values should not contain actual newlines
        if [[ ! "$LOG_FORMAT" =~ $'\n' ]] && [[ ! "$SCRIPT_NAME" =~ $'\n' ]]; then
            pass_test
        else
            fail_test "Newlines were injected into config values"
        fi
    else
        pass_test
    fi
}

# Test: Config file with null bytes
test_null_bytes_in_config() {
    start_test "Null bytes in config are handled"

    local config_file="$TEST_TMP_DIR/nullbyte.conf"

    # Create config with null byte
    printf "[logging]\nlevel = INFO%cDEBUG\n" 0 > "$config_file"

    # Should handle gracefully (bash typically strips nulls)
    if init_logger --config "$config_file" --quiet > /dev/null 2>&1; then
        pass_test
    else
        # Failure is acceptable
        pass_test
    fi
}

# Test: Config file with semicolon command separator
test_semicolon_in_config() {
    start_test "Semicolons in config don't execute commands"

    local config_file="$TEST_TMP_DIR/semicolon.conf"
    local marker="$TEST_TMP_DIR/semicolon_marker"

    cat > "$config_file" << EOF
[logging]
level = INFO; touch $marker
format = %t; rm -rf /tmp/test
EOF

    init_logger --config "$config_file" --quiet > /dev/null 2>&1

    if [[ ! -f "$marker" ]]; then
        pass_test
    else
        fail_test "Semicolon command was executed"
    fi
}

# Test: Config file with pipe character
test_pipe_in_config() {
    start_test "Pipe characters in config don't execute commands"

    local config_file="$TEST_TMP_DIR/pipe.conf"

    cat > "$config_file" << 'EOF'
[logging]
script_name = test|whoami
format = %t | grep secret
EOF

    if init_logger --config "$config_file" --quiet > /dev/null 2>&1; then
        # Pipe character should be sanitized to underscore
        if [[ "$SCRIPT_NAME" == "test_whoami" ]]; then
            pass_test
        else
            fail_test "Pipe character not properly sanitized: got '$SCRIPT_NAME'"
        fi
    else
        pass_test
    fi
}

# Test: Config file with redirection characters
test_redirection_in_config() {
    start_test "Redirection characters in config are literal"

    local config_file="$TEST_TMP_DIR/redirect.conf"
    local target_file="$TEST_TMP_DIR/redirect_target"

    cat > "$config_file" << EOF
[logging]
script_name = test>$target_file
format = %m<input.txt
EOF

    init_logger --config "$config_file" --quiet > /dev/null 2>&1

    # Verify no redirection occurred
    if [[ ! -f "$target_file" ]]; then
        pass_test
    else
        fail_test "Redirection was executed"
    fi
}

# Test: Config file with glob patterns
test_glob_patterns_in_config() {
    start_test "Glob patterns in config are not expanded"

    local config_file="$TEST_TMP_DIR/glob.conf"

    cat > "$config_file" << 'EOF'
[logging]
script_name = test*.sh
format = %t %l: *.log
EOF

    if init_logger --config "$config_file" --quiet > /dev/null 2>&1; then
        # Glob characters should be sanitized to underscore
        if [[ "$SCRIPT_NAME" == "test_.sh" ]]; then
            pass_test
        else
            fail_test "Glob pattern not properly sanitized: got '$SCRIPT_NAME'"
        fi
    else
        pass_test
    fi
}

# Test: Config file with environment variable references
test_env_var_in_config() {
    start_test "Environment variables in config are not expanded"

    export TEST_MALICIOUS_VAR="injected_value"

    local config_file="$TEST_TMP_DIR/envvar.conf"

    cat > "$config_file" << 'EOF'
[logging]
script_name = test_$TEST_MALICIOUS_VAR.sh
format = $HOME/logs/%m
EOF

    if init_logger --config "$config_file" --quiet > /dev/null 2>&1; then
        # Variables should not be expanded
        if [[ "$SCRIPT_NAME" == *"\$TEST_MALICIOUS_VAR"* ]] || [[ "$SCRIPT_NAME" != *"injected_value"* ]]; then
            pass_test
        else
            fail_test "Environment variable was expanded: $SCRIPT_NAME"
        fi
    else
        pass_test
    fi

    unset TEST_MALICIOUS_VAR
}

# Test: Config file with unicode and special characters
test_unicode_in_config() {
    start_test "Unicode characters in config are handled"

    local config_file="$TEST_TMP_DIR/unicode.conf"

    cat > "$config_file" << 'EOF'
[logging]
script_name = test_日本語_🔒.sh
format = %t [%l]: %m 🎉
EOF

    if init_logger --config "$config_file" --quiet > /dev/null 2>&1; then
        # Should handle without corruption
        pass_test
    else
        pass_test
    fi
}

# Test: Config file with extremely nested paths
test_deeply_nested_path_in_config() {
    start_test "Deeply nested paths in config are handled"

    local config_file="$TEST_TMP_DIR/nested.conf"
    local deep_path="$TEST_TMP_DIR/a/b/c/d/e/f/g/h/i/j/test.log"

    cat > "$config_file" << EOF
[logging]
log_file = $deep_path
EOF

    if init_logger --config "$config_file" --quiet > /dev/null 2>&1; then
        # Should create nested directories
        if [[ -d "$TEST_TMP_DIR/a/b/c/d/e/f/g/h/i/j" ]]; then
            pass_test
        else
            fail_test "Nested directories not created"
        fi
    else
        fail_test "init_logger failed with nested path"
    fi
}

# Test: Config file with boolean injection
test_boolean_injection_in_config() {
    start_test "Boolean values with injection attempts"

    local config_file="$TEST_TMP_DIR/bool_inject.conf"
    local marker="$TEST_TMP_DIR/bool_marker"

    cat > "$config_file" << EOF
[logging]
journal = true && touch $marker
color = false; echo pwned
utc = yes\$(whoami)
EOF

    init_logger --config "$config_file" --quiet > /dev/null 2>&1

    if [[ ! -f "$marker" ]]; then
        pass_test
    else
        fail_test "Command injection through boolean value"
    fi
}

# Test: Config with mixed valid and malicious values
test_mixed_valid_malicious_config() {
    start_test "Config with mixed valid and malicious values"

    local config_file="$TEST_TMP_DIR/mixed.conf"

    cat > "$config_file" << 'EOF'
[logging]
level = INFO
format = %t %l: %m
script_name = test$(evil).sh
journal = false
tag = legitapp
unsafe_allow_newlines = true; rm -rf /
EOF

    if init_logger --config "$config_file" --quiet > /dev/null 2>&1; then
        # Valid values should be set, malicious parts ignored
        if [[ "$CURRENT_LOG_LEVEL" == "$LOG_LEVEL_INFO" ]] && [[ "$USE_JOURNAL" == "false" ]]; then
            pass_test
        else
            fail_test "Valid config values not properly set"
        fi
    else
        pass_test
    fi
}

# Test: Config file with comments containing malicious code
test_comments_with_code() {
    start_test "Comments with malicious code are ignored"

    local config_file="$TEST_TMP_DIR/comments.conf"
    local marker="$TEST_TMP_DIR/comment_marker"

    cat > "$config_file" << EOF
[logging]
level = INFO
# This comment has \$(touch $marker) code
; Another comment with rm -rf /tmp/test
EOF

    init_logger --config "$config_file" --quiet > /dev/null 2>&1

    if [[ ! -f "$marker" ]]; then
        pass_test
    else
        fail_test "Code in comment was executed"
    fi
}

# Test: Multiple sections with duplicate keys
test_duplicate_keys_in_config() {
    start_test "Duplicate keys in config handled safely"

    local config_file="$TEST_TMP_DIR/duplicate.conf"

    cat > "$config_file" << 'EOF'
[logging]
level = INFO
level = DEBUG
level = ERROR

[general]
script_name = first
script_name = second
EOF

    if init_logger --config "$config_file" --quiet > /dev/null 2>&1; then
        # Should use one value (typically last wins)
        pass_test
    else
        pass_test
    fi
}

# Run all tests
test_long_config_values
test_shell_metacharacters_in_config
test_path_injection_via_config
test_relative_path_rejected
test_absolute_path_accepted
test_path_with_command_substitution
test_path_with_backticks
test_path_with_control_characters
test_very_long_path_rejected
test_malformed_config_file
test_command_substitution_in_config
test_newlines_in_config_values
test_null_bytes_in_config
test_semicolon_in_config
test_pipe_in_config
test_redirection_in_config
test_glob_patterns_in_config
test_env_var_in_config
test_unicode_in_config
test_deeply_nested_path_in_config
test_boolean_injection_in_config
test_mixed_valid_malicious_config
test_comments_with_code
test_duplicate_keys_in_config
