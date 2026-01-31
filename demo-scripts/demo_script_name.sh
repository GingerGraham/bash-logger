#!/bin/bash
#
# demo_script_name.sh - Demonstrates custom script name functionality
#
# This script shows how to:
# - Set a custom script name during initialization
# - Change the script name dynamically at runtime
# - Use script names to identify different phases of execution
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

LOGGING_FILE="${LOGS_DIR}/demo_script_name.log"
echo "Log file: $LOGGING_FILE"

# Source the logger module
source "$LOGGER_PATH"

echo "========== Script Name Demo =========="
echo "This demonstrates the use of custom script names in log messages."
echo

# Initialize with a custom script name
echo "========== Initializing with Custom Script Name =========="
init_logger --log "${LOGGING_FILE}" --name "my-application" --format "%d [%l] [%s] %m" || {
    echo "Failed to initialize logger" >&2
    exit 1
}

log_info "Application started with custom script name"
log_info "This message shows 'my-application' as the script name"

# Demonstrate changing script name for different phases
echo -e "\n========== Changing Script Name for Init Phase =========="
set_script_name "my-application:init"

log_info "Loading configuration..."
log_info "Connecting to database..."
log_info "Initialization complete"

echo -e "\n========== Changing Script Name for Main Phase =========="
set_script_name "my-application:main"

log_info "Processing data..."
log_info "Performing calculations..."
log_info "Main processing complete"

echo -e "\n========== Changing Script Name for Cleanup Phase =========="
set_script_name "my-application:cleanup"

log_info "Closing connections..."
log_info "Releasing resources..."
log_info "Cleanup complete"

# Restore original name
echo -e "\n========== Restoring Original Script Name =========="
set_script_name "my-application"

log_info "Application finished"

echo -e "\n========== Script Name Demo Complete =========="
echo "Log file: ${LOGGING_FILE}"
echo
echo "Review the log file to see how script names appear in log messages."
echo "This is especially useful for:"
echo "  - Identifying logs from shell RC files (bashrc, zshrc)"
echo "  - Tracking different phases of script execution"
echo "  - Distinguishing between components in complex scripts"
