# shellcheck shell=sh
# Journal logging with a logger command outside the trusted system paths
. "$LOGGER_ROOT/logging.sh"
mkdir -p "$SCENARIO_DIR/bin"
printf '#!/bin/sh\nexit 0\n' > "$SCENARIO_DIR/bin/logger"
chmod +x "$SCENARIO_DIR/bin/logger"
PATH="$SCENARIO_DIR/bin:$PATH"
init_logger --no-color --journal --tag jtag
printf 'rc=%s journal=%s path=[%s]\n' "$?" "$USE_JOURNAL" "$LOGGER_PATH"
check_logger_available
printf 'available rc=%s\n' "$?"
set_journal_logging true
printf 'rc=%s journal=%s\n' "$?" "$USE_JOURNAL"
log_to_journal info "forced message"
printf 'rc=%s\n' "$?"
log_to_journal debug "below level is silent"
printf 'rc=%s\n' "$?"
