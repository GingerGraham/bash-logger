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
# - Sourcing twice succeeds and leaves a working logger in every shell in TEST_SHELLS
# - Constants are unchanged after a second source
# - Runtime state after a second source (pins current behaviour)
# - Environment variables cannot bypass initialisation
# - The guard pattern is anchored and ignores look-alike values
# - The _is_readonly helper
#
# The cross-shell tests run once for each shell in TEST_SHELLS (Issue #195), as the other
# cross-shell suites do. The default is bash only. CI runs bash, bash --posix, zsh, dash and
# busybox ash. A shell that is not installed is skipped, or fails when it is listed in
# TEST_REQUIRE_SHELLS.

# Snippet that sources logging.sh a second time (the helper sources it first),
# reports the status, then logs a message.
_resource_snippet() {
    printf '%s' ". '$PROJECT_ROOT/logging.sh'; echo \"rc=\$?\"; init_logger --no-color; log_info 'after resource'"
}

# Test: Sourcing twice works
test_resource_works() {
    local shell_command="$1"
    start_test "[$shell_command] Sourcing logging.sh twice works (Issue #139)"

    require_shell "${shell_command%% *}" || return 0

    local output
    output=$(run_with_logger_in_shell "$shell_command" "$(_resource_snippet)" 2>&1)

    assert_contains "$output" "rc=0" "second source should return 0" || return
    assert_contains "$output" "after resource" "logger should work after second source" || return
    assert_not_contains "$output" "readonly variable" "no readonly errors" || return

    pass_test
}

# Test: Constants are unchanged after a second source
test_resource_keeps_constants() {
    local shell_command="$1"
    start_test "[$shell_command] Constants are unchanged after a second source"

    require_shell "${shell_command%% *}" || return 0

    local report="printf '%s|%s|%s\n' \"\$BASH_LOGGER_VERSION\" \"\$LOG_LEVEL_INFO\" \"\$COLOR_RESET\""
    local before
    local after
    before=$(run_with_logger_in_shell "$shell_command" "$report" 2>&1)
    after=$(run_with_logger_in_shell "$shell_command" \
        ". '$PROJECT_ROOT/logging.sh'; $report" 2>&1)
    assert_equals "$before" "$after" "constants changed" || return
    assert_contains "$after" "|6|" "LOG_LEVEL_INFO should be 6" || return

    pass_test
}

# Test: Runtime state after a second source (pins current behaviour)
# Mutable defaults are reassigned on every source, so the level set before the
# second source is reset to INFO. This test pins that, in every shell.
test_resource_keeps_runtime_state() {
    local shell_command="$1"
    start_test "[$shell_command] Second source resets mutable log level to the default"

    require_shell "${shell_command%% *}" || return 0

    local snippet="init_logger --quiet; set_log_level DEBUG >/dev/null; \
. '$PROJECT_ROOT/logging.sh'; echo \"level=\$CURRENT_LOG_LEVEL\""
    local output
    output=$(run_with_logger_in_shell "$shell_command" "$snippet" 2>&1)
    assert_equals "level=6" "$output" "log level after second source" || return

    pass_test
}

# Test: Environment variables do not bypass initialisation
test_env_bypass_rejected() {
    local shell_command="$1"
    start_test "[$shell_command] Environment variables cannot bypass initialisation"

    require_shell "${shell_command%% *}" || return 0

    local check="[ \"\$COLOR_RESET\" = \"\$(printf '\\033[0m')\" ] && echo color_ok; \
[ \"\$BASH_LOGGER_VERSION\" != fake ] && echo version_ok"
    local output
    output=$(BASH_LOGGER_VERSION=fake COLOR_RESET=x \
        run_with_logger_in_shell "$shell_command" "$check" 2>&1)
    assert_contains "$output" "color_ok" "COLOR_RESET should be the real escape" || return
    assert_contains "$output" "version_ok" "BASH_LOGGER_VERSION should be real" || return

    pass_test
}

