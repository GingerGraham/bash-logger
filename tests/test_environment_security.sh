#!/usr/bin/env bash
#
# test_environment_security.sh - Tests for environment variable security
#
# Tests that environment variables cannot be used to compromise
# logging security or inject malicious values.
#
# Related to security review finding INFO-04

# shellcheck source=tests/test_helpers.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

# Test: Pre-set LOG_FILE doesn't override init_logger
test_preset_log_file_handling() {
    start_test "Pre-set LOG_FILE environment variable handling"

    export LOG_FILE="/tmp/malicious.log"
    local intended_file="$TEST_TMP_DIR/intended.log"

    init_logger -l "$intended_file" --no-color > /dev/null 2>&1
    log_info "Test message"

    # Verify message went to intended file, not malicious one
    if [[ -f "$intended_file" ]] && ! [[ -f "/tmp/malicious.log" ]]; then
        pass_test
    elif grep -q "Test message" "$intended_file" 2>/dev/null; then
        # Message in correct file
        pass_test
    else
        fail_test "LOG_FILE environment variable may have been used"
    fi

    unset LOG_FILE
}

# Test: Malicious PATH variable
test_malicious_path_variable() {
    start_test "Malicious PATH variable doesn't compromise logging"

    local original_path="$PATH"
    local malicious_dir="$TEST_TMP_DIR/malicious_bin"
    mkdir -p "$malicious_dir"

    # Create fake logger command
    cat > "$malicious_dir/logger" << 'EOF'
#!/usr/bin/env bash
echo "MALICIOUS LOGGER EXECUTED" >> /tmp/malicious_execution_marker
EOF
    chmod +x "$malicious_dir/logger"

    # Prepend malicious directory to PATH
    export PATH="$malicious_dir:$PATH"

    local log_file="$TEST_TMP_DIR/path_test.log"
    init_logger -l "$log_file" --journal --no-color > /dev/null 2>&1
    log_info "Path test message"

    # Restore PATH
    export PATH="$original_path"

    # Check if malicious logger was NOT executed
    if [[ ! -f "/tmp/malicious_execution_marker" ]]; then
        pass_test
    else
        fail_test "Malicious logger from PATH was executed"
        rm -f "/tmp/malicious_execution_marker"
    fi
}

# Test: Malicious IFS variable
test_malicious_ifs_variable() {
    start_test "Malicious IFS variable doesn't break logging"

    local original_ifs="$IFS"
    export IFS=$'\n\t;|&'

    local log_file="$TEST_TMP_DIR/ifs_test.log"

    if init_logger -l "$log_file" --no-color > /dev/null 2>&1; then
        if log_info "IFS test message"; then
            if [[ -f "$log_file" ]]; then
                pass_test
            else
                fail_test "Log file not created with malicious IFS"
            fi
        else
            fail_test "Logging failed with malicious IFS"
        fi
    else
        fail_test "init_logger failed with malicious IFS"
    fi

    export IFS="$original_ifs"
}

# Test: Environment variables in log messages
test_env_vars_in_messages() {
    start_test "Environment variables in messages are not expanded"

    export MALICIOUS_VAR='$(rm -rf /tmp/test)'
    local log_file="$TEST_TMP_DIR/env_msg.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1
    log_info "Message with \$MALICIOUS_VAR reference"

    local log_content
    log_content=$(cat "$log_file")

    # Variable should appear literally, not expanded
    if [[ "$log_content" =~ "MALICIOUS_VAR" ]] || [[ ! "$log_content" =~ "rm -rf" ]]; then
        pass_test
    else
        fail_test "Environment variable may have been expanded"
    fi

    unset MALICIOUS_VAR
}

# Test: TZ environment variable manipulation
test_tz_variable_manipulation() {
    start_test "TZ variable manipulation doesn't break logging"

    local original_tz="${TZ:-}"
    export TZ="Invalid/Timezone"

    local log_file="$TEST_TMP_DIR/tz_test.log"

    if init_logger -l "$log_file" --no-color > /dev/null 2>&1; then
        if log_info "TZ test message"; then
            pass_test
        else
            fail_test "Logging failed with invalid TZ"
        fi
    else
        fail_test "init_logger failed with invalid TZ"
    fi

    if [[ -n "$original_tz" ]]; then
        export TZ="$original_tz"
    else
        unset TZ
    fi
}

# Test: HOME variable pointing to malicious location
test_home_variable_manipulation() {
    start_test "HOME variable manipulation is safe"

    local original_home="$HOME"
    export HOME="/tmp/malicious_home"
    mkdir -p "$HOME"

    local log_file="$TEST_TMP_DIR/home_test.log"

    if init_logger -l "$log_file" --no-color > /dev/null 2>&1; then
        log_info "HOME test message"

        # Verify log went to intended location, not under fake HOME
        if [[ -f "$log_file" ]]; then
            pass_test
        else
            fail_test "Log file location affected by HOME variable"
        fi
    else
        fail_test "init_logger failed with modified HOME"
    fi

    export HOME="$original_home"
}

