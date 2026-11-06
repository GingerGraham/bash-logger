# shellcheck shell=sh
# Invalid values, unknown keys, bad syntax, comments, sections, quotes, BOM and CRLF
. "$LOGGER_ROOT/logging.sh"
report() {
    printf 'rc=%s level=%s stderr=%s colors=%s utc=%s format=%s name=%s tag=%s facility=%s max=%s jmax=%s file=%s\n' \
        "$1" "$CURRENT_LOG_LEVEL" "$LOG_STDERR_LEVEL" "$USE_COLORS" "$USE_UTC" \
        "$LOG_FORMAT" "$SCRIPT_NAME" "$JOURNAL_TAG" "$SYSLOG_FACILITY" \
        "$LOG_MAX_LINE_LENGTH" "$LOG_MAX_JOURNAL_LENGTH" "$LOG_FILE"
}
cat > "$SCENARIO_DIR/bad.conf" <<'CONF'
   # indented comment
; semicolon comment
[section one]
[]
[a]b]
level = NOTALEVEL
utc = maybe
facility = NOTAFACILITY
color = sometimes
quiet = perhaps
console_log = perhaps
verbose = perhaps
journal = perhaps
init_message = perhaps
unsafe_allow_newlines = perhaps
unsafe_allow_ansi_codes = perhaps
max_line_length = 99999999
max_journal_length = -1
max_line_length = 08
max_journal_length = 010
unknown_key = value
just some text without equals
=value without key
tag = bad;tag$(x)
log_file = relative/path.log
log_file = /tmp/$(whoami).log
log_file = /tmp/a; rm -rf /
format = "unterminated
stderr_level = bogus
CONF
init_logger --no-color --config "$SCENARIO_DIR/bad.conf"
report "$?"

printf '\357\273\277level = ERROR\r\nformat = %%m\r\n  key_only  \r\n' > "$SCENARIO_DIR/bom.conf"
init_logger --no-color --config "$SCENARIO_DIR/bom.conf"
report "$?"

init_logger --no-color --config "$SCENARIO_DIR/missing.conf"
report "$?"
init_logger --no-color --config
report "$?"