# Test: A readonly variable whose value contains " NAME=" does not satisfy a guard
test_guard_ignores_value_lookalike() {
    local shell_command="$1"
    start_test "[$shell_command] Guard ignores a readonly value that looks like a guarded name"

    require_shell "${shell_command%% *}" || return 0

    local snippet="readonly DECOY='x BASH_LOGGER_VERSION=1 COLOR_RESET=2'
. '$PROJECT_ROOT/logging.sh'
echo \"version=\$BASH_LOGGER_VERSION\"
[ \"\$COLOR_RESET\" = \"\$(printf '\\033[0m')\" ] && echo color_ok"
    local output
    output=$(run_with_logger_in_shell "$shell_command" "$snippet" 2>&1)

    assert_matches "$output" "version=[0-9]+\.[0-9]+\.[0-9]+" "first source should initialise" || return
    assert_contains "$output" "color_ok" "colour constants should be initialised" || return

    pass_test
}

# Test: _is_readonly helper
test_is_readonly_helper() {
    local shell_command="$1"
    start_test "[$shell_command] _is_readonly detects readonly variables"

    require_shell "${shell_command%% *}" || return 0

    local snippet="readonly RO_PLAIN=1; RO_EXPORTED=2; export RO_EXPORTED; readonly RO_EXPORTED; \
NORMAL_VAR=3; unset UNSET_VAR; \
_is_readonly RO_PLAIN; printf '%s ' \"\$?\"; \
_is_readonly RO_EXPORTED; printf '%s ' \"\$?\"; \
_is_readonly NORMAL_VAR; printf '%s ' \"\$?\"; \
_is_readonly UNSET_VAR; printf '%s\n' \"\$?\""
    local output
    output=$(run_with_logger_in_shell "$shell_command" "$snippet" 2>&1)
    assert_equals "0 0 1 1" "$output" "_is_readonly results" || return

    pass_test
}

# Test: _is_readonly is reliable under a caller's pipefail
# Over 64 KiB of readonly -p output fills the pipe buffer, so a grep that
# exits on its first match leaves readonly -p blocked and it is killed by
# SIGPIPE. Under pipefail that turned a readonly variable into "not readonly".
test_is_readonly_with_pipefail() {
    local shell_command="$1"
    start_test "[$shell_command] _is_readonly is reliable under pipefail with large readonly -p output"

    require_shell "${shell_command%% *}" || return 0

    # pipefail is not POSIX. A shell without it (dash, older busybox ash) cannot run this test.
    # A POSIX shell exits on an unknown set option, so the probe runs in its own process.
    # shellcheck disable=SC2086  # word splitting of shell_command is intended
    if ! $shell_command -c 'set -o pipefail' >/dev/null 2>&1; then
        skip_test "${shell_command%% *} has no pipefail option"
        return 0
    fi

    local snippet='set -o pipefail; i=0; \
while [ "$i" -lt 2000 ]; do \
eval "readonly ZZ_FILL_$i=$(printf %0100d 0)"; i=$((i + 1)); done; \
readonly AAA_RO=1; _is_readonly AAA_RO; echo "rc=$?"'
    local output
    output=$(run_with_logger_in_shell "$shell_command" "$snippet" 2>&1)
    assert_equals "rc=0" "$output" "_is_readonly under pipefail" || return

    pass_test
}

# Run all tests, once for each shell in TEST_SHELLS
while IFS= read -r guard_shell; do
    test_resource_works "$guard_shell"
    test_resource_keeps_constants "$guard_shell"
    test_resource_keeps_runtime_state "$guard_shell"
    test_env_bypass_rejected "$guard_shell"
    test_guard_ignores_value_lookalike "$guard_shell"
    test_is_readonly_helper "$guard_shell"
    test_is_readonly_with_pipefail "$guard_shell"
done <<< "$(test_shell_list)"
