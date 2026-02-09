#!/usr/bin/env bash
#
# test_unsafe_newlines.sh - Tests for log injection prevention and unsafe flag
#
# Tests:
# - Default sanitization prevents log injection
# - Newline, carriage return, and tab characters are sanitized
# - Unsafe flag can be enabled via CLI
# - Unsafe flag can be enabled via config file
# - Unsafe flag can be toggled at runtime
# - Unsafe mode preserves newlines (not recommended)

# Test: Default mode sanitizes newlines
test_default_sanitizes_newlines() {
    start_test "Default mode sanitizes newlines"

    local malicious_input=$'First line\nSecond line'
    local expected="First line Second line"

    LOG_UNSAFE_ALLOW_NEWLINES="false"
    local sanitized
    sanitized=$(_sanitize_log_message "$malicious_input")

    if [[ "$sanitized" == "$expected" ]]; then
        pass_test
    else
        fail_test "Newline was not sanitized: $sanitized"
    fi
}

# Test: Default mode sanitizes carriage returns
test_default_sanitizes_carriage_returns() {
    start_test "Default mode sanitizes carriage returns"

    local malicious_input=$'First line\rSecond line'
    local expected="First line Second line"

    LOG_UNSAFE_ALLOW_NEWLINES="false"
    local sanitized
    sanitized=$(_sanitize_log_message "$malicious_input")

    if [[ "$sanitized" == "$expected" ]]; then
        pass_test
    else
        fail_test "Carriage return was not sanitized: $sanitized"
    fi
}

# Test: Default mode sanitizes tabs
test_default_sanitizes_tabs() {
    start_test "Default mode sanitizes tabs"

    local malicious_input=$'Column1\tColumn2'
    local expected="Column1 Column2"

    LOG_UNSAFE_ALLOW_NEWLINES="false"
    local sanitized
    sanitized=$(_sanitize_log_message "$malicious_input")

    if [[ "$sanitized" == "$expected" ]]; then
        pass_test
    else
        fail_test "Tab character was not sanitized: $sanitized"
    fi
}

# Test: Unsafe flag is disabled by default
test_unsafe_flag_disabled_by_default() {
    start_test "Unsafe flag is disabled by default"

    [[ "$LOG_UNSAFE_ALLOW_NEWLINES" == "false" ]] || {
        fail_test "LOG_UNSAFE_ALLOW_NEWLINES should default to false"
        return
    }

    pass_test
}

# Test: CLI flag -U enables unsafe mode
test_cli_short_flag_unsafe() {
    start_test "CLI flag -U enables unsafe mode"

    init_logger -q -U

    [[ "$LOG_UNSAFE_ALLOW_NEWLINES" == "true" ]] || {
        fail_test "LOG_UNSAFE_ALLOW_NEWLINES should be true after -U flag"
        return
    }

    pass_test
}

# Test: CLI flag --unsafe-allow-newlines enables unsafe mode
test_cli_long_flag_unsafe() {
    start_test "CLI flag --unsafe-allow-newlines enables unsafe mode"

    init_logger -q --unsafe-allow-newlines

    [[ "$LOG_UNSAFE_ALLOW_NEWLINES" == "true" ]] || {
        fail_test "LOG_UNSAFE_ALLOW_NEWLINES should be true after --unsafe-allow-newlines flag"
        return
    }

    pass_test
}

# Test: Unsafe mode preserves newlines
test_unsafe_mode_preserves_newlines() {
    start_test "Unsafe mode preserves newlines"

    local malicious_input=$'First line\nInjected critical message'

    LOG_UNSAFE_ALLOW_NEWLINES="true"
    local sanitized
    sanitized=$(_sanitize_log_message "$malicious_input")

    if [[ "$sanitized" == "$malicious_input" ]]; then
        pass_test
    else
        fail_test "Newline was not preserved in unsafe mode: $sanitized"
    fi
}

# Test: Config file sets unsafe mode
test_config_file_unsafe() {
    start_test "Config file sets unsafe mode"

    # Create a config file with unsafe_allow_newlines=true
    local config_file="$TEST_DIR/logging.conf"
    cat > "$config_file" << 'EOF'
[logging]
unsafe_allow_newlines = true
EOF

    init_logger -q -c "$config_file"

    [[ "$LOG_UNSAFE_ALLOW_NEWLINES" == "true" ]] || {
        fail_test "Config file did not set unsafe mode"
        return
    }

    pass_test
}

