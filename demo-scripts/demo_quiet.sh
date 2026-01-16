#!/bin/bash
#
# demo_quiet.sh - Demonstrates quiet mode
#
# This script shows how to:
# - Enable quiet mode to suppress console output
# - Verify logs still go to file and journal
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

LOGGING_FILE="${LOGS_DIR}/demo_quiet.log"
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

echo "========== Quiet Mode Demo =========="
echo

# Check logger availability
check_logger_availability

JOURNAL_PARAM=""
if [[ "$LOGGER_AVAILABLE" == true ]]; then
    JOURNAL_PARAM="--journal --tag quiet-demo"
    echo "Journal logging will be enabled"
fi

# Initialize with quiet mode
echo "========== Initializing with quiet mode =========="
echo "Messages will be logged to file but NOT displayed on console"
echo

# Use word splitting for JOURNAL_PARAM
# shellcheck disable=SC2086
init_logger --log "${LOGGING_FILE}" --quiet $JOURNAL_PARAM || {
    echo "Failed to initialize logger" >&2
    exit 1
}

# Log messages (won't appear on console but will go to file and journal)
log_info "This info should NOT appear on console but will be in the log file"
log_warn "This warning should also be suppressed from console"
log_error "This error should be suppressed from console but in log file"

# Summarize what happened
echo "Messages were logged to file but not displayed on console due to --quiet"

echo -e "\n========== Quiet Mode Demo Complete =========="
echo "Log file: ${LOGGING_FILE}"
echo
echo "Check the log file to see the messages:"
echo "  cat ${LOGGING_FILE}"

if [[ "$LOGGER_AVAILABLE" == true ]]; then
    echo
    echo "Check the journal to see the messages:"
    echo "  journalctl -t quiet-demo"
fi
