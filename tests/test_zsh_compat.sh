#!/usr/bin/env bash
#
# test_zsh_compat.sh - zsh compatibility tests (Issue #141)
#
# The suite runs in bash; each test runs logging.sh under zsh through
# run_with_logger_in_shell and compares against bash where relevant.
# Tests skip when zsh is not installed, unless TEST_REQUIRE_SHELLS contains zsh.
#
# Tests:
# - Config parsing gives identical results in bash and zsh
# - Section headers and quoted values in config files
# - --config position in the argument list
# - set_syslog_facility does not exit the calling script
# - set_unsafe_* flags set exact values
# - zsh options used by the config parser do not leak to the caller

# Print the logger settings affected by config parsing, one per line
_settings_report() {
    printf '%s' "printf '%s\n' \
\"level=\$CURRENT_LOG_LEVEL\" \
\"format=\$LOG_FORMAT\" \
\"utc=\$USE_UTC\" \
\"facility=\$SYSLOG_FACILITY\" \
\"tag=\$JOURNAL_TAG\" \
\"colors=\$USE_COLORS\" \
\"newlines=\$LOG_UNSAFE_ALLOW_NEWLINES\" \
\"ansi=\$LOG_UNSAFE_ALLOW_ANSI_CODES\""
}

# Parse a config under one shell; settings on stdout, warnings on stderr
_parse_config_in_shell() {
    local shell_command="$1"
    local config_file="$2"
    run_with_logger_in_shell "$shell_command" \
        "init_logger --no-color --quiet --config '$config_file'; echo \"rc=\$?\"; $(_settings_report)"
}

