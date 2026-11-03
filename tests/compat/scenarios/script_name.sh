# shellcheck shell=sh
# Script name: auto-detected from the calling script, and sanitized from --name
. "$LOGGER_ROOT/logging.sh"
init_logger --no-color --format "[%s] %m"
log_info "auto-detected"
init_logger --no-color --name 'a b;c$(d)`e`|f&g/h\i'
log_info "sanitized"
init_logger --no-color --name ''
log_info "empty name keeps previous"
set_script_name '../../etc/passwd'
log_info "path-like name"
