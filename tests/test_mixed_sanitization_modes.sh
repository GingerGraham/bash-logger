#!/usr/bin/env bash
#
# test_mixed_sanitization_modes.sh - Tests for independent sanitization flag behavior
#
# Tests that LOG_UNSAFE_ALLOW_NEWLINES and LOG_UNSAFE_ALLOW_ANSI_CODES
# work independently and don't create unintended security bypasses.
#
# Regression test for PR #54 comment about mixed-mode scenarios.
#
# Test scenarios:
# 1. Both flags false (default): Strip both newlines and ANSI codes
# 2. Newlines=true, ANSI=false: Preserve newlines, strip ANSI
# 3. Newlines=false, ANSI=true: Strip newlines, preserve ANSI
# 4. Both flags true: Preserve both

# Test: Default mode (both false) strips both newlines and ANSI codes
test_default_mode_strips_both() {
    start_test "Default mode strips both newlines and ANSI codes"

    local input=$'Line1\nLine2 with \e[31mcolor\e[0m'
    local expected="Line1 Line2 with color"

    LOG_UNSAFE_ALLOW_NEWLINES="false"
    LOG_UNSAFE_ALLOW_ANSI_CODES="false"

    local sanitized
    sanitized=$(_sanitize_log_message "$input")

    if [[ "$sanitized" == "$expected" ]]; then
        pass_test
    else
        fail_test "Expected both stripped. Got: '$sanitized', Expected: '$expected'"
    fi
}

# Test: Mixed mode - preserve newlines, strip ANSI
test_preserve_newlines_strip_ansi() {
    start_test "Newlines=true, ANSI=false: Preserve newlines, strip ANSI"

    local input=$'Line1\nLine2 with \e[31mcolor\e[0m and \e[1mbold\e[0m'
    local expected=$'Line1\nLine2 with color and bold'

    LOG_UNSAFE_ALLOW_NEWLINES="true"
    LOG_UNSAFE_ALLOW_ANSI_CODES="false"

    local sanitized
    sanitized=$(_sanitize_log_message "$input")

    if [[ "$sanitized" == "$expected" ]]; then
        pass_test
    else
        fail_test "Newlines should be preserved but ANSI stripped. Got: '$sanitized'"
    fi
}

# Test: Mixed mode - strip newlines, preserve ANSI (though unusual)
test_strip_newlines_preserve_ansi() {
    start_test "Newlines=false, ANSI=true: Strip newlines, preserve ANSI"

    local input=$'Line1\nLine2 with \e[31mcolor\e[0m'
    local expected=$'Line1 Line2 with \e[31mcolor\e[0m'

    LOG_UNSAFE_ALLOW_NEWLINES="false"
    LOG_UNSAFE_ALLOW_ANSI_CODES="true"

    local sanitized
    sanitized=$(_sanitize_log_message "$input")

    if [[ "$sanitized" == "$expected" ]]; then
        pass_test
    else
        fail_test "Newlines should be stripped but ANSI preserved. Got: '$sanitized', Expected: '$expected'"
    fi
}

# Test: Both unsafe flags enabled - preserve everything
test_both_unsafe_modes_preserve_all() {
    start_test "Both flags true: Preserve both newlines and ANSI"

    local input=$'Line1\nLine2 with \e[31mcolor\e[0m'
    local expected="$input"

    LOG_UNSAFE_ALLOW_NEWLINES="true"
    LOG_UNSAFE_ALLOW_ANSI_CODES="true"

    local sanitized
    sanitized=$(_sanitize_log_message "$input")

    if [[ "$sanitized" == "$expected" ]]; then
        pass_test
    else
        fail_test "Both should be preserved. Got: '$sanitized'"
    fi
}

