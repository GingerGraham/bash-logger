#!/usr/bin/env bash
#
# Demonstration of ANSI Code Injection Protection (Issue #36)
# Shows how secure-by-default ANSI stripping prevents terminal manipulation attacks

# Get the parent directory (where logging.sh is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source the logging module
source "$PROJECT_ROOT/logging.sh"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ANSI Code Injection Protection Demonstration (Issue #36)     ║"
echo "║  Secure-by-Default Implementation                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Initialize logger with console output
init_logger --no-color > /dev/null 2>&1

echo "Demo 1: Attempted Terminal Clear and Cursor Manipulation"
echo "─────────────────────────────────────────────────────────"
# Attacker crafted input with ANSI codes to clear screen and reposition cursor
malicious1=$'Normal log entry\e[2J\e[HFAKE CRITICAL: System compromised!\e[0m'
log_error "Processing user input: $malicious1"
echo "✓ ANSI codes stripped - fake error message neutralized"
echo ""

echo "Demo 2: Attempted Window Title and Information Disclosure"
echo "──────────────────────────────────────────────────────────"
# Attacker tries to change window title (could lead to info disclosure when screenshot taken)
malicious2=$'\e]0;Pwned Terminal\aYour password is required\e[0m'
log_warn "Message from system: $malicious2"
echo "✓ OSC sequence stripped - window title manipulation prevented"
echo ""

echo "Demo 3: Color Code Injection"
echo "────────────────────────────"
# Attacker reuses malicious color codes
malicious3=$'\e[31m\e[1m\e[5mFLASH: CRITICAL ERROR\e[0m\e]0;HACKED\a'
log_critical "Alert: $malicious3"
echo "✓ All escape sequences stripped - visual manipulation prevented"
echo ""

echo "Demo 4: Library-Generated Colors Still Work"
echo "───────────────────────────────────────────"
# Re-initialize with colors enabled to show library colors still work
init_logger --color > /dev/null 2>&1
log_debug "Debug message (blue if colors enabled)"
log_notice "Notice message (green if colors enabled)"
log_error "Error message (red if colors enabled)"
echo "✓ Library-generated colors are preserved"
echo ""

echo "Demo 5: Unsafe Mode (NOT RECOMMENDED)"
echo "────────────────────────────────────"
init_logger --no-color --unsafe-allow-ansi-codes > /dev/null 2>&1
log_warn "Unsafe mode enabled - ANSI codes preserved (NOT RECOMMENDED)"
echo "(In unsafe mode, ANSI codes would be preserved, enabling attacks)"
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Summary: ANSI Injection Protection Active                   ║"
echo "║  • Secure by default - ANSI codes stripped from user input   ║"
echo "║  • Library colors still generated automatically              ║"
echo "║  • Terminal manipulation attacks prevented                   ║"
echo "║  • Optional unsafe mode for backward compatibility           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
