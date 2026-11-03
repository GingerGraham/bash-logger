# shellcheck shell=sh
# Sourcing and logging under set -eu must not exit the caller
set -eu
. "$LOGGER_ROOT/logging.sh"
init_logger --no-color --level DEBUG --log "$SCENARIO_DIR/test.log"
log_debug "debug"
log_info "info"
log_sensitive "sensitive"
log_init "init"
set_log_level INFO
log_debug "filtered under set -e"
set_log_format "%l %m"
set_script_name "eu"
set_timezone_utc false
set_color_mode never
set_journal_logging false
set_unsafe_allow_newlines false
set_unsafe_allow_ansi_codes false
LOG_MAX_LINE_LENGTH=20
log_info "a message long enough to be truncated"
init_logger --no-color --config "$SCENARIO_DIR/missing.conf" || printf 'config failure handled\n'
printf 'reached the end\n'
