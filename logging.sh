#!/usr/bin/env bash
#
# logging.sh - Reusable Bash Logging Module
# 
# This script provides logging functionality that can be sourced by other scripts
# 
# Usage in other scripts:
#   source /path/to/logging.sh # Ensure that the path is an absolute path
#   init_logger [-l|--log FILE] [-q|--quiet] [-v|--verbose] [-d|--level LEVEL] [-f|--format FORMAT] [-j|--journal] [-t|--tag TAG] [--color] [--no-color]
#
# Functions provided:
#   log_debug "message"      - Log debug level message
#   log_info "message"       - Log info level message
#   log_notice "message"     - Log notice level message
#   log_warn "message"       - Log warning level message
#   log_error "message"      - Log error level message
#   log_critical "message"   - Log critical level message
#   log_alert "message"      - Log alert level message
#   log_emergency "message"  - Log emergency level message (system unusable)
#   log_sensitive "message"  - Log sensitive message (console only, never to file or journal)
#
# Log Levels (following complete syslog standard):
#   7 = DEBUG (most verbose/least severe)
#   6 = INFO (informational messages)
#   5 = NOTICE (normal but significant conditions)
#   4 = WARN/WARNING (warning conditions)
#   3 = ERROR (error conditions)
#   2 = CRITICAL (critical conditions)
#   1 = ALERT (action must be taken immediately)
#   0 = EMERGENCY (system is unusable)

# Log levels (following complete syslog standard - higher number = less severe)
LOG_LEVEL_EMERGENCY=0  # System is unusable (most severe)
LOG_LEVEL_ALERT=1      # Action must be taken immediately
LOG_LEVEL_CRITICAL=2   # Critical conditions
LOG_LEVEL_ERROR=3      # Error conditions
LOG_LEVEL_WARN=4       # Warning conditions
LOG_LEVEL_NOTICE=5     # Normal but significant conditions
LOG_LEVEL_INFO=6       # Informational messages
LOG_LEVEL_DEBUG=7      # Debug information (least severe)

# Aliases for backward compatibility
LOG_LEVEL_FATAL=$LOG_LEVEL_EMERGENCY  # Alias for EMERGENCY

# Default settings (these can be overridden by init_logger)
CONSOLE_LOG="true"
LOG_FILE=""
VERBOSE="false"
CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO
USE_UTC="false" # Set to true to use UTC time in logs

# Journal logging settings
USE_JOURNAL="true"
JOURNAL_TAG=""  # Tag for syslog/journal entries

# Color settings
USE_COLORS="auto"  # Can be "auto", "always", or "never"

# Default log format
# Format variables:
#   %d = date and time (YYYY-MM-DD HH:MM:SS)
#   %z = timezone (UTC or LOCAL)
#   %l = log level name (DEBUG, INFO, WARN, ERROR)
#   %s = script name
#   %m = message
# Example:
#   "[%l] %d [%s] %m" => "[INFO] 2025-03-03 12:34:56 [myscript.sh] Hello world"
#  "%d %z [%l] [%s] %m" => "2025-03-03 12:34:56 UTC [INFO] [myscript.sh] Hello world"
LOG_FORMAT="%d [%l] [%s] %m"

# Function to detect terminal color support
detect_color_support() {
    # Default to no colors if explicitly disabled
    if [[ -n "${NO_COLOR:-}" || "${CLICOLOR:-}" == "0" ]]; then
        return 1
    fi
    
    # Force colors if explicitly enabled
    if [[ "${CLICOLOR_FORCE:-}" == "1" ]]; then
        return 0
    fi
    
    # Check if stdout is a terminal
    if [[ ! -t 1 ]]; then
        return 1
    fi
    
    # Check color capabilities with tput if available
    if command -v tput >/dev/null 2>&1; then
        if [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
            return 0
        fi
    fi
    
    # Check TERM as fallback
    if [[ -n "${TERM:-}" && "${TERM:-}" != "dumb" ]]; then
        case "${TERM:-}" in
            xterm*|rxvt*|ansi|linux|screen*|tmux*|vt100|vt220|alacritty)
                return 0
                ;;
        esac
    fi
    
    return 1  # Default to no colors
}