# Test: Mixed mode with carriage returns and tabs
test_preserve_newlines_with_cr_tab() {
    start_test "Newlines=true preserves CR and TAB too"

    local input=$'Line1\rLine2\tColumn with \e[5mflash\e[0m'
    local expected=$'Line1\rLine2\tColumn with flash'

    LOG_UNSAFE_ALLOW_NEWLINES="true"
    LOG_UNSAFE_ALLOW_ANSI_CODES="false"

    local sanitized
    sanitized=$(_sanitize_log_message "$input")

    if [[ "$sanitized" == "$expected" ]]; then
        pass_test
    else
        fail_test "CR and TAB should be preserved, ANSI stripped. Got: '$sanitized'"
    fi
}

# Test: Mixed mode with OSC sequences
test_preserve_newlines_strip_osc_sequences() {
    start_test "Newlines=true, ANSI=false: Strip OSC sequences"

    local input=$'Line1\nTitle:\e]0;Hacked\aContent'
    local expected=$'Line1\nTitle:Content'

    LOG_UNSAFE_ALLOW_NEWLINES="true"
    LOG_UNSAFE_ALLOW_ANSI_CODES="false"

    local sanitized
    sanitized=$(_sanitize_log_message "$input")

    if [[ "$sanitized" == "$expected" ]]; then
        pass_test
    else
        fail_test "OSC sequences should be stripped. Got: '$sanitized'"
    fi
}

# Test: Mixed mode with ST-terminated OSC sequences
test_preserve_newlines_strip_osc_st_terminated() {
    start_test "Newlines=true, ANSI=false: Strip ST-terminated OSC"

    # ST (String Terminator) is ESC \ (0x1b 0x5c)
    local input=$'Line1\nTitle:\e]0;Hacked\e\\Content'
    local expected=$'Line1\nTitle:Content'

    LOG_UNSAFE_ALLOW_NEWLINES="true"
    LOG_UNSAFE_ALLOW_ANSI_CODES="false"

    local sanitized
    sanitized=$(_sanitize_log_message "$input")

    if [[ "$sanitized" == "$expected" ]]; then
        pass_test
    else
        fail_test "ST-terminated OSC should be stripped. Got: '$sanitized'"
    fi
}

# Test: Mixed mode with screen control sequences
test_preserve_newlines_strip_screen_control() {
    start_test "Newlines=true, ANSI=false: Strip screen control"

    local input=$'Error:\nClearing\e[2J\e[H screen'
    local expected=$'Error:\nClearing screen'

    LOG_UNSAFE_ALLOW_NEWLINES="true"
    LOG_UNSAFE_ALLOW_ANSI_CODES="false"

    local sanitized
    sanitized=$(_sanitize_log_message "$input")

    if [[ "$sanitized" == "$expected" ]]; then
        pass_test
    else
        fail_test "Screen control sequences should be stripped. Got: '$sanitized'"
    fi
}

# Test: Runtime configuration change - toggle newlines only
test_runtime_toggle_newlines_only() {
    start_test "Runtime: Toggle newlines flag independently"

    local log_file="$TEST_TMP_DIR/test_runtime_newlines.log"

    source "$PROJECT_ROOT/logging.sh"
    init_logger -l "$log_file" --no-color -q

    # Start with both false
    LOG_UNSAFE_ALLOW_NEWLINES="false"
    LOG_UNSAFE_ALLOW_ANSI_CODES="false"

    # Enable newlines only
    set_unsafe_allow_newlines "true"

    # Verify ANSI codes flag is still false
    if [[ "$LOG_UNSAFE_ALLOW_NEWLINES" == "true" && "$LOG_UNSAFE_ALLOW_ANSI_CODES" == "false" ]]; then
        pass_test
    else
        fail_test "Toggling newlines flag affected ANSI flag"
    fi
}

# Test: Runtime configuration change - toggle ANSI only
test_runtime_toggle_ansi_only() {
    start_test "Runtime: Toggle ANSI flag independently"

    local log_file="$TEST_TMP_DIR/test_runtime_ansi.log"

    source "$PROJECT_ROOT/logging.sh"
    init_logger -l "$log_file" --no-color -q

    # Start with both false
    LOG_UNSAFE_ALLOW_NEWLINES="false"
    LOG_UNSAFE_ALLOW_ANSI_CODES="false"

    # Enable ANSI only
    set_unsafe_allow_ansi_codes "true"

    # Verify newlines flag is still false
    if [[ "$LOG_UNSAFE_ALLOW_ANSI_CODES" == "true" && "$LOG_UNSAFE_ALLOW_NEWLINES" == "false" ]]; then
        pass_test
    else
        fail_test "Toggling ANSI flag affected newlines flag"
    fi
}