# Test: Config file accepts alternative key names
test_config_file_unsafe_alternative_keys() {
    start_test "Config file accepts unsafe-allow-newlines variant"

    local config_file="$TEST_DIR/logging.conf"
    cat > "$config_file" << 'EOF'
[logging]
unsafe-allow-newlines = true
EOF

    init_logger -q -c "$config_file"

    [[ "$LOG_UNSAFE_ALLOW_NEWLINES" == "true" ]] || {
        fail_test "Config file did not recognize unsafe-allow-newlines key"
        return
    }

    pass_test
}

# Test: Config file accepts various boolean formats
test_config_file_unsafe_boolean_formats() {
    start_test "Config file accepts various boolean formats for unsafe mode"

    for value in "true" "yes" "1" "on"; do
        # Reset for each iteration
        # shellcheck disable=SC2034
        CONSOLE_LOG="true"
        LOG_UNSAFE_ALLOW_NEWLINES="false"

        local config_file="$TEST_DIR/logging_${value}.conf"
        cat > "$config_file" << EOF
[logging]
unsafe_allow_newlines = $value
EOF

        init_logger -q -c "$config_file"

        [[ "$LOG_UNSAFE_ALLOW_NEWLINES" == "true" ]] || {
            fail_test "Config file did not recognize '$value' as true"
            return
        }
    done

    pass_test
}

# Test: Config file false values disable unsafe mode
test_config_file_unsafe_false_values() {
    start_test "Config file false values disable unsafe mode"

    for value in "false" "no" "0" "off"; do
        # Start with unsafe mode enabled
        LOG_UNSAFE_ALLOW_NEWLINES="true"

        local config_file="$TEST_DIR/logging_false_${value}.conf"
        cat > "$config_file" << EOF
[logging]
unsafe_allow_newlines = $value
EOF

        init_logger -q -c "$config_file"

        [[ "$LOG_UNSAFE_ALLOW_NEWLINES" == "false" ]] || {
            fail_test "Config file did not recognize '$value' as false"
            return
        }
    done

    pass_test
}

# Test: set_unsafe_allow_newlines enables unsafe mode
test_runtime_function_enable() {
    start_test "set_unsafe_allow_newlines enables unsafe mode"

    init_logger -q
    [[ "$LOG_UNSAFE_ALLOW_NEWLINES" == "false" ]] || {
        fail_test "Should start with unsafe mode disabled"
        return
    }

    set_unsafe_allow_newlines "true" >"$TEST_STDOUT" 2>"$TEST_STDERR"

    [[ "$LOG_UNSAFE_ALLOW_NEWLINES" == "true" ]] || {
        fail_test "set_unsafe_allow_newlines did not enable unsafe mode"
        return
    }

    pass_test
}

# Test: set_unsafe_allow_newlines disables unsafe mode
test_runtime_function_disable() {
    start_test "set_unsafe_allow_newlines disables unsafe mode"

    LOG_UNSAFE_ALLOW_NEWLINES="true"
    init_logger -q

    set_unsafe_allow_newlines "false" >"$TEST_STDOUT" 2>"$TEST_STDERR"

    [[ "$LOG_UNSAFE_ALLOW_NEWLINES" == "false" ]] || {
        fail_test "set_unsafe_allow_newlines did not disable unsafe mode"
        return
    }

    pass_test
}

# Test: set_unsafe_allow_newlines logging includes warning for unsafe
test_runtime_function_logs_warning() {
    start_test "set_unsafe_allow_newlines logs warning when enabling unsafe mode"

    local log_file="$TEST_DIR/unsafe_warning.log"
    LOG_FILE="$log_file"
    CONSOLE_LOG="false"
    USE_JOURNAL="false"

    set_unsafe_allow_newlines "true"

    if grep -q "WARNING" "$log_file"; then
        pass_test
    else
        fail_test "Warning text not written to log file"
    fi
}

