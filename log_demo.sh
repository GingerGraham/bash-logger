#!/bin/bash
#
# all_demo.sh - Comprehensive demonstration of logging module features
#
# This script demonstrates all features of the logging module including:
# - Log levels
# - Formatting options
# - UTC time
# - Journal logging (new feature)

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Path to logger module
LOGGER_PATH="${PARENT_DIR}/logging.sh" # logger is in the parent directory
# LOGGER_PATH="${SCRIPT_DIR}/logging.sh" # uncomment if logger is in same directory

# Check if logger exists
if [[ ! -f "$LOGGER_PATH" ]]; then
    echo "Error: Logger module not found at $LOGGER_PATH" >&2
    exit 1
fi

# Create log directory
LOGS_DIR="${PARENT_DIR}/logs"
mkdir -p "$LOGS_DIR"

LOGGING_FILE="${LOGS_DIR}/all_demo.log"
echo "Log file is at $LOGGING_FILE"

# Source the logger module
echo "Sourcing logger from: $LOGGER_PATH"
source "$LOGGER_PATH"

# Function to test all log levels
test_all_log_levels() {
    local reason="$1"
    echo "Testing all log messages ($reason)"
    log_debug "This is a DEBUG message"
    log_info "This is an INFO message"
    log_warn "This is a WARN message"
    log_error "This is an ERROR message"
    log_fatal "This is a FATAL message"
    log_sensitive "This is a SENSITIVE message (console only)"
    echo
}

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

# ====================================================
# PART 1: Log Levels Demo
# ====================================================
echo "========== PART 1: Log Levels Demo =========="

# Initialize with default level (INFO)
echo "========== Initializing with default level (INFO) =========="
init_logger --log "${LOGGING_FILE}" || {
    echo "Failed to initialize logger" >&2
    exit 1
}

test_all_log_levels "with default INFO level"

# Initialize with DEBUG level
echo "========== Setting level to DEBUG =========="
set_log_level "DEBUG"
test_all_log_levels "with DEBUG level"

# Initialize with WARN level
echo "========== Setting level to WARN =========="
set_log_level "WARN"
test_all_log_levels "with WARN level"

# Initialize with ERROR level
echo "========== Setting level to ERROR =========="
set_log_level "ERROR"
test_all_log_levels "with ERROR level"

# Test initialization with level parameter
echo "========== Reinitializing with WARN level =========="
init_logger --log "${LOGGING_FILE}" --level WARN || {
    echo "Failed to initialize logger" >&2
    exit 1
}
test_all_log_levels "after init with --level WARN"

# Test verbose flag
echo "========== Reinitializing with --verbose =========="
init_logger --log "${LOGGING_FILE}" --verbose || {
    echo "Failed to initialize logger" >&2
    exit 1
}
test_all_log_levels "after init with --verbose (DEBUG level)"

echo "========== Log Level Demo Complete =========="

# ====================================================
# PART 2: Formatting Demo
# ====================================================
echo -e "\n========== PART 2: Formatting Demo =========="
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
test_format "%d | %-5l | %m" "Format with aligned level"
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

# ====================================================
# PART 3: Timezone Demo
# ====================================================
echo -e "\n========== PART 3: Timezone Demo =========="
echo "This demonstrates the use of UTC time in log messages."

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
echo "========== Setting back to local time =========="
set_timezone_utc "false"

# Log some messages
log_info "This message shows the timestamp in local time"
log_warn "This is another message with local timestamp"

echo "========== Timezone Demo Complete =========="

# ====================================================
# PART 4: Journal Logging Demo
# ====================================================
echo -e "\n========== PART 4: Journal Logging Demo =========="

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
    echo "========== Reinitializing with custom journal tag =========="
    init_logger --log "${LOGGING_FILE}" --journal --tag "demo-logger" || {
        echo "Failed to initialize logger" >&2
        exit 1
    }
    
    log_info "This message is logged with the tag 'demo-logger'"
    log_warn "This warning uses the custom tag in the journal"
    
    # Test sensitive logging (shouldn't go to journal)
    echo "========== Testing sensitive logging with journal enabled =========="
    log_sensitive "This sensitive message should NOT appear in the journal"
    
    # Test disabling journal logging
    echo "========== Disabling journal logging =========="
    set_journal_logging "false"
    log_info "This message should NOT appear in the journal (it's disabled)"
    
    # Re-enable and change tag
    echo "========== Re-enabling journal and changing tag =========="
    set_journal_logging "true"
    set_journal_tag "new-tag"
    log_info "This message should use the 'new-tag' tag in the journal"
    
    echo "========== Journal Demo Complete =========="
    echo "Journal logs can be viewed with: journalctl -t demo-logger -t new-tag"
else
    echo "Skipping journal logging demo as 'logger' command is not available."
fi

# ====================================================
# PART 5: Combined Features Demo
# ====================================================
echo -e "\n========== PART 5: Combined Features Demo =========="

# Initialize with multiple features enabled
JOURNAL_PARAM=""
if [[ "$LOGGER_AVAILABLE" == true ]]; then
    JOURNAL_PARAM="--journal --tag all-features"
fi

echo "========== Initializing with multiple features =========="
init_logger --log "${LOGGING_FILE}" --level INFO --format "[%z %d] [%l] %m" --utc $JOURNAL_PARAM || {
    echo "Failed to initialize logger" >&2
    exit 1
}

# Log various messages
log_debug "This is a DEBUG message (shouldn't show with INFO level)"
log_info "This message combines UTC time, custom format and journal logging"
log_warn "This warning also demonstrates multiple features"
log_error "This error message shows the combined setup"
log_sensitive "This sensitive message shows only on console"

echo "========== Combined Features Demo Complete =========="

# ====================================================
# PART 6: Quiet Mode Demo
# ====================================================
echo -e "\n========== PART 6: Quiet Mode Demo =========="

# Initialize with quiet mode
echo "========== Initializing with quiet mode =========="
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

echo "========== Quiet Mode Demo Complete =========="

# ====================================================
# Final Summary
# ====================================================
echo -e "\n========== Demo Summary =========="
echo "All logging features have been demonstrated."
echo "Log file is at: ${LOGGING_FILE}"

if [[ "$LOGGER_AVAILABLE" == true ]]; then
    echo "Journal logs were created with tags: demo-logger, new-tag, all-features"
    echo "You can view them with:"
    echo "  journalctl -t demo-logger"
    echo "  journalctl -t new-tag"
    echo "  journalctl -t all-features"
fi

echo "Demo completed successfully!"