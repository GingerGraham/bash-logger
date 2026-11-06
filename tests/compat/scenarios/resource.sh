# shellcheck shell=sh
# Sourcing twice keeps constants readonly and resets mutable flags
. "$LOGGER_ROOT/logging.sh"
version="$BASH_LOGGER_VERSION"
. "$LOGGER_ROOT/logging.sh"
printf 'resource rc=%s same_version=%s\n' "$?" "$([ "$version" = "$BASH_LOGGER_VERSION" ] && echo yes)"
init_logger --no-color
log_info "after double source"
for constant in LOG_LEVEL_EMERGENCY LOG_LEVEL_DEBUG COLOR_RESET BASH_LOGGER_VERSION CONFIG_MAX_VALUE_LENGTH; do
    if _is_readonly "$constant"; then
        printf '%s readonly\n' "$constant"
    else
        printf '%s writable\n' "$constant"
    fi
done
printf 'debug=%s emergency=%s fatal=%s init=%s\n' \
    "$LOG_LEVEL_DEBUG" "$LOG_LEVEL_EMERGENCY" "$LOG_LEVEL_FATAL" "$LOG_LEVEL_INIT"