# Test: Config parsing parity between bash and zsh
test_zsh_config_parity() {
    start_test "Config parsing gives the same results in bash and zsh"

    require_shell zsh || return 0

    local fixture_dir="$TEST_DIR/fixtures"
    mkdir -p "$fixture_dir"

    cat > "$fixture_dir/all_keys.conf" << 'EOF'
# Every key with mixed-case values
[logging]
level = Debug
format = "%l: %m"
utc = YES
facility = LOCAL4
tag = my-app
color = Never
unsafe_allow_newlines = On
unsafe_allow_ansi_codes = TRUE
EOF

    cat > "$fixture_dir/single_quotes.conf" << 'EOF'
[logging]
log_level = warn
log_format = '[%l] %m'
use_utc = off
syslog_facility = user
EOF

    cat > "$fixture_dir/invalid_values.conf" << 'EOF'
[logging]
level = NOTALEVEL
utc = maybe
facility = NOTAFACILITY
color = sometimes
unsafe_allow_newlines = perhaps
unknown_key = value
EOF

    cat > "$fixture_dir/comments_whitespace.conf" << 'EOF'
; semicolon comment
   # indented comment

[logging]
   level   =   ERROR
format=%m
EOF

    local fixture
    local bash_stdout
    local bash_stderr
    local zsh_stdout
    local zsh_stderr
    for fixture in "$fixture_dir"/*.conf; do
        bash_stdout=$(_parse_config_in_shell "bash" "$fixture" 2>"$TEST_DIR/bash.err")
        zsh_stdout=$(_parse_config_in_shell "zsh" "$fixture" 2>"$TEST_DIR/zsh.err")
        bash_stderr=$(cat "$TEST_DIR/bash.err")
        zsh_stderr=$(cat "$TEST_DIR/zsh.err")

        assert_contains "$bash_stdout" "rc=0" "bash rc for $(basename "$fixture")" || return
        assert_equals "$bash_stdout" "$zsh_stdout" "settings for $(basename "$fixture")" || return
        assert_equals "$bash_stderr" "$zsh_stderr" "warnings for $(basename "$fixture")" || return
    done

    pass_test
}

# Test: Section headers and quoted values parse in zsh
test_zsh_config_sections_and_quotes() {
    start_test "zsh accepts section headers and removes value quotes"

    require_shell zsh || return 0

    local double_file="$TEST_DIR/double.conf"
    local single_file="$TEST_DIR/single.conf"
    printf '[logging]\nformat = "%%l: %%m"\n' > "$double_file"
    printf "[logging]\nformat = '%%l: %%m'\n" > "$single_file"

    local output
    local config_file
    for config_file in "$double_file" "$single_file"; do
        output=$(_parse_config_in_shell "zsh" "$config_file" 2>&1)
        assert_contains "$output" "rc=0" "$(basename "$config_file")" || return
        assert_contains "$output" "format=%l: %m" "$(basename "$config_file")" || return
        assert_not_contains "$output" "Invalid syntax" "$(basename "$config_file")" || return
    done

    pass_test
}

# Test: --config position does not matter in zsh
test_zsh_config_option_positions() {
    start_test "zsh loads --config wherever it appears in the arguments"

    require_shell zsh || return 0

    local config_file="$TEST_DIR/position.conf"
    printf '[logging]\nlevel = DEBUG\n' > "$config_file"

    local arguments
    local output
    for arguments in \
        "--config '$config_file' --no-color --quiet" \
        "--no-color --config '$config_file' --quiet" \
        "--quiet --no-color --config '$config_file'" \
        "--quiet --no-color -c '$config_file'"; do
        output=$(run_with_logger_in_shell "zsh" \
            "init_logger $arguments; echo \"rc=\$? level=\$CURRENT_LOG_LEVEL\"" 2>&1)
        assert_equals "rc=0 level=7" "$output" "init_logger $arguments" || return
    done

    output=$(run_with_logger_in_shell "zsh" \
        "init_logger --no-color --config; echo \"rc=\$?\"" 2>&1)
    assert_contains "$output" "requires a file path" || return
    assert_contains "$output" "rc=1" || return

    pass_test
}

# Test: set_syslog_facility does not exit the calling script in zsh
test_zsh_set_syslog_facility_does_not_exit() {
    start_test "zsh set_syslog_facility does not exit the caller"

    require_shell zsh || return 0

    local output
    output=$(run_with_logger_in_shell "zsh" \
        "init_logger --no-color; set_syslog_facility local0; echo \"after facility=\$SYSLOG_FACILITY\"" 2>&1)

    assert_contains "$output" "after facility=local0" || return
    assert_not_contains "$output" "bad substitution" || return

    pass_test
}

# Test: set_unsafe_* set exact values in zsh
test_zsh_set_unsafe_flags() {
    start_test "zsh set_unsafe_* flags set exact values"

    require_shell zsh || return 0

    local snippet="init_logger --quiet; \
set_unsafe_allow_newlines true; printf '%s ' \"\$LOG_UNSAFE_ALLOW_NEWLINES\"; \
set_unsafe_allow_newlines false; printf '%s ' \"\$LOG_UNSAFE_ALLOW_NEWLINES\"; \
set_unsafe_allow_newlines bogus 2>/dev/null; printf '%s ' \"\$? \$LOG_UNSAFE_ALLOW_NEWLINES\"; \
set_unsafe_allow_ansi_codes true; printf '%s ' \"\$LOG_UNSAFE_ALLOW_ANSI_CODES\"; \
set_unsafe_allow_ansi_codes false; printf '%s ' \"\$LOG_UNSAFE_ALLOW_ANSI_CODES\"; \
set_unsafe_allow_ansi_codes bogus 2>/dev/null; printf '%s\n' \"\$? \$LOG_UNSAFE_ALLOW_ANSI_CODES\""

    local output
    output=$(run_with_logger_in_shell "zsh" "$snippet" 2>&1)

    assert_equals "true false 1 false true false 1 false" "$output" || return

    pass_test
}

# Test: zsh options set by the config parser do not leak into the caller
test_zsh_options_not_leaked() {
    start_test "zsh options used by the config parser do not leak"

    require_shell zsh || return 0

    local config_file="$TEST_DIR/leak.conf"
    printf '[logging]\nlevel = DEBUG\n' > "$config_file"

    local output
    output=$(run_with_logger_in_shell "zsh" \
        "init_logger --quiet --config '$config_file'; \
[[ -o ksh_arrays ]] && echo ksh_arrays_set; \
[[ -o bash_rematch ]] && echo bash_rematch_set; \
echo done" 2>&1)

    assert_equals "done" "$output" || return

    pass_test
}

# Run all tests
test_zsh_config_parity
test_zsh_config_sections_and_quotes
test_zsh_config_option_positions
test_zsh_set_syslog_facility_does_not_exit
test_zsh_set_unsafe_flags
test_zsh_options_not_leaked