# Test: CLI flags set independently
test_cli_flags_independent() {
    start_test "CLI: -U and -A flags work independently"

    local log_file="$TEST_TMP_DIR/test_cli_mixed.log"

    source "$PROJECT_ROOT/logging.sh"
    init_logger -l "$log_file" --no-color -q -U

    # Only -U specified, so only newlines flag should be true
    if [[ "$LOG_UNSAFE_ALLOW_NEWLINES" == "true" && "$LOG_UNSAFE_ALLOW_ANSI_CODES" == "false" ]]; then
        pass_test
    else
        fail_test "-U flag should only affect newlines. ANSI=$LOG_UNSAFE_ALLOW_ANSI_CODES"
    fi
}

# Test: CLI flags can be combined
test_cli_flags_combined() {
    start_test "CLI: -U and -A can be combined"

    local log_file="$TEST_TMP_DIR/test_cli_both.log"

    source "$PROJECT_ROOT/logging.sh"
    init_logger -l "$log_file" --no-color -q -U -A

    if [[ "$LOG_UNSAFE_ALLOW_NEWLINES" == "true" && "$LOG_UNSAFE_ALLOW_ANSI_CODES" == "true" ]]; then
        pass_test
    else
        fail_test "Both flags should be true when -U -A specified"
    fi
}

# Test: Config file sets mixed mode
test_config_file_mixed_mode() {
    start_test "Config file: Set newlines=true, ANSI=false"

    local config_file="$TEST_DIR/logging.conf"
    cat > "$config_file" << 'EOF'
[logging]
unsafe_allow_newlines = true
unsafe_allow_ansi_codes = false
EOF

    source "$PROJECT_ROOT/logging.sh"
    init_logger -q -c "$config_file"

    if [[ "$LOG_UNSAFE_ALLOW_NEWLINES" == "true" && "$LOG_UNSAFE_ALLOW_ANSI_CODES" == "false" ]]; then
        pass_test
    else
        fail_test "Config file should set independent flags"
    fi
}

# Test: Config file reversed mixed mode
test_config_file_reversed_mixed_mode() {
    start_test "Config file: Set newlines=false, ANSI=true"

    local config_file="$TEST_DIR/logging.conf"
    cat > "$config_file" << 'EOF'
[logging]
unsafe_allow_newlines = false
unsafe_allow_ansi_codes = true
EOF

    source "$PROJECT_ROOT/logging.sh"
    init_logger -q -c "$config_file"

    if [[ "$LOG_UNSAFE_ALLOW_NEWLINES" == "false" && "$LOG_UNSAFE_ALLOW_ANSI_CODES" == "true" ]]; then
        pass_test
    else
        fail_test "Config file should set independent flags"
    fi
}

# Test: End-to-end log output with mixed mode
test_e2e_mixed_mode_output() {
    start_test "End-to-end: Mixed mode in actual log output"

    local log_file="$TEST_TMP_DIR/test_e2e_mixed.log"

    source "$PROJECT_ROOT/logging.sh"
    init_logger -l "$log_file" --no-color -q

    # Set mixed mode: preserve newlines, strip ANSI
    LOG_UNSAFE_ALLOW_NEWLINES="true"
    LOG_UNSAFE_ALLOW_ANSI_CODES="false"

    local malicious_message=$'Multi\nLine with \e[31mcolor\e[0m attack'
    log_info "$malicious_message"

    local log_content
    log_content=$(cat "$log_file")

    # Should contain newline but NOT ANSI codes
    if [[ "$log_content" == *$'\n'* ]] && [[ ! "$log_content" =~ $'\e\[' ]]; then
        pass_test
    else
        fail_test "Log should preserve newlines but strip ANSI. Got: $log_content"
    fi
}

