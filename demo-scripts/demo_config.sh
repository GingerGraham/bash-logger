#!/bin/bash
#
# demo_config.sh - Demonstrates configuration file usage
#
# This script shows how to:
# - Load logger configuration from an INI file
# - Override config file settings with CLI options
# - Use different configuration profiles
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

LOGGING_FILE="${LOGS_DIR}/demo_config.log"
echo "Log file: $LOGGING_FILE"

# Source the logger module
source "$LOGGER_PATH"

echo "========== Configuration File Demo =========="
echo "This demonstrates loading logger configuration from an INI file."
echo

# Create a temporary config file for testing
CONFIG_FILE="${LOGS_DIR}/test_logging.conf"

echo "========== Creating test configuration file =========="
cat > "$CONFIG_FILE" << 'EOF'
# Test configuration file for logging module
[logging]
level = DEBUG
format = [CONFIG] %d [%l] %m
utc = false
color = auto
stderr_level = ERROR
quiet = false
EOF

echo "Config file created at: $CONFIG_FILE"
echo "Contents:"
cat "$CONFIG_FILE"
echo

# Initialize logger using config file
echo "========== Initializing with config file =========="
init_logger --config "$CONFIG_FILE" --log "${LOGGING_FILE}" || {
    echo "Failed to initialize logger with config file" >&2
    exit 1
}

log_debug "This DEBUG message should appear (config sets level=DEBUG)"
log_info "This INFO message uses format from config file"
log_warn "This WARN message also uses the config format"
log_error "This ERROR message goes to stderr per config"

# Test CLI override of config values
echo -e "\n========== Testing CLI override of config values =========="
echo "Config file sets level=DEBUG, but CLI will override to WARN"
init_logger --config "$CONFIG_FILE" --log "${LOGGING_FILE}" --level WARN || {
    echo "Failed to initialize logger" >&2
    exit 1
}

log_debug "This DEBUG message should NOT appear (CLI override to WARN)"
log_info "This INFO message should NOT appear (CLI override to WARN)"
log_warn "This WARN message should appear (matches CLI level)"
log_error "This ERROR message should appear"

# Test config file with different settings
echo -e "\n========== Testing config with UTC and custom format =========="
cat > "$CONFIG_FILE" << 'EOF'
# Configuration with UTC time and JSON-like format
[logging]
level = INFO
format = {"time":"%d","tz":"%z","level":"%l","msg":"%m"}
utc = true
color = never
EOF

echo "Updated config file:"
cat "$CONFIG_FILE"
echo

init_logger --config "$CONFIG_FILE" --log "${LOGGING_FILE}" || {
    echo "Failed to initialize logger" >&2
    exit 1
}

log_info "This message uses JSON-like format with UTC time"
log_warn "Warning message in JSON format"
log_error "Error message in JSON format"

# Clean up temporary config file
rm -f "$CONFIG_FILE"

echo -e "\n========== Configuration File Demo Complete =========="
echo "Log file: ${LOGGING_FILE}"
echo
echo "Tip: You can use configuration files to maintain consistent logging"
echo "     settings across multiple scripts in your project."
