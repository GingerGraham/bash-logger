# shellcheck shell=sh
# Message truncation at the console/file limit, ASCII only
. "$LOGGER_ROOT/logging.sh"
init_logger --no-color --format "%m" --max-line-length 20
log_info "short"
log_info "exactly twenty chars"
log_info "twenty-one characters"
log_info "a much longer message that is certainly truncated"
LOG_MAX_LINE_LENGTH=10
log_info "limit smaller than the suffix length"
LOG_MAX_LINE_LENGTH=14
log_info "limit equal to the suffix length"
LOG_MAX_LINE_LENGTH=15
log_info "limit one more than the suffix"
LOG_MAX_LINE_LENGTH=0
log_info "zero disables truncation for this long message"
LOG_MAX_LINE_LENGTH=abc
log_info "non-numeric limit disables truncation"
LOG_MAX_LINE_LENGTH=
log_info "empty limit disables truncation"
