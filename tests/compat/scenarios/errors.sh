# shellcheck shell=sh
# Error paths: unwritable log file, directory as log file, symlink, invalid level and facility
. "$LOGGER_ROOT/logging.sh"
: > "$SCENARIO_DIR/not-a-dir"
init_logger --no-color --log "$SCENARIO_DIR/not-a-dir/sub/test.log"
printf 'rc=%s\n' "$?"
mkdir -p "$SCENARIO_DIR/a-dir"
init_logger --no-color --log "$SCENARIO_DIR/a-dir"
printf 'rc=%s\n' "$?"
: > "$SCENARIO_DIR/target.log"
ln -s "$SCENARIO_DIR/target.log" "$SCENARIO_DIR/link.log"
init_logger --no-color --log "$SCENARIO_DIR/link.log"
printf 'rc=%s\n' "$?"
init_logger --no-color --level NOTALEVEL
printf 'rc=%s level=%s\n' "$?" "$CURRENT_LOG_LEVEL"
init_logger --no-color --facility bogus
printf 'rc=%s facility=%s\n' "$?" "$SYSLOG_FACILITY"
init_logger --no-color --log "$SCENARIO_DIR/ok.log"
printf 'rc=%s\n' "$?"
rm -f "$SCENARIO_DIR/ok.log"
mkdir "$SCENARIO_DIR/ok.log"
log_info "write fails once"
log_info "write fails twice"
log_to_journal
printf 'rc=%s\n' "$?"
log_to_journal BOGUS "message"
printf 'rc=%s\n' "$?"
