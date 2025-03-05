#!/bin/bash
#
# levels_demo.sh - Demonstration of Log Levels
#
# This script demonstrates setting and changing log levels

# Make sure we're using the correct path to the logging script
# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Path to logger module
LOGGER_PATH="${PARENT_DIR}/logging.sh" # logger is in the parent directory (example of an optional, alternative path)
# LOGGER_PATH="${SCRIPT_DIR}/logging.sh" # logger is in same directory as script

# Check if logger exists
if [[ ! -f "$LOGGER_PATH" ]]; then
    echo "Error: Logger module not found at $LOGGER_PATH" >&2
    exit 1
fi

# Create log directory
LOGS_DIR="${PARENT_DIR}/logs"
mkdir -p "$LOGS_DIR"

LOGGING_FILE="${LOGS_DIR}/all_demo.log"
echo "Log file is at $LOGGING_FILE"

# Source the logger module
echo "Sourcing logger from: $LOGGER_PATH"
source "$LOGGER_PATH"

# Function to test all log levels
test_all_log_levels() {
    local reason="$1"
    echo "Testing all log messages ($reason)"
    log_debug "This is a DEBUG message"
    log_info "This is an INFO message"
    log_warn "This is a WARN message"
    log_error "This is an ERROR message"
    log_fatal "This is a FATAL message"
    log_sensitive "This is a SENSITIVE message and should not be logged"
    echo
}

# Test log messages with a specific format
test_format() {
    local format="$1"
    local description="$2"
    
    echo -e "\n========== Using format: \"$format\" =========="
    echo "$description"
    
    # Update the format
    set_log_format "$format"
    
    # Log example messages
    log_info "This is an example informational message"
    log_error "This is an example error message"
}

# Initialize with default level (INFO)
echo "========== Initializing with default level (INFO) =========="
echo "Log file is at ${LOGGING_FILE}"
init_logger --log "${LOGGING_FILE}" || {
    echo "Failed to initialize logger" >&2
    exit 1
}

echo "========== Log Level Demo =========="

test_all_log_levels "with default INFO level"

# Initialize with DEBUG level
echo "========== Setting level to DEBUG =========="
set_log_level "DEBUG"
test_all_log_levels "with DEBUG level"

# Initialize with WARN level
echo "========== Setting level to WARN =========="
set_log_level "WARN"
test_all_log_levels "with WARN level"

# Initialize with ERROR level
echo "========== Setting level to ERROR =========="
set_log_level "ERROR"
test_all_log_levels "with ERROR level"

# Initialize with FATAL level
echo "========== Setting level to FATAL =========="
set_log_level "FATAL"
test_all_log_levels "with FATAL level"

# Initialize with numeric level (INFO = 1)
echo "========== Setting level to 1 (INFO) =========="
set_log_level "1"
test_all_log_levels "with numeric level 1 (INFO)"

# Test initialization with level parameter
echo "========== Reinitializing with WARN level =========="
init_logger --log "${LOGGING_FILE}" --level WARN || {
    echo "Failed to initialize logger" >&2
    exit 1
}
test_all_log_levels "after init with --level WARN"

# Test verbose flag with level parameter (level should take precedence)
echo "========== Reinitializing with --verbose AND --level ERROR =========="
init_logger --log "${LOGGING_FILE}" --verbose --level ERROR || {
    echo "Failed to initialize logger" >&2
    exit 1
}
test_all_log_levels "after init with --verbose AND --level ERROR"

echo "========== Log Level Demo Complete =========="

echo -e "\n========== Format Demo =========="
init_logger --log "${LOGGING_FILE}" --verbose --level INFO || {
    echo "Failed to initialize logger" >&2
    exit 1
}

# Show the default format first
echo "Default format: \"$LOG_FORMAT\""
log_info "This is the default log format"

# Test various formats
test_format "%l: %m" "Basic format with just level and message"

test_format "[%l] [%s] %m" "Format without timestamp"

test_format "%d | %-5l | %m" "Format with aligned level"

test_format "%d | %s | %l | %m" "Pipe-separated format"

test_format "{\"timestamp\":\"%d\", \"level\":\"%l\", \"script\":\"%s\", \"message\":\"%m\"}" "JSON-like format"

test_format "$(hostname) %d [%l] (%s) %m" "Format with hostname"

test_format "%d UTC [%l] %m" "Format with timezone indicator"

# Test initialization with format parameter
echo -e "\n========== Initializing with custom format =========="
init_logger --log "$LOGGING_FILE" --format "CUSTOM: %d [%l] %m" || {
    echo "Failed to initialize logger" >&2
    exit 1
}
log_info "This message uses the format specified during initialization"

echo -e "\n========== Format Demo Complete =========="

echo -e "\n========== Use UTC Complete =========="
echo "This script demonstrates the use of UTC time in log messages."
echo "The log messages will show the timestamp in UTC time."

# Initialize with default settings
echo "========== Initializing with UTC Time =========="
init_logger --log "${LOGGING_FILE}" --format "%d %z [%l] [%s] %m" --utc || {
    echo "Failed to initialize logger" >&2
    exit 1
}

# Log some messages
log_info "This is an informational message"
log_warn "This is a warning message"
log_error "This is an error message"

# Revert back to local time
echo "========== Setting back to local time =========="
set_timezone_utc "false"

# Log some messages
log_info "This is an informational message"
log_warn "This is a warning message"
log_error "This is an error message"

echo "========== Use UTC Demo Complete =========="

echo "Log file is at ${LOGGING_FILE}"
echo "You can examine the log file to see how different formats appear in the log."