# Test: CLI flag overrides config file
test_cli_flag_overrides_config() {
    start_test "CLI flag overrides config file"

    # Create config with safe mode
    local config_file="$TEST_DIR/logging.conf"
    cat > "$config_file" << 'EOF'
[logging]
unsafe_allow_newlines = false
EOF

    # Use CLI flag to enable unsafe
    init_logger -q -c "$config_file" -U

    [[ "$LOG_UNSAFE_ALLOW_NEWLINES" == "true" ]] || {
        fail_test "CLI flag did not override config file"
        return
    }

    pass_test
}

# Test: set_unsafe_allow_newlines writes to log file
# This exercises the file output branch

test_runtime_function_writes_to_file() {
    start_test "set_unsafe_allow_newlines writes to log file"

    local log_file="$TEST_DIR/unsafe_file.log"
    LOG_FILE="$log_file"
    CONSOLE_LOG="false"
    USE_JOURNAL="false"

    set_unsafe_allow_newlines "true"

    if [[ -s "$log_file" ]]; then
        pass_test
    else
        fail_test "Log file was not written"
    fi
}

# Test: set_unsafe_allow_newlines console color branches
# This exercises both color and non-color output paths

test_runtime_function_color_branches() {
    start_test "set_unsafe_allow_newlines console color branches"

    CONSOLE_LOG="true"
    USE_COLORS="always"
    USE_JOURNAL="false"

    set_unsafe_allow_newlines "true"

    # shellcheck disable=SC2034
    USE_COLORS="never"
    set_unsafe_allow_newlines "false"

    pass_test
}

# Test: set_unsafe_allow_newlines journal logging branch
# This uses a stubbed logger function to avoid external dependencies

test_runtime_function_journal_logging() {
    start_test "set_unsafe_allow_newlines journal logging branch"

    LOG_TEST_LOGGER_CALLED=0
    logger() {
        LOG_TEST_LOGGER_CALLED=$((LOG_TEST_LOGGER_CALLED + 1))
    }

    # shellcheck disable=SC2034
    USE_JOURNAL="true"
    # shellcheck disable=SC2034
    CONSOLE_LOG="false"
    # shellcheck disable=SC2034
    LOG_FILE=""

    set_unsafe_allow_newlines "true"

    if [[ "$LOG_TEST_LOGGER_CALLED" -ge 1 ]]; then
        pass_test
    else
        fail_test "Logger command was not invoked"
    fi

    unset -f logger
}

# Test: Log injection scenario - sanitized
test_log_injection_scenario_sanitized() {
    start_test "Log injection scenario - sanitized in default mode"

    # Simulate attacker input
    local user_input=$'Message from user\n[CRITICAL] Admin logged in as root'

    # Create a log file
    local log_file="$TEST_DIR/injection_test.log"

    init_logger -q -l "$log_file"
    log_info "User submitted: $user_input"

    # Read the log file
    local log_content
    log_content=$(cat "$log_file")

    # Should not have multiple log entries on separate lines
    # Both messages should be on same line
    if echo "$log_content" | grep -q "Message from user.*Admin logged in"; then
        pass_test
    else
        fail_test "Log injection not properly sanitized: $log_content"
    fi
}

# Test: Multiple control characters are all sanitized
test_multiple_control_characters() {
    start_test "Multiple control characters are all sanitized"

    local malicious=$'Line1\nLine2\rLine3\tLine4'
    local expected="Line1 Line2 Line3 Line4"

    LOG_UNSAFE_ALLOW_NEWLINES="false"
    local sanitized
    sanitized=$(_sanitize_log_message "$malicious")

    if [[ "$sanitized" == "$expected" ]]; then
        pass_test
    else
        fail_test "Control characters not fully sanitized: $sanitized"
    fi
}

# Run all tests
test_default_sanitizes_newlines
test_default_sanitizes_carriage_returns
test_default_sanitizes_tabs
test_unsafe_flag_disabled_by_default
test_cli_short_flag_unsafe
test_cli_long_flag_unsafe
test_unsafe_mode_preserves_newlines
test_config_file_unsafe
test_config_file_unsafe_alternative_keys
test_config_file_unsafe_boolean_formats
test_config_file_unsafe_false_values
test_runtime_function_enable
test_runtime_function_disable
test_runtime_function_logs_warning
test_cli_flag_overrides_config
test_runtime_function_writes_to_file
test_runtime_function_color_branches
test_runtime_function_journal_logging
test_log_injection_scenario_sanitized
test_multiple_control_characters
