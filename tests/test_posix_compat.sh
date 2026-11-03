#!/usr/bin/env bash
#
# test_posix_compat.sh - Behaviour that differs, or could differ, between shells (Issue #143)
#
# Each test runs logging.sh under every shell in TEST_SHELLS (see test_shell_list in
# test_helpers.sh). Shells that are not installed are skipped unless they are listed
# in TEST_REQUIRE_SHELLS.
#
# Tests:
# - Caller detection: the script name is the calling script when sourced with "."
# - Truncation: characters in bash and zsh, bytes in dash and busybox, and a UTF-8
#   character is never cut in half
# - Truncation byte classes cannot be injected through the environment
# - Color constants hold the real escape bytes
# - init_logger options, including a missing value at the end, parse as in bash
# - Sourcing and logging under set -eu does not exit the caller
# - Running logging.sh directly in bash prints the usage message
# - scripts/check-posix-compat.sh accepts logging.sh and rejects bash-only syntax

# Run a snippet with logging.sh sourced, under a shell command, with a fixed locale.
# The snippet runs from a script file (not -c), so the detected script name is the
# same in every shell.
run_snippet_in_shell() {
    local shell_command="$1"
    local locale_name="$2"
    local snippet="$3"
    # A fixed name, so the detected script name is the same on every run
    local snippet_file="$TEST_DIR/snippet.sh"
    printf '%s\n' ". '$PROJECT_ROOT/logging.sh'" "$snippet" > "$snippet_file"
    # shellcheck disable=SC2086  # word splitting of shell_command is intended
    env -i PATH="$PATH" HOME="$TEST_DIR" LC_ALL="$locale_name" \
        $shell_command "$snippet_file" </dev/null
    local status=$?
    rm -f "$snippet_file"
    return "$status"
}

# Print an installed UTF-8 locale name, or nothing
utf8_locale_name() {
    local candidate
    for candidate in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8; do
        if locale -a 2>/dev/null | grep -qx "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
}

test_posix_caller_detection() {
    local shell_command="$1"
    start_test "[$shell_command] script name is the calling script when sourced with ."

    require_shell "${shell_command%% *}" || return 0

    local caller_script="$TEST_DIR/my_caller.sh"
    printf '%s\n' \
        ". '$PROJECT_ROOT/logging.sh'" \
        "init_logger --no-color --format '%s|%m'" \
        "log_info detected" > "$caller_script"

    local output
    # shellcheck disable=SC2086  # word splitting of shell_command is intended
    output=$(env -i PATH="$PATH" LC_ALL=C $shell_command "$caller_script" 2>&1 </dev/null)

    assert_equals "my_caller.sh|detected" "$output" || return

    pass_test
}

test_posix_truncation_bytes() {
    local shell_command="$1"
    start_test "[$shell_command] truncation follows the documented character or byte rule"

    require_shell "${shell_command%% *}" || return 0

    # ASCII: the same in every shell
    local output
    output=$(run_snippet_in_shell "$shell_command" C \
        "init_logger --no-color --format '%m' --max-line-length 20; \
log_info 'abcdefghijklmnopqrstuvwxyz'; \
LOG_MAX_LINE_LENGTH=5; log_info 'abcdefghij'" 2>&1)
    assert_equals "abcdef...[truncated]
abcde" "$output" "ASCII truncation" || return

    local utf8_locale
    utf8_locale=$(utf8_locale_name)
    if [[ -z "$utf8_locale" ]]; then
        skip_test "no UTF-8 locale installed for the multi-byte cases"
        return 0
    fi

    # "a" then 20 two-byte characters (é). The limit leaves 6 to keep before the suffix.
    output=$(run_snippet_in_shell "$shell_command" "$utf8_locale" \
        "init_logger --no-color --format '%m' --max-line-length 20; \
log_info 'aéééééééééééééééééééé'; \
LOG_MAX_LINE_LENGTH=4; log_info 'ééééé'" 2>&1)

    if shell_counts_characters "$shell_command"; then
        # 6 characters, then 4 characters
        assert_equals "aééééé...[truncated]
éééé" "$output" "character truncation" || return
    else
        # 6 bytes is "a", two é and half of the third: the half character is removed.
        # 4 bytes is exactly two é.
        assert_equals "aéé...[truncated]
éé" "$output" "byte truncation" || return
    fi

    pass_test
}

