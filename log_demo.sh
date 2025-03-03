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
# LOGGER_PATH="${PARENT_DIR}/logging.sh" # logger is in the parent directory (example of an optional, alternative path)
LOGGER_PATH="${SCRIPT_DIR}/logging.sh" # logger is in same directory as script

# Check if logger exists
if [[ ! -f "$LOGGER_PATH" ]]; then
    echo "Error: Logger module not found at $LOGGER_PATH" >&2
    exit 1
fi

# Create log directory
LOGS_DIR="${PARENT_DIR}/logs"
mkdir -p "$LOGS_DIR"

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
    echo
}

# Initialize with default level (INFO)
echo "========== Initializing with default level (INFO) =========="
init_logger --log "${LOGS_DIR}/log_levels_demo.log" || {
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

# Initialize with numeric level (INFO = 1)
echo "========== Setting level to 1 (INFO) =========="
set_log_level "1"
test_all_log_levels "with numeric level 1 (INFO)"

# Test initialization with level parameter
echo "========== Reinitializing with WARN level =========="
init_logger --log "${LOGS_DIR}/log_levels_demo.log" --level WARN || {
    echo "Failed to initialize logger" >&2
    exit 1
}
test_all_log_levels "after init with --level WARN"

# Test verbose flag with level parameter (level should take precedence)
echo "========== Reinitializing with --verbose AND --level ERROR =========="
init_logger --log "${LOGS_DIR}/log_levels_demo.log" --verbose --level ERROR || {
    echo "Failed to initialize logger" >&2
    exit 1
}
test_all_log_levels "after init with --verbose AND --level ERROR"

echo "========== Log Level Demo Complete =========="
echo "Log file is at ${LOGS_DIR}/log_levels_demo.log"