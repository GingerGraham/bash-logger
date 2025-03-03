#!/bin/bash
#
# demo_app.sh - Example Script Using the Logging Module
# 
# Usage: ./demo_app.sh [-l|--log FILE] [-q|--quiet] [-v|--verbose] [-h|--help]
#
# Options:
#   -l, --log FILE     Log to specified file (and console by default)
#   -q, --quiet        Suppress console output (still logs to file if specified)
#   -v, --verbose      Enable verbose logging
#   -h, --help         Display this help message and exit

# Path to logger module - adjust as needed
LOGGER_PATH="./logging.sh"

# Function to display usage
show_help() {
    grep '^#' "$0" | grep -v '#!/bin/bash' | sed 's/^# \?//'
    exit 0
}

# Check if logger exists
if [[ ! -f "$LOGGER_PATH" ]]; then
    echo "Error: Logger module not found at $LOGGER_PATH" >&2
    exit 1
fi

# Source the logger module
source "$LOGGER_PATH"

# Parse command line arguments
LOGGER_ARGS=()
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -l|--log)
            LOGGER_ARGS+=("$1" "$2")
            shift 2
            ;;
        -q|--quiet)
            LOGGER_ARGS+=("$1")
            shift
            ;;
        -v|--verbose)
            LOGGER_ARGS+=("$1")
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown parameter: $1" >&2
            show_help
            ;;
    esac
done

# Initialize the logger with collected arguments
init_logger "${LOGGER_ARGS[@]}" || {
    echo "Failed to initialize logger" >&2
    exit 1
}

# ======================================
# APPLICATION LOGIC STARTS HERE
# ======================================

# Example usage
log_debug "This is a debug message (only shown in verbose mode)"
log_info "Script started successfully"
log_warn "This is a warning message"
log_error "This is an error message"

# Function to simulate different operations with appropriate logging
simulate_operation() {
    local operation="$1"
    log_info "Starting operation: $operation"
    
    # Simulate operation with random success/failure
    if (( RANDOM % 10 > 2 )); then
        log_debug "Operation details: successfully completed $operation"
        log_info "Operation '$operation' completed successfully"
        return 0
    else
        log_error "Operation '$operation' failed"
        return 1
    fi
}

# Run some example operations
simulate_operation "data backup" || log_warn "Backup failure detected, will retry later"
simulate_operation "configuration update"
simulate_operation "health check"

log_info "Script execution completed"

exit 0