# Function to determine if colors should be used
should_use_colors() {
    case "$USE_COLORS" in
        "always")
            return 0
            ;;
        "never")
            return 1
            ;;
        "auto"|*)
            detect_color_support
            return $?
            ;;
    esac
}

# Check if logger command is available
check_logger_available() {
    command -v logger &>/dev/null
}

# Convert log level name to numeric value
get_log_level_value() {
    local level_name="$1"
    case "${level_name^^}" in
        "DEBUG")
            echo $LOG_LEVEL_DEBUG
            ;;
        "INFO")
            echo $LOG_LEVEL_INFO
            ;;
        "NOTICE")
            echo $LOG_LEVEL_NOTICE
            ;;
        "WARN" | "WARNING")
            echo $LOG_LEVEL_WARN
            ;;
        "ERROR" | "ERR")
            echo $LOG_LEVEL_ERROR
            ;;
        "CRITICAL" | "CRIT")
            echo $LOG_LEVEL_CRITICAL
            ;;
        "ALERT")
            echo $LOG_LEVEL_ALERT
            ;;
        "EMERGENCY" | "EMERG" | "FATAL")
            echo $LOG_LEVEL_EMERGENCY
            ;;
        *)
            # If it's a number between 0-7 (valid syslog levels), use it directly
            if [[ "$level_name" =~ ^[0-7]$ ]]; then
                echo "$level_name"
            else
                # Default to INFO if invalid
                echo $LOG_LEVEL_INFO
            fi
            ;;
    esac
}

# Get log level name from numeric value
get_log_level_name() {
    local level_value="$1"
    case "$level_value" in
        "$LOG_LEVEL_DEBUG")
            echo "DEBUG"
            ;;
        "$LOG_LEVEL_INFO")
            echo "INFO"
            ;;
        "$LOG_LEVEL_NOTICE")
            echo "NOTICE"
            ;;
        "$LOG_LEVEL_WARN")
            echo "WARN"
            ;;
        "$LOG_LEVEL_ERROR")
            echo "ERROR"
            ;;
        "$LOG_LEVEL_CRITICAL")
            echo "CRITICAL"
            ;;
        "$LOG_LEVEL_ALERT")
            echo "ALERT"
            ;;
        "$LOG_LEVEL_EMERGENCY")
            echo "EMERGENCY"
            ;;
        *)
            echo "UNKNOWN"
            ;;
    esac
}

# Map log level to syslog priority
get_syslog_priority() {
    local level_value="$1"
    case "$level_value" in
        "$LOG_LEVEL_DEBUG")
            echo "debug"
            ;;
        "$LOG_LEVEL_INFO")
            echo "info"
            ;;
        "$LOG_LEVEL_NOTICE")
            echo "notice"
            ;;
        "$LOG_LEVEL_WARN")
            echo "warning"
            ;;
        "$LOG_LEVEL_ERROR")
            echo "err"
            ;;
        "$LOG_LEVEL_CRITICAL")
            echo "crit"
            ;;
        "$LOG_LEVEL_ALERT")
            echo "alert"
            ;;
        "$LOG_LEVEL_EMERGENCY")
            echo "emerg"
            ;;
        *)
            echo "notice"  # Default to notice for unknown levels
            ;;
    esac
}

# Function to format log message
format_log_message() {
    local level_name="$1"
    local message="$2"
    
    # Get timestamp in appropriate timezone
    local current_date
    local timezone_str
    if [[ "$USE_UTC" == "true" ]]; then
        current_date=$(date -u '+%Y-%m-%d %H:%M:%S')  # UTC time
        timezone_str="UTC"
    else
        current_date=$(date '+%Y-%m-%d %H:%M:%S')     # Local time
        timezone_str="LOCAL"
    fi
    
    # Replace format variables - zsh compatible method
    local formatted_message="$LOG_FORMAT"
    # Handle % escaping for zsh compatibility
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        # In zsh, we need a different approach
        formatted_message=${formatted_message:gs/%d/$current_date}
        formatted_message=${formatted_message:gs/%l/$level_name}
        formatted_message=${formatted_message:gs/%s/${SCRIPT_NAME:-unknown}}
        formatted_message=${formatted_message:gs/%m/$message}
        formatted_message=${formatted_message:gs/%z/$timezone_str}
    else
        # Bash version (original)
        formatted_message="${formatted_message//%d/$current_date}"
        formatted_message="${formatted_message//%l/$level_name}"
        formatted_message="${formatted_message//%s/${SCRIPT_NAME:-unknown}}"
        formatted_message="${formatted_message//%m/$message}"
        formatted_message="${formatted_message//%z/$timezone_str}"
    fi
    
    echo "$formatted_message"
}

