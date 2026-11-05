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
# - A failing tr falls back to the in-shell replacement for long messages
# - busybox in a UTF-8 locale still truncates by bytes (_text_length), and the
#   _LOGGER_UTF8_PROBE value cannot be set through the environment
# - Messages -n, -e and -E are logged as written
# - Sourcing from inside a function keeps the constants (zsh readonly is local there)
# - A trap handler that logs does not replace the message in progress
# - log_sensitive text does not stay in shell variables
# - A logger symlink to busybox is accepted only in a safe directory
# - A second --config with no value returns an error
# - --max-line-length and --max-journal-length, a config file BOM, truncating 4-byte
#   characters, a failing logger, and level names in a Turkish locale

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

# Print text of a length: 63 characters then a newline, repeated, cut to the length
make_multiline_text() {
    awk -v length_wanted="$1" 'BEGIN {
        text = ""
        line = 0
        while (length(text) < length_wanted) {
            for (j = 0; j < 63; j++) text = text sprintf("%c", 97 + (line + j) % 26)
            text = text "\n"
            line++
        }
        printf "%s", substr(text, 1, length_wanted)
    }'
}

test_posix_tr_failure_fallback() {
    local shell_command="$1"
    start_test "[$shell_command] a failing tr does not lose or skip sanitizing a long message"

    require_shell "${shell_command%% *}" || return 0

    # Long enough for the tr path: above 2,048 characters, or 16,384 in bash and zsh
    local message_size=3000
    if shell_counts_characters "$shell_command"; then
        message_size=17000
    fi
    local message_file="$TEST_DIR/message.txt"
    make_multiline_text "$message_size" > "$message_file"

    local marker="$TEST_DIR/tr-called"
    local log_setup="init_logger --quiet --no-color --format '%m' --max-line-length 0"
    local read_message="message=\$(cat '$message_file')"

    run_snippet_in_shell "$shell_command" C "$log_setup --log '$TEST_DIR/working.log'
$read_message
log_info \"\$message\"" >/dev/null 2>&1

    # tr is replaced after init_logger, so only the sanitizer can call it
    run_snippet_in_shell "$shell_command" C "$log_setup --log '$TEST_DIR/broken.log'
$read_message
tr() { : > '$marker'; return 127; }
log_info \"\$message\"" >/dev/null 2>&1

    assert_file_exists "$marker" "the failing tr was not called" || return
    local working_line
    local broken_line
    working_line=$(tail -1 "$TEST_DIR/working.log")
    broken_line=$(tail -1 "$TEST_DIR/broken.log")
    assert_equals "$working_line" "$broken_line" "log line with a failing tr" || return
    assert_equals "2" "$(wc -l < "$TEST_DIR/broken.log" | tr -d ' ')" \
        "one init line and one message line" || return

    pass_test
}

test_posix_busybox_utf8_byte_length() {
    start_test "busybox sh in a UTF-8 locale truncates multi-byte text by bytes"

    require_shell busybox || return 0
    local utf8_locale
    utf8_locale=$(utf8_locale_name)
    if [[ -z "$utf8_locale" ]]; then
        skip_test "no UTF-8 locale installed"
        return 0
    fi

    # "a" and 3,000 two-byte characters: 6,001 bytes but 3,001 characters, so a
    # character count would fit the 4,096 limit. 4,096 - 14 (suffix) = 4,082 bytes is
    # "a", 2,040 characters and half of the next, which is removed.
    local message="a"
    local expected="a"
    local index=0
    while [[ $index -lt 3000 ]]; do
        message="${message}é"
        if [[ $index -lt 2040 ]]; then
            expected="${expected}é"
        fi
        index=$((index + 1))
    done
    expected="${expected}...[truncated]"

    local output
    output=$(run_snippet_in_shell "busybox sh" "$utf8_locale" \
        "init_logger --no-color --format '%m'; log_info '$message'" 2>&1)
    assert_equals "$expected" "$output" "without an environment probe value" || return

    # A probe value from the environment (2 characters, as if the shell counted bytes)
    # must be cleared at source time, or the byte count would be skipped
    local snippet_file="$TEST_DIR/probe.sh"
    printf '%s\n' ". '$PROJECT_ROOT/logging.sh'" \
        "init_logger --no-color --format '%m'; log_info '$message'" > "$snippet_file"
    output=$(env -i PATH="$PATH" LC_ALL="$utf8_locale" _LOGGER_UTF8_PROBE="ab" \
        busybox sh "$snippet_file" 2>&1 </dev/null)
    assert_equals "$expected" "$output" "with _LOGGER_UTF8_PROBE=ab in the environment" || return

    pass_test
}