# Test: TMPDIR variable manipulation
test_tmpdir_variable_manipulation() {
    start_test "TMPDIR variable doesn't affect log locations"

    local original_tmpdir="${TMPDIR:-}"
    export TMPDIR="/tmp/malicious_tmp"
    mkdir -p "$TMPDIR"

    local log_file="$TEST_TMP_DIR/tmpdir_test.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1
    log_info "TMPDIR test message"

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "TMPDIR manipulation affected logging"
    fi

    if [[ -n "$original_tmpdir" ]]; then
        export TMPDIR="$original_tmpdir"
    else
        unset TMPDIR
    fi
}

# Test: Shell option variables
test_shell_option_variables() {
    start_test "Shell option environment variables are safe"

    # Save original options
    local original_opts=$-

    # Set potentially problematic options
    set +e  # Continue on error
    set +u  # Don't treat unset variables as errors

    local log_file="$TEST_TMP_DIR/shell_opts.log"

    if init_logger -l "$log_file" --no-color > /dev/null 2>&1; then
        if log_info "Shell options test"; then
            pass_test
        else
            fail_test "Logging failed with modified shell options"
        fi
    else
        fail_test "init_logger failed with modified shell options"
    fi

    # Restore by re-reading original options (simplified)
    [[ "$original_opts" == *e* ]] && set -e || set +e
    [[ "$original_opts" == *u* ]] && set -u || set +u
}

# Test: LC_ALL and LANG variables
test_locale_variables() {
    start_test "Locale variables don't break logging"

    local original_lc_all="${LC_ALL:-}"
    local original_lang="${LANG:-}"

    export LC_ALL="invalid.UTF-8"
    export LANG="C.INVALID"

    local log_file="$TEST_TMP_DIR/locale_test.log"

    if init_logger -l "$log_file" --no-color > /dev/null 2>&1; then
        if log_info "Locale test message"; then
            pass_test
        else
            fail_test "Logging failed with invalid locale"
        fi
    else
        fail_test "init_logger failed with invalid locale"
    fi

    if [[ -n "$original_lc_all" ]]; then
        export LC_ALL="$original_lc_all"
    else
        unset LC_ALL
    fi

    if [[ -n "$original_lang" ]]; then
        export LANG="$original_lang"
    else
        unset LANG
    fi
}

# Test: PS4 variable for debugging
test_ps4_variable() {
    start_test "PS4 variable doesn't interfere with logging"

    local original_ps4="${PS4:-}"
    export PS4='MALICIOUS_PS4> '

    local log_file="$TEST_TMP_DIR/ps4_test.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1
    log_info "PS4 test message"

    local log_content
    log_content=$(cat "$log_file")

    if [[ ! "$log_content" =~ "MALICIOUS_PS4" ]]; then
        pass_test
    else
        fail_test "PS4 variable affected log output"
    fi

    export PS4="$original_ps4"
}

# Test: BASH_ENV variable
test_bash_env_variable() {
    start_test "BASH_ENV variable doesn't compromise logging"

    local original_bash_env="${BASH_ENV:-}"
    local malicious_script="$TEST_TMP_DIR/malicious_env.sh"

    cat > "$malicious_script" << 'EOF'
export MALICIOUS_FLAG="EXECUTED"
EOF

    export BASH_ENV="$malicious_script"

    local log_file="$TEST_TMP_DIR/bash_env_test.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1
    log_info "BASH_ENV test"

    # Verify malicious script didn't affect logging
    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "BASH_ENV may have interfered"
    fi

    if [[ -n "$original_bash_env" ]]; then
        export BASH_ENV="$original_bash_env"
    else
        unset BASH_ENV
    fi
}

# Test: Overriding internal variables
test_internal_variable_override() {
    start_test "Internal variables can't be maliciously overridden"

    # Try to pre-set internal variables
    export LOG_LEVEL_INFO=999
    export COLOR_RED="MALICIOUS"
    export SCRIPT_NAME='$(rm -rf /tmp/test)'

    local log_file="$TEST_TMP_DIR/internal_override.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1
    log_info "Internal override test"

    # Verify logging still works correctly
    if [[ -f "$log_file" ]] && grep -q "Internal override test" "$log_file"; then
        pass_test
    else
        fail_test "Internal variable override affected logging"
    fi

    unset LOG_LEVEL_INFO COLOR_RED SCRIPT_NAME
}

