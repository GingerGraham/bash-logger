# shellcheck shell=sh
# Message content that echo would interpret in some shells
. "$LOGGER_ROOT/logging.sh"
init_logger --no-color --log "$SCENARIO_DIR/test.log" --format "%l|%m|"
log_info 'backslash t \t and n \n'
log_info 'backslash c \c stops echo'
log_info 'octal \0101 \101 and \\ double'
log_info '-n'
log_info '-e'
log_info '-E'
log_info ''
log_info '%s %d %b printf specifiers'
set_script_name 'x\ty'
log_warn 'after name'
set_journal_tag 'tag\c'
printf 'tag rc=%s\n' "$?"
