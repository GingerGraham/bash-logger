# shellcheck shell=sh
# Newline, carriage return and tab sanitization, ANSI stripping, and the unsafe modes
. "$LOGGER_ROOT/logging.sh"
init_logger --log "$SCENARIO_DIR/test.log" --no-color --format "%l %m"
esc=$(printf '\033')
bel=$(printf '\007')
log_info "line1
line2"
log_info "$(printf 'cr\rtab\tend')"
log_info "csi ${esc}[31mred${esc}[0m ${esc}[2J${esc}[H ${esc}[?25l private"
log_info "osc bel ${esc}]0;title${bel}after"
log_info "osc st ${esc}]8;;http://x${esc}\\link${esc}]8;;${esc}\\ done"
log_info "dcs ${esc}Pq#0;2;0;0;0${esc}\\ pm ${esc}^private${esc}\\ apc ${esc}_cmd${esc}\\ end"
log_info "lone ${esc}c reset and ${esc}(B charset"
log_info "nested ${esc}${esc}[31m[0m twice"
log_info "trailing newlines

"
set_unsafe_allow_newlines true
log_info "unsafe
newline"
log_info "$(printf 'unsafe\ttab')"
set_unsafe_allow_newlines false
set_unsafe_allow_ansi_codes true
log_info "unsafe ${esc}[31mansi${esc}[0m kept"
set_unsafe_allow_ansi_codes false
log_info "safe again ${esc}[31mansi${esc}[0m"
