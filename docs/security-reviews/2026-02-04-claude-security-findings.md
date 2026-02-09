# bash-logger Security Review Findings

**Reviewer:** Security Analysis
**Date:** 2026-02-04
**Component:** logging.sh v1.2.1
**Severity Scale:** CRITICAL | HIGH | MEDIUM | LOW | INFO

---

## Executive Summary

The bash-logger library has been reviewed for security vulnerabilities with focus on code injection,
privilege escalation, information disclosure, and file system attacks. The library demonstrates good
security practices overall with minimal attack surface due to its simplicity and lack of external dependencies.

**Overall Security Posture:** GOOD with minor recommendations

**Findings Summary:**

* 0 Critical vulnerabilities
* 0 High severity vulnerabilities
* 2 Medium severity vulnerabilities
* 3 Low severity vulnerabilities
* 4 Informational items

---

## MEDIUM SEVERITY

### [MEDIUM-01] Log Injection via Newline Characters

**Component:** `_log_message()`, `_format_log_message()`
**CWE:** CWE-117 (Improper Output Neutralization for Logs)

**Description:**

User-provided input containing newline characters (`\n`, `\r`) can inject fake log entries. An attacker who can control logged messages could inject arbitrary log entries that appear legitimate.

**Proof of Concept:**

```bash
# Attacker-controlled input
malicious_input="Legitimate message\n$(date '+%Y-%m-%d %H:%M:%S') [CRITICAL] Admin logged in successfully"

# This creates two log entries
log_info "User input: $malicious_input"
```

**Result:** Creates fake CRITICAL log entry that appears legitimate, potentially hiding actual security events or triggering false alerts.

**Impact:**

* Log forgery and audit trail manipulation
* False security alerts
* Hiding malicious activity in legitimate-looking log entries
* Compliance violations (audit logs must be tamper-evident)

**Affected Code:**

```bash
# No sanitization before logging
_log_message() {
    # ...
    local log_entry
    log_entry=$(_format_log_message "$level_name" "$message")
    # Message is used directly without sanitization
}
```

**Recommendation:**

Add input sanitization option (opt-in for backward compatibility):

```bash
# Add function to sanitize log messages
_sanitize_log_message() {
    local message="$1"
    # Remove newlines and carriage returns
    message="${message//$'\n'/ }"
    message="${message//$'\r'/ }"
    # Optionally remove other control characters
    message="${message//[$'\t\v\f']/  }"
    echo "$message"
}

# Add init_logger flag: --sanitize or --escape-newlines
# Environment variable: LOG_SANITIZE_INPUT=true
```

**Mitigation for Users:**

```bash
# Current workaround - users must sanitize input themselves
user_input="${user_input//[$'\n\r']/}"
log_info "User input: ${user_input}"
```

---

### [MEDIUM-02] Terminal Escape Sequence Injection (ANSI Code Injection)

**Component:** `_log_to_console()`, color handling
**CWE:** CWE-150 (Improper Neutralization of Escape, Meta, or Control Sequences)

**Description:**

The library uses ANSI color codes which are powerful terminal control sequences. If user input is logged and contains malicious ANSI escape sequences, it could:

* Manipulate terminal display when logs are viewed
* Hide information from terminal viewers
* Potentially trigger terminal emulator vulnerabilities

**Proof of Concept:**

```bash
# Attacker crafts input with ANSI codes
malicious_input="Normal text\e[2J\e[H\e[31mFAKE CRITICAL ERROR\e[0m"

# When logged and viewed in terminal
log_info "Processing: $malicious_input"
# Could clear screen, reposition cursor, change colors, etc.
```

**More dangerous sequences:**

```bash
# Clear screen and hide previous output
malicious="\e[2J\e[H"

# Change window title (information disclosure when screenshot taken)
malicious="\e]0;Hacked Terminal\a"

# Historical terminal vulnerabilities (rare but possible)
malicious="\e]4;0;rgb:00/00/00\e\\"  # Change terminal colors
```

**Impact:**

* Terminal display manipulation when viewing logs
* Hide security-relevant log entries
* Social engineering attacks (fake prompts, fake errors)
* Potential terminal emulator exploitation (historical CVEs)

**Affected Code:**

