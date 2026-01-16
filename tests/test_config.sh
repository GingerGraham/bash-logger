#!/usr/bin/env bash
#
# test_config.sh - Tests for configuration file parsing
#
# Tests:
# - Basic INI file parsing
# - All configuration options
# - Comments and whitespace handling
# - Invalid configuration handling
# - CLI overrides config file

# Test: Basic config file loading
test_basic_config_load() {
    start_test "Basic config file loads correctly"

    local config_file="$TEST_DIR/basic.conf"
    cat > "$config_file" << 'EOF'
[logging]
level = ERROR
EOF

    init_logger --config "$config_file"

    assert_equals "$LOG_LEVEL_ERROR" "$CURRENT_LOG_LEVEL" || return

    pass_test
}

# Test: Multiple config options
test_multiple_config_options() {
    start_test "Multiple config options are loaded"

    local config_file="$TEST_DIR/multiple.conf"
    cat > "$config_file" << 'EOF'
[logging]
level = WARN
format = %l: %m
utc = true
EOF

    init_logger --config "$config_file"

    assert_equals "$LOG_LEVEL_WARN" "$CURRENT_LOG_LEVEL" || return
    assert_equals "%l: %m" "$LOG_FORMAT" || return
    assert_equals "true" "$USE_UTC" || return

    pass_test
}

# Test: Log file path in config
test_config_log_file() {
    start_test "Log file path in config"

    local log_file="$TEST_DIR/from_config.log"
    local config_file="$TEST_DIR/config.conf"
    cat > "$config_file" << EOF
[logging]
log_file = $log_file
EOF

    init_logger --config "$config_file" --quiet

    assert_equals "$log_file" "$LOG_FILE" || return

    log_info "Config test"
    assert_file_contains "$log_file" "Config test" || return

    pass_test
}

# Test: Journal settings in config
test_config_journal() {
    start_test "Journal settings in config"

    local config_file="$TEST_DIR/journal.conf"
    cat > "$config_file" << 'EOF'
[logging]
journal = false
tag = test_app
EOF

    init_logger --config "$config_file"

    assert_equals "false" "$USE_JOURNAL" || return
    assert_equals "test_app" "$JOURNAL_TAG" || return

    pass_test
}

# Test: Color settings in config
test_config_colors() {
    start_test "Color settings in config"

    local config_file="$TEST_DIR/colors.conf"
    cat > "$config_file" << 'EOF'
[logging]
color = never
EOF

    init_logger --config "$config_file"

    assert_equals "never" "$USE_COLORS" || return

    pass_test
}

# Test: Color variations (always, auto)
test_config_color_variations() {
    start_test "Color config accepts always/auto/never"

    # Test always
    local config_file="$TEST_DIR/color_always.conf"
    cat > "$config_file" << 'EOF'
[logging]
color = always
EOF

    init_logger --config "$config_file"
    assert_equals "always" "$USE_COLORS" || return

    # Test auto
    config_file="$TEST_DIR/color_auto.conf"
    cat > "$config_file" << 'EOF'
[logging]
color = auto
EOF

    init_logger --config "$config_file"
    assert_equals "auto" "$USE_COLORS" || return

    pass_test
}

# Test: Stderr level in config
test_config_stderr_level() {
    start_test "Stderr level in config"

    local config_file="$TEST_DIR/stderr.conf"
    cat > "$config_file" << 'EOF'
[logging]
stderr_level = WARN
EOF

    init_logger --config "$config_file"

    assert_equals "$LOG_LEVEL_WARN" "$LOG_STDERR_LEVEL" || return

    pass_test
}

# Test: Quiet/console_log in config
test_config_quiet() {
    start_test "Quiet setting in config"

    local config_file="$TEST_DIR/quiet.conf"
    cat > "$config_file" << 'EOF'
[logging]
quiet = true
EOF

    init_logger --config "$config_file"

    assert_equals "false" "$CONSOLE_LOG" || return

    pass_test
}

# Test: console_log in config
test_config_console_log() {
    start_test "console_log setting in config"

    local config_file="$TEST_DIR/console.conf"
    cat > "$config_file" << 'EOF'
[logging]
console_log = false
EOF

    init_logger --config "$config_file"

    assert_equals "false" "$CONSOLE_LOG" || return

    pass_test
}

# Test: Verbose in config
test_config_verbose() {
    start_test "Verbose setting in config"

    local config_file="$TEST_DIR/verbose.conf"
    cat > "$config_file" << 'EOF'
[logging]
verbose = true
EOF

    init_logger --config "$config_file"

    assert_equals "true" "$VERBOSE" || return
    assert_equals "$LOG_LEVEL_DEBUG" "$CURRENT_LOG_LEVEL" || return

    pass_test
}

# Test: Comments in config file
test_config_comments() {
    start_test "Comments are ignored in config"

    local config_file="$TEST_DIR/comments.conf"
    cat > "$config_file" << 'EOF'
# This is a comment
[logging]
# Another comment
level = ERROR
; Semicolon comment
format = %m
EOF

    init_logger --config "$config_file"

    assert_equals "$LOG_LEVEL_ERROR" "$CURRENT_LOG_LEVEL" || return
    assert_equals "%m" "$LOG_FORMAT" || return

    pass_test
}

