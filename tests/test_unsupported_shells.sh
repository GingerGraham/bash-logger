#!/usr/bin/env bash
#
# test_unsupported_shells.sh - Tests for the source-time self-check (Issue #196)
#
# A shell that is not bash or zsh runs the portable code, which is written and tested for
# dash and busybox ash. A shell that cannot run it correctly must refuse to load logging.sh
# instead of writing log lines. posh loads the file but does not sanitize newlines (a forged
# log line is written), and ksh93 has no `local`.
#
# Tests:
# - posh and ksh93 each refuse to load: status 1, one error on stderr, no log functions, no log
#   file, a script under set -e stops, and running logging.sh directly exits 1
# - No environment variable skips the check
# - The shells that are supported load without output and leave nothing behind
# - The check does not run in bash and zsh, and the file holds a literal tab for it
#
# One test covers each unsupported shell, so a machine without the shell records one skip.

# Write a script that sources logging.sh, then tries to log a message with a newline
# Arguments: file path, log file path, optional first line of the script
_write_probe_script() {
    local script_file="$1"
    local log_file="$2"
    local first_line="${3:-}"
    {
        if [[ -n "$first_line" ]]; then
            printf '%s\n' "$first_line"
        fi
        printf '%s\n' ". '$PROJECT_ROOT/logging.sh'"
        printf '%s\n' "printf 'source status=%s\\n' \"\$?\""
        printf '%s\n' "init_logger --quiet --no-init-message --log '$log_file' 2>/dev/null"
        printf '%s\n' "log_info \"\$(printf 'first\\n2026-01-01 00:00:00 [ERROR] [x] forged')\" 2>/dev/null"
        printf '%s\n' "printf 'script continued\\n'"
    } > "$script_file"
}

# Assert that one shell refuses to load logging.sh and writes no log line
# Arguments: shell name, text of the reason the error message must give
_assert_shell_refuses_to_load() {
    local shell_name="$1"
    local reason="$2"
    local script_file="$TEST_DIR/probe.sh"
    local log_file="$TEST_DIR/probe.log"

    # Sourced: one error, status 1, and the script carries on with no log function to call
    _write_probe_script "$script_file" "$log_file"
    local stdout=""
    stdout=$("$shell_name" "$script_file" 2>"$TEST_STDERR")
    local stderr=""
    stderr=$(cat "$TEST_STDERR")

    assert_contains "$stdout" "source status=1" "$shell_name: . returns 1" || return 1
    assert_contains "$stderr" "logging.sh: this shell cannot run bash-logger safely ($reason)." "$shell_name: error message" || return 1
    assert_contains "$stderr" "Supported shells: bash 3.2+, zsh, dash, busybox ash, mksh" "$shell_name: supported shells" || return 1
    assert_contains "$stderr" "docs/shell-compatibility.md" "$shell_name: documentation" || return 1
    assert_equals 1 "$(printf '%s\n' "$stderr" | grep -c 'cannot run bash-logger safely')" "$shell_name: one error" || return 1
    assert_file_not_exists "$log_file" "$shell_name: no log file written" || return 1

    # No function is defined, so a script that carries on cannot log
    local functions_script="$TEST_DIR/functions.sh"
    printf '%s\n' ". '$PROJECT_ROOT/logging.sh' 2>/dev/null" \
        "for name in init_logger log_info _log_message _replace_all set_log_level; do" \
        "    if command -v \"\$name\" >/dev/null 2>&1; then echo \"defined: \$name\"; fi" \
        "done" \
        "echo checked" > "$functions_script"
    stdout=$("$shell_name" "$functions_script" 2>/dev/null)
    assert_contains "$stdout" "checked" "$shell_name: function probe ran" || return 1
    assert_not_contains "$stdout" "defined:" "$shell_name: no function is defined" || return 1

    # A script that runs under set -e stops at the failed source
    _write_probe_script "$script_file" "$log_file" "set -e"
    stdout=$("$shell_name" "$script_file" 2>/dev/null)
    local exit_code=$?
    assert_equals 1 "$exit_code" "$shell_name: set -e exit status" || return 1
    assert_not_contains "$stdout" "script continued" "$shell_name: set -e script stopped" || return 1
    assert_file_not_exists "$log_file" "$shell_name: set -e, no log file written" || return 1

    # Run directly, the file exits with 1
    "$shell_name" "$PROJECT_ROOT/logging.sh" >/dev/null 2>"$TEST_STDERR"
    exit_code=$?
    assert_equals 1 "$exit_code" "$shell_name: direct execution status" || return 1
    assert_file_contains "$TEST_STDERR" "this shell cannot run bash-logger safely" "$shell_name: direct execution message" || return 1

    # No environment variable skips the check, and none selects a supported family
    _write_probe_script "$script_file" "$log_file"
    stdout=$(env -i PATH="$PATH" LC_ALL=C \
        _LOGGER_SHELL_FAMILY=bash BASH_VERSION=5.2.21 ZSH_VERSION=5.9 \
        LOGGER_SKIP_SHELL_CHECK=1 LOGGER_SKIP_SELF_CHECK=true LOGGING_SH_FORCE=1 \
        _logger_check_reason="" _logger_check_failed="" \
        "$shell_name" "$script_file" 2>/dev/null)
    assert_contains "$stdout" "source status=1" "$shell_name: environment does not skip the check" || return 1
    assert_file_not_exists "$log_file" "$shell_name: environment, no log file written" || return 1
}

