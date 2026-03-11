#!/usr/bin/env bash
#
# test_journal_logging.sh - Tests for log_to_journal and journal dispatch
#
# Covers:
#   - log_to_journal forces journal write regardless of USE_JOURNAL
#   - log_to_journal with USE_JOURNAL=true (no double dispatch)
#   - Invalid level name returns 1 and prints an error
#   - Missing arguments returns 1 and prints a usage error
#   - Message below current log level is silently suppressed
#   - logger not available emits warning to stderr and returns 1
#   - log_sensitive is unaffected — still skips journal after this change

# shellcheck source=tests/test_helpers.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

# Helper: create a stub logger that appends its arguments to a capture file.
# Sets $STUB_LOGGER and $STUB_CAPTURE as side-effects.
# Usage: _create_stub_logger <test_dir>
_create_stub_logger() {
    local dir="$1"
    STUB_LOGGER="$dir/stub_logger"
    STUB_CAPTURE="$dir/journal_capture.log"
    # The stub writes everything passed to it into a capture log
    cat > "$STUB_LOGGER" << STUB
#!/usr/bin/env bash
echo "\$*" >> "$STUB_CAPTURE"
STUB
    chmod +x "$STUB_LOGGER"
}

# ---------------------------------------------------------------------------
# Test 1: log_to_journal forces a journal write when USE_JOURNAL=false
# Uses a stub script to intercept the logger invocation.
# ---------------------------------------------------------------------------
test_log_to_journal_forces_write_when_journal_disabled() {
    start_test "log_to_journal forces journal write when USE_JOURNAL=false"

    _create_stub_logger "$TEST_DIR"

    local result exit_code
    result=$(bash -c "
        source '$PROJECT_ROOT/logging.sh'

        # Point LOGGER_PATH at the stub before the readonly guard fires.
        # Sourcing sets LOGGER_PATH='' (not readonly yet); assign our stub
        # and override the validation helpers so the stub path is accepted.
        LOGGER_PATH='$STUB_LOGGER'
        _find_and_validate_logger() { return 0; }
        check_logger_available() { return 0; }

        init_logger --no-color --quiet
        USE_JOURNAL='false'

        log_to_journal INFO "journal_force_test_unique_$RANDOM"
        echo exit:\$?
    " 2>&1)
    exit_code=$(echo "$result" | grep -o 'exit:[0-9]*' | cut -d: -f2)

    assert_equals "0" "$exit_code" \
        "log_to_journal should return 0 on success" || return
    assert_file_contains "$STUB_CAPTURE" "journal_force_test_unique" \
        "Stub logger should have captured the message" || return

    pass_test
}

# ---------------------------------------------------------------------------
# Test 2: log_to_journal with USE_JOURNAL=true — journal written exactly once
# ---------------------------------------------------------------------------
test_log_to_journal_no_double_dispatch_when_journal_enabled() {
    start_test "log_to_journal with USE_JOURNAL=true writes to journal exactly once"

    _create_stub_logger "$TEST_DIR"

    bash -c "
        source '$PROJECT_ROOT/logging.sh'

        LOGGER_PATH='$STUB_LOGGER'
        _find_and_validate_logger() { return 0; }
        check_logger_available() { return 0; }

        init_logger --no-color --quiet
        USE_JOURNAL='true'

        log_to_journal INFO 'dispatch_once_marker'
    " 2>/dev/null

    local count
    count=$(grep -c 'dispatch_once_marker' "$STUB_CAPTURE" 2>/dev/null || echo "0")
    assert_equals "1" "$count" \
        "Message should appear in the journal exactly once" || return

    pass_test
}

# ---------------------------------------------------------------------------
# Test 3: Unrecognised level name returns 1 and prints an error
# ---------------------------------------------------------------------------
test_log_to_journal_invalid_level_returns_error() {
    start_test "log_to_journal with invalid level returns 1 and prints error"

    local exit_code
    exit_code=$(bash -c "
        source '$PROJECT_ROOT/logging.sh'
        init_logger --no-color --quiet 2>/dev/null
        log_to_journal BOGUS_LEVEL 'some message' 2>/dev/null
        echo \$?
    ")

    assert_equals "1" "$exit_code" \
        "log_to_journal with invalid level should return 1" || return

    local err
    err=$(bash -c "
        source '$PROJECT_ROOT/logging.sh'
        init_logger --no-color --quiet 2>/dev/null
        log_to_journal BOGUS_LEVEL 'some message'
    " 2>&1)
    assert_contains "$err" "unrecognised level" \
        "stderr should mention unrecognised level" || return

    pass_test
}

# ---------------------------------------------------------------------------
# Test 4: Missing arguments returns 1 and prints a usage error
# ---------------------------------------------------------------------------
test_log_to_journal_missing_args_returns_usage_error() {
    start_test "log_to_journal with missing arguments returns 1 and usage error"

    local exit_code
    exit_code=$(bash -c "
        source '$PROJECT_ROOT/logging.sh'
        init_logger --no-color --quiet 2>/dev/null
        log_to_journal INFO
        echo \$?
    " 2>/dev/null)

    assert_equals "1" "$exit_code" \
        "log_to_journal with one arg should return 1" || return

    local err
    err=$(bash -c "
        source '$PROJECT_ROOT/logging.sh'
        init_logger --no-color --quiet 2>/dev/null
        log_to_journal INFO
    " 2>&1)
    assert_contains "$err" "Usage:" \
        "stderr should contain a usage hint" || return

    # Zero arguments
    exit_code=$(bash -c "
        source '$PROJECT_ROOT/logging.sh'
        init_logger --no-color --quiet 2>/dev/null
        log_to_journal
        echo \$?
    " 2>/dev/null)

    assert_equals "1" "$exit_code" \
        "log_to_journal with zero args should return 1" || return

    pass_test
}

# ---------------------------------------------------------------------------
# Test 5: Message below current log level is silently suppressed
# ---------------------------------------------------------------------------
test_log_to_journal_below_level_is_suppressed() {
    start_test "log_to_journal message below log level is silently suppressed"

    _create_stub_logger "$TEST_DIR"

    bash -c "
        source '$PROJECT_ROOT/logging.sh'

        LOGGER_PATH='$STUB_LOGGER'
        _find_and_validate_logger() { return 0; }
        check_logger_available() { return 0; }

        # Set level to WARN — DEBUG messages should be filtered
        init_logger --no-color --quiet --level WARN
        USE_JOURNAL='false'

        log_to_journal DEBUG 'suppressed_debug_message'
    " 2>/dev/null

    if [[ -f "$STUB_CAPTURE" ]]; then
        assert_file_not_contains "$STUB_CAPTURE" "suppressed_debug_message" \
            "Stub should not have received the suppressed message" || return
    fi

    pass_test
}

# ---------------------------------------------------------------------------
# Test 6: logger not available — warning to stderr and return 1
# ---------------------------------------------------------------------------
test_log_to_journal_no_logger_emits_warning() {
    start_test "log_to_journal without logger emits warning to stderr and returns 1"

    local exit_code
    local err
    # Run in a subshell where we ensure check_logger_available fails
    err=$(bash -c "
        source '$PROJECT_ROOT/logging.sh'

        # Override so the availability check always fails
        _find_and_validate_logger() { return 1; }
        check_logger_available() { return 1; }
        LOGGER_PATH=''

        init_logger --no-color --quiet 2>/dev/null
        USE_JOURNAL='false'

        log_to_journal INFO 'no_logger_test_message'
    " 2>&1)
    exit_code=$?

    assert_equals "1" "$exit_code" \
        "log_to_journal should return 1 when logger is not available" || return
    assert_contains "$err" "WARNING: log_to_journal called but logger command is not available" \
        "stderr should contain the expected warning" || return

    pass_test
}

# ---------------------------------------------------------------------------
# Test 7: Calling log_to_journal when USE_JOURNAL=true and logger is
# unavailable should use the existing _write_to_journal error path,
# NOT the force_journal=true warning (no double-warn).
# ---------------------------------------------------------------------------
test_log_to_journal_no_double_warn_when_journal_enabled() {
    start_test "log_to_journal emits exactly one warning when USE_JOURNAL=true and logger unavailable"

    # log_to_journal now performs a LOGGER_PATH-first availability check unconditionally
    # (regardless of USE_JOURNAL). This means it warns and returns 1 before _log_message
    # is called, so _write_to_journal never fires — no double-warning is possible.
    local err
    err=$(bash -c "
        source '$PROJECT_ROOT/logging.sh'

        # Make the real logger unavailable
        _find_and_validate_logger() { return 1; }
        check_logger_available() { return 1; }
        LOGGER_PATH=''

        init_logger --no-color --quiet 2>/dev/null
        USE_JOURNAL='true'  # journal enabled globally, but logger will fail

        log_to_journal INFO 'double_warn_test'
    " 2>&1)
    local exit_code=$?

    assert_equals "1" "$exit_code" \
        "log_to_journal should return 1 when logger is unavailable" || return

    # Warning should appear exactly once — from log_to_journal's pre-check only.
    # _log_message is never reached, so _write_to_journal cannot emit a duplicate.
    local warn_count
    warn_count=$(echo "$err" | grep -c "WARNING: log_to_journal called but logger command is not available" || true)
    assert_equals "1" "$warn_count" \
        "Warning should appear exactly once (no double-warn from _write_to_journal)" || return

    pass_test
}

# ---------------------------------------------------------------------------
# Test 8: log_sensitive is unaffected — skip_journal still takes precedence
# ---------------------------------------------------------------------------
test_log_sensitive_unaffected_by_force_journal() {
    start_test "log_sensitive still skips journal after log_to_journal change"

    _create_stub_logger "$TEST_DIR"

    local log_file="$TEST_DIR/sensitive_journal.log"

    bash -c "
        source '$PROJECT_ROOT/logging.sh'

        LOGGER_PATH='$STUB_LOGGER'
        _find_and_validate_logger() { return 0; }
        check_logger_available() { return 0; }

        init_logger --no-color --log '$log_file' --quiet
        USE_JOURNAL='true'

        log_sensitive 'sensitive_secret_value'
        log_info 'public_info_message'
    " 2>/dev/null

    # Stub should NOT have received the sensitive message
    if [[ -f "$STUB_CAPTURE" ]]; then
        assert_file_not_contains "$STUB_CAPTURE" "sensitive_secret_value" \
            "Sensitive message must never reach the journal" || return
    fi

    # Sensitive message should also not appear in the log file
    if [[ -f "$log_file" ]]; then
        assert_file_not_contains "$log_file" "sensitive_secret_value" \
            "Sensitive message must not appear in log file" || return
    fi

    pass_test
}

# ---------------------------------------------------------------------------
# Test 9: Level aliases are accepted and resolve to canonical names
# ---------------------------------------------------------------------------
test_log_to_journal_level_aliases() {
    start_test "log_to_journal accepts level aliases (WARNING, ERR, CRIT, EMERG, FATAL)"

    _create_stub_logger "$TEST_DIR"

    local aliases=("WARNING" "ERR" "CRIT" "EMERG" "FATAL")
    local alias

    for alias in "${aliases[@]}"; do
        bash -c "
            source '$PROJECT_ROOT/logging.sh'

            LOGGER_PATH='$STUB_LOGGER'
            _find_and_validate_logger() { return 0; }
            check_logger_available() { return 0; }

            init_logger --no-color --quiet --level DEBUG
            USE_JOURNAL='false'

            log_to_journal '$alias' 'alias_test_${alias}'
        " 2>/dev/null

        local exit_code=$?
        if [[ $exit_code -ne 0 ]]; then
            fail_test "log_to_journal '$alias' returned $exit_code; expected 0"
            return
        fi
    done

    pass_test
}

# ---------------------------------------------------------------------------
# Test 10: Numeric syslog levels (0-7) are accepted
# ---------------------------------------------------------------------------
test_log_to_journal_numeric_levels() {
    start_test "log_to_journal accepts numeric syslog levels 0-7"

    _create_stub_logger "$TEST_DIR"

    local level
    for level in 0 1 2 3 4 5 6 7; do
        local exit_code
        exit_code=$(bash -c "
            source '$PROJECT_ROOT/logging.sh'

            LOGGER_PATH='$STUB_LOGGER'
            _find_and_validate_logger() { return 0; }
            check_logger_available() { return 0; }

            init_logger --no-color --quiet --level DEBUG
            USE_JOURNAL='false'

            log_to_journal '$level' 'numeric_level_test'
            echo \$?
        " 2>/dev/null)

        assert_equals "0" "$exit_code" \
            "log_to_journal '$level' should return 0" || return
    done

    pass_test
}

# ---------------------------------------------------------------------------
# Tests migrated from test_initialization.sh
# ---------------------------------------------------------------------------

# Test: --journal flag sets USE_JOURNAL
test_journal_option() {
    start_test "Journal option enables journal logging"

    if ! check_logger_available; then
        skip_test "logger command not available"
        return
    fi

    init_logger --journal

    assert_equals "true" "$USE_JOURNAL" || return

    pass_test
}

# Test: set_journal_logging disables journal at runtime
test_no_journal_via_runtime() {
    start_test "Journal logging can be disabled at runtime"

    init_logger
    set_journal_logging false

    assert_equals "false" "$USE_JOURNAL" || return

    pass_test
}

# Run all tests
test_journal_option
test_no_journal_via_runtime
test_log_to_journal_forces_write_when_journal_disabled
test_log_to_journal_no_double_dispatch_when_journal_enabled
test_log_to_journal_invalid_level_returns_error
test_log_to_journal_missing_args_returns_usage_error
test_log_to_journal_below_level_is_suppressed
test_log_to_journal_no_logger_emits_warning
test_log_to_journal_no_double_warn_when_journal_enabled
test_log_sensitive_unaffected_by_force_journal
test_log_to_journal_level_aliases
test_log_to_journal_numeric_levels
