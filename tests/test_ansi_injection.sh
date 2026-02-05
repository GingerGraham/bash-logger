#!/usr/bin/env bash
#
# test_ansi_injection.sh - Tests for ANSI code injection prevention (Issue #36)
#
# Tests that malicious ANSI escape sequences are stripped from user input
# while library-generated ANSI codes (colors) are preserved.
#
# Tests:
# - Default mode sanitizes CSI sequences
# - Default mode sanitizes OSC sequences
# - Multiple ANSI sequences are stripped
# - Unsafe flag can be enabled via CLI
# - Unsafe flag can be enabled via config file
# - Unsafe flag can be toggled at runtime
# - Unsafe mode preserves ANSI codes (not recommended)
# - Library color output is not affected

# Setup before running any tests
setup_test_suite

# Test: Default mode strips CSI color sequences
test_default_strips_csi_sequences() {
    start_test "Default mode strips CSI color sequences"

    local malicious_input=$'\e[31m\e[1mRED\e[0m'
    local expected="RED"

    LOG_UNSAFE_ALLOW_ANSI_CODES="false"
    local sanitized
    sanitized=$(_strip_ansi_codes "$malicious_input")

    if [[ "$sanitized" == "$expected" ]]; then
        pass_test
    else
        fail_test "CSI sequences not stripped: got '$sanitized' expected '$expected'"
    fi
}

# Test: Default mode strips screen control sequences
test_default_strips_screen_control() {
    start_test "Default mode strips screen control sequences"

    local malicious_input=$'Error:\e[2J\e[H'
    local expected="Error:"

    LOG_UNSAFE_ALLOW_ANSI_CODES="false"
    local sanitized
    sanitized=$(_strip_ansi_codes "$malicious_input")

    if [[ "$sanitized" == "$expected" ]]; then
        pass_test
    else
        fail_test "Screen control sequences not stripped: got '$sanitized' expected '$expected'"
    fi
}

# Test: Default mode strips OSC sequences
test_default_strips_osc_sequences() {
    start_test "Default mode strips OSC sequences"

    local malicious_input=$'Title:\e]0;Hacked\aContent'
    local expected="Title:Content"

    LOG_UNSAFE_ALLOW_ANSI_CODES="false"
    local sanitized
    sanitized=$(_strip_ansi_codes "$malicious_input")

    if [[ "$sanitized" == "$expected" ]]; then
        pass_test
    else
        fail_test "OSC sequences not stripped: got '$sanitized' expected '$expected'"
    fi
}

# Test: Multiple different ANSI sequences are stripped
test_multiple_ansi_sequences_stripped() {
    start_test "Multiple ANSI sequences are stripped"

    local malicious_input=$'\e[31m\e[1m\e[5mFLASH\e[0mNormal\e]0;WIN\a'
    local expected="FLASHNormal"

    LOG_UNSAFE_ALLOW_ANSI_CODES="false"
    local sanitized
    sanitized=$(_strip_ansi_codes "$malicious_input")

    if [[ "$sanitized" == "$expected" ]]; then
        pass_test
    else
        fail_test "Not all sequences stripped: got '$sanitized' expected '$expected'"
    fi
}

# Test: ANSI codes in message get stripped in log output
test_ansi_codes_stripped_in_output() {
    start_test "ANSI codes stripped in final log output"

    local log_file="$TEST_TMP_DIR/test_ansi_output.log"


    source "$PROJECT_ROOT/logging.sh"
    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    local malicious_message="\e[31mRED\e[0m Text"
    log_info "Message: $malicious_message"

    local log_content
    log_content=$(tail -1 "$log_file")

    # Verify message is in log and ANSI codes are stripped
    if [[ "$log_content" =~ "Message:" ]] && [[ ! "$log_content" =~ $'\e\[' ]]; then
        pass_test
    else
        fail_test "ANSI codes were not stripped in output: $log_content"
    fi
}

# Test: Unsafe mode preserves ANSI codes
test_unsafe_mode_preserves_ansi() {
    start_test "Unsafe mode preserves ANSI codes"

    local malicious_input=$'\e[31mRED\e[0m'

    LOG_UNSAFE_ALLOW_ANSI_CODES="true"
    local result
    result=$(_strip_ansi_codes "$malicious_input")

    if [[ "$result" == "$malicious_input" ]]; then
        pass_test
    else
        fail_test "Unsafe mode did not preserve ANSI codes"
    fi
}

# Test: CLI flag -A enables unsafe ANSI mode
test_cli_flag_a_unsafe_mode() {
    start_test "CLI flag -A enables unsafe ANSI mode"

    local log_file="$TEST_TMP_DIR/test_cli_unsafe.log"

    source "$PROJECT_ROOT/logging.sh"
    init_logger -l "$log_file" --no-color -A > /dev/null 2>&1

    if [[ "$LOG_UNSAFE_ALLOW_ANSI_CODES" == "true" ]]; then
        pass_test
    else
        fail_test "CLI flag -A did not set unsafe mode"
    fi
}