test_posix_probe_ignores_environment() {
    local shell_command="$1"
    start_test "[$shell_command] _LOGGER_UTF8_PROBE is not taken from the environment"

    require_shell "${shell_command%% *}" || return 0

    local output
    # shellcheck disable=SC2086  # word splitting of shell_command is intended
    output=$(env -i PATH="$PATH" LC_ALL=C _LOGGER_UTF8_PROBE="ab" \
        $shell_command -c ". '$PROJECT_ROOT/logging.sh'; printf '[%s]\n' \"\$_LOGGER_UTF8_PROBE\"" \
        2>&1 </dev/null)

    assert_equals "[]" "$output" || return

    pass_test
}

test_posix_echo_option_messages() {
    local shell_command="$1"
    start_test "[$shell_command] messages -n, -e and -E are logged as written"

    require_shell "${shell_command%% *}" || return 0

    # bash before Issue #143 logged these as empty lines, because the message went
    # through echo; the sanitizing golden corpus leaves them out for that reason
    local output
    output=$(run_snippet_in_shell "$shell_command" C \
        "init_logger --no-color --format '[%m]'; log_info '-n'; log_info '-e'; log_info '-E'; \
log_info '-n -e text'" 2>&1)

    assert_equals "[-n]
[-e]
[-E]
[-n -e text]" "$output" || return

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

test_posix_source_in_function() {
    local shell_command="$1"
    start_test "[$shell_command] sourcing from inside a function keeps the constants"

    require_shell "${shell_command%% *}" || return 0

    local caller_script="$TEST_DIR/in_function.sh"
    printf '%s\n' \
        "setup() {" \
        "    . '$PROJECT_ROOT/logging.sh'" \
        "    init_logger --no-color --format '%s|%l|%m'" \
        "    log_info inside" \
        "}" \
        "setup" \
        'log_info "outside $LOG_LEVEL_DEBUG"' > "$caller_script"

    local output
    # shellcheck disable=SC2086  # word splitting of shell_command is intended
    output=$(run_with_timeout 20 env -i PATH="$PATH" LC_ALL=C \
        $shell_command "$caller_script" 2>&1 </dev/null)

    assert_equals "in_function.sh|INFO|inside
in_function.sh|INFO|outside 7" "$output" || return

    pass_test
}

test_posix_trap_keeps_message() {
    local shell_command="$1"
    start_test "[$shell_command] a trap that logs does not replace the message in progress"

    require_shell "${shell_command%% *}" || return 0

    # The signal arrives while sed strips the message, so the handler runs before the
    # result reaches the rest of _log_message
    local output
    output=$(run_with_timeout 20 run_snippet_in_shell "$shell_command" C '
init_logger --no-color --format "%m"
trap "log_warn handler" USR1
sed() { kill -USR1 $$; sleep 1; command sed "$@"; }
log_info "$(printf "\033[1mkept\033[0m")"
' 2>&1)

    assert_contains "$output" "kept" || return

    pass_test
}

test_posix_message_not_kept_in_variables() {
    local shell_command="$1"
    start_test "[$shell_command] log_sensitive text does not stay in shell variables"

    require_shell "${shell_command%% *}" || return 0

    local output
    output=$(run_snippet_in_shell "$shell_command" C '
init_logger --no-color >/dev/null
log_sensitive "hunter2-secret" >/dev/null
:
set | grep -c hunter2-secret
' 2>&1)

    assert_equals "0" "$output" || return

    pass_test
}

test_posix_busybox_logger_symlink() {
    local shell_command="$1"
    start_test "[$shell_command] a logger symlink to busybox in a safe directory is accepted"

    require_shell "${shell_command%% *}" || return 0

    local system_logger
    system_logger=$(command -v logger 2>/dev/null)
    case "$system_logger" in
        /bin/logger|/usr/bin/logger|/usr/local/bin/logger|/sbin/logger|/usr/sbin/logger) ;;
        *)
            skip_test "logger is not in a safe directory"
            return 0
            ;;
    esac

    # readlink reports what it would for a busybox applet symlink
    local output
    output=$(run_snippet_in_shell "$shell_command" C '
readlink() { printf "%s\n" /usr/bin/busybox; }
check_logger_available
printf "%s|%s\n" "$?" "$LOGGER_PATH"
' 2>&1)
    assert_equals "0|$system_logger" "$output" || return

    # The same symlink outside a safe directory is still rejected
    mkdir -p "$TEST_DIR/unsafe_bin"
    ln -sf "$system_logger" "$TEST_DIR/unsafe_bin/logger"
    output=$(run_snippet_in_shell "$shell_command" C "
PATH='$TEST_DIR/unsafe_bin':\$PATH
readlink() { printf '%s\n' /usr/bin/busybox; }
check_logger_available
printf 'status=%s\n' \"\$?\"
" 2>&1)
    assert_contains "$output" "status=1" || return

    # A link in another directory on the way to busybox could be changed later
    output=$(run_snippet_in_shell "$shell_command" C '
readlink() {
    case "$1" in
        -f) printf "%s\n" /usr/bin/busybox ;;
        *) printf "%s\n" /tmp/elsewhere/logger ;;
    esac
}
check_logger_available 2>/dev/null
printf "status=%s path=[%s]\n" "$?" "$LOGGER_PATH"
' 2>&1)
    assert_equals "status=1 path=[]" "$output" || return

    pass_test
}

test_posix_second_config_without_value() {
    local shell_command="$1"
    start_test "[$shell_command] a second --config with no value returns an error"

    require_shell "${shell_command%% *}" || return 0

    printf 'level=info\n' > "$TEST_DIR/second.ini"
    local output
    output=$(run_with_timeout 20 run_snippet_in_shell "$shell_command" C "
init_logger -c '$TEST_DIR/second.ini' -c
printf 'status=%s\n' \"\$?\"
" 2>&1)

    assert_contains "$output" "requires a value" || return
    assert_contains "$output" "status=1" || return

    pass_test
}

test_posix_max_length_options() {
    local shell_command="$1"
    start_test "[$shell_command] --max-line-length and --max-journal-length set their variables"

    require_shell "${shell_command%% *}" || return 0

    local output
    output=$(run_snippet_in_shell "$shell_command" C '
init_logger --quiet --max-line-length 50 --max-journal-length 60
printf "%s|%s\n" "$LOG_MAX_LINE_LENGTH" "$LOG_MAX_JOURNAL_LENGTH"
' 2>&1)
    assert_equals "50|60" "$output" || return

    pass_test
}

test_posix_config_bom() {
    local shell_command="$1"
    start_test "[$shell_command] a UTF-8 BOM at the start of a config file is ignored"

    require_shell "${shell_command%% *}" || return 0

    printf '\357\273\277level=debug\n' > "$TEST_DIR/bom.ini"
    local output
    output=$(run_snippet_in_shell "$shell_command" C "
init_logger --quiet -c '$TEST_DIR/bom.ini'
printf '%s\n' \"\$CURRENT_LOG_LEVEL\"
" 2>&1)
    assert_equals "7" "$output" || return

    pass_test
}

test_posix_truncation_four_byte_character() {
    local shell_command="$1"
    start_test "[$shell_command] truncation never cuts a 4-byte character in half"

    require_shell "${shell_command%% *}" || return 0

    local locale_name
    locale_name=$(utf8_locale_name)
    if [[ -z "$locale_name" ]]; then
        skip_test "no UTF-8 locale installed"
        return 0
    fi

    local output
    output=$(run_snippet_in_shell "$shell_command" "$locale_name" '
init_logger --no-color --format "%m"
for limit in 18 19 20 21 22 23 24 25; do
    LOG_MAX_LINE_LENGTH=$limit
    log_info "$(printf "\360\237\231\202\360\237\231\202\360\237\231\202\360\237\231\202")$(printf "\360\237\231\202\360\237\231\202\360\237\231\202\360\237\231\202")"
done
' 2>&1)
    # A cut character makes the output invalid UTF-8, which iconv rejects
    if ! printf '%s\n' "$output" | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1; then
        fail_test "Output is not valid UTF-8"
        return
    fi

    pass_test
}

test_posix_journal_failure_reported_once() {
    local shell_command="$1"
    start_test "[$shell_command] a failing logger is reported once and disables journal logging"

    require_shell "${shell_command%% *}" || return 0

    # LOGGER_PATH points at a command that always fails
    printf '#!/bin/sh\nexit 1\n' > "$TEST_DIR/failing_logger"
    chmod +x "$TEST_DIR/failing_logger"
    local output
    output=$(run_snippet_in_shell "$shell_command" C "
init_logger --no-color --format '%m'
LOGGER_PATH='$TEST_DIR/failing_logger'
USE_JOURNAL=true
log_info one
printf 'status=%s use=%s\n' \"\$?\" \"\$USE_JOURNAL\"
USE_JOURNAL=true
log_info two
" 2>&1)
    assert_contains "$output" "status=1 use=false" || return
    assert_equals "1" "$(printf '%s\n' "$output" | grep -c 'logger command failed')" \
        "The failure should be reported once" || return

    pass_test
}

test_posix_levels_in_turkish_locale() {
    local shell_command="$1"
    start_test "[$shell_command] level names work in a Turkish locale"

    require_shell "${shell_command%% *}" || return 0

    if ! locale -a 2>/dev/null | grep -qiE '^tr_TR\.utf-?8$'; then
        skip_test "tr_TR.UTF-8 locale not installed"
        return 0
    fi

    local output
    output=$(run_snippet_in_shell "$shell_command" tr_TR.UTF-8 '
init_logger --quiet --level critical
printf "%s\n" "$CURRENT_LOG_LEVEL"
' 2>&1)
    assert_equals "2" "$output" || return

    pass_test
}

test_posix_version_variables_from_environment() {
    local shell_command="$1"
    start_test "[$shell_command] inherited BASH_VERSION and ZSH_VERSION do not change the shell used"

    require_shell "${shell_command%% *}" || return 0

    local snippet_file="$TEST_DIR/version_env.sh"
    printf '%s\n' ". '$PROJECT_ROOT/logging.sh'" \
        "init_logger --no-color --format '%m' --max-line-length 20" \
        "log_info abcdefghijklmnopqrstuvwxyz0123456789" \
        'printf "status=%s level=%s\n" "$?" "$LOG_LEVEL_DEBUG"' \
        '( LOG_LEVEL_DEBUG=9 ) 2>/dev/null && printf "assignable\n"' > "$snippet_file"
    local output variable
    for variable in ZSH_VERSION BASH_VERSION; do
        case "${shell_command%% *}:$variable" in
            # The shell sets this one itself
            bash:BASH_VERSION|zsh:ZSH_VERSION) continue ;;
        esac
        # shellcheck disable=SC2086  # word splitting of shell_command is intended
        output=$(env -i PATH="$PATH" LC_ALL=C "$variable=5.9" $shell_command "$snippet_file" 2>&1 </dev/null)
        assert_equals "abcdef...[truncated]
status=0 level=7" "$output" "$variable from the environment" || return
    done

    pass_test
}

# Run all tests
test_posix_executed_directly
test_posix_lint_check
test_posix_busybox_utf8_byte_length
while IFS= read -r posix_shell; do
    test_posix_caller_detection "$posix_shell"
    test_posix_truncation_bytes "$posix_shell"
    test_posix_truncation_ignores_environment "$posix_shell"
    test_posix_ansi_constants "$posix_shell"
    test_posix_init_logger_args "$posix_shell"
    test_posix_set_e_set_u "$posix_shell"
    test_posix_tr_failure_fallback "$posix_shell"
    test_posix_probe_ignores_environment "$posix_shell"
    test_posix_echo_option_messages "$posix_shell"
    test_posix_source_in_function "$posix_shell"
    test_posix_trap_keeps_message "$posix_shell"
    test_posix_message_not_kept_in_variables "$posix_shell"
    test_posix_busybox_logger_symlink "$posix_shell"
    test_posix_second_config_without_value "$posix_shell"
    test_posix_version_variables_from_environment "$posix_shell"
    test_posix_max_length_options "$posix_shell"
    test_posix_config_bom "$posix_shell"
    test_posix_truncation_four_byte_character "$posix_shell"
    test_posix_journal_failure_reported_once "$posix_shell"
    test_posix_levels_in_turkish_locale "$posix_shell"
done <<< "$(test_shell_list)"
