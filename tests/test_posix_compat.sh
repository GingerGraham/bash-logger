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
# - Long names and many trailing newlines take linear time
# - Escape sequences and control characters are removed, in linear time
# - --tag is validated; created log files are private; a log file replaced by a symbolic
#   link is not written through
# - A readonly value with a newline cannot fake a readonly constant, and a logger path
#   that was not validated is never run
# - CONFIG notices follow the stderr level
# - Timestamps match date, in local time, in UTC and with TZ changed or readonly, and use
#   the builtin only in bash 4.2+ and zsh
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

test_posix_config_notice_stream() {
    local shell_command="$1"
    start_test "[$shell_command] CONFIG notices follow the stderr level"

    require_shell "${shell_command%% *}" || return 0

    local output
    output=$(run_snippet_in_shell "$shell_command" C '
init_logger --no-color --format "%l %m"
set_log_format "%l" 2>/dev/null
init_logger --no-color --format "%l %m" --stderr-level DEBUG
set_log_format "%l" >/dev/null 2>&1
printf "end\n"
' 2>/dev/null)
    assert_equals "CONFIG
end" "$output" || return

    pass_test
}

test_posix_timestamp_matches_date() {
    local shell_command="$1"
    start_test "[$shell_command] timestamps match date in local time and UTC"

    require_shell "${shell_command%% *}" || return 0

    # A fixed offset needs no time zone data. Each check is tried again if it fails, because
    # the second can change during it: bash reads a coarse clock that can be one tick behind
    # date, so its second can even look earlier.
    local output
    output=$(run_snippet_in_shell "$shell_command" C '
stamp="+%Y-%m-%d %H:%M:%S"
check() {
    label="$1"; shift
    for attempt in 1 2 3; do
        before=$("$@" "$stamp")
        logged=$(log_info x)
        after=$("$@" "$stamp")
        if [ "$logged" = "$before" ] || [ "$logged" = "$after" ]; then
            printf "%s ok\n" "$label"
            return 0
        fi
    done
    printf "%s MISMATCH [%s] [%s] [%s]\n" "$label" "$before" "$logged" "$after"
}
init_logger --no-color --format "%d"
check local date
set_timezone_utc true >/dev/null
check utc date -u
set_timezone_utc false >/dev/null
export TZ=ZZZ-5
check offset date
set_timezone_utc true >/dev/null
check offset-utc date -u
set_timezone_utc false >/dev/null
check offset-again date
TZ=ZZZ+3
check offset-changed date
unset TZ
check unset date
' 2>&1)
    assert_equals "local ok
utc ok
offset ok
offset-utc ok
offset-again ok
offset-changed ok
unset ok" "$output" || return

    pass_test
}

test_posix_timestamp_readonly_tz() {
    local shell_command="$1"
    start_test "[$shell_command] UTC timestamps work when the caller made TZ readonly"

    require_shell "${shell_command%% *}" || return 0

    local snippet_file="$TEST_DIR/readonly_tz.sh"
    printf '%s\n' \
        "export TZ=ZZZ-5" \
        "readonly TZ" \
        ". '$PROJECT_ROOT/logging.sh'" \
        "init_logger --no-color --utc --format '%d'" \
        'for attempt in 1 2 3; do' \
        '    before=$(date -u "+%Y-%m-%d %H:%M:%S")' \
        '    logged=$(log_info x)' \
        '    after=$(date -u "+%Y-%m-%d %H:%M:%S")' \
        '    if [ "$logged" = "$before" ] || [ "$logged" = "$after" ]; then echo ok; exit 0; fi' \
        'done' \
        'echo "bad [$logged] [$before]"' \
        > "$snippet_file"
    local output
    # shellcheck disable=SC2086  # word splitting of shell_command is intended
    output=$(env -i PATH="$PATH" LC_ALL=C $shell_command "$snippet_file" 2>&1 </dev/null)
    assert_equals "ok" "$output" || return

    pass_test
}

test_posix_timestamp_builtin_and_fallback() {
    local shell_command="$1"
    start_test "[$shell_command] timestamps use the builtin in bash 4.2+ and zsh, and date otherwise"

    require_shell "${shell_command%% *}" || return 0

    # date prints a marker, which shows which path made the timestamp
    local output
    output=$(run_snippet_in_shell "$shell_command" C '
date() { printf "from-date\n"; }
init_logger --no-color --format "%d"
log_info x
_LOGGER_TIME_BUILTIN=""
log_info x
printf "%s\n" "builtin=$_LOGGER_TIME_BUILTIN"
' 2>&1)

    local expected_first="from-date"
    local actual_bash_major
    case "${shell_command%% *}" in
        zsh)
            expected_first=""
            ;;
        bash)
            actual_bash_major=$(bash -c 'printf "%s" "$((BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1]))"')
            if [[ "$actual_bash_major" -ge 402 ]]; then
                expected_first=""
            fi
            ;;
    esac
    local first_line second_line
    first_line=$(printf '%s\n' "$output" | sed -n 1p)
    second_line=$(printf '%s\n' "$output" | sed -n 2p)
    if [[ -z "$expected_first" ]]; then
        assert_not_equals "from-date" "$first_line" "builtin should be used" || return
    else
        assert_equals "from-date" "$first_line" "date should be used" || return
    fi
    assert_equals "from-date" "$second_line" "date is the fallback" || return

    pass_test
}

test_posix_timestamp_ignores_environment() {
    local shell_command="$1"
    start_test "[$shell_command] the timestamp method cannot be set through the environment"

    require_shell "${shell_command%% *}" || return 0

    local snippet_file="$TEST_DIR/env_time.sh"
    printf '%s\n' ". '$PROJECT_ROOT/logging.sh'" \
        "init_logger --no-color --format '%d'" "log_info x" > "$snippet_file"
    local output
    # shellcheck disable=SC2086  # word splitting of shell_command is intended
    output=$(env -i PATH="$PATH" LC_ALL=C _LOGGER_TIME_BUILTIN=nonsense _LOGGER_TIMESTAMP=forged \
        $shell_command "$snippet_file" 2>&1 </dev/null)
    case "$output" in
        [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\ [0-9][0-9]:[0-9][0-9]:[0-9][0-9]) ;;
        *) fail_test "Unexpected timestamp: $output"; return ;;
    esac

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

    # LOGGER_PATH points at a command that always fails, locked as validation locks it
    printf '#!/bin/sh\nexit 1\n' > "$TEST_DIR/failing_logger"
    chmod +x "$TEST_DIR/failing_logger"
    local output
    output=$(run_snippet_in_shell "$shell_command" C "
init_logger --no-color --format '%m'
LOGGER_PATH='$TEST_DIR/failing_logger'; readonly LOGGER_PATH
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

test_posix_utc_from_epoch() {
    local shell_command="$1"
    start_test "[$shell_command] UTC timestamps are calculated correctly from the epoch"

    require_shell "${shell_command%% *}" || return 0

    # Includes leap days, century years with and without a leap day, and year ends
    local output
    output=$(run_snippet_in_shell "$shell_command" C '
check() {
    _utc_timestamp_from_epoch "$1"
    printf "%s %s\n" "$1" "$_LOGGER_TIMESTAMP"
}
check 0
check 59
check 86399
check 86400
check 68169600
check 951782400
check 951868799
check 951868800
check 1709251199
check 1735689599
check 1735689600
check 4107542399
check 4107542400
check 4102444800
check 32503680000
' 2>&1)
    assert_equals "0 1970-01-01 00:00:00
59 1970-01-01 00:00:59
86399 1970-01-01 23:59:59
86400 1970-01-02 00:00:00
68169600 1972-02-29 00:00:00
951782400 2000-02-29 00:00:00
951868799 2000-02-29 23:59:59
951868800 2000-03-01 00:00:00
1709251199 2024-02-29 23:59:59
1735689599 2024-12-31 23:59:59
1735689600 2025-01-01 00:00:00
4107542399 2100-02-28 23:59:59
4107542400 2100-03-01 00:00:00
4102444800 2100-01-01 00:00:00
32503680000 3000-01-01 00:00:00" "$output" || return

    pass_test
}

test_posix_readonly_guard_cannot_be_spoofed() {
    local shell_command="$1"
    start_test "[$shell_command] a readonly value with a newline cannot fake a readonly constant"

    require_shell "${shell_command%% *}" || return 0

    # dash and busybox print readonly values with literal newlines in "readonly -p", so
    # this value used to make LOGGER_PATH, _LOGGER_ESC and _LOGGER_NEWLINE look readonly
    # and their environment values were kept
    local stub_logger="$TEST_DIR/spoofed_logger"
    local stub_capture="$TEST_DIR/spoofed_logger.capture"
    printf '#!/bin/sh\necho ran >> "%s"\n' "$stub_capture" > "$stub_logger"
    chmod +x "$stub_logger"
    local spoof_note="x
readonly LOGGER_PATH='$stub_logger'
readonly _LOGGER_ESC='x'
readonly _LOGGER_NEWLINE='y'"
    local snippet_file="$TEST_DIR/spoof.sh"
    printf '%s\n' 'readonly UNTRUSTED_NOTE="$NOTE"' \
        ". '$PROJECT_ROOT/logging.sh'" \
        'printf "path=[%s]\n" "$LOGGER_PATH"' \
        "init_logger --no-color --format '%m'" \
        'log_info "$(printf "a\033[31mb\nc")"' \
        'log_to_journal info probe >/dev/null 2>&1' > "$snippet_file"

    local output
    # shellcheck disable=SC2086  # word splitting of shell_command is intended
    output=$(env -i PATH="$PATH" LC_ALL=C NOTE="$spoof_note" LOGGER_PATH="$stub_logger" \
        _LOGGER_ESC=x _LOGGER_NEWLINE=y $shell_command "$snippet_file" 2>&1 </dev/null)

    assert_equals "path=[]
ab c" "$output" || return
    assert_file_not_exists "$stub_capture" "The logger from the environment must not run" || return

    pass_test
}

test_posix_unvalidated_logger_path_not_run() {
    local shell_command="$1"
    start_test "[$shell_command] a logger path that was not validated is never run"

    require_shell "${shell_command%% *}" || return 0

    local stub_logger="$TEST_DIR/unvalidated_logger"
    local stub_capture="$TEST_DIR/unvalidated_logger.capture"
    printf '#!/bin/sh\necho ran >> "%s"\n' "$stub_capture" > "$stub_logger"
    chmod +x "$stub_logger"

    # Assigned without validation: refused by the journal writer
    local output
    output=$(run_snippet_in_shell "$shell_command" C "
init_logger --no-color --format '%m' --quiet
LOGGER_PATH='$stub_logger'
USE_JOURNAL=true
log_info one
printf 'status=%s use=%s\n' \"\$?\" \"\$USE_JOURNAL\"
" 2>&1)
    assert_contains "$output" "status=1 use=false" || return
    assert_contains "$output" "not validated" || return
    assert_file_not_exists "$stub_capture" "An unvalidated logger path must not run" || return

    # Locked, but no longer the logger that validation finds: log_to_journal stops
    output=$(run_snippet_in_shell "$shell_command" C "
init_logger --no-color --format '%m' --quiet
LOGGER_PATH='$stub_logger'; readonly LOGGER_PATH
log_to_journal info two
printf 'status=%s\n' \"\$?\"
" 2>&1)
    assert_contains "$output" "status=1" || return
    assert_file_not_exists "$stub_capture" "A path that fails validation must not run" || return

    pass_test
}

test_posix_long_names_and_trailing_newlines() {
    local shell_command="$1"
    start_test "[$shell_command] long names and many trailing newlines take linear time"

    require_shell "${shell_command%% *}" || return 0

    # 2.x-era loops copied the text once per character replaced or newline removed:
    # these inputs took about a minute in bash. The timeout is generous so that only
    # that kind of growth fails.
    local output
    output=$(run_with_timeout 20 run_snippet_in_shell "$shell_command" C '
big=$(awk "BEGIN { for (i = 0; i < 131072; i++) printf \"%s\", (i % 3 == 0) ? \" \" : \"a\" }")
init_logger --quiet --no-init-message --name "$big"
printf "name=%s %s\n" "${#SCRIPT_NAME}" "${SCRIPT_NAME%"${SCRIPT_NAME#????}"}"
set_script_name "$(printf "a b\\\\c")" >/dev/null
printf "short=%s\n" "$SCRIPT_NAME"
lots=$(awk "BEGIN { printf \"x\"; for (i = 0; i < 80000; i++) printf \"\\n\" }"; printf y)
init_logger --quiet --no-init-message --no-color --format "%m" --unsafe-allow-newlines
log_info "${lots%y}"
printf "status=%s\n" "$?"
' 2>&1)
    assert_equals "name=8192 _aa_
short=a_b_c
status=0" "$output" || return

    pass_test
}

# Log each control-character case from the 3.0.0 security review and compare the log file
# with the expected bytes. Prints "ok" or, for each case that differs, its output as od shows it.
# Each case is "<message>|<expected log line>", both printf formats.
control_character_snippet() {
    cat <<'SNIPPET'
init_logger --quiet --no-color --no-init-message --format '%m' --max-line-length 0 -l "$OUT"
failures=0
for case_spec in 'A\033[38:2:0:0:0mB|AB' 'A\033[1`B|AB' 'A\033[1;1;24;80$zB|AB' 'A\033[2 qB|AB' \
    'A\033[200~B|AB' 'A\033]0;title\007B|AB' 'A\033]8;;x\033\134B|AB' 'A\033]0;open|A' \
    'A\033Pq\033\134B|AB' 'A\033]0;a\033[31mb\033\134B|AB' 'A\033\303\251B|A\303\251B' \
    'A\033\377B|A\377B' 'AB\033|AB' 'AB\010C|ABC' 'A\013B\014C|ABC' 'A\007B\177C|ABC' \
    'A\016B\017C|ABC' 'A\302\205B|AB' 'A\302\23331mB|A31mB' 'A\342\200\250B\342\200\251C|ABC' \
    'A\342\200\256BC\342\200\254D|ABCD' 'A\342\201\246B\342\201\251C|ABC' \
    '\303\251 \360\237\231\202|\303\251 \360\237\231\202' 'A\342\200\213B|A\342\200\213B'; do
    : > "$OUT"
    log_info "$(printf "${case_spec%%|*}")"
    printf "${case_spec#*|}\n" > "$OUT.expected"
    if ! cmp -s "$OUT" "$OUT.expected"; then
        printf 'case %s gave:%s\n' "${case_spec%%|*}" "$(od -An -c "$OUT" | tr -s ' ' | tr -d '\n')"
        failures=$((failures + 1))
    fi
done
[ "$failures" -eq 0 ] && printf 'ok\n'
SNIPPET
}

test_posix_control_characters_removed() {
    local shell_command="$1"
    start_test "[$shell_command] escape sequences and control characters are removed"

    require_shell "${shell_command%% *}" || return 0

    # Covers findings P1, P2 and P4 of the 3.0.0 security review: CSI sequences outside
    # the old grammar, C0, C1, line separator and bidirectional controls, and ESC followed
    # by a byte that is not valid UTF-8. UTF-8 text, including after ESC, is kept.
    local locale_name output
    for locale_name in C "$(utf8_locale_name)"; do
        [[ -z "$locale_name" ]] && continue
        output=$(run_snippet_in_shell "$shell_command" \
            "$locale_name" "OUT='$TEST_DIR/control.log'
$(control_character_snippet)" 2>/dev/null)
        if [[ "$output" != "ok" ]]; then
            fail_test "LC_ALL=$locale_name: $output"
            return
        fi
    done

    pass_test
}

test_posix_unterminated_sequences_linear() {
    local shell_command="$1"
    start_test "[$shell_command] long runs of unterminated escape sequences take linear time"

    require_shell "${shell_command%% *}" || return 0

    # 240 KB of unterminated OSC sequences took 90 s with busybox sed and the 2.x
    # expressions. Checked with truncation off (no cap), and with the default limits,
    # where the message is cut before sanitizing.
    local output
    output=$(run_with_timeout 20 run_snippet_in_shell "$shell_command" C "
message=\$(awk 'BEGIN { for (i = 0; i < 80000; i++) printf \"\\033]a\" }')
init_logger --quiet --no-color --no-init-message --format '%m' --max-line-length 0 \\
    -l '$TEST_DIR/unterminated.log'
log_info \"\$message\"
printf 'unlimited=%s\n' \"\$(wc -c < '$TEST_DIR/unterminated.log' | tr -d ' ')\"
init_logger --quiet --no-color --no-init-message --format '%m' --max-line-length 4096 \\
    -l '$TEST_DIR/unterminated.log'
: > '$TEST_DIR/unterminated.log'
log_info \"\$message\"
printf 'limited=%s\n' \"\$(wc -c < '$TEST_DIR/unterminated.log' | tr -d ' ')\"
" 2>/dev/null)
    # Each unterminated OSC is removed up to the next ESC, so nothing is left; with the
    # cap, the truncation suffix shows that the message was cut
    assert_equals "unlimited=1
limited=15" "$output" || return

    pass_test
}

test_posix_tag_option_validated() {
    local shell_command="$1"
    start_test "[$shell_command] --tag is validated like the tag config key"

    require_shell "${shell_command%% *}" || return 0

    local output
    output=$(run_snippet_in_shell "$shell_command" C "
init_logger --quiet --no-init-message --tag 'good-tag'
printf 'tag=%s\n' \"\$JOURNAL_TAG\"
init_logger --quiet --no-init-message --tag 'bad;tag' 2>&1
printf 'tag=%s status=%s\n' \"\$JOURNAL_TAG\" \"\$?\"
" 2>/dev/null)
    assert_contains "$output" "tag=good-tag" || return
    assert_contains "$output" "shell metacharacters" || return
    assert_contains "$output" "tag=good-tag status=0" || return

    pass_test
}

test_posix_log_file_permissions() {
    local shell_command="$1"
    start_test "[$shell_command] a created log file and directory are private, existing ones are kept"

    require_shell "${shell_command%% *}" || return 0

    local existing_file="$TEST_DIR/existing.log"
    : > "$existing_file"
    chmod 644 "$existing_file"
    run_snippet_in_shell "$shell_command" C "
umask 022
init_logger --quiet -l '$TEST_DIR/new_dir/nested/new.log'
init_logger --quiet -l '$existing_file'
printf 'umask=%s\n' \"\$(umask)\"
" > "$TEST_DIR/permissions.out" 2>/dev/null

    # ls prints the mode the same way on Linux and macOS
    assert_equals "-rw-------" "$(ls -l "$TEST_DIR/new_dir/nested/new.log" | cut -c1-10)" \
        "new log file" || return
    assert_equals "drwx------" "$(ls -ld "$TEST_DIR/new_dir" | cut -c1-10)" "new directory" || return
    assert_equals "drwx------" "$(ls -ld "$TEST_DIR/new_dir/nested" | cut -c1-10)" \
        "new nested directory" || return
    assert_equals "-rw-r--r--" "$(ls -l "$existing_file" | cut -c1-10)" "existing file" || return
    # zsh prints the umask as 022, the other shells as 0022
    if ! grep -Eq '^umask=0*22$' "$TEST_DIR/permissions.out"; then
        fail_test "The caller's umask changed: $(cat "$TEST_DIR/permissions.out")"
        return
    fi

    pass_test
}

test_posix_log_file_replaced_by_symlink() {
    local shell_command="$1"
    start_test "[$shell_command] a log file replaced by a symbolic link is not written through"

    require_shell "${shell_command%% *}" || return 0

    local log_file="$TEST_DIR/swapped.log"
    local link_target="$TEST_DIR/link_target"
    : > "$link_target"
    local output
    output=$(run_snippet_in_shell "$shell_command" C "
init_logger --quiet --no-color --no-init-message --format '%m' -l '$log_file'
log_info before
rm -f '$log_file'
ln -s '$link_target' '$log_file'
log_info after-one
log_info after-two
set_log_level debug
printf 'status=%s\n' \"\$?\"
" 2>&1)
    assert_file_not_contains "$link_target" "after" "The link target must not be written" || return
    assert_equals "1" "$(printf '%s\n' "$output" | grep -c 'symbolic link')" \
        "The problem should be reported once" || return
    assert_contains "$output" "after-two" "Entries should still go to stderr" || return
    assert_contains "$output" "status=0" || return

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

test_run_with_timeout_stops_process_tree() {
    start_test "run_with_timeout stops descendants, including ones that ignore TERM"

    local started_at=$SECONDS
    local output
    output=$(run_with_timeout 1 bash -c 'trap "" TERM; sleep 30; echo finished' 2>/dev/null)
    local elapsed=$((SECONDS - started_at))
    assert_equals "" "$output" || return
    if [[ "$elapsed" -ge 15 ]]; then
        fail_test "Took ${elapsed}s to stop"
        return
    fi

    pass_test
}

# Run all tests
test_posix_executed_directly
test_posix_lint_check
test_posix_busybox_utf8_byte_length
test_run_with_timeout_stops_process_tree
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
    test_posix_config_notice_stream "$posix_shell"
    test_posix_utc_from_epoch "$posix_shell"
    test_posix_version_variables_from_environment "$posix_shell"
    test_posix_tag_option_validated "$posix_shell"
    test_posix_log_file_permissions "$posix_shell"
    test_posix_log_file_replaced_by_symlink "$posix_shell"
    test_posix_control_characters_removed "$posix_shell"
    test_posix_unterminated_sequences_linear "$posix_shell"
    test_posix_long_names_and_trailing_newlines "$posix_shell"
    test_posix_readonly_guard_cannot_be_spoofed "$posix_shell"
    test_posix_unvalidated_logger_path_not_run "$posix_shell"
    test_posix_timestamp_matches_date "$posix_shell"
    test_posix_timestamp_readonly_tz "$posix_shell"
    test_posix_timestamp_builtin_and_fallback "$posix_shell"
    test_posix_timestamp_ignores_environment "$posix_shell"
    test_posix_max_length_options "$posix_shell"
    test_posix_config_bom "$posix_shell"
    test_posix_truncation_four_byte_character "$posix_shell"
    test_posix_journal_failure_reported_once "$posix_shell"
    test_posix_levels_in_turkish_locale "$posix_shell"
done <<< "$(test_shell_list)"