# Function to initialize logger with custom settings
init_logger() {
    # Get the calling script's name
    local caller_script
    if [[ -n "${BASH_SOURCE[1]:-}" ]]; then
        caller_script=$(basename "${BASH_SOURCE[1]}")
    else
        caller_script="unknown"
    fi
    
    # Parse command line arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --color|--colour)
                USE_COLORS="always"
                shift
                ;;
            --no-color|--no-colour)
                USE_COLORS="never"
                shift
                ;;
            -d|--level)
                local level_value
                level_value=$(get_log_level_value "$2")
                CURRENT_LOG_LEVEL=$level_value
                # If both --verbose and --level are specified, --level takes precedence
                shift 2
                ;;
            -f|--format)
                LOG_FORMAT="$2"
                shift 2
                ;;
            -j|--journal)
                if check_logger_available; then
                    USE_JOURNAL="true"
                else
                    echo "Warning: logger command not found, journal logging disabled" >&2
                fi
                shift
                ;;
            -l|--log|--logfile|--log-file|--file)
                LOG_FILE="$2"
                shift 2
                ;;
            -q|--quiet)
                CONSOLE_LOG="false"
                shift
                ;;
            -t|--tag)
                JOURNAL_TAG="$2"
                shift 2
                ;;
            -u|--utc)
                USE_UTC="true"
                shift
                ;;
            -v|--verbose|--debug)
                VERBOSE="true"
                CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG
                shift
                ;;
            *)
                echo "Unknown parameter for logger: $1" >&2
                return 1
                ;;
        esac
    done
    
    # Set a global variable for the script name to use in log messages
    SCRIPT_NAME="$caller_script"
    
    # Set default journal tag if not specified but journal logging is enabled
    if [[ "$USE_JOURNAL" == "true" && -z "$JOURNAL_TAG" ]]; then
        JOURNAL_TAG="$SCRIPT_NAME"
    fi
    
    # Validate log file path if specified
    if [[ -n "$LOG_FILE" ]]; then
        # Get directory of log file 
        LOG_DIR=$(dirname "$LOG_FILE")
        
        # Try to create directory if it doesn't exist
        if [[ ! -d "$LOG_DIR" ]]; then
            mkdir -p "$LOG_DIR" 2>/dev/null || {
                echo "Error: Cannot create log directory '$LOG_DIR'" >&2
                return 1
            }
        fi
        
        # Try to touch the file to ensure we can write to it
        touch "$LOG_FILE" 2>/dev/null || {
            echo "Error: Cannot write to log file '$LOG_FILE'" >&2
            return 1
        }
        
        # Verify one more time that file exists and is writable
        if [[ ! -w "$LOG_FILE" ]]; then
            echo "Error: Log file '$LOG_FILE' is not writable" >&2
            return 1
        fi
        
        # Write the initialization message using the same format
        local init_message
        init_message=$(format_log_message "INIT" "Logger initialized by $caller_script")
        echo "$init_message" >> "$LOG_FILE" 2>/dev/null || {
            echo "Error: Failed to write test message to log file" >&2
            return 1
        }
        
        echo "Logger: Successfully initialized with log file at '$LOG_FILE'" >&2
    fi
    
    # Log initialization success
    log_debug "Logger initialized by '$caller_script' with: console=$CONSOLE_LOG, file=$LOG_FILE, journal=$USE_JOURNAL, colors=$USE_COLORS, log level=$(get_log_level_name $CURRENT_LOG_LEVEL), format=\"$LOG_FORMAT\""
    return 0
}

