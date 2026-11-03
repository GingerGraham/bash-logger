#!/usr/bin/env bash
#
# test_source_guard.sh - Tests for re-sourcing logging.sh (Issue #139)
#
# logging.sh guards its readonly constants so that sourcing it a second time
# does not try to reassign them. The guards read `readonly -p`, whose output
# differs between shells:
#   bash (normal)        declare -r X="1"
#   bash --posix / sh    readonly X="1"
#   zsh                  typeset -r X=1  (export -r X=1 when also exported)
#
# Tests:
# - Sourcing twice succeeds and leaves a working logger in bash, bash --posix and zsh
# - Constants are unchanged after a second source
# - Runtime state after a second source (pins current behaviour)
# - Environment variables cannot bypass initialisation
# - The guard pattern is anchored and ignores look-alike values
# - The _is_readonly helper

# Shells exercised by the cross-shell tests. zsh is checked with require_shell.
GUARD_TEST_SHELLS=("bash" "bash --posix" "zsh")

# Snippet that sources logging.sh a second time (the helper sources it first),
# reports the status, then logs a message.
_resource_snippet() {
    printf '%s' ". '$PROJECT_ROOT/logging.sh'; echo \"rc=\$?\"; init_logger --no-color; log_info 'after resource'"
}

# Assert that sourcing twice works under one shell command
_assert_resource_works() {
    local shell_command="$1"
    local output

    output=$(run_with_logger_in_shell "$shell_command" "$(_resource_snippet)" 2>&1)

    assert_contains "$output" "rc=0" "second source should return 0 ($shell_command)" || return
    assert_contains "$output" "after resource" "logger should work after second source ($shell_command)" || return
    assert_not_contains "$output" "readonly variable" "no readonly errors ($shell_command)" || return
}

# Test: Re-source in bash
test_resource_bash() {
    start_test "Sourcing logging.sh twice works in bash"

    _assert_resource_works "bash" || return

    pass_test
}

# Test: Re-source in bash POSIX mode
test_resource_bash_posix() {
    start_test "Sourcing logging.sh twice works in bash --posix (Issue #139)"

    _assert_resource_works "bash --posix" || return

    pass_test
}

# Test: Re-source in zsh
test_resource_zsh() {
    start_test "Sourcing logging.sh twice works in zsh (Issue #139)"

    require_shell zsh || return 0

    _assert_resource_works "zsh" || return

    pass_test
}

# Test: Constants are unchanged after a second source
test_resource_keeps_constants() {
    start_test "Constants are unchanged after a second source"

    require_shell zsh || return 0

    local report="printf '%s|%s|%s\n' \"\$BASH_LOGGER_VERSION\" \"\$LOG_LEVEL_INFO\" \"\$COLOR_RESET\""
    local shell_command
    local before
    local after
    for shell_command in "${GUARD_TEST_SHELLS[@]}"; do
        before=$(run_with_logger_in_shell "$shell_command" "$report" 2>&1)
        after=$(run_with_logger_in_shell "$shell_command" \
            ". '$PROJECT_ROOT/logging.sh'; $report" 2>&1)
        assert_equals "$before" "$after" "constants changed ($shell_command)" || return
        assert_contains "$after" "|6|" "LOG_LEVEL_INFO should be 6 ($shell_command)" || return
    done

    pass_test
}

# Test: Runtime state after a second source (pins current behaviour)
# Mutable defaults are reassigned on every source, so the level set before the
# second source is reset to INFO. This test pins that, in every shell.
test_resource_keeps_runtime_state() {
    start_test "Second source resets mutable log level to the default in every shell"

    require_shell zsh || return 0

    local snippet="init_logger --quiet; set_log_level DEBUG >/dev/null; \
. '$PROJECT_ROOT/logging.sh'; echo \"level=\$CURRENT_LOG_LEVEL\""
    local shell_command
    local output
    for shell_command in "${GUARD_TEST_SHELLS[@]}"; do
        output=$(run_with_logger_in_shell "$shell_command" "$snippet" 2>&1)
        assert_equals "level=6" "$output" "log level after second source ($shell_command)" || return
    done

    pass_test
}

# Test: Environment variables do not bypass initialisation
test_env_bypass_rejected_posix() {
    start_test "Environment variables cannot bypass initialisation in bash --posix and zsh"

    require_shell zsh || return 0

    local check="[ \"\$COLOR_RESET\" = \"\$(printf '\\033[0m')\" ] && echo color_ok; \
[ \"\$BASH_LOGGER_VERSION\" != fake ] && echo version_ok"
    local shell_command
    local output
    for shell_command in "bash --posix" "zsh"; do
        output=$(BASH_LOGGER_VERSION=fake COLOR_RESET=x \
            run_with_logger_in_shell "$shell_command" "$check" 2>&1)
        assert_contains "$output" "color_ok" "COLOR_RESET should be the real escape ($shell_command)" || return
        assert_contains "$output" "version_ok" "BASH_LOGGER_VERSION should be real ($shell_command)" || return
    done

    pass_test
}

# Test: A readonly variable whose value contains " NAME=" does not satisfy a guard
test_guard_ignores_value_lookalike() {
    start_test "Guard ignores a readonly value that looks like a guarded name"

    local output
    output=$(bash -c "
        readonly DECOY='x BASH_LOGGER_VERSION=1 COLOR_RESET=2'
        . '$PROJECT_ROOT/logging.sh'
        echo \"version=\$BASH_LOGGER_VERSION\"
        [[ \"\$COLOR_RESET\" == \$'\\e[0m' ]] && echo color_ok
    " 2>&1)

    assert_matches "$output" "version=[0-9]+\.[0-9]+\.[0-9]+" "first source should initialise" || return
    assert_contains "$output" "color_ok" "colour constants should be initialised" || return

    pass_test
}

# Test: _is_readonly helper
test_is_readonly_helper() {
    start_test "_is_readonly detects readonly variables in every shell"

    require_shell zsh || return 0

    local snippet="readonly RO_PLAIN=1; RO_EXPORTED=2; export RO_EXPORTED; readonly RO_EXPORTED; \
NORMAL_VAR=3; unset UNSET_VAR; \
_is_readonly RO_PLAIN; printf '%s ' \"\$?\"; \
_is_readonly RO_EXPORTED; printf '%s ' \"\$?\"; \
_is_readonly NORMAL_VAR; printf '%s ' \"\$?\"; \
_is_readonly UNSET_VAR; printf '%s\n' \"\$?\""
    local shell_command
    local output
    for shell_command in "${GUARD_TEST_SHELLS[@]}"; do
        output=$(run_with_logger_in_shell "$shell_command" "$snippet" 2>&1)
        assert_equals "0 0 1 1" "$output" "_is_readonly results ($shell_command)" || return
    done

    pass_test
}

# Run all tests
test_resource_bash
test_resource_bash_posix
test_resource_zsh
test_resource_keeps_constants
test_resource_keeps_runtime_state
test_env_bypass_rejected_posix
test_guard_ignores_value_lookalike
test_is_readonly_helper
