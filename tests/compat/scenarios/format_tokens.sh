# shellcheck shell=sh
# Each format token, unknown tokens, '%%', a trailing '%', and message content
# that looks like tokens or replacement syntax
. "$LOGGER_ROOT/logging.sh"
init_logger --no-color --name fmt-test --format "%d|%z|%l|%s|%m"
log_info "all tokens"
set_log_format "[%l] %q %% %m %"
log_info "unknown token"
set_log_format "%m"
log_info "message with %d %l %s %z %m & \\& tokens"
set_log_format "%m %m"
log_info "twice"
set_log_format "no tokens at all"
log_info "ignored"
set_log_format ""
log_info "empty format"
set_log_format "%l:%m"
set_timezone_utc true
log_info "utc on"
set_log_format "%z %m"
log_warn "zone"
set_timezone_utc false
log_warn "zone local"