```bash
_log_to_console() {
    # ANSI codes added to message
    output="${color}${log_entry}${COLOR_RESET}"
    echo -e "${output}"  # -e interprets escape sequences
}
```

**Recommendation:**

1. Strip ANSI codes from journal/file output (already done):

```bash
# Already implemented - good!
local plain_message="${message//\e\[[0-9;]*m/}"
logger -t "${JOURNAL_TAG}" "$plain_message"
```

1. Add option to strip escape sequences from user input:

```bash
_strip_ansi_codes() {
    local input="$1"
    # Remove ANSI CSI sequences
    input="${input//$'\e'\[[0-9;]*[a-zA-Z]/}"
    # Remove OSC sequences
    input="${input//$'\e'\][^\a]*\a/}"
    # Remove other escape sequences
    input="${input//$'\e'[^[]*.}"
    echo "$input"
}

# Add init_logger flag: --strip-ansi or --sanitize-ansi
```

**Mitigation for Users:**

```bash
# Strip escape sequences before logging user input
sanitized="${user_input//$'\e'\[[0-9;]*m/}"
log_info "User input: $sanitized"
```

---

## LOW SEVERITY

### [LOW-01] Information Disclosure via Log File Paths

**Component:** Error messages in `init_logger()`
**CWE:** CWE-209 (Generation of Error Message Containing Sensitive Information)

**Description:**

Error messages reveal full file system paths, which could aid attackers in reconnaissance:

```bash
echo "Error: Cannot create log directory '$LOG_DIR'" >&2
echo "Error: Cannot write to log file '$LOG_FILE'" >&2
```

**Impact:**

* Reveals directory structure
* Leaks username information if using $HOME
* Provides reconnaissance data for privilege escalation

**Recommendation:**

Option 1 - Sanitize paths in error messages (may reduce debuggability):

```bash
echo "Error: Cannot create log directory" >&2
echo "Error: Cannot write to log file" >&2
```

Option 2 - Add security logging mode that suppresses paths:

```bash
if [[ "$SECURITY_MODE" == "true" ]]; then
    echo "Error: Cannot create log directory" >&2
else
    echo "Error: Cannot create log directory '$LOG_DIR'" >&2
fi
```

**Priority:** Low - paths are typically not sensitive in most threat models, but defense-in-depth suggests minimizing information disclosure.

---

### [LOW-02] Race Condition in Log File Creation

**Component:** `init_logger()` - `mkdir -p` and `touch`
**CWE:** CWE-367 (Time-of-check Time-of-use - TOCTOU)

**Description:**

Between the directory creation and file touch operations, an attacker with local access could:

1. Create a symlink at the log file path
2. Cause logs to be written to an unintended location

**Attack Scenario:**

```bash
# Terminal 1 - victim script
init_logger --log /tmp/app.log

# Terminal 2 - attacker (between mkdir and touch)
rm -f /tmp/app.log
ln -s /etc/passwd /tmp/app.log

# Victim's logs now written to /etc/passwd (if writable)
```

**Affected Code:**

```bash
mkdir -p "$LOG_DIR" 2>/dev/null
# <- Race condition window here
touch "$LOG_FILE" 2>/dev/null
```

**Impact:**

* Write logs to unintended files
* Potential privilege escalation if running as different users
* File content overwrite

**Likelihood:** Low - requires local access, specific timing, and writable target

**Recommendation:**

Add symlink detection:

```bash
# After touch, verify it's a regular file
if [[ -L "$LOG_FILE" ]]; then
    echo "Error: Log file path is a symbolic link" >&2
    return 1
fi

if [[ ! -f "$LOG_FILE" ]]; then
    echo "Error: Log file is not a regular file" >&2
    return 1
fi
```

Or use atomic operations:

```bash
# Create file exclusively (fails if exists)
set -C  # noclobber
: > "$LOG_FILE" 2>/dev/null || {
    echo "Error: Cannot create log file (already exists or permission denied)" >&2
    return 1
}
set +C
```

---

### [LOW-03] Function Name Injection via Caller Detection

**Component:** `_get_calling_script_name()`, caller script name detection
**CWE:** CWE-20 (Improper Input Validation)

**Description:**

The function extracts calling script name from `BASH_SOURCE`:

