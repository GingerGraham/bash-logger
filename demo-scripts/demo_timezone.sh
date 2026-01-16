#!/bin/bash
#
# demo_timezone.sh - Demonstrates timezone settings (UTC vs local)
#
# This script shows how to:
# - Enable UTC timestamps in logs
# - Switch between UTC and local time
# - Display timezone information in log format
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

LOGGING_FILE="${LOGS_DIR}/demo_timezone.log"
echo "Log file: $LOGGING_FILE"

# Source the logger module
source "$LOGGER_PATH"

echo "========== Timezone Demo =========="
echo "This demonstrates the use of UTC time in log messages."
echo

# Initialize with UTC time
echo "========== Initializing with UTC Time =========="
init_logger --log "${LOGGING_FILE}" --format "%d %z [%l] [%s] %m" --utc || {
    echo "Failed to initialize logger" >&2
    exit 1
}

# Log some messages
log_info "This message shows the timestamp in UTC time"
log_warn "This is another message with UTC timestamp"

# Revert back to local time
echo -e "\n========== Setting back to local time =========="
set_timezone_utc "false"

# Log some messages
log_info "This message shows the timestamp in local time"
log_warn "This is another message with local timestamp"

echo -e "\n========== Timezone Demo Complete =========="
echo "Log file: ${LOGGING_FILE}"
