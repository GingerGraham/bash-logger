# shellcheck shell=sh
# Color output for every level, forced on
. "$LOGGER_ROOT/logging.sh"
init_logger --color --level DEBUG --format "%l %m"
log_debug "d"
log_info "i"
log_notice "n"
log_warn "w"
log_error "e"
log_critical "c"
log_alert "a"
log_emergency "em"
log_fatal "f"
log_init "init"
log_sensitive "s"
set_unsafe_allow_newlines true
set_unsafe_allow_newlines false
set_color_mode auto
log_info "auto, not a terminal"
export NO_COLOR=1
set_color_mode always
log_info "always overrides NO_COLOR"
