#!/bin/bash
#
# bash_logger.sh - Reusable Bash Logging Module
# 
# This script provides logging functionality that can be sourced by other scripts
# 
# Usage in other scripts:
#   source /path/to/bash_logger.sh
#   init_logger [-l|--log FILE] [-q|--quiet] [-v|--verbose]
#
# Functions provided:
#   log_debug "message"   - Log debug level message
#   log_info "message"    - Log info level message
#   log_warn "message"    - Log warning level message
#   log_error "message"   - Log error level message

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

# Function to initialize logger with custom settings
init_logger() {
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
            *)
                echo "Unknown parameter for logger: $1" >&2
                return 1
                ;;
        esac
    done
    
    # Validate log file path if specified
    if [[ -n "$LOG_FILE" ]]; then
        # Check if directory exists
        LOG_DIR=$(dirname "$LOG_FILE")
        if [[ ! -d "$LOG_DIR" ]]; then
            echo "Error: Log directory '$LOG_DIR' does not exist" >&2
            return 1
        fi
        
        # Check if log file is writable (if it exists)
        if [[ -f "$LOG_FILE" && ! -w "$LOG_FILE" ]]; then
            echo "Error: Log file '$LOG_FILE' is not writable" >&2
            return 1
        fi
        
        # Check if directory is writable (for creating the file)
        if [[ ! -w "$LOG_DIR" ]]; then
            echo "Error: Directory '$LOG_DIR' is not writable" >&2
            return 1
        fi
        
        # Create log file
        touch "$LOG_FILE" || {
            echo "Error: Could not create log file '$LOG_FILE'" >&2
            return 1
        }
    fi
    
    # Log initialization success
    log_debug "Logger initialized with: console=$CONSOLE_LOG, file=$LOG_FILE, verbose=$VERBOSE"
    return 0
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
    local log_entry="[${level_name}] ${current_date} ${message}"
    
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
        echo "${log_entry}" >> "$LOG_FILE"
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
    echo "Usage: source bash_logger.sh"
    exit 1
fi