```bash
# From _get_calling_script_name()
caller_script=$(basename "${BASH_SOURCE[1]}")
```

If an attacker can control the script name (e.g., via crafted filename), this could inject shell metacharacters into log output or the `$SCRIPT_NAME` variable.

**Attack Scenario:**

```bash
# Create malicious script name
touch '/tmp/script$(rm -rf /tmp/evil).sh'
chmod +x '/tmp/script$(rm -rf /tmp/evil).sh'

# If script name is used in eval or command substitution later
# This is unlikely but possible if users extend the library
```

**Current Risk:** Very Low - `SCRIPT_NAME` is only used in:

1. Log format placeholders (safe)
2. Journal tag (passed to `logger` - properly quoted)

**Affected Code:**

```bash
caller_script=$(basename "${BASH_SOURCE[1]}")
SCRIPT_NAME="$caller_script"
```

**Recommendation:**

Sanitize script name:

```bash
_get_calling_script_name() {
    # ... existing code ...

    # Sanitize script name - remove shell metacharacters
    caller_script="${caller_script//[^a-zA-Z0-9._-]/_}"
    echo "$caller_script"
}
```

**Priority:** Low - limited impact, mostly defense-in-depth.

---

## INFORMATIONAL

### [INFO-01] Sensitive Data Logging Function - Incomplete Protection

**Component:** `log_sensitive()`
**Related Documentation:** docs/sensitive-data.md

**Observation:**

The `log_sensitive()` function is designed to prevent sensitive data from being written to files or journals, but has limitations:

```bash
log_sensitive() {
    _log_message "SENSITIVE" $LOG_LEVEL_INFO "$1" "true" "true"
}
```

**Limitations:**

1. If console output is redirected to a file, sensitive data is captured:

   ```bash
   script.sh > output.log 2>&1  # Captures sensitive logs
   ```

2. Process memory dumps could contain sensitive data

3. Terminal scrollback buffers retain data

4. Shell history may capture commands containing sensitive data

**Recommendation:**

Document these limitations clearly in the sensitive data documentation. Consider adding warnings:

```bash
log_sensitive() {
    if [[ -t 1 ]]; then
        # Only log if stdout is a terminal
        _log_message "SENSITIVE" $LOG_LEVEL_INFO "$1" "true" "true"
    else
        # Warn that output is redirected
        _log_message "WARN" $LOG_LEVEL_WARN "Attempted to log sensitive data while stdout is redirected - suppressed" "false" "false"
    fi
}
```

---

### [INFO-02] No Input Length Limits

**Component:** All logging functions

**Observation:**

The library does not enforce maximum message length. Extremely large log messages could:

* Fill disk space rapidly
* Cause performance issues
* Create denial-of-service conditions
* Exceed journal message size limits (default ~2MB in systemd)

**Current Behavior:**

* Bash handles strings up to available memory
* Files grow unbounded
* Journal may truncate or reject large messages

**Recommendation:**

Add optional message truncation:

```bash
LOG_MAX_MESSAGE_LENGTH=4096  # Default: no limit

_log_message() {
    local message="$3"

    # Truncate if length limit set
    if [[ -n "$LOG_MAX_MESSAGE_LENGTH" ]] && [[ ${#message} -gt $LOG_MAX_MESSAGE_LENGTH ]]; then
        message="${message:0:$LOG_MAX_MESSAGE_LENGTH}... [TRUNCATED]"
    fi

    # ... rest of function
}
```

**Priority:** Informational - users should implement log rotation and disk monitoring regardless.

---

### [INFO-03] Configuration File Parsing - Limited Validation

**Component:** `_parse_config_file()`

**Observation:**

Config file parsing has minimal validation:

* No limits on line length
* No validation of special characters in values
* No protection against malformed config files

**Potential Issues:**

* Very long lines could cause performance issues
* Malformed files could cause unexpected behavior
* No detection of obviously malicious patterns

**Example Concerns:**

```ini
# Very long value
log_file=/var/log/aaaaaaa... [repeat 10MB times] ...aaa

# Embedded newlines (if parser is modified)
log_format="Line 1
Line 2"

# Shell metacharacters
log_file=$(rm -rf /)
```

