# shellcheck shell=sh
# Every configuration key, with valid values and alternate key spellings
. "$LOGGER_ROOT/logging.sh"
report() {
    printf 'rc=%s console=%s level=%s stderr=%s colors=%s utc=%s format=%s name=%s tag=%s facility=%s nl=%s ansi=%s max=%s jmax=%s verbose=%s init=%s file=%s\n' \
        "$1" "$CONSOLE_LOG" "$CURRENT_LOG_LEVEL" "$LOG_STDERR_LEVEL" "$USE_COLORS" "$USE_UTC" \
        "$LOG_FORMAT" "$SCRIPT_NAME" "$JOURNAL_TAG" "$SYSLOG_FACILITY" \
        "$LOG_UNSAFE_ALLOW_NEWLINES" "$LOG_UNSAFE_ALLOW_ANSI_CODES" \
        "$LOG_MAX_LINE_LENGTH" "$LOG_MAX_JOURNAL_LENGTH" "$VERBOSE" "$LOG_INIT_MESSAGE" "$LOG_FILE"
}
cat > "$SCENARIO_DIR/a.conf" <<CONF
[logging]
level = notice
format = "[%l] %m"
log_file = $SCENARIO_DIR/from-config.log
journal = false
tag = cfg-tag
facility = Local5
utc = yes
color = never
stderr_level = WARN
quiet = false
script_name = cfg name!
verbose = off
unsafe_allow_newlines = no
unsafe_allow_ansi_codes = 0
max_line_length = 300
max_journal_length = 400
init_message = false
CONF
init_logger --config "$SCENARIO_DIR/a.conf"
report "$?"
log_notice "written with config a"

cat > "$SCENARIO_DIR/b.conf" <<CONF
; alternate spellings
log_level = 3
log_format = '%m'
logfile = $SCENARIO_DIR/b.log
use_journal = off
journal_tag = b_tag
syslog_facility = cron
use_utc = TRUE
colour = always
stderr-level = 0
console_log = true
scriptname = bname
unsafe-allow-newlines = On
unsafe-allow-ansi-codes = 1
max-line-length = 0
journal_max_length = 0
log_init_message = true
CONF
init_logger --config "$SCENARIO_DIR/b.conf"
report "$?"

cat > "$SCENARIO_DIR/c.conf" <<CONF
file = $SCENARIO_DIR/c.log
colors = auto
colours = never
use_colors = always
name = cname
quiet = true
verbose = true
log-max-line-length = 50
max_journal_length = 60
journal-max-line-length = 70
CONF
init_logger -c "$SCENARIO_DIR/c.conf" --name cli-overrides
report "$?"