test_posix_ansi_constants() {
    local shell_command="$1"
    start_test "[$shell_command] color constants contain the real escape bytes"

    require_shell "${shell_command%% *}" || return 0

    # Each constant is compared, inside the shell under test, with the bytes printf
    # makes from an octal escape. This avoids od, whose output format differs
    # between GNU and BSD.
    local output
    output=$(run_snippet_in_shell "$shell_command" C '
check() {
    if [ "$2" = "$(printf "\033[$3")" ]; then
        printf "%s ok\n" "$1"
    else
        printf "%s wrong\n" "$1"
    fi
}
check COLOR_RESET "$COLOR_RESET" "0m"
check COLOR_BLUE "$COLOR_BLUE" "34m"
check COLOR_GREEN "$COLOR_GREEN" "32m"
check COLOR_YELLOW "$COLOR_YELLOW" "33m"
check COLOR_RED "$COLOR_RED" "31m"
check COLOR_RED_BOLD "$COLOR_RED_BOLD" "31;1m"
check COLOR_WHITE_ON_RED "$COLOR_WHITE_ON_RED" "37;41m"
check COLOR_BOLD_WHITE_ON_RED "$COLOR_BOLD_WHITE_ON_RED" "1;37;41m"
check COLOR_PURPLE "$COLOR_PURPLE" "35m"
check COLOR_CYAN "$COLOR_CYAN" "36m"
' 2>&1)

    local expected
    expected=$(printf '%s ok\n' COLOR_RESET COLOR_BLUE COLOR_GREEN COLOR_YELLOW COLOR_RED \
        COLOR_RED_BOLD COLOR_WHITE_ON_RED COLOR_BOLD_WHITE_ON_RED COLOR_PURPLE COLOR_CYAN)

    assert_equals "$expected" "$output" || return

    pass_test
}

test_posix_init_logger_args() {
    local shell_command="$1"
    start_test "[$shell_command] init_logger options parse as in bash"

    require_shell "${shell_command%% *}" || return 0

    local report="printf '%s|' \"\$?\" \"\$CONSOLE_LOG\" \"\$CURRENT_LOG_LEVEL\" \"\$LOG_STDERR_LEVEL\" \
\"\$USE_COLORS\" \"\$USE_UTC\" \"\$LOG_FORMAT\" \"\$SCRIPT_NAME\" \"\$JOURNAL_TAG\" \"\$SYSLOG_FACILITY\" \
\"\$LOG_UNSAFE_ALLOW_NEWLINES\" \"\$LOG_UNSAFE_ALLOW_ANSI_CODES\" \"\$LOG_MAX_LINE_LENGTH\" \
\"\$LOG_MAX_JOURNAL_LENGTH\" \"\$LOG_INIT_MESSAGE\"; printf '\\n'"

    local snippet="init_logger --quiet --color --utc --verbose --no-init-message; $report
init_logger -q --no-colour -d warn -e 1 -f '%l %m' -n 'a name' -t tag1 -F local2 -U -A \
--max-line-length 50 --max-journal-length 60; $report
init_logger --level 3 --stderr-level CRIT --format '' --name '' --tag '' --facility USER; $report"

    local option
    for option in -d --level -f --format -l --log --logfile --log-file --file \
                  -n --name --script-name -t --tag -e --stderr-level -F --facility \
                  --max-line-length --max-journal-length -c --config; do
        snippet="$snippet
init_logger --quiet $option; $report"
    done
    snippet="$snippet
printf 'finished\\n'"

    local reference_output
    local shell_output
    reference_output=$(run_with_timeout 30 run_snippet_in_shell "bash" C "$snippet" 2>&1)
    shell_output=$(run_with_timeout 30 run_snippet_in_shell "$shell_command" C "$snippet" 2>&1)

    # bash must finish (it used to loop forever on a missing value) and report each one
    assert_contains "$reference_output" "finished" "bash finished" || return
    assert_contains "$reference_output" "Error: --format requires a value" || return
    assert_contains "$reference_output" "Error: -t requires a value" || return
    assert_contains "$reference_output" "Error: --config requires a file path argument" || return
    if [[ "$reference_output" != "$shell_output" ]]; then
        fail_test "Output differs from bash (diff below)"
        diff <(printf '%s\n' "$reference_output") <(printf '%s\n' "$shell_output") \
            | head -20 | sed 's/^/    /'
        return 0
    fi

    pass_test
}

test_posix_set_e_set_u() {
    local shell_command="$1"
    start_test "[$shell_command] sourcing and logging under set -eu does not exit the caller"

    require_shell "${shell_command%% *}" || return 0

    local log_file="$TEST_DIR/eu.log"
    local output
    # shellcheck disable=SC2086  # word splitting of shell_command is intended
    output=$(env -i PATH="$PATH" LC_ALL=C $shell_command -c "set -eu
. '$PROJECT_ROOT/logging.sh'
. '$PROJECT_ROOT/logging.sh'
init_logger --quiet --level DEBUG --log '$log_file'
log_debug d; log_info i; log_notice n; log_warn w; log_error e; log_critical c
log_alert a; log_emergency em; log_fatal f; log_init init; log_sensitive s
set_log_level WARN; log_info filtered
set_log_format '%l %m'; set_script_name eu; set_timezone_utc true; set_color_mode never
set_journal_logging false; set_unsafe_allow_newlines false; set_unsafe_allow_ansi_codes false
LOG_MAX_LINE_LENGTH=20; log_warn 'a message that is long enough to be truncated'
_validate_config_file_path /tmp/a.log log_file 1
check_logger_available || true
printf 'reached the end\n'" 2>&1)

    assert_contains "$output" "reached the end" || return
    assert_file_contains "$log_file" "WARN a mess...[truncated]" || return

    pass_test
}

test_posix_truncation_ignores_environment() {
    local shell_command="$1"
    start_test "[$shell_command] truncation byte classes are not taken from the environment"

    require_shell "${shell_command%% *}" || return 0

    # The byte classes are inserted into a sed script when truncating by bytes. A value
    # from the environment must not reach it (GNU sed's e command runs a shell command).
    local marker="$TEST_DIR/injected"
    local injected="x//;e touch $marker #"
    local output
    # shellcheck disable=SC2086  # word splitting of shell_command is intended
    output=$(env -i PATH="$PATH" LC_ALL=C \
        _LOGGER_UTF8_LEAD="$injected" _LOGGER_UTF8_LEAD3="$injected" \
        _LOGGER_UTF8_LEAD4="$injected" _LOGGER_UTF8_CONTINUATION="$injected" \
        $shell_command -c ". '$PROJECT_ROOT/logging.sh'; \
init_logger --no-color --format '%m' --max-line-length 20; \
log_info 'abcdefghijklmnopqrstuvwxyz'" 2>&1 </dev/null)

    assert_file_not_exists "$marker" "sed command from the environment ran" || return
    assert_equals "abcdef...[truncated]" "$output" || return

    pass_test
}

test_posix_executed_directly() {
    start_test "Running logging.sh directly in bash prints the usage message"

    local output
    local status=0
    output=$(bash "$PROJECT_ROOT/logging.sh" 2>&1) || status=$?

    assert_equals "1" "$status" "exit status" || return
    assert_contains "$output" "designed to be sourced" || return
    assert_contains "$output" "Usage: source logging.sh" || return

    pass_test
}

test_posix_lint_check() {
    start_test "check-posix-compat.sh passes logging.sh and rejects bash-only syntax"

    if ! command -v shellcheck >/dev/null 2>&1; then
        skip_test "shellcheck not installed"
        return 0
    fi

    local check_script="$PROJECT_ROOT/scripts/check-posix-compat.sh"
    local output
    local status=0
    output=$("$check_script" 2>&1) || status=$?
    assert_equals "0" "$status" "logging.sh: $output" || return

    local sample_file="$TEST_DIR/sample.sh"
    printf '%s\n' 'if [[ -n "$x" ]]; then y="${x:0:1}"; fi' > "$sample_file"
    status=0
    output=$("$check_script" "$sample_file" 2>&1) || status=$?
    assert_equals "1" "$status" "bash-only sample should fail" || return
    assert_contains "$output" "SC3010" || return
    assert_contains "$output" "SC3057" || return

    pass_test
}

# Run all tests
test_posix_executed_directly
test_posix_lint_check
while IFS= read -r posix_shell; do
    test_posix_caller_detection "$posix_shell"
    test_posix_truncation_bytes "$posix_shell"
    test_posix_truncation_ignores_environment "$posix_shell"
    test_posix_ansi_constants "$posix_shell"
    test_posix_init_logger_args "$posix_shell"
    test_posix_set_e_set_u "$posix_shell"
done <<< "$(test_shell_list)"
