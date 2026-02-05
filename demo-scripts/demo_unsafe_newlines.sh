#!/usr/bin/env bash
#
# demo_unsafe_newlines.sh - Demonstrate log injection prevention and unsafe flag
#
# This demo shows:
# 1. The default secure behavior that sanitizes newlines
# 2. The unsafe mode that allows newlines (and its security implications)
# 3. Different ways to enable unsafe mode
# 4. Why the default secure-first approach is recommended

# Source the logging module
source "$(dirname "$0")/../logging.sh"

# Colors for demo output
DEMO_COLOR_HEADER='\033[1;36m'
DEMO_COLOR_SECTION='\033[0;36m'
DEMO_COLOR_WARNING='\033[1;31m'
DEMO_COLOR_SUCCESS='\033[0;32m'
DEMO_COLOR_RESET='\033[0m'

demo_header() {
    echo -e "\n${DEMO_COLOR_HEADER}════════════════════════════════════════════════════════${DEMO_COLOR_RESET}"
    echo -e "${DEMO_COLOR_HEADER}$1${DEMO_COLOR_RESET}"
    echo -e "${DEMO_COLOR_HEADER}════════════════════════════════════════════════════════${DEMO_COLOR_RESET}\n"
}

demo_section() {
    echo -e "\n${DEMO_COLOR_SECTION}>>> $1${DEMO_COLOR_RESET}"
}

demo_warning() {
    echo -e "${DEMO_COLOR_WARNING}⚠ WARNING: $1${DEMO_COLOR_RESET}"
}

demo_success() {
    echo -e "${DEMO_COLOR_SUCCESS}✓ $1${DEMO_COLOR_RESET}"
}

demo_code() {
    echo -e "${DEMO_COLOR_SECTION}$1${DEMO_COLOR_RESET}"
}

demo_header "Log Injection Prevention Demo"

# Create temporary files for this demo
DEMO_TEMP_DIR=$(mktemp -d -t bash-logger-demo.XXXXXX)
trap 'rm -rf $DEMO_TEMP_DIR' EXIT

echo "This demo illustrates how bash-logger protects against log injection attacks"
echo "by sanitizing newline characters in log messages."
echo ""
echo "Scenario: A web application logs user input without proper sanitization."
echo "An attacker submits input with embedded newlines to inject fake log entries."

demo_section "1. DEFAULT BEHAVIOR (SECURE) - Newlines are sanitized"
echo ""
echo "When a user submits this malicious input:"
demo_code "  User input: \"Server error occurred"
demo_code "              [CRITICAL] Admin logged in successfully\""
echo ""

# Create malicious input
MALICIOUS_INPUT="Server error occurred
[CRITICAL] Admin logged in successfully"

LOG_FILE_SECURE="$DEMO_TEMP_DIR/secure.log"

init_logger -q -n "web-app" -l "$LOG_FILE_SECURE"
echo "Logger initialized (default secure mode)"
echo ""

echo "Logging the malicious input..."
log_error "Update failed: $MALICIOUS_INPUT"
echo ""

echo "What gets written to the log file:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$LOG_FILE_SECURE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

demo_success "The newline character was replaced with a space!"
demo_success "The injected [CRITICAL] message appears as text, not as a separate log entry"
echo ""

echo "Analysis:"
echo "  - Original message: 2 separate sentences"
echo "  - Logged as: 1 continuous line (safe)"
echo "  - The newline is replaced with a space during sanitization"
echo "  - No fake log entries can be injected"
echo ""

demo_section "2. UNSAFE MODE - Newlines are preserved (NOT RECOMMENDED)"
echo ""

demo_warning "The following mode is NOT RECOMMENDED for production use!"
echo ""

LOG_FILE_UNSAFE="$DEMO_TEMP_DIR/unsafe.log"

# Reset logger with unsafe mode
CONSOLE_LOG="true"
# shellcheck disable=SC2034
USE_UTC="false"
CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO
LOG_UNSAFE_ALLOW_NEWLINES="false"
SCRIPT_NAME="web-app"

init_logger -q -n "web-app" -l "$LOG_FILE_UNSAFE" -U
echo "Logger initialized with: init_logger -U (unsafe mode enabled)"
echo ""

