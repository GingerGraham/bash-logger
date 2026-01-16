#!/bin/bash
#
# demo_combined.sh - Demonstrates using multiple features together
#
# This script shows how to:
# - Combine UTC time, custom format, colors, and journal logging
# - Initialize with multiple options at once
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

LOGGING_FILE="${LOGS_DIR}/demo_combined.log"
echo "Log file: $LOGGING_FILE"

# Source the logger module
source "$LOGGER_PATH"

# Function to check if logger command is available
check_logger_availability() {
    if command -v logger &>/dev/null; then
        LOGGER_AVAILABLE=true
    else
        LOGGER_AVAILABLE=false
    fi
}

echo "========== Combined Features Demo =========="
echo

# Check logger availability
check_logger_availability

# Initialize with multiple features enabled
JOURNAL_PARAM=""
if [[ "$LOGGER_AVAILABLE" == true ]]; then
    JOURNAL_PARAM="--journal --tag all-features"
    echo "Journal logging will be enabled with tag 'all-features'"
else
    echo "Journal logging not available ('logger' command not found)"
fi

echo "========== Initializing with multiple features =========="
echo "Features: UTC time, custom format, colors, journal logging (if available)"
echo

# Use word splitting for JOURNAL_PARAM
# shellcheck disable=SC2086
init_logger --log "${LOGGING_FILE}" --level INFO --format "[%z %d] [%l] %m" --utc $JOURNAL_PARAM --color || {
    echo "Failed to initialize logger" >&2
    exit 1
}

# Log various messages
log_debug "This is a DEBUG message (shouldn't show with INFO level)"
log_info "This message combines UTC time, custom format, colors, and journal logging"
log_warn "This warning also demonstrates multiple features"
log_error "This error message shows the combined setup"
log_sensitive "This sensitive message shows only on console"

echo -e "\n========== Combined Features Demo Complete =========="
echo "Log file: ${LOGGING_FILE}"

if [[ "$LOGGER_AVAILABLE" == true ]]; then
    echo
    echo "Journal logs can be viewed with:"
    echo "  journalctl -t all-features"
fi