# Function to change log level after initialization
set_log_level() {
    local level="$1"
    local old_level
    old_level=$(get_log_level_name $CURRENT_LOG_LEVEL)
    CURRENT_LOG_LEVEL=$(get_log_level_value "$level")
    local new_level
    new_level=$(get_log_level_name $CURRENT_LOG_LEVEL)
    
    # Create a special log entry that bypasses level checks
    local message="Log level changed from $old_level to $new_level"
    local log_entry
    log_entry=$(format_log_message "CONFIG" "$message")
    
    # Always print to console if enabled
    if [[ "$CONSOLE_LOG" == "true" ]]; then
        if should_use_colors; then
            echo -e "\e[35m${log_entry}\e[0m"  # Purple for configuration changes
        else
            echo "${log_entry}"
        fi
    fi
    
    # Always write to log file if set
    if [[ -n "$LOG_FILE" ]]; then
        echo "${log_entry}" >> "$LOG_FILE" 2>/dev/null
    fi
    
    # Always log to journal if enabled
    if [[ "$USE_JOURNAL" == "true" ]]; then
        logger -p "daemon.notice" -t "${JOURNAL_TAG:-$SCRIPT_NAME}" "CONFIG: $message"
    fi
}

set_timezone_utc() {
    local use_utc="$1"
    local old_setting="$USE_UTC"
    USE_UTC="$use_utc"
    
    local message="Timezone setting changed from $old_setting to $USE_UTC"
    local log_entry
    log_entry=$(format_log_message "CONFIG" "$message")
    
    # Always print to console if enabled
    if [[ "$CONSOLE_LOG" == "true" ]]; then
        if should_use_colors; then
            echo -e "\e[35m${log_entry}\e[0m"  # Purple for configuration changes
        else
            echo "${log_entry}"
        fi
    fi
    
    # Always write to log file if set
    if [[ -n "$LOG_FILE" ]]; then
        echo "${log_entry}" >> "$LOG_FILE" 2>/dev/null
    fi
    
    # Always log to journal if enabled
    if [[ "$USE_JOURNAL" == "true" ]]; then
        logger -p "daemon.notice" -t "${JOURNAL_TAG:-$SCRIPT_NAME}" "CONFIG: $message"
    fi
}

# Function to change log format
set_log_format() {
    local old_format="$LOG_FORMAT"
    LOG_FORMAT="$1"
    
    local message="Log format changed from \"$old_format\" to \"$LOG_FORMAT\""
    local log_entry
    log_entry=$(format_log_message "CONFIG" "$message")
    
    # Always print to console if enabled
    if [[ "$CONSOLE_LOG" == "true" ]]; then
        if should_use_colors; then
            echo -e "\e[35m${log_entry}\e[0m"  # Purple for configuration changes
        else
            echo "${log_entry}"
        fi
    fi
    
    # Always write to log file if set
    if [[ -n "$LOG_FILE" ]]; then
        echo "${log_entry}" >> "$LOG_FILE" 2>/dev/null
    fi
    
    # Always log to journal if enabled
    if [[ "$USE_JOURNAL" == "true" ]]; then
        logger -p "daemon.notice" -t "${JOURNAL_TAG:-$SCRIPT_NAME}" "CONFIG: $message"
    fi
}

# Function to toggle journal logging
set_journal_logging() {
    local old_setting="$USE_JOURNAL"
    USE_JOURNAL="$1"
    
    # Check if logger is available when enabling
    if [[ "$USE_JOURNAL" == "true" ]]; then
        if ! check_logger_available; then
            echo "Error: logger command not found, cannot enable journal logging" >&2
            USE_JOURNAL="$old_setting"
            return 1
        fi
    fi
    
    local message="Journal logging changed from $old_setting to $USE_JOURNAL"
    local log_entry
    log_entry=$(format_log_message "CONFIG" "$message")
    
    # Always print to console if enabled
    if [[ "$CONSOLE_LOG" == "true" ]]; then
        if should_use_colors; then
            echo -e "\e[35m${log_entry}\e[0m"  # Purple for configuration changes
        else
            echo "${log_entry}"
        fi
    fi
    
    # Always write to log file if set
    if [[ -n "$LOG_FILE" ]]; then
        echo "${log_entry}" >> "$LOG_FILE" 2>/dev/null
    fi
    
    # Log to journal if it was previously enabled or just being enabled
    if [[ "$old_setting" == "true" || "$USE_JOURNAL" == "true" ]]; then
        logger -p "daemon.notice" -t "${JOURNAL_TAG:-$SCRIPT_NAME}" "CONFIG: $message"
    fi
}