# Test: Verify no unintended bypass - newlines flag doesn't affect ANSI stripping
test_no_bypass_newlines_to_ansi() {
    start_test "Security: Newlines=true doesn't bypass ANSI stripping"

    # This is the critical regression test for the bug mentioned in PR #54
    local input=$'\e[31mRED\e[0m Text'
    local expected="RED Text"

    LOG_UNSAFE_ALLOW_NEWLINES="true"
    LOG_UNSAFE_ALLOW_ANSI_CODES="false"

    local sanitized
    sanitized=$(_sanitize_log_message "$input")

    if [[ "$sanitized" == "$expected" ]]; then
        pass_test
    else
        fail_test "CRITICAL: Enabling newlines bypassed ANSI stripping! Got: '$sanitized'"
    fi
}

# Test: Verify no unintended bypass - ANSI flag doesn't affect newline stripping
test_no_bypass_ansi_to_newlines() {
    start_test "Security: ANSI=true doesn't bypass newline stripping"

    local input=$'Line1\nLine2'
    local expected="Line1 Line2"

    LOG_UNSAFE_ALLOW_NEWLINES="false"
    LOG_UNSAFE_ALLOW_ANSI_CODES="true"

    local sanitized
    sanitized=$(_sanitize_log_message "$input")

    if [[ "$sanitized" == "$expected" ]]; then
        pass_test
    else
        fail_test "CRITICAL: Enabling ANSI bypassed newline stripping! Got: '$sanitized'"
    fi
}

# Test: Complex attack scenario - default mode protects against combined attack
test_combined_attack_default_protection() {
    start_test "Security: Default mode protects against combined attack"

    # Simulated attack: fake log entry with newlines and ANSI codes
    local attack=$'Normal message\n[CRITICAL] \e[1;37;41mFAKE ALERT\e[0m System compromised\nReal continuation'
    local expected="Normal message [CRITICAL] FAKE ALERT System compromised Real continuation"

    LOG_UNSAFE_ALLOW_NEWLINES="false"
    LOG_UNSAFE_ALLOW_ANSI_CODES="false"

    local sanitized
    sanitized=$(_sanitize_log_message "$attack")

    if [[ "$sanitized" == "$expected" ]]; then
        pass_test
    else
        fail_test "Combined attack not fully sanitized. Got: '$sanitized'"
    fi
}

# Test: Mixed mode with complex realistic scenario
test_mixed_mode_realistic_scenario() {
    start_test "Realistic: Multiline error with ANSI in mixed mode"

    # Realistic case: Preserving legitimate multiline error messages
    # but stripping potentially malicious ANSI codes
    local input=$'Error stack trace:\n  at function1()\n  \e[31mat function2()\e[0m\n  at main()'
    local expected=$'Error stack trace:\n  at function1()\n  at function2()\n  at main()'

    LOG_UNSAFE_ALLOW_NEWLINES="true"
    LOG_UNSAFE_ALLOW_ANSI_CODES="false"

    local sanitized
    sanitized=$(_sanitize_log_message "$input")

    if [[ "$sanitized" == "$expected" ]]; then
        pass_test
    else
        fail_test "Realistic multiline scenario not handled correctly. Got: '$sanitized'"
    fi
}

# Run all tests
test_default_mode_strips_both
test_preserve_newlines_strip_ansi
test_strip_newlines_preserve_ansi
test_both_unsafe_modes_preserve_all
test_preserve_newlines_with_cr_tab
test_preserve_newlines_strip_osc_sequences
test_preserve_newlines_strip_osc_st_terminated
test_preserve_newlines_strip_screen_control
test_runtime_toggle_newlines_only
test_runtime_toggle_ansi_only
test_cli_flags_independent
test_cli_flags_combined
test_config_file_mixed_mode
test_config_file_reversed_mixed_mode
test_e2e_mixed_mode_output
test_no_bypass_newlines_to_ansi
test_no_bypass_ansi_to_newlines
test_combined_attack_default_protection
test_mixed_mode_realistic_scenario
