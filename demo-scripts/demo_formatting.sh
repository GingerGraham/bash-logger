#!/bin/bash
#
# demo_formatting.sh - Demonstrates log formatting options
#
# This script shows how to:
# - Use different format templates
# - Customize log output format
# - Use format placeholders (%d, %l, %s, %m, %z)
# - Initialize with custom format
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

LOGGING_FILE="${LOGS_DIR}/demo_formatting.log"
echo "Log file: $LOGGING_FILE"

# Source the logger module
source "$LOGGER_PATH"

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

echo "========== Formatting Demo =========="
echo

init_logger --log "${LOGGING_FILE}" --level INFO || {
    echo "Failed to initialize logger" >&2
    exit 1
}

# Show the default format first
echo "Default format: \"$LOG_FORMAT\""
log_info "This is the default log format"

# Test various formats
test_format "%l: %m" "Basic format with just level and message"
test_format "[%l] [%s] %m" "Format without timestamp"
test_format "%d | %l | %m" "Format with pipe separators"
test_format "{\"timestamp\":\"%d\", \"level\":\"%l\", \"script\":\"%s\", \"message\":\"%m\"}" "JSON-like format"
test_format "$(hostname) %d [%l] (%s) %m" "Format with hostname"

# Test initialization with format parameter
echo -e "\n========== Initializing with custom format =========="
init_logger --log "$LOGGING_FILE" --format "CUSTOM: %d [%l] %m" || {
    echo "Failed to initialize logger" >&2
    exit 1
}
log_info "This message uses the format specified during initialization"

echo -e "\n========== Format Demo Complete =========="
echo "Log file: ${LOGGING_FILE}"