# Function to set journal tag
set_journal_tag() {
    local old_tag="$JOURNAL_TAG"
    JOURNAL_TAG="$1"
    
    local message="Journal tag changed from \"$old_tag\" to \"$JOURNAL_TAG\""
    local log_entry
    log_entry=$(format_log_message "CONFIG" "$message")
    
    # Always print to console if enabled
    if [[ "$CONSOLE_LOG" == "true" ]]; then
        if should_use_colors; then
            echo -e "\e[35m${log_entry}\e[0m"  # Purple for configuration changes
        else
            echo "${log_entry}"
        fi
    fi
    
    # Always write to log file if set
    if [[ -n "$LOG_FILE" ]]; then
        echo "${log_entry}" >> "$LOG_FILE" 2>/dev/null
    fi
    
    # Log to journal if enabled, using the old tag
    if [[ "$USE_JOURNAL" == "true" ]]; then
        logger -p "daemon.notice" -t "${old_tag:-$SCRIPT_NAME}" "CONFIG: Journal tag changing to \"$JOURNAL_TAG\""
    fi
}

# Function to set color mode
set_color_mode() {
    local mode="$1"
    local old_setting="$USE_COLORS"
    
    case "$mode" in
        true|on|yes|1)
            USE_COLORS="always"
            ;;
        false|off|no|0)
            USE_COLORS="never"
            ;;
        auto)
            USE_COLORS="auto"
            ;;
        *)
            USE_COLORS="$mode"  # Set directly if it's already "always", "never", or "auto"
            ;;
    esac
    
    local message="Color mode changed from \"$old_setting\" to \"$USE_COLORS\""
    local log_entry
    log_entry=$(format_log_message "CONFIG" "$message")
    
    # Always print to console if enabled
    if [[ "$CONSOLE_LOG" == "true" ]]; then
        if should_use_colors; then
            echo -e "\e[35m${log_entry}\e[0m"  # Purple for configuration changes
        else
            echo "${log_entry}"
        fi
    fi
    
    # Always write to log file if set
    if [[ -n "$LOG_FILE" ]]; then
        echo "${log_entry}" >> "$LOG_FILE" 2>/dev/null
    fi
    
    # Log to journal if enabled
    if [[ "$USE_JOURNAL" == "true" ]]; then
        logger -p "daemon.notice" -t "${JOURNAL_TAG:-$SCRIPT_NAME}" "CONFIG: $message"
    fi
}

