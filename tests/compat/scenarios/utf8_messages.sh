# shellcheck shell=sh
# compat-locale: C.UTF-8
# Multi-byte UTF-8 messages, names and tags, below every length limit
. "$LOGGER_ROOT/logging.sh"
init_logger --no-color --log "$SCENARIO_DIR/test.log" --format "%l|%s|%m"
log_info "café naïve 日本語 emoji😀 Ωmega"
log_warn "tab	and newline
inside"
set_journal_tag "tág"
printf 'tag rc=%s tag=%s\n' "$?" "$JOURNAL_TAG"
set_log_format "→ %l ← %m"
log_error "arrows in the format"