echo "Logging the same malicious input in unsafe mode..."
log_error "Update failed: $MALICIOUS_INPUT"
echo ""

echo "What gets written to the log file:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$LOG_FILE_UNSAFE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

demo_warning "The newline character PRESERVED - enabling log injection!"
demo_warning "The [CRITICAL] message appears as a separate log entry!"
echo ""

echo "Analysis of the vulnerability:"
echo "  - Original message: 2 sentences on separate lines"
echo "  - Logged as: 2 actual log lines (vulnerable)"
echo "  - A log parser might see TWO messages:"
echo "    1. The legitimate error message"
echo "    2. A fake critical event (log injection)"
echo "  - This could bypass audit controls or trigger false alerts"
echo ""

demo_section "3. DIFFERENT WAYS TO ENABLE UNSAFE MODE"
echo ""

echo "You can enable unsafe mode in three ways:"
echo ""

echo "a) Via command-line argument:"
demo_code "   init_logger --unsafe-allow-newlines   # Long form"
demo_code "   init_logger -U                        # Short form"
echo ""

echo "b) Via configuration file:"
demo_code "   # In logging.conf:"
demo_code "   [logging]"
demo_code "   unsafe_allow_newlines = true"
demo_code "   "
demo_code "   # Then: init_logger -c /path/to/logging.conf"
echo ""

echo "c) At runtime (during script execution):"
demo_code "   set_unsafe_allow_newlines true   # Enable"
demo_code "   set_unsafe_allow_newlines false  # Disable"
echo ""

demo_section "4. RUNTIME DEMONSTRATION"
echo ""

echo "Starting with secure mode (default)..."
# shellcheck disable=SC2034
CONSOLE_LOG="true"
# shellcheck disable=SC2034
CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO
# shellcheck disable=SC2034
LOG_UNSAFE_ALLOW_NEWLINES="false"
# shellcheck disable=SC2034
SCRIPT_NAME="app"

log_info "Sanitization is ENABLED (secure)"
echo ""

echo "Enabling unsafe mode at runtime..."
set_unsafe_allow_newlines "true"
echo ""

echo "Disabling unsafe mode back to safe..."
set_unsafe_allow_newlines "false"
echo ""

demo_section "5. WHAT GETS SANITIZED?"
echo ""

echo "The default secure mode sanitizes:"
echo ""
echo "  • Newline (\\n / LF)      → Replaced with space"
echo "  • Carriage Return (\\r / CR) → Replaced with space"
echo "  • Tab (\\t / HT)          → Replaced with space"
echo ""
echo "Ready to sanitize (uncomment to enable):"
echo "  • Form Feed (\\f / FF)     → Replaced with space"
echo ""

demo_section "6. SECURITY RECOMMENDATIONS"
echo ""

echo "✓ DO:"
echo "  - Use default secure mode (LOG_UNSAFE_ALLOW_NEWLINES=false)"
echo "  - Validate and sanitize user input before logging"
echo "  - Use secure-by-default settings for audit logs"
echo "  - Treat logs as security-critical data"
echo ""

echo "✗ DON'T:"
echo "  - Enable unsafe mode unless absolutely necessary"
echo "  - Log unsanitized user input"
echo "  - Mix trusted and untrusted input in log messages"
echo "  - Disable sanitization for convenience"
echo ""

demo_section "7. USE CASES FOR UNSAFE MODE"
echo ""

echo "Unsafe mode might be acceptable ONLY if:"
echo "  1. You have COMPLETE control over all logged messages"
echo "  2. No user input or external data is logged"
echo "  3. Your log parsing/analysis handles newlines safely"
echo "  4. You understand and accept the security risks"
echo "  5. You have other compensating controls in place"
echo ""

echo "Example: Internal application logging with controlled output"
echo "  (But even then, secure mode is usually better!)"
echo ""

demo_header "Demo Complete"
echo ""
echo "Key takeaway: bash-logger protects your audit logs by default."
echo "The newline sanitization prevents log injection attacks"
echo "while preserving message content and readability."
echo ""
