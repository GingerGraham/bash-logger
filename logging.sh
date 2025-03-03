#!/bin/bash
#
# logging.sh - Reusable Bash Logging Module
# 
# This script provides logging functionality that can be sourced by other scripts
# 
# Usage in other scripts:
#   source /path/to/logging.sh # Ensure that the path is an absolute path
#   init_logger [-l|--log FILE] [-q|--quiet] [-v|--verbose] [-d|--level LEVEL]
#
# Functions provided:
#   log_debug "message"   - Log debug level message
#   log_info "message"    - Log info level message
#   log_warn "message"    - Log warning level message
#   log_error "message"   - Log error level message
#
# Log Levels:
#   0 = DEBUG (most verbose)
#   1 = INFO (default)
#   2 = WARN
#   3 = ERROR (least verbose)

# Log levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# Default settings (these can be overridden by init_logger)
CONSOLE_LOG="true"
LOG_FILE=""
VERBOSE="false"
CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO

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
        "WARN" | "WARNING")
            echo $LOG_LEVEL_WARN
            ;;
        "ERROR")
            echo $LOG_LEVEL_ERROR
            ;;
        *)
            # If it's a number between 0-3, use it directly
            if [[ "$level_name" =~ ^[0-3]$ ]]; then
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
        $LOG_LEVEL_DEBUG)
            echo "DEBUG"
            ;;
        $LOG_LEVEL_INFO)
            echo "INFO"
            ;;
        $LOG_LEVEL_WARN)
            echo "WARN"
            ;;
        $LOG_LEVEL_ERROR)
            echo "ERROR"
            ;;
        *)
            echo "UNKNOWN"
            ;;
    esac
}

# Function to initialize logger with custom settings
init_logger() {
    # Get the calling script's name
    local caller_script
    if [[ -n "${BASH_SOURCE[1]}" ]]; then
        caller_script=$(basename "${BASH_SOURCE[1]}")
    else
        caller_script="unknown"
    fi
    
    # Parse command line arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -l|--log)
                LOG_FILE="$2"
                shift 2
                ;;
            -q|--quiet)
                CONSOLE_LOG="false"
                shift
                ;;
            -v|--verbose)
                VERBOSE="true"
                CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG
                shift
                ;;
            -d|--level)
                local level_value=$(get_log_level_value "$2")
                CURRENT_LOG_LEVEL=$level_value
                # If both --verbose and --level are specified, --level takes precedence
                shift 2
                ;;
            *)
                echo "Unknown parameter for logger: $1" >&2
                return 1
                ;;
        esac
    done
    
    # Set a global variable for the script name to use in log messages
    SCRIPT_NAME="$caller_script"
    
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
        
        # Write a test message to the log file
        echo "[INIT] $(date '+%Y-%m-%d %H:%M:%S') Logger initialized by $caller_script" >> "$LOG_FILE" 2>/dev/null || {
            echo "Error: Failed to write test message to log file" >&2
            return 1
        }
        
        echo "Logger: Successfully initialized with log file at '$LOG_FILE'" >&2
    fi
    
    # Log initialization success
    log_debug "Logger initialized by '$caller_script' with: console=$CONSOLE_LOG, file=$LOG_FILE, log level=$(get_log_level_name $CURRENT_LOG_LEVEL)"
    return 0
}

# Function to change log level after initialization
set_log_level() {
    local level="$1"
    local old_level=$(get_log_level_name $CURRENT_LOG_LEVEL)
    CURRENT_LOG_LEVEL=$(get_log_level_value "$level")
    local new_level=$(get_log_level_name $CURRENT_LOG_LEVEL)
    
    log_warn "Log level changed from $old_level to $new_level"
}

# Function to log messages with different severity levels
log_message() {
    local level_name="$1"
    local level_value="$2"
    local message="$3"
    
    # Skip logging if message level is below current log level
    if [[ "$level_value" -lt "$CURRENT_LOG_LEVEL" ]]; then
        return
    fi
    
    local current_date=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[${level_name}] ${current_date} [${SCRIPT_NAME:-unknown}] ${message}"
    
    # If CONSOLE_LOG is true, print to console
    if [[ "$CONSOLE_LOG" == "true" ]]; then
        # Color output for console based on log level
        case "$level_name" in
            "DEBUG")
                echo -e "\e[34m${log_entry}\e[0m"  # Blue
                ;;
            "INFO")
                echo -e "${log_entry}"  # Default color
                ;;
            "WARN")
                echo -e "\e[33m${log_entry}\e[0m"  # Yellow
                ;;
            "ERROR")
                echo -e "\e[31m${log_entry}\e[0m" >&2  # Red, to stderr
                ;;
        esac
    fi
    
    # If LOG_FILE is set and not empty, append to the log file (without colors)
    if [[ -n "$LOG_FILE" ]]; then
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
}

# Helper functions for different log levels
log_debug() {
    log_message "DEBUG" $LOG_LEVEL_DEBUG "$1"
}

log_info() {
    log_message "INFO" $LOG_LEVEL_INFO "$1"
}

log_warn() {
    log_message "WARN" $LOG_LEVEL_WARN "$1"
}

log_error() {
    log_message "ERROR" $LOG_LEVEL_ERROR "$1"
}

# Only execute initialization if this script is being run directly
# If it's being sourced, the sourcing script should call init_logger
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is designed to be sourced by other scripts, not executed directly."
    echo "Usage: source logging.sh"
    exit 1
fi