**Current Protection:**

* Values are properly quoted when used
* No use of `eval` on config values ✓
* Direct assignment only ✓

**Recommendation:**

Add validation in `_parse_config_file()`:

```bash
# Add length limits
if [[ ${#value} -gt 4096 ]]; then
    echo "Warning: Config value too long, truncating" >&2
    value="${value:0:4096}"
fi

# Validate specific parameters
case "$key" in
    log_file)
        # Must be absolute path
        if [[ "$value" != /* ]]; then
            echo "Error: log_file must be absolute path" >&2
            return 1
        fi
        ;;
esac
```

---

### [INFO-04] Environment Variable Override Capability

**Component:** Global variables (LOG_FILE, USE_COLORS, etc.)

**Observation:**

All configuration is stored in global variables that can be overridden by the user's environment:

```bash
# User can set before sourcing
export LOG_FILE="/attacker/controlled/path"
source logging.sh
init_logger  # Uses attacker's LOG_FILE
```

**Impact:**

* Users can override internal configuration
* Could redirect logs to attacker-controlled location
* Could disable security features

**Current Status:**

* This is expected bash behavior for sourced libraries
* Not necessarily a vulnerability, but worth documenting

**Recommendation:**

Document this behavior and provide guidance:

```bash
# In documentation - recommended pattern
init_logger() {
    # Store original environment
    local env_log_file="${LOG_FILE:-}"

    # Reset to secure defaults
    LOG_FILE=""
    USE_COLORS="auto"

    # Parse arguments (overrides defaults)
    # ...

    # Only use environment if explicitly enabled
    if [[ "$ALLOW_ENV_OVERRIDE" == "true" ]] && [[ -n "$env_log_file" ]]; then
        LOG_FILE="${LOG_FILE:-$env_log_file}"
    fi
}
```

**Priority:** Informational - document expected behavior rather than changing it.

---

## Positive Security Features

The following security-positive practices were observed:

1. **No use of `eval`** - All user input is safely handled ✓
2. **Proper quoting** - Variables are correctly quoted throughout ✓
3. **No command substitution of user input** - Parameters are never executed ✓
4. **ANSI code stripping** - Journal/file output strips color codes ✓
5. **Minimal dependencies** - Reduces supply chain risk ✓
6. **No network operations** - Cannot be exploited remotely ✓
7. **Read-only operations** - Most functions only read, don't modify system ✓
8. **Permission checks** - Validates file writability before use ✓

---

## Recommendations Summary

### Immediate Actions (Medium Priority)

1. Add log injection protection (sanitize newlines)
2. Add ANSI escape sequence stripping for user input
3. Document terminal injection risks

### Near-term Improvements (Low Priority)

1. Add symlink detection for log files
2. Sanitize script names extracted from BASH_SOURCE
3. Add message length limits (optional)

### Documentation Updates

1. Expand security documentation with injection examples
2. Document `log_sensitive()` limitations
3. Add security best practices guide
4. Include input validation examples

---

## Testing Recommendations

Create security test suite:

```bash
# tests/security_tests.sh

# Test log injection
test_log_injection() {
    malicious="Normal\n$(date) [CRITICAL] Fake entry"
    log_info "$malicious"
    # Verify only one entry created
}

# Test ANSI injection
test_ansi_injection() {
    malicious="Text\e[2J\e[HCleared!"
    log_info "$malicious"
    # Verify ANSI codes stripped in file
}

# Test symlink attack
test_symlink_attack() {
    ln -s /etc/passwd /tmp/test.log
    init_logger --log /tmp/test.log
    # Should fail or detect symlink
}
```

---

## Conclusion

bash-logger demonstrates solid security practices with a minimal attack surface.
The identified issues are primarily defense-in-depth recommendations rather than critical vulnerabilities.
The library's simplicity and lack of external dependencies are security strengths.

**Risk Level:** LOW
**Recommended Actions:** Implement MEDIUM severity fixes, document limitations
**Blocking Issues:** None - library is safe for production use

For a community-driven, security-conscious project, consider adding:

* SECURITY.md with vulnerability reporting process (already exists ✓)
* Security testing in CI/CD
* Fuzzing tests for parsing functions
* Regular security audits when accepting contributions