# Function to log messages with different severity levels
log_message() {
    local level_name="$1"
    local level_value="$2"
    local message="$3"
    local skip_file="${4:-false}"
    local skip_journal="${5:-false}"
    
    # Skip logging if message level is more verbose than current log level
    # With syslog-style levels, HIGHER values are LESS severe (more verbose)
    if [[ "$level_value" -gt "$CURRENT_LOG_LEVEL" ]]; then
        return
    fi
    
    # Format the log entry
    local log_entry
    log_entry=$(format_log_message "$level_name" "$message")
    
    # If CONSOLE_LOG is true, print to console
    if [[ "$CONSOLE_LOG" == "true" ]]; then
        if should_use_colors; then
            # Color output for console based on log level
            case "$level_name" in
                "DEBUG")
                    echo -e "\e[34m${log_entry}\e[0m"  # Blue
                    ;;
                "INFO")
                    echo -e "${log_entry}"  # Default color
                    ;;
                "NOTICE")
                    echo -e "\e[32m${log_entry}\e[0m"  # Green
                    ;;
                "WARN")
                    echo -e "\e[33m${log_entry}\e[0m"  # Yellow
                    ;;
                "ERROR")
                    echo -e "\e[31m${log_entry}\e[0m" >&2  # Red, to stderr
                    ;;
                "CRITICAL")
                    echo -e "\e[31;1m${log_entry}\e[0m" >&2  # Bright Red, to stderr
                    ;;
                "ALERT")
                    echo -e "\e[37;41m${log_entry}\e[0m" >&2  # White on Red background, to stderr
                    ;;
                "EMERGENCY"|"FATAL")
                    echo -e "\e[1;37;41m${log_entry}\e[0m" >&2  # Bold White on Red background, to stderr
                    ;;
                "INIT")
                    echo -e "\e[35m${log_entry}\e[0m"  # Purple for init
                    ;;
                "SENSITIVE")
                    echo -e "\e[36m${log_entry}\e[0m"  # Cyan for sensitive
                    ;;
                *)
                    echo "${log_entry}"  # Default color for unknown level
                    ;;
            esac
        else
            # Plain output without colors
            if [[ "$level_name" == "ERROR" || "$level_name" == "CRITICAL" || "$level_name" == "ALERT" || "$level_name" == "EMERGENCY" || "$level_name" == "FATAL" ]]; then
                echo "${log_entry}" >&2  # Error messages to stderr
            else
                echo "${log_entry}"
            fi
        fi
    fi
    
    # If LOG_FILE is set and not empty, append to the log file (without colors)
    # Skip writing to the file if skip_file is true
    if [[ -n "$LOG_FILE" && "$skip_file" != "true" ]]; then
        echo "${log_entry}" >> "$LOG_FILE" 2>/dev/null || {
            # Only print the error once to avoid spam
            if [[ -z "$LOGGER_FILE_ERROR_REPORTED" ]]; then
                echo "ERROR: Failed to write to log file: $LOG_FILE" >&2
                LOGGER_FILE_ERROR_REPORTED="yes"
            fi
            
            # Print the original message to stderr to not lose it
            echo "${log_entry}" >&2
        }
    fi
    
    # If journal logging is enabled and logger is available, log to the system journal
    # Skip journal logging if skip_journal is true
    if [[ "$USE_JOURNAL" == "true" && "$skip_journal" != "true" ]]; then
        if check_logger_available; then
            # Map our log level to syslog priority
            local syslog_priority
            syslog_priority=$(get_syslog_priority "$level_value")
            
            # Use the logger command to send to syslog/journal
            # Strip any ANSI color codes from the message
            local plain_message="${message//\e\[[0-9;]*m/}"
            logger -p "daemon.${syslog_priority}" -t "${JOURNAL_TAG:-$SCRIPT_NAME}" "$plain_message"
        fi
    fi
}

# Helper functions for different log levels
log_debug() {
    log_message "DEBUG" $LOG_LEVEL_DEBUG "$1"
}

log_info() {
    log_message "INFO" $LOG_LEVEL_INFO "$1"
}

log_notice() {
    log_message "NOTICE" $LOG_LEVEL_NOTICE "$1"
}

log_warn() {
    log_message "WARN" $LOG_LEVEL_WARN "$1"
}

log_error() {
    log_message "ERROR" $LOG_LEVEL_ERROR "$1"
}

log_critical() {
    log_message "CRITICAL" $LOG_LEVEL_CRITICAL "$1"
}

log_alert() {
    log_message "ALERT" $LOG_LEVEL_ALERT "$1"
}

log_emergency() {
    log_message "EMERGENCY" $LOG_LEVEL_EMERGENCY "$1"
}

# Alias for backward compatibility
log_fatal() {
    log_message "FATAL" $LOG_LEVEL_EMERGENCY "$1"
}

log_init() {
    log_message "INIT" -1 "$1"  # Using -1 to ensure it always shows
}

# Function for sensitive logging - console only, never to file or journal
log_sensitive() {
    log_message "SENSITIVE" $LOG_LEVEL_INFO "$1" "true" "true"
}

# Only execute initialization if this script is being run directly
# If it's being sourced, the sourcing script should call init_logger
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is designed to be sourced by other scripts, not executed directly."
    echo "Usage: source logging.sh"
    exit 1
fi