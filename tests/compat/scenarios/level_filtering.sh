# shellcheck shell=sh
# Level filtering and stderr routing thresholds
. "$LOGGER_ROOT/logging.sh"
init_logger --no-color --level WARN --stderr-level WARN
log_debug "hidden debug"
log_info "hidden info"
log_notice "hidden notice"
log_warn "shown warn"
log_error "shown error"
log_init "init is always shown"
set_log_level 7
log_debug "debug after set_log_level 7"
set_log_level notice
log_info "hidden info after notice"
log_notice "notice after notice"
set_log_level not-a-level
log_debug "hidden debug after invalid level"
log_info "info after invalid level"
