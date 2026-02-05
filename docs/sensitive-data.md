# Sensitive Data <!-- omit in toc -->

The Bash Logging Module provides a special function for handling sensitive information that should not be written to
persistent storage.

## Table of Contents <!-- omit in toc -->

* [Overview](#overview)
* [The log_sensitive Function](#the-log_sensitive-function)
  * [Basic Usage](#basic-usage)
  * [What Gets Logged Where](#what-gets-logged-where)
* [When to Use log_sensitive](#when-to-use-log_sensitive)
  * [Appropriate Use Cases](#appropriate-use-cases)
  * [Example: API Authentication](#example-api-authentication)
  * [Example: Database Connection](#example-database-connection)
* [Security Considerations](#security-considerations)
  * [Console Output Security](#console-output-security)
  * [Production Environments](#production-environments)
  * [ANSI Code Injection Prevention](#ansi-code-injection-prevention)
  * [Alternative Approaches](#alternative-approaches)
    * [1. Redact Sensitive Values](#1-redact-sensitive-values)
    * [2. Hash for Verification](#2-hash-for-verification)
    * [3. Boolean Indicators](#3-boolean-indicators)
* [Examples](#examples)
  * [OAuth Flow](#oauth-flow)
  * [SSH Key Management](#ssh-key-management)
  * [Environment Variable Debugging](#environment-variable-debugging)
  * [User Authentication](#user-authentication)
* [What log_sensitive Does NOT Do](#what-log_sensitive-does-not-do)
  * [Not a Security Solution](#not-a-security-solution)
  * [Still Need Proper Security Practices](#still-need-proper-security-practices)
* [Best Practices](#best-practices)
  * [1. Minimize Sensitive Logging](#1-minimize-sensitive-logging)
  * [2. Use Structured Redaction](#2-use-structured-redaction)
  * [3. Document Sensitive Data Handling](#3-document-sensitive-data-handling)
  * [4. Disable in Production](#4-disable-in-production)
  * [5. Audit Sensitive Logging](#5-audit-sensitive-logging)
* [Testing Sensitive Logging](#testing-sensitive-logging)
  * [Verify Sensitive Data Doesn't Persist](#verify-sensitive-data-doesnt-persist)
* [Related Documentation](#related-documentation)

## Overview

The `log_sensitive` function allows you to log sensitive information that will:

* **Display on console** - Visible during interactive execution
* **Never write to log files** - Not persisted to disk
* **Never send to journal** - Not stored in systemd journal
* **Not send to syslog** - Excluded from system logs

## The log_sensitive Function

### Basic Usage

```bash
#!/bin/bash

source /path/to/logging.sh
init_logger --log "/var/log/myapp.log" --journal --tag "myapp"

# Regular logging - goes everywhere
log_info "Authenticating user"

# Sensitive logging - console only
log_sensitive "API Token: $API_TOKEN"
log_sensitive "Password hash: $PASSWORD_HASH"

# Regular logging continues
log_info "Authentication successful"
```

### What Gets Logged Where

```bash
log_info "Starting authentication"        # → Console, File, Journal
log_sensitive "Password: $PASSWORD"       # → Console ONLY
log_info "Authentication complete"        # → Console, File, Journal
```

## When to Use log_sensitive

### Appropriate Use Cases

Use `log_sensitive` for:

* **Passwords and passphrases**
* **API keys and tokens**
* **OAuth secrets**
* **Private keys**
* **Database connection strings with embedded credentials**
* **Session tokens**
* **Authentication credentials**
* **Encryption keys**
* **Personal Identifiable Information (PII) in some contexts**

### Example: API Authentication

```bash
#!/bin/bash
source /path/to/logging.sh
init_logger --log "/var/log/api-client.log"

log_info "Connecting to API"

# Don't log the actual token to file
log_sensitive "Using API token: $API_TOKEN"

# Make API call
response=$(curl -H "Authorization: Bearer $API_TOKEN" "$API_URL")

log_info "API request completed with status: $status"
```

### Example: Database Connection

```bash
#!/bin/bash
source /path/to/logging.sh
init_logger --log "/var/log/db-backup.log"

log_info "Starting database backup"

# Connection string contains password
log_sensitive "Database connection: postgresql://$DB_USER:$DB_PASS@$DB_HOST/$DB_NAME"

# Perform backup
pg_dump "$DB_NAME" > backup.sql

log_info "Backup completed successfully"
```

## Security Considerations

### Console Output Security

Even though `log_sensitive` doesn't write to files or journals, the output still appears on the console. You must ensure:

1. **Terminal sessions are secure** - Not being recorded or monitored
2. **Screen sharing is disabled** - When handling sensitive data
3. **Terminal history is protected** - Some terminals save output history
4. **Not running in logged SSH sessions** - Some systems log terminal sessions
5. **No screen recording software** - Terminal recordings can capture sensitive data

### Production Environments

In production environments, consider:

```bash
#!/bin/bash
source /path/to/logging.sh
init_logger --log "/var/log/app.log" --journal

# Check if running interactively
if [[ -t 1 ]]; then
    # Interactive - safe to show sensitive data
    log_sensitive "Debug token: $TOKEN"
else
    # Non-interactive - even console output might be captured
    log_info "Token loaded (not displayed in non-interactive mode)"
fi
```

### ANSI Code Injection Prevention

bash-logger provides secure-by-default protection against ANSI escape sequence injection attacks. This is important
because malicious ANSI codes can:

* **Manipulate terminal display** - Clear screen, reposition cursor
* **Hide information** - Make previous output invisible
* **Spoof messages** - Create fake error or success messages
* **Enable social engineering** - Change window titles, fake prompts
* **Exploit terminal bugs** - Some terminal emulators have CVEs triggered by specific sequences

**Default Behavior:**

```bash
# By default, ANSI codes in user input are stripped
malicious_input=$'\e[2J\e[HFAKE ERROR\e[0m'
log_error "Processing: $malicious_input"
# Output: "Processing: FAKE ERROR" (without escape sequences)
```

**ANSI Code Protection:**

* All user input is automatically scrubbed of ANSI escape sequences
* Library-generated colors (for log levels) are preserved
* This protection is transparent - no code changes needed

**If You Need ANSI Codes in Log Messages:**

Only enable unsafe mode if you have complete control over all logged content:

```bash
init_logger --unsafe-allow-ansi-codes  # Not recommended

# Or at runtime:
set_unsafe_allow_ansi_codes true
```

**See Also:**

* [ANSI Code Injection Protection](../examples.md#ansi-code-injection-protection) in Examples
* [api-reference.md](api-reference.md#set_unsafe_allow_ansi_codes) - set_unsafe_allow_ansi_codes function
* [runtime-configuration.md](runtime-configuration.md#set_unsafe_allow_ansi_codes) - Runtime control

### Alternative Approaches

#### 1. Redact Sensitive Values

Instead of logging the full value, log a redacted version:

```bash
# Instead of:
log_sensitive "API Key: $API_KEY"

# Consider:
log_info "API Key: ${API_KEY:0:4}...${API_KEY: -4}"  # Show first/last 4 chars
log_info "API Key loaded: [REDACTED]"
log_info "Using API key ending in: ...${API_KEY: -4}"
```

#### 2. Hash for Verification

Log a hash instead of the actual value:

```bash
# Log hash for verification without exposing actual value
KEY_HASH=$(echo -n "$API_KEY" | sha256sum | cut -d' ' -f1)
log_info "API Key hash: $KEY_HASH"
```

#### 3. Boolean Indicators

Just indicate presence/absence:

```bash
if [[ -n "$API_KEY" ]]; then
    log_info "API key is configured"
else
    log_error "API key is missing"
fi
```

## Examples

### OAuth Flow

```bash
#!/bin/bash
source /path/to/logging.sh
init_logger --log "/var/log/oauth.log"

log_info "Starting OAuth authentication"

# Get OAuth token
OAUTH_TOKEN=$(get_oauth_token "$CLIENT_ID" "$CLIENT_SECRET")

# Log for debugging, but don't persist
log_sensitive "OAuth Token: $OAUTH_TOKEN"

# Use token
make_api_request "$OAUTH_TOKEN"

log_info "OAuth authentication complete"
```

### SSH Key Management

```bash
#!/bin/bash
source /path/to/logging.sh
init_logger --log "/var/log/ssh-setup.log"

log_info "Setting up SSH keys"

# Generate key
ssh-keygen -t ed25519 -f /tmp/temp_key -N ""

# Show private key for debugging (console only)
log_sensitive "Private key content:"
log_sensitive "$(cat /tmp/temp_key)"

# Show public key (this is safe to log normally)
log_info "Public key: $(cat /tmp/temp_key.pub)"

# Clean up
rm -f /tmp/temp_key /tmp/temp_key.pub

log_info "SSH key setup complete"
```

### Environment Variable Debugging

```bash
#!/bin/bash
source /path/to/logging.sh
init_logger --log "/var/log/app.log"

log_info "Application starting"

# Debug environment (sensitive variables to console only)
log_sensitive "Environment variables:"
log_sensitive "DATABASE_URL=$DATABASE_URL"
log_sensitive "SECRET_KEY=$SECRET_KEY"
log_sensitive "API_TOKEN=$API_TOKEN"

# Regular startup continues
log_info "Configuration loaded"
```

### User Authentication

```bash
#!/bin/bash
source /path/to/logging.sh
init_logger --log "/var/log/auth.log" --journal

authenticate_user() {
    local username=$1
    local password=$2

    log_info "Authentication attempt for user: $username"

    # Never log actual password to file/journal
    log_sensitive "Password provided: $password"

    # Perform authentication
    if verify_credentials "$username" "$password"; then
        log_info "Authentication successful for user: $username"
        return 0
    else
        log_warn "Authentication failed for user: $username"
        return 1
    fi
}

authenticate_user "admin" "$USER_PASSWORD"
```

## What log_sensitive Does NOT Do

### Not a Security Solution

`log_sensitive` is **not** a complete security solution. It:

* ✗ Does **not** encrypt the data
* ✗ Does **not** prevent console capture/recording
* ✗ Does **not** prevent terminal history logging
* ✗ Does **not** prevent memory dumps
* ✗ Does **not** prevent process monitoring
* ✗ Does **not** clear variables from memory

### Still Need Proper Security Practices

You must still:

* Store secrets in secure vaults (like HashiCorp Vault, AWS Secrets Manager)
* Use environment variables instead of hardcoding
* Implement proper access controls
* Use encrypted communication channels
* Follow the principle of least privilege
* Rotate credentials regularly
* Monitor for credential exposure

## Best Practices

### 1. Minimize Sensitive Logging

Only log sensitive data when absolutely necessary for debugging:

```bash
# Production
if [[ "$DEBUG_MODE" == "true" ]]; then
    log_sensitive "Debug credentials: $CREDS"
fi

# Not in production
log_info "Credentials loaded successfully"
```

### 2. Use Structured Redaction

Create helper functions for consistent redaction:

```bash
redact_token() {
    local token=$1
    local length=${#token}

    if [[ $length -gt 8 ]]; then
        echo "${token:0:4}...${token: -4}"
    else
        echo "[REDACTED]"
    fi
}

log_info "API Token: $(redact_token "$API_TOKEN")"
```

### 3. Document Sensitive Data Handling

Make it clear in your code:

```bash
# SECURITY: This function handles sensitive authentication data
# Sensitive values are only logged to console via log_sensitive
# and are never persisted to disk or sent to journal
authenticate() {
    log_sensitive "Auth token: $1"
    # ... authentication logic ...
}
```

### 4. Disable in Production

Consider disabling sensitive logging entirely in production:

```bash
#!/bin/bash
source /path/to/logging.sh
init_logger --log "/var/log/app.log"

log_sensitive_safe() {
    if [[ "${ENVIRONMENT}" != "production" ]]; then
        log_sensitive "$@"
    fi
}

# Only logs in non-production environments
log_sensitive_safe "API Key: $API_KEY"
```

### 5. Audit Sensitive Logging

Regularly review your code for sensitive logging:

```bash
# Search for potential sensitive data in logs
grep -r "password\|token\|secret\|key" your_scripts/
```

## Testing Sensitive Logging

### Verify Sensitive Data Doesn't Persist

```bash
#!/bin/bash
source /path/to/logging.sh

LOG_FILE="/tmp/test-sensitive.log"
init_logger --log "$LOG_FILE"

log_info "Regular message"
log_sensitive "SECRET: this should not appear in file"
log_info "Another regular message"

echo "=== Log file contents ==="
cat "$LOG_FILE"
echo "=== End of log file ==="

# Verify the word "SECRET" doesn't appear in the log file
if grep -q "SECRET" "$LOG_FILE"; then
    echo "ERROR: Sensitive data found in log file!"
    exit 1
else
    echo "SUCCESS: Sensitive data not in log file"
fi

rm "$LOG_FILE"
```

## Related Documentation

* [Log Levels](log-levels.md) - Understanding log severity levels
* [Journal Logging](journal-logging.md) - What doesn't go to the journal
* [Examples](examples.md) - More examples of sensitive data handling
* [Getting Started](getting-started.md) - Basic logging usage
