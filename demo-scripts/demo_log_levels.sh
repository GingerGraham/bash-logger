#!/bin/bash
#
# demo_log_levels.sh - Demonstrates log level functionality
#
# This script shows how to:
# - Use different log levels (DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY)
# - Change log level at runtime
# - Initialize with specific log level
# - Use --verbose flag for DEBUG level
#
# shellcheck disable=SC1090

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Path to logger module
LOGGER_PATH="${PARENT_DIR}/logging.sh"

# Check if logger exists
if [[ ! -f "$LOGGER_PATH" ]]; then
    echo "Error: Logger module not found at $LOGGER_PATH" >&2
    exit 1
fi

# Create log directory
LOGS_DIR="${PARENT_DIR}/logs"
mkdir -p "$LOGS_DIR"

LOGGING_FILE="${LOGS_DIR}/demo_log_levels.log"
echo "Log file: $LOGGING_FILE"

# Source the logger module
source "$LOGGER_PATH"

# Function to test all log levels
test_all_log_levels() {
    local reason="$1"
    echo "Testing all log messages ($reason)"
    # All syslog standard levels from least to most severe
    log_debug "This is a DEBUG message (level 7)"
    log_info "This is an INFO message (level 6)"
    log_notice "This is a NOTICE message (level 5)"
    log_warn "This is a WARN message (level 4)"
    log_error "This is an ERROR message (level 3)"
    log_critical "This is a CRITICAL message (level 2)"
    log_alert "This is an ALERT message (level 1)"
    log_emergency "This is an EMERGENCY message (level 0)"

    # Special logging types
    log_sensitive "This is a SENSITIVE message (console only)"
    echo
}

echo "========== Log Levels Demo =========="
echo

# Initialize with default level (INFO)
echo "========== Initializing with default level (INFO) =========="
init_logger --log "${LOGGING_FILE}" || {
    echo "Failed to initialize logger" >&2
    exit 1
}

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

# Test initialization with level parameter
echo "========== Reinitializing with WARN level =========="
init_logger --log "${LOGGING_FILE}" --level WARN || {
    echo "Failed to initialize logger" >&2
    exit 1
}
test_all_log_levels "after init with --level WARN"

# Test verbose flag
echo "========== Reinitializing with --verbose =========="
init_logger --log "${LOGGING_FILE}" --verbose || {
    echo "Failed to initialize logger" >&2
    exit 1
}
test_all_log_levels "after init with --verbose (DEBUG level)"

echo "========== Log Level Demo Complete =========="
echo "Log file: ${LOGGING_FILE}"