# Test: posh loads the file but does not remove text with a quoted pattern, so a newline in a
# message would write a second, forged log line (Issue #196)
test_posh_refuses_to_load() {
    start_test "posh refuses to load logging.sh and writes no log line"

    require_shell posh || return 0

    _assert_shell_refuses_to_load posh "a parameter expansion with a quoted pattern does not remove text" || return

    pass_test
}

# Test: ksh93 has no local, so a function would change the variables of its caller (Issue #196)
test_ksh_refuses_to_load() {
    start_test "ksh93 refuses to load logging.sh and writes no log line"

    require_shell ksh || return 0
    # A binary named ksh can be mksh or another shell that is not ksh93
    case "$(ksh --version 2>&1)" in
        *93*) ;;
        *) skip_test "ksh is not ksh93"; return 0 ;;
    esac

    _assert_shell_refuses_to_load ksh "'local' does not keep a variable local to a function" || return

    pass_test
}

# Test: supported shells load with no output and leave nothing of the check behind
test_supported_shells_load_silently() {
    start_test "dash and busybox ash load with no output and leave no check variables or function"

    local shell_command
    for shell_command in "dash" "busybox sh"; do
        require_shell "${shell_command%% *}" || return 0

        local script_file="$TEST_DIR/silent.sh"
        printf '%s\n' "set -eu" ". '$PROJECT_ROOT/logging.sh'" \
            "printf 'status=%s\\n' \"\$?\"" \
            "printf 'leftover=%s\\n' \"\$(set | grep -c '_logger_check')\"" \
            "if command -v _logger_check_local >/dev/null 2>&1; then echo 'function left'; fi" \
            > "$script_file"

        local stdout="" stderr=""
        # shellcheck disable=SC2086  # word splitting of shell_command is intended
        stdout=$($shell_command "$script_file" 2>"$TEST_STDERR")
        stderr=$(cat "$TEST_STDERR")

        assert_equals "" "$stderr" "$shell_command: nothing on stderr" || return
        assert_contains "$stdout" "status=0" "$shell_command: . returns 0" || return
        assert_contains "$stdout" "leftover=0" "$shell_command: no check variable left" || return
        assert_not_contains "$stdout" "function left" "$shell_command: no check function left" || return
    done

    pass_test
}

# Test: the check does not run in bash and zsh
test_self_check_skipped_in_bash_and_zsh() {
    start_test "The self-check is skipped in bash and zsh"

    local shell_command
    for shell_command in "bash" "bash --posix" "zsh"; do
        require_shell "${shell_command%% *}" || return 0

        # The check defines and then unsets _logger_check_local. A function of that name
        # that the caller defined before sourcing survives only if the check did not run.
        local output=""
        # shellcheck disable=SC2086  # word splitting of shell_command is intended
        output=$($shell_command -c "_logger_check_local() { echo kept; }; . '$PROJECT_ROOT/logging.sh'; _logger_check_local" 2>&1)

        assert_equals "kept" "$output" "$shell_command: the check did not run" || return
    done

    pass_test
}

# Test: the file holds a literal tab for the tab check
test_self_check_has_literal_tab() {
    start_test "The self-check tab is a literal tab character"

    # An editor that turns the tab into spaces would leave the check running with a space
    local tab_character=""
    tab_character=$(printf '\t')
    assert_file_contains "$PROJECT_ROOT/logging.sh" "_logger_check_tab='$tab_character'" || return

    pass_test
}

# Run all tests
test_posh_refuses_to_load
test_ksh_refuses_to_load
test_supported_shells_load_silently
test_self_check_skipped_in_bash_and_zsh
test_self_check_has_literal_tab