# Test: CLI flag --unsafe-allow-ansi-codes enables unsafe ANSI mode
test_cli_long_flag_unsafe() {
    start_test "CLI flag --unsafe-allow-ansi-codes enables unsafe mode"

    local log_file="$TEST_TMP_DIR/test_cli_long_unsafe.log"

    source "$PROJECT_ROOT/logging.sh"
    init_logger -l "$log_file" --no-color --unsafe-allow-ansi-codes > /dev/null 2>&1

    if [[ "$LOG_UNSAFE_ALLOW_ANSI_CODES" == "true" ]]; then
        pass_test
    else
        fail_test "Long flag did not set unsafe mode"
    fi
}

# Test: Config file can set unsafe ANSI mode
test_config_file_unsafe_ansi() {
    start_test "Config file sets unsafe ANSI mode"

    local config_file="$TEST_TMP_DIR/test_ansi.conf"
    local log_file="$TEST_TMP_DIR/test_ansi.log"

    cat > "$config_file" <<EOF
[logging]
unsafe_allow_ansi_codes=true
log_file=$log_file
EOF

    source "$PROJECT_ROOT/logging.sh"
    init_logger -c "$config_file" --no-color > /dev/null 2>&1

    if [[ "$LOG_UNSAFE_ALLOW_ANSI_CODES" == "true" ]]; then
        pass_test
    else
        fail_test "Config file did not set unsafe ANSI mode"
    fi
}

# Test: set_unsafe_allow_ansi_codes enables unsafe mode
test_setter_enable_unsafe() {
    start_test "set_unsafe_allow_ansi_codes enables unsafe mode"

    local log_file="$TEST_TMP_DIR/test_setter_enable.log"

    source "$PROJECT_ROOT/logging.sh"
    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    if [[ "$LOG_UNSAFE_ALLOW_ANSI_CODES" != "true" ]]; then
        set_unsafe_allow_ansi_codes "true" > /dev/null 2>&1

        if [[ "$LOG_UNSAFE_ALLOW_ANSI_CODES" == "true" ]]; then
            pass_test
        else
            fail_test "set_unsafe_allow_ansi_codes did not enable"
        fi
    else
        fail_test "Unexpected initial state"
    fi
}

# Test: set_unsafe_allow_ansi_codes disables unsafe mode
test_setter_disable_unsafe() {
    start_test "set_unsafe_allow_ansi_codes disables unsafe mode"

    local log_file="$TEST_TMP_DIR/test_setter_disable.log"

    source "$PROJECT_ROOT/logging.sh"
    init_logger -l "$log_file" --no-color -A > /dev/null 2>&1

    if [[ "$LOG_UNSAFE_ALLOW_ANSI_CODES" == "true" ]]; then
        set_unsafe_allow_ansi_codes "false" > /dev/null 2>&1

        if [[ "$LOG_UNSAFE_ALLOW_ANSI_CODES" == "false" ]]; then
            pass_test
        else
            fail_test "set_unsafe_allow_ansi_codes did not disable"
        fi
    else
        fail_test "Unexpected initial state"
    fi
}

# Test: Default mode is secure (false)
test_default_is_secure() {
    start_test "Default ANSI mode is secure"

    local log_file="$TEST_TMP_DIR/test_default_secure.log"

    source "$PROJECT_ROOT/logging.sh"
    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    if [[ "$LOG_UNSAFE_ALLOW_ANSI_CODES" == "false" ]]; then
        pass_test
    else
        fail_test "Default ANSI mode is not secure"
    fi
}

# Test: Sanitize function integrates with _sanitize_log_message
test_sanitize_integration() {
    start_test "ANSI stripping integrates with _sanitize_log_message"

    local message_with_ansi=$'\e[31mRED\e[0m Text'
    local message_with_newline=$'Line1\nLine2'

    # shellcheck disable=SC2034
    LOG_UNSAFE_ALLOW_NEWLINES="false"
    LOG_UNSAFE_ALLOW_ANSI_CODES="false"
    local sanitized
    sanitized=$(_sanitize_log_message "$message_with_ansi$message_with_newline")

    # Should have both ANSI codes and newlines stripped
    if [[ ! "$sanitized" =~ $'\e' ]] && [[ ! "$sanitized" =~ $'\n' ]]; then
        pass_test
    else
        fail_test "Integration failed: $sanitized"
    fi
}

# Run all tests
test_default_strips_csi_sequences
test_default_strips_screen_control
test_default_strips_osc_sequences
test_multiple_ansi_sequences_stripped
test_ansi_codes_stripped_in_output
test_unsafe_mode_preserves_ansi
test_cli_flag_a_unsafe_mode
test_cli_long_flag_unsafe
test_config_file_unsafe_ansi
test_setter_enable_unsafe
test_setter_disable_unsafe
test_default_is_secure
test_sanitize_integration

# Cleanup after running all tests
cleanup_test_suite

