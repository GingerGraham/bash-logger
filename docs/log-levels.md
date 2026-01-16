# Log Levels <!-- omit in toc -->

The Bash Logging Module supports standard syslog log levels, providing a hierarchy of severity from most critical to
least critical.

## Table of Contents <!-- omit in toc -->

- [Overview](#overview)
- [Available Log Levels](#available-log-levels)
- [Log Level Details](#log-level-details)
  - [EMERGENCY (0)](#emergency-0)
  - [ALERT (1)](#alert-1)
  - [CRITICAL (2)](#critical-2)
  - [ERROR (3)](#error-3)
  - [WARN (4)](#warn-4)
  - [NOTICE (5)](#notice-5)
  - [INFO (6)](#info-6)
  - [DEBUG (7)](#debug-7)
- [Special Level: SENSITIVE](#special-level-sensitive)
- [Setting Log Levels](#setting-log-levels)
  - [At Initialization](#at-initialization)
  - [At Runtime](#at-runtime)
- [Log Level Filtering](#log-level-filtering)
- [Choosing the Right Level](#choosing-the-right-level)
  - [Development](#development)
  - [Testing](#testing)
  - [Production](#production)
  - [Monitoring/Operations](#monitoringoperations)
- [Best Practices](#best-practices)
- [Examples](#examples)
  - [Progressive Verbosity](#progressive-verbosity)
  - [Debug Mode](#debug-mode)
  - [Production Mode](#production-mode)
- [Related Documentation](#related-documentation)

## Overview

Log levels allow you to control the verbosity of your logging output. When you set a log level, only messages at that
level or higher (more severe) are displayed.

## Available Log Levels

| Level     | Numeric Value | Function        | Syslog Priority | Description                      |
| --------- | ------------- | --------------- | --------------- | -------------------------------- |
| EMERGENCY | 0             | `log_emergency` | emerg           | System is unusable               |
| ALERT     | 1             | `log_alert`     | alert           | Action must be taken immediately |
| CRITICAL  | 2             | `log_critical`  | crit            | Critical conditions              |
| ERROR     | 3             | `log_error`     | err             | Error conditions                 |
| WARN      | 4             | `log_warn`      | warning         | Warning conditions               |
| NOTICE    | 5             | `log_notice`    | notice          | Normal but significant condition |
| INFO      | 6             | `log_info`      | info            | Informational messages           |
| DEBUG     | 7             | `log_debug`     | debug           | Debug-level messages             |

## Log Level Details

### EMERGENCY (0)

**When to use:** System is completely unusable or about to crash.

```bash
log_emergency "Critical system failure - cannot continue"
```

**Examples:**

- Complete system failure
- Unrecoverable errors that require immediate shutdown
- Data corruption preventing any operation

### ALERT (1)

**When to use:** Action must be taken immediately.

```bash
log_alert "Database connection lost - attempting recovery"
```

**Examples:**

- Service outages requiring immediate attention
- Security breaches detected
- Critical resource exhaustion

### CRITICAL (2)

**When to use:** Critical conditions that may lead to system failure.

```bash
log_critical "Disk space critically low: 1% remaining"
```

**Examples:**

- Hardware failures
- Critical resource depletion
- Application component failures

### ERROR (3)

**When to use:** Error conditions that prevent normal operation.

```bash
log_error "Failed to write to configuration file"
```

**Examples:**

- File I/O errors
- Failed operations
- Invalid input or state
- Recoverable errors

### WARN (4)

**When to use:** Warning conditions that should be reviewed but don't prevent operation.

```bash
log_warn "API rate limit approaching threshold"
```

**Examples:**

- Deprecated feature usage
- Configuration issues that can be worked around
- Resource usage approaching limits
- Potential future problems

### NOTICE (5)

**When to use:** Normal but significant conditions worth noting.

```bash
log_notice "Configuration reloaded successfully"
```

**Examples:**

- Service startup/shutdown
- Configuration changes
- Significant but normal events
- Successful completion of important operations

### INFO (6)

**When to use:** General informational messages about normal operation.

```bash
log_info "Processing file: data.csv"
```

**Examples:**

- Progress updates
- Status messages
- Regular operational events
- User actions

**Note:** INFO is the default log level.

### DEBUG (7)

**When to use:** Detailed debugging information for development and troubleshooting.

```bash
log_debug "Variable value: count=$count, max=$max"
```

**Examples:**

- Variable values
- Function entry/exit
- Detailed state information
- Development diagnostics

**Note:** DEBUG messages are suppressed by default. Enable with `--verbose` or `--level DEBUG`.

## Special Level: SENSITIVE

The `log_sensitive` function provides a special logging level for sensitive information:

```bash
log_sensitive "API Key: $API_KEY"
```

**Behavior:**

- Displayed only on console
- Never written to log files
- Never sent to system journal
- Logged at INFO level severity for display purposes

See [Sensitive Data](sensitive-data.md) for more details.

## Setting Log Levels

### At Initialization

```bash
# Default (INFO)
init_logger

# Debug mode
init_logger --verbose
init_logger --level DEBUG

# Specific level
init_logger --level WARN
init_logger --level ERROR

# Using numeric value
init_logger --level 4  # WARN
```

### At Runtime

```bash
# Change level during execution
set_log_level DEBUG
set_log_level WARN
set_log_level ERROR
```

See [Runtime Configuration](runtime-configuration.md) for more details.

## Log Level Filtering

When you set a log level, messages below that severity are suppressed:

```bash
# Set level to WARN
init_logger --level WARN

log_debug "Not shown"
log_info "Not shown"
log_notice "Not shown"
log_warn "SHOWN"
log_error "SHOWN"
log_critical "SHOWN"
```

## Choosing the Right Level

### Development

```bash
# See everything
init_logger --verbose  # DEBUG level
```

### Testing

```bash
# See informational and above
init_logger --level INFO
```

### Production

```bash
# See warnings and errors only
init_logger --level WARN
```

### Monitoring/Operations

```bash
# See errors only
init_logger --level ERROR
```

## Best Practices

1. **Use INFO for normal operation** - Regular status updates and progress
2. **Use DEBUG liberally in code** - Add debug messages during development, they're hidden by default
3. **Use WARN for potential problems** - Issues that should be reviewed but don't require immediate action
4. **Use ERROR for failures** - Operations that failed but allow continued execution
5. **Reserve CRITICAL and above for severe issues** - System-threatening conditions
6. **Use SENSITIVE for secrets** - Passwords, tokens, keys, and other sensitive data

## Examples

### Progressive Verbosity

```bash
#!/bin/bash
source /path/to/logging.sh

# Default - shows INFO and above
init_logger

log_debug "Detailed debug info"      # Hidden
log_info "Normal operation"          # Shown
log_warn "Potential issue"           # Shown
log_error "Error occurred"           # Shown
```

### Debug Mode

```bash
#!/bin/bash
source /path/to/logging.sh

# Debug mode - shows everything
init_logger --verbose

log_debug "Detailed debug info"      # Shown
log_info "Normal operation"          # Shown
log_warn "Potential issue"           # Shown
log_error "Error occurred"           # Shown
```

### Production Mode

```bash
#!/bin/bash
source /path/to/logging.sh

# Production - only warnings and errors
init_logger --level WARN

log_debug "Detailed debug info"      # Hidden
log_info "Normal operation"          # Hidden
log_warn "Potential issue"           # Shown
log_error "Error occurred"           # Shown
```

## Related Documentation

- [Initialization](initialization.md) - Setting log level at startup
- [Runtime Configuration](runtime-configuration.md) - Changing log level dynamically
- [Sensitive Data](sensitive-data.md) - Handling sensitive information
- [Examples](examples.md) - More usage examples
