#!/bin/bash
#
# demo_journal.sh - Demonstrates systemd journal logging
#
# This script shows how to:
# - Enable journal logging
# - Use custom journal tags
# - Change journal settings at runtime
# - Verify that sensitive messages don't go to journal
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

LOGGING_FILE="${LOGS_DIR}/demo_journal.log"
echo "Log file: $LOGGING_FILE"

# Source the logger module
source "$LOGGER_PATH"

# Function to check if logger command is available
check_logger_availability() {
    if command -v logger &>/dev/null; then
        echo "✓ 'logger' command is available for journal logging"
        LOGGER_AVAILABLE=true
    else
        echo "✗ 'logger' command is not available. Journal logging features will be skipped."
        LOGGER_AVAILABLE=false
    fi
}

echo "========== Journal Logging Demo =========="
echo

# Check if logger command is available
check_logger_availability

if [[ "$LOGGER_AVAILABLE" == true ]]; then
    # Initialize with journal logging enabled
    echo "========== Initializing with journal logging =========="
    init_logger --log "${LOGGING_FILE}" --journal || {
        echo "Failed to initialize logger" >&2
        exit 1
    }

    # Log with default tag (script name)
    log_info "This message is logged to the journal with default tag"
    log_warn "This warning message is also sent to the journal"
    log_error "This error message should appear in the journal too"

    # Test with custom tag
    echo -e "\n========== Reinitializing with custom journal tag =========="
    init_logger --log "${LOGGING_FILE}" --journal --tag "demo-logger" || {
        echo "Failed to initialize logger" >&2
        exit 1
    }

    log_info "This message is logged with the tag 'demo-logger'"
    log_warn "This warning uses the custom tag in the journal"

    # Test sensitive logging (shouldn't go to journal)
    echo -e "\n========== Testing sensitive logging with journal enabled =========="
    log_sensitive "This sensitive message should NOT appear in the journal"

    # Test disabling journal logging
    echo -e "\n========== Disabling journal logging =========="
    set_journal_logging "false"
    log_info "This message should NOT appear in the journal (it's disabled)"

    # Re-enable and change tag
    echo -e "\n========== Re-enabling journal and changing tag =========="
    set_journal_logging "true"
    set_journal_tag "new-tag"
    log_info "This message should use the 'new-tag' tag in the journal"

    echo -e "\n========== Journal Demo Complete =========="
    echo "Log file: ${LOGGING_FILE}"
    echo
    echo "Journal logs can be viewed with:"
    echo "  journalctl -t demo-logger"
    echo "  journalctl -t new-tag"
else
    echo "Skipping journal logging demo as 'logger' command is not available."
fi