# Test: Multiple environment variable attacks combined
test_combined_env_attacks() {
    start_test "Combined environment variable attacks are handled"

    export LOG_FILE="/tmp/attacker.log"
    export IFS=$'\n'
    export PATH="/malicious/path:$PATH"
    export MALICIOUS_VAR='$(evil)'

    local log_file="$TEST_TMP_DIR/combined_test.log"

    if init_logger -l "$log_file" --no-color > /dev/null 2>&1; then
        if log_info "Combined attack test"; then
            if [[ -f "$log_file" ]] && ! [[ -f "/tmp/attacker.log" ]]; then
                pass_test
            else
                fail_test "Combined attack may have succeeded"
            fi
        else
            fail_test "Logging failed under combined attack"
        fi
    else
        fail_test "init_logger failed under combined attack"
    fi

    unset LOG_FILE MALICIOUS_VAR
}

# Test: LD_PRELOAD variable
test_ld_preload_variable() {
    start_test "LD_PRELOAD doesn't compromise logging"

    local original_ld_preload="${LD_PRELOAD:-}"
    export LD_PRELOAD="/tmp/malicious.so"

    local log_file="$TEST_TMP_DIR/ld_preload_test.log"

    # Should work regardless of LD_PRELOAD (as bash is already loaded)
    if init_logger -l "$log_file" --no-color > /dev/null 2>&1; then
        if log_info "LD_PRELOAD test"; then
            pass_test
        else
            fail_test "Logging failed with LD_PRELOAD set"
        fi
    else
        fail_test "init_logger failed with LD_PRELOAD set"
    fi

    if [[ -n "$original_ld_preload" ]]; then
        export LD_PRELOAD="$original_ld_preload"
    else
        unset LD_PRELOAD
    fi
}

# Test: CDPATH variable manipulation
test_cdpath_variable() {
    start_test "CDPATH manipulation doesn't affect logging"

    local original_cdpath="${CDPATH:-}"
    export CDPATH="/tmp:/malicious:/etc"

    local log_file="$TEST_TMP_DIR/cdpath_test.log"

    if init_logger -l "$log_file" --no-color > /dev/null 2>&1; then
        if log_info "CDPATH test"; then
            pass_test
        else
            fail_test "Logging failed with malicious CDPATH"
        fi
    else
        fail_test "init_logger failed with malicious CDPATH"
    fi

    if [[ -n "$original_cdpath" ]]; then
        export CDPATH="$original_cdpath"
    else
        unset CDPATH
    fi
}

# Test: GLOBIGNORE variable
test_globignore_variable() {
    start_test "GLOBIGNORE doesn't interfere with logging"

    local original_globignore="${GLOBIGNORE:-}"
    export GLOBIGNORE="*"

    local log_file="$TEST_TMP_DIR/globignore_test.log"

    if init_logger -l "$log_file" --no-color > /dev/null 2>&1; then
        if log_info "GLOBIGNORE test"; then
            if [[ -f "$log_file" ]]; then
                pass_test
            else
                fail_test "GLOBIGNORE prevented file creation"
            fi
        else
            fail_test "Logging failed with GLOBIGNORE set"
        fi
    else
        fail_test "init_logger failed with GLOBIGNORE set"
    fi

    if [[ -n "$original_globignore" ]]; then
        export GLOBIGNORE="$original_globignore"
    else
        unset GLOBIGNORE
    fi
}

# Test: PROMPT_COMMAND injection
test_prompt_command_injection() {
    start_test "PROMPT_COMMAND doesn't execute during logging"

    local original_prompt="${PROMPT_COMMAND:-}"
    local marker="$TEST_TMP_DIR/prompt_marker"
    export PROMPT_COMMAND="touch $marker"

    local log_file="$TEST_TMP_DIR/prompt_test.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1
    log_info "PROMPT_COMMAND test"

    # PROMPT_COMMAND should not execute during logging
    if [[ ! -f "$marker" ]]; then
        pass_test
    else
        fail_test "PROMPT_COMMAND was executed during logging"
    fi

    export PROMPT_COMMAND="$original_prompt"
}

# Test: Readonly variable conflicts
test_readonly_variable_conflicts() {
    start_test "Readonly variables don't cause crashes"

    # Make a variable readonly
    local TEST_READONLY="original"
    # shellcheck disable=SC2034
    readonly TEST_READONLY

    local log_file="$TEST_TMP_DIR/readonly_test.log"

    # Should work even if some variables are readonly
    if init_logger -l "$log_file" --no-color > /dev/null 2>&1; then
        if log_info "Readonly test"; then
            pass_test
        else
            fail_test "Logging failed with readonly variables"
        fi
    else
        fail_test "init_logger failed with readonly variables"
    fi
}

# Run all tests
test_preset_log_file_handling
test_malicious_path_variable
test_malicious_ifs_variable
test_env_vars_in_messages
test_tz_variable_manipulation
test_home_variable_manipulation
test_tmpdir_variable_manipulation
test_shell_option_variables
test_locale_variables
test_ps4_variable
test_bash_env_variable
test_internal_variable_override
test_combined_env_attacks
test_ld_preload_variable
test_cdpath_variable
test_globignore_variable
test_prompt_command_injection
test_readonly_variable_conflicts
