#!/bin/bash
#
# config_demo.sh - Demonstration of INI configuration file support
#
# This script demonstrates loading logger configuration from INI files,
# including CLI argument overrides and error handling.

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Path to logger module
LOGGER_PATH="${SCRIPT_DIR}/logging.sh"

# Check if logger exists
if [[ ! -f "$LOGGER_PATH" ]]; then
    echo "Error: Logger module not found at $LOGGER_PATH" >&2
    exit 1
fi

# Create directories
LOGS_DIR="${PARENT_DIR}/logs"
CONFIG_DIR="${LOGS_DIR}/config_tests"
mkdir -p "$CONFIG_DIR"

# Source the logger module
source "$LOGGER_PATH"

echo "=========================================="
echo "Configuration File Demo for logging.sh"
echo "=========================================="
echo

# ====================================================
# Test 1: Basic configuration file
# ====================================================
echo "--- Test 1: Basic Configuration File ---"

CONFIG_FILE="${CONFIG_DIR}/basic.conf"
cat > "$CONFIG_FILE" << 'EOF'
# Basic logging configuration
[logging]
level = DEBUG
format = %d [%l] %m
color = auto
EOF

echo "Config file: $CONFIG_FILE"
echo "Contents:"
cat "$CONFIG_FILE"
echo

init_logger --config "$CONFIG_FILE" || exit 1

log_debug "Debug message from basic config"
log_info "Info message from basic config"
log_warn "Warning message from basic config"
log_error "Error message from basic config"
echo

# ====================================================
# Test 2: Configuration with file logging
# ====================================================
echo "--- Test 2: Configuration with File Logging ---"

LOG_FILE="${CONFIG_DIR}/app.log"
CONFIG_FILE="${CONFIG_DIR}/file_logging.conf"
cat > "$CONFIG_FILE" << EOF
# Configuration with file logging enabled
[logging]
level = INFO
log_file = ${LOG_FILE}
format = %d [%l] [%s] %m
EOF

echo "Config file: $CONFIG_FILE"
echo "Contents:"
cat "$CONFIG_FILE"
echo

init_logger --config "$CONFIG_FILE" || exit 1

log_info "This message goes to console and file"
log_warn "Warning also logged to file"
log_error "Error logged to file"

echo "Log file contents:"
cat "$LOG_FILE"
echo

# ====================================================
# Test 3: CLI arguments override config values
# ====================================================
echo "--- Test 3: CLI Override of Config Values ---"

CONFIG_FILE="${CONFIG_DIR}/override_test.conf"
cat > "$CONFIG_FILE" << 'EOF'
# Config sets DEBUG level, CLI will override
[logging]
level = DEBUG
format = [FROM_CONFIG] %l: %m
color = never
EOF

echo "Config file sets: level=DEBUG, format=[FROM_CONFIG]..."
echo "CLI will override: --level WARN"
echo

init_logger --config "$CONFIG_FILE" --level WARN || exit 1

log_debug "DEBUG - should NOT appear (CLI set level to WARN)"
log_info "INFO - should NOT appear (CLI set level to WARN)"
log_warn "WARN - should appear (matches CLI level)"
log_error "ERROR - should appear"
echo

# ====================================================
# Test 4: UTC time and custom format
# ====================================================
echo "--- Test 4: UTC Time and Custom Format ---"

CONFIG_FILE="${CONFIG_DIR}/utc_format.conf"
cat > "$CONFIG_FILE" << 'EOF'
# Configuration with UTC time and detailed format
[logging]
level = INFO
format = %d %z | %l | %s | %m
utc = true
color = auto
EOF

echo "Config file: $CONFIG_FILE"
echo "Contents:"
cat "$CONFIG_FILE"
echo

init_logger --config "$CONFIG_FILE" || exit 1

log_info "Message with UTC timestamp"
log_warn "Another UTC message"
echo

# ====================================================
# Test 5: Stderr level configuration
# ====================================================
echo "--- Test 5: Stderr Level Configuration ---"

CONFIG_FILE="${CONFIG_DIR}/stderr_level.conf"
cat > "$CONFIG_FILE" << 'EOF'
# Configuration with custom stderr threshold
[logging]
level = DEBUG
stderr_level = WARN
format = [%l] %m
color = never
EOF

