#!/bin/bash
#
# demo_colors.sh - Demonstrates color settings
#
# This script shows how to:
# - Use auto-detection of color support
# - Force colors on or off
# - Change color mode at runtime
#
# shellcheck disable=SC1090,SC2034

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

LOGGING_FILE="${LOGS_DIR}/demo_colors.log"
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

echo "========== Color Settings Demo =========="
echo

# Default auto-detection mode
echo "========== Default color auto-detection mode =========="
init_logger --log "${LOGGING_FILE}" || {
    echo "Failed to initialize logger" >&2
    exit 1
}

# Show current color mode
log_info "Current color mode: $USE_COLORS (auto-detection)"
test_all_log_levels "with auto-detected colors"

# Force colors on with --color
echo "========== Forcing colors ON with --color =========="
init_logger --log "${LOGGING_FILE}" --color || {
    echo "Failed to initialize logger" >&2
    exit 1
}

# Show current color mode
log_info "Current color mode: $USE_COLORS (forced on)"
test_all_log_levels "with colors forced ON"

# Force colors off with --no-color
echo "========== Forcing colors OFF with --no-color =========="
init_logger --log "${LOGGING_FILE}" --no-color || {
    echo "Failed to initialize logger" >&2
    exit 1
}

# Show current color mode
log_info "Current color mode: $USE_COLORS (forced off)"
test_all_log_levels "with colors forced OFF"

# Change color mode at runtime
echo "========== Changing color mode at runtime =========="
set_color_mode "always"
log_info "Color mode changed to: $USE_COLORS (always)"
log_warn "This warning should be colored"
log_error "This error should be colored"

set_color_mode "never"
log_info "Color mode changed to: $USE_COLORS (never)"
log_warn "This warning should NOT be colored"
log_error "This error should NOT be colored"

set_color_mode "auto"
log_info "Color mode changed to: $USE_COLORS (auto-detection)"
log_warn "This warning may be colored depending on terminal capabilities"
log_error "This error may be colored depending on terminal capabilities"

echo -e "\n========== Color Settings Demo Complete =========="
echo "Log file: ${LOGGING_FILE}"