# Test: Whitespace handling
test_config_whitespace() {
    start_test "Whitespace is handled correctly"

    local config_file="$TEST_DIR/whitespace.conf"
    cat > "$config_file" << 'EOF'
[logging]
  level   =   INFO
   format=%l - %m
EOF

    init_logger --config "$config_file"

    assert_equals "$LOG_LEVEL_INFO" "$CURRENT_LOG_LEVEL" || return
    assert_equals "%l - %m" "$LOG_FORMAT" || return

    pass_test
}

# Test: Quoted values
test_config_quoted_values() {
    start_test "Quoted values are handled"

    local config_file="$TEST_DIR/quotes.conf"
    cat > "$config_file" << 'EOF'
[logging]
format = "%d [%l] %m"
tag = "my app"
EOF

    init_logger --config "$config_file"

    assert_equals "%d [%l] %m" "$LOG_FORMAT" || return
    assert_equals "my app" "$JOURNAL_TAG" || return

    pass_test
}

# Test: Case insensitive keys
test_config_case_insensitive() {
    start_test "Config keys are case insensitive"

    local config_file="$TEST_DIR/case.conf"
    cat > "$config_file" << 'EOF'
[logging]
LEVEL = ERROR
Format = %m
UTC = true
EOF

    init_logger --config "$config_file"

    assert_equals "$LOG_LEVEL_ERROR" "$CURRENT_LOG_LEVEL" || return
    assert_equals "%m" "$LOG_FORMAT" || return
    assert_equals "true" "$USE_UTC" || return

    pass_test
}

# Test: Boolean value variations
test_config_boolean_variations() {
    start_test "Boolean values accept multiple formats"

    # Test various true values
    local config_file="$TEST_DIR/bool_true.conf"
    cat > "$config_file" << 'EOF'
[logging]
utc = yes
EOF

    init_logger --config "$config_file"
    assert_equals "true" "$USE_UTC" || return

    # Test various false values
    config_file="$TEST_DIR/bool_false.conf"
    cat > "$config_file" << 'EOF'
[logging]
utc = no
EOF

    init_logger --config "$config_file"
    assert_equals "false" "$USE_UTC" || return

    pass_test
}

# Test: Empty config file
test_config_empty() {
    start_test "Empty config file doesn't cause errors"

    local config_file="$TEST_DIR/empty.conf"
    touch "$config_file"

    # Should not fail
    init_logger --config "$config_file" 2>/dev/null

    pass_test
}

# Test: Config file with only comments
test_config_only_comments() {
    start_test "Config with only comments"

    local config_file="$TEST_DIR/only_comments.conf"
    cat > "$config_file" << 'EOF'
# Just comments
# Nothing else
EOF

    # Should not fail
    init_logger --config "$config_file" 2>/dev/null

    pass_test
}

# Test: Missing config file
test_config_missing_file() {
    start_test "Missing config file produces error"

    local stderr
    stderr=$(init_logger --config "/nonexistent/config.conf" 2>&1 >/dev/null)

    assert_contains "$stderr" "not found" || return

    pass_test
}

# Test: CLI overrides config
test_cli_overrides_config() {
    start_test "CLI arguments override config file"

    local config_file="$TEST_DIR/override.conf"
    cat > "$config_file" << 'EOF'
[logging]
level = ERROR
utc = false
format = %m
EOF

    init_logger --config "$config_file" --level INFO --utc --format "%l: %m"

    # CLI values should win
    assert_equals "$LOG_LEVEL_INFO" "$CURRENT_LOG_LEVEL" || return
    assert_equals "true" "$USE_UTC" || return
    assert_equals "%l: %m" "$LOG_FORMAT" || return

    pass_test
}

# Test: Unknown config keys produce warnings
test_config_unknown_key() {
    start_test "Unknown config keys produce warnings"

    local config_file="$TEST_DIR/unknown.conf"
    cat > "$config_file" << 'EOF'
[logging]
level = INFO
unknown_key = value
EOF

    local stderr
    stderr=$(init_logger --config "$config_file" 2>&1 >/dev/null)

    assert_contains "$stderr" "Unknown" || return

    pass_test
}

# Test: Alternative key names
test_config_alternative_keys() {
    start_test "Alternative key names work"

    local config_file="$TEST_DIR/alt_keys.conf"
    local log_file="$TEST_DIR/alt.log"
    cat > "$config_file" << EOF
[logging]
log_level = WARN
logfile = $log_file
EOF

    init_logger --config "$config_file"

    assert_equals "$LOG_LEVEL_WARN" "$CURRENT_LOG_LEVEL" || return
    assert_equals "$log_file" "$LOG_FILE" || return

    pass_test
}

# Run all tests
test_basic_config_load
test_multiple_config_options
test_config_log_file
test_config_journal
test_config_colors
test_config_color_variations
test_config_stderr_level
test_config_quiet
test_config_console_log
test_config_verbose
test_config_comments
test_config_whitespace
test_config_quoted_values
test_config_case_insensitive
test_config_boolean_variations
test_config_empty
test_config_only_comments
test_config_missing_file
test_cli_overrides_config
test_config_unknown_key
test_config_alternative_keys
