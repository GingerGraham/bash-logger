#!/bin/bash
#
# demo_stderr.sh - Demonstrates stderr level configuration
#
# This script shows how to:
# - Control which log levels go to stderr vs stdout
# - Set stderr level at initialization
# - Test output stream separation
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

LOGGING_FILE="${LOGS_DIR}/demo_stderr.log"
echo "Log file: $LOGGING_FILE"

# Source the logger module
source "$LOGGER_PATH"

echo "========== Stderr Level Demo =========="
echo "This demonstrates configuring which log levels go to stderr vs stdout."
echo "By default, ERROR and above go to stderr, while lower levels go to stdout."
echo

# Default stderr level (ERROR)
echo "========== Default stderr level (ERROR and above to stderr) =========="
init_logger --log "${LOGGING_FILE}" --level DEBUG || {
    echo "Failed to initialize logger" >&2
    exit 1
}

echo "Running: some_script.sh 2>/dev/null (suppressing stderr)"
echo "You should see DEBUG, INFO, NOTICE, WARN but NOT ERROR, CRITICAL, ALERT, EMERGENCY:"
(
    log_debug "DEBUG goes to stdout"
    log_info "INFO goes to stdout"
    log_notice "NOTICE goes to stdout"
    log_warn "WARN goes to stdout"
    log_error "ERROR goes to stderr (hidden)"
    log_critical "CRITICAL goes to stderr (hidden)"
    log_alert "ALERT goes to stderr (hidden)"
    log_emergency "EMERGENCY goes to stderr (hidden)"
) 2>/dev/null

echo -e "\nRunning: some_script.sh 1>/dev/null (suppressing stdout)"
echo "You should see ERROR, CRITICAL, ALERT, EMERGENCY but NOT DEBUG, INFO, NOTICE, WARN:"
(
    log_debug "DEBUG goes to stdout (hidden)"
    log_info "INFO goes to stdout (hidden)"
    log_notice "NOTICE goes to stdout (hidden)"
    log_warn "WARN goes to stdout (hidden)"
    log_error "ERROR goes to stderr"
    log_critical "CRITICAL goes to stderr"
    log_alert "ALERT goes to stderr"
    log_emergency "EMERGENCY goes to stderr"
) 1>/dev/null

# Set stderr level to WARN
echo -e "\n========== Setting stderr level to WARN =========="
init_logger --log "${LOGGING_FILE}" --level DEBUG --stderr-level WARN || {
    echo "Failed to initialize logger" >&2
    exit 1
}

echo "Running: some_script.sh 2>/dev/null (suppressing stderr)"
echo "You should see DEBUG, INFO, NOTICE but NOT WARN and above:"
(
    log_debug "DEBUG goes to stdout"
    log_info "INFO goes to stdout"
    log_notice "NOTICE goes to stdout"
    log_warn "WARN goes to stderr (hidden)"
    log_error "ERROR goes to stderr (hidden)"
) 2>/dev/null

# Set stderr level to DEBUG (everything to stderr)
echo -e "\n========== Setting stderr level to DEBUG (all output to stderr) =========="
init_logger --log "${LOGGING_FILE}" --level DEBUG --stderr-level DEBUG || {
    echo "Failed to initialize logger" >&2
    exit 1
}

echo "Running: some_script.sh 2>/dev/null (suppressing stderr)"
echo "You should see NOTHING (all output goes to stderr which is suppressed):"
(
    log_debug "DEBUG goes to stderr (hidden)"
    log_info "INFO goes to stderr (hidden)"
    log_warn "WARN goes to stderr (hidden)"
    log_error "ERROR goes to stderr (hidden)"
) 2>/dev/null

echo "(If you see nothing above, the test passed!)"

# Set stderr level to EMERGENCY (almost everything to stdout)
echo -e "\n========== Setting stderr level to EMERGENCY (only EMERGENCY to stderr) =========="
init_logger --log "${LOGGING_FILE}" --level DEBUG --stderr-level EMERGENCY || {
    echo "Failed to initialize logger" >&2
    exit 1
}

echo "Running: some_script.sh 2>/dev/null (suppressing stderr)"
echo "You should see everything except EMERGENCY:"
(
    log_debug "DEBUG goes to stdout"
    log_info "INFO goes to stdout"
    log_warn "WARN goes to stdout"
    log_error "ERROR goes to stdout"
    log_critical "CRITICAL goes to stdout"
    log_alert "ALERT goes to stdout"
    log_emergency "EMERGENCY goes to stderr (hidden)"
) 2>/dev/null

echo -e "\n========== Stderr Level Demo Complete =========="
echo "Log file: ${LOGGING_FILE}"