echo "Config sets stderr_level=WARN (WARN and above to stderr)"
echo

init_logger --config "$CONFIG_FILE" || exit 1

echo "Suppressing stderr (2>/dev/null) - should see DEBUG and INFO only:"
(
    log_debug "DEBUG goes to stdout"
    log_info "INFO goes to stdout"
    log_warn "WARN goes to stderr (hidden)"
    log_error "ERROR goes to stderr (hidden)"
) 2>/dev/null
echo

# ====================================================
# Test 6: Quiet mode via config
# ====================================================
echo "--- Test 6: Quiet Mode via Config ---"

LOG_FILE="${CONFIG_DIR}/quiet_mode.log"
CONFIG_FILE="${CONFIG_DIR}/quiet_mode.conf"
cat > "$CONFIG_FILE" << EOF
# Quiet mode - no console output
[logging]
level = DEBUG
log_file = ${LOG_FILE}
quiet = true
format = %d [%l] %m
EOF

echo "Config sets quiet=true (no console output)"
echo "Messages will only go to log file"
echo

# Clear log file
> "$LOG_FILE"

init_logger --config "$CONFIG_FILE" || exit 1

log_info "This should NOT appear on console"
log_warn "This warning is also silent on console"
log_error "This error is only in the log file"

echo "Console output above should be empty."
echo "Log file contents:"
cat "$LOG_FILE"
echo

# ====================================================
# Test 7: Journal logging via config
# ====================================================
echo "--- Test 7: Journal Logging via Config ---"

if command -v logger &>/dev/null; then
    CONFIG_FILE="${CONFIG_DIR}/journal.conf"
    cat > "$CONFIG_FILE" << 'EOF'
# Configuration with journal logging
[logging]
level = INFO
journal = true
tag = config-demo
format = %d [%l] %m
EOF

    echo "Config enables journal logging with tag 'config-demo'"
    echo

    init_logger --config "$CONFIG_FILE" || exit 1

    log_info "Message sent to journal via config"
    log_warn "Warning also sent to journal"

    echo "View journal entries with: journalctl -t config-demo --since '1 minute ago'"
else
    echo "Skipping journal test - 'logger' command not available"
fi
echo

# ====================================================
# Test 8: Boolean value variations
# ====================================================
echo "--- Test 8: Boolean Value Variations ---"

CONFIG_FILE="${CONFIG_DIR}/booleans.conf"
cat > "$CONFIG_FILE" << 'EOF'
# Test various boolean formats
[logging]
level = INFO
verbose = yes
utc = on
color = always
quiet = no
journal = off
EOF

echo "Config uses various boolean formats: yes, on, no, off"
echo

init_logger --config "$CONFIG_FILE" || exit 1

log_debug "DEBUG should appear (verbose=yes sets DEBUG level)"
log_info "UTC and colors should be enabled"
echo

# ====================================================
# Test 9: Error handling - missing file
# ====================================================
echo "--- Test 9: Error Handling - Missing File ---"

echo "Attempting to load non-existent config file..."
if init_logger --config "/nonexistent/path/config.conf" 2>&1; then
    echo "ERROR: Should have failed!"
else
    echo "Correctly failed with error (as expected)"
fi
echo

# ====================================================
# Test 10: Error handling - invalid values
# ====================================================
echo "--- Test 10: Error Handling - Invalid Values ---"

CONFIG_FILE="${CONFIG_DIR}/invalid.conf"
cat > "$CONFIG_FILE" << 'EOF'
# Configuration with some invalid values
[logging]
level = INFO
utc = maybe
color = sometimes
unknown_key = value
EOF

echo "Config has invalid values - should show warnings:"
echo

init_logger --config "$CONFIG_FILE" 2>&1

log_info "Logger still works despite warnings"
echo

# ====================================================
# Cleanup
# ====================================================
echo "--- Cleanup ---"
rm -rf "$CONFIG_DIR"
echo "Removed test config directory: $CONFIG_DIR"

echo
echo "=========================================="
echo "Configuration File Demo Complete"
echo "=========================================="
