# shellcheck shell=sh
# Every init_logger option that takes no value, and the options with values
. "$LOGGER_ROOT/logging.sh"
report() {
    printf 'rc=%s console=%s level=%s stderr=%s colors=%s utc=%s format=%s name=%s tag=%s facility=%s nl=%s ansi=%s max=%s jmax=%s verbose=%s\n' \
        "$1" "$CONSOLE_LOG" "$CURRENT_LOG_LEVEL" "$LOG_STDERR_LEVEL" "$USE_COLORS" "$USE_UTC" \
        "$LOG_FORMAT" "$SCRIPT_NAME" "$JOURNAL_TAG" "$SYSLOG_FACILITY" \
        "$LOG_UNSAFE_ALLOW_NEWLINES" "$LOG_UNSAFE_ALLOW_ANSI_CODES" \
        "$LOG_MAX_LINE_LENGTH" "$LOG_MAX_JOURNAL_LENGTH" "$VERBOSE"
}
init_logger --color --quiet --verbose --utc --no-init-message
report "$?"
init_logger --no-colour -d ERROR -e CRITICAL -f "%l %m" -n "my name" -t mytag -F LOCAL3 -u -U -A \
    --max-line-length 100 --max-journal-length 200
report "$?"
init_logger --colour --level warning --stderr-level 2 --format "%m" --name other --tag t2 \
    --facility user --debug --unsafe-allow-newlines --unsafe-allow-ansi-codes
report "$?"
init_logger --max-line-length abc --max-journal-length -5
report "$?"
init_logger --facility notafacility
report "$?"
init_logger --bogus-option
report "$?"
