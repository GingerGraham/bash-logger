# API Reference <!-- omit in toc -->

Complete reference for all public functions in the bash-logger module.

## Table of Contents <!-- omit in toc -->

* [Overview](#overview)
* [Initialization Functions](#initialization-functions)
  * [init\_logger](#init_logger)
  * [check\_logger\_available](#check_logger_available)
* [Logging Functions](#logging-functions)
  * [log\_debug](#log_debug)
  * [log\_info](#log_info)
  * [log\_notice](#log_notice)
  * [log\_warn](#log_warn)
  * [log\_error](#log_error)
  * [log\_critical](#log_critical)
  * [log\_alert](#log_alert)
  * [log\_emergency](#log_emergency)
  * [log\_fatal](#log_fatal)
  * [log\_init](#log_init)
  * [log\_sensitive](#log_sensitive)
* [Runtime Configuration Functions](#runtime-configuration-functions)
  * [set\_log\_level](#set_log_level)
  * [set\_log\_format](#set_log_format)
  * [set\_timezone\_utc](#set_timezone_utc)
  * [set\_journal\_logging](#set_journal_logging)
  * [set\_journal\_tag](#set_journal_tag)
  * [set\_color\_mode](#set_color_mode)
* [Public Constants](#public-constants)
  * [Log Level Constants](#log-level-constants)
  * [Current Settings](#current-settings)
  * [Version](#version)
* [Internal Functions](#internal-functions)
* [Related Documentation](#related-documentation)

## Overview

This document provides a complete reference for all public functions in bash-logger. Functions are organized by
category:

* **Initialization** - Set up the logger
* **Logging** - Output log messages at different severity levels
* **Runtime Configuration** - Change settings after initialization

**Note:** Functions prefixed with underscore (`_`) are internal implementation details and should not be called
directly by consuming scripts.

## Initialization Functions

### init_logger

Initialize the logging system with optional configuration.

**Syntax:**

```bash
init_logger [options]
```

**Options:**

| Option                 | Short | Description                                    | Default     |
| ---------------------- | ----- | ---------------------------------------------- | ----------- |
| `--level LEVEL`        | `-d`  | Set log level (DEBUG, INFO, WARN, ERROR, etc.) | INFO        |
| `--log FILE`           | `-l`  | Write logs to file                             | (none)      |
| `--quiet`              | `-q`  | Disable console output                         | false       |
| `--verbose`            | `-v`  | Enable DEBUG level logging                     | false       |
| `--journal`            | `-j`  | Enable system journal logging                  | false       |
| `--tag TAG`            | `-t`  | Set journal tag                                | (script)    |
| `--utc`                | `-u`  | Use UTC timestamps instead of local time       | false       |
| `--format FORMAT`      | `-f`  | Set log message format                         | (see below) |
| `--color`              |       | Force color output                             | auto        |
| `--no-color`           |       | Disable color output                           | auto        |
| `--config FILE`        | `-c`  | Load configuration from INI file               | (none)      |
| `--stderr-level LEVEL` | `-e`  | Messages at/above this level go to stderr      | ERROR       |

**Default Format:**

```
%d [%l] [%s] %m
```

**Format Variables:**

* `%d` - Date and time (YYYY-MM-DD HH:MM:SS)
* `%z` - Timezone (UTC or LOCAL)
* `%l` - Log level name (DEBUG, INFO, WARN, ERROR, etc.)
* `%s` - Script name
* `%m` - Log message

**Returns:**

* `0` - Success
* `1` - Error (e.g., cannot create log file)

**Examples:**

```bash
# Basic initialization
init_logger

# Development mode
init_logger --verbose --color

# Production with file logging
init_logger --log "/var/log/myapp.log" --level INFO

# System service with journal
init_logger --journal --tag "myapp"

# Load from configuration file
init_logger --config /etc/myapp/logging.conf

# Custom format
init_logger --format "%d %z [%l] %m"

# Multiple options
init_logger --log "/var/log/app.log" --journal --tag "app" --level DEBUG
```

**See Also:**

* [Initialization Guide](initialization.md)
* [Configuration Files](configuration.md)

---

### check_logger_available

Check if the system `logger` command is available for journal logging.

**Syntax:**

```bash
check_logger_available
```

**Returns:**

* `0` - logger command is available
* `1` - logger command is not available

**Examples:**

```bash
# Check before enabling journal logging
if check_logger_available; then
    init_logger --journal
else
    init_logger --log "/var/log/myapp.log"
fi

# Conditional journal logging
if check_logger_available; then
    log_info "Journal logging is available"
else
    log_warn "Journal logging not available, using file logging only"
fi
```

**See Also:**

* [Journal Logging Guide](journal-logging.md)

---

## Logging Functions

All logging functions accept a single string parameter: the message to log.

### log_debug

Output a DEBUG level message (level 7).

**Syntax:**

```bash
log_debug "message"
```

**When to Use:**

* Detailed debugging information
* Variable values during troubleshooting
* Function entry/exit points
* Loop iterations and conditions

**Visibility:**

* Hidden by default (only shown when log level is DEBUG)
* Use `--verbose` or `--level DEBUG` to enable

**Examples:**

```bash
log_debug "Entering process_data function"
log_debug "Variable value: count=$count"
log_debug "Processing item $i of $total"
```

**See Also:**

* [Log Levels Guide](log-levels.md#debug-7)

---

### log_info

Output an INFO level message (level 6).

**Syntax:**

```bash
log_info "message"
```

**When to Use:**

* General informational messages
* Script progress updates
* Successful operations
* Normal workflow events

**Visibility:**

* Shown by default (INFO is the default log level)

**Examples:**

```bash
log_info "Starting backup process"
log_info "Successfully processed 100 records"
log_info "Configuration loaded from file"
```

**See Also:**

* [Log Levels Guide](log-levels.md#info-6)

---

### log_notice

Output a NOTICE level message (level 5).

**Syntax:**

```bash
log_notice "message"
```

**When to Use:**

* Normal but significant conditions
* Important milestones
* Configuration changes
* State transitions

**Visibility:**

* Shown by default

**Examples:**

```bash
log_notice "Application started in production mode"
log_notice "Cache cleared successfully"
log_notice "Switching to fallback database"
```

**See Also:**

* [Log Levels Guide](log-levels.md#notice-5)

---

### log_warn

Output a WARN level message (level 4).

**Syntax:**

```bash
log_warn "message"
```

**When to Use:**

* Warning conditions that don't prevent operation
* Deprecated feature usage
* Configuration issues that have defaults
* Approaching resource limits

**Visibility:**

* Shown by default
* Goes to stdout by default

**Examples:**

```bash
log_warn "Disk space is running low (85% used)"
log_warn "API rate limit approaching"
log_warn "Using deprecated configuration format"
```

**See Also:**

* [Log Levels Guide](log-levels.md#warn-4)

---

### log_error

Output an ERROR level message (level 3).

**Syntax:**

```bash
log_error "message"
```

**When to Use:**

* Error conditions that may be recoverable
* Failed operations
* Unexpected conditions
* Exceptions that are caught and handled

**Visibility:**

* Shown by default
* Goes to stderr by default

**Examples:**

```bash
log_error "Failed to connect to database"
log_error "File not found: $filename"
log_error "Invalid input: expected number, got '$input'"
```

**See Also:**

* [Log Levels Guide](log-levels.md#error-3)
* [Output Streams](output-streams.md)

---

### log_critical

Output a CRITICAL level message (level 2).

**Syntax:**

```bash
log_critical "message"
```

**When to Use:**

* Critical conditions requiring immediate attention
* System component failures
* Data corruption
* Security breaches

**Visibility:**

* Always shown
* Goes to stderr

**Examples:**

```bash
log_critical "Database corruption detected"
log_critical "Security certificate has expired"
log_critical "Out of memory - cannot continue"
```

**See Also:**

* [Log Levels Guide](log-levels.md#critical-2)

---

### log_alert

Output an ALERT level message (level 1).

**Syntax:**

```bash
log_alert "message"
```

**When to Use:**

* Action must be taken immediately
* Service outages
* Critical system failures requiring operator intervention

**Visibility:**

* Always shown
* Goes to stderr

**Examples:**

```bash
log_alert "Primary database is down - failover required"
log_alert "All API endpoints are unresponsive"
log_alert "Backup system has failed"
```

**See Also:**

* [Log Levels Guide](log-levels.md#alert-1)

---

### log_emergency

Output an EMERGENCY level message (level 0).

**Syntax:**

```bash
log_emergency "message"
```

**When to Use:**

* System is completely unusable
* Imminent crash or data loss
* Unrecoverable errors

**Visibility:**

* Always shown
* Goes to stderr

**Examples:**

```bash
log_emergency "System is out of resources and must shut down"
log_emergency "Critical configuration error - cannot start"
log_emergency "Data integrity compromised - halting all operations"
```

**See Also:**

* [Log Levels Guide](log-levels.md#emergency-0)

---

### log_fatal

Alias for `log_emergency`. Output a FATAL level message (level 0).

**Syntax:**

```bash
log_fatal "message"
```

**When to Use:**

Same as `log_emergency` - provided for compatibility and readability.

**Examples:**

```bash
log_fatal "Fatal error: cannot recover"
log_fatal "System initialization failed"
```

**See Also:**

* [log_emergency](#log_emergency)

---

### log_init

Output an initialization message (shown at INFO level).

**Syntax:**

```bash
log_init "message"
```

**When to Use:**

* Logging initialization events
* Component startup messages
* System bootstrap logging

**Special Behavior:**

* Not logged to journal (prevents initialization loops)
* Always shown regardless of log level

**Examples:**

```bash
log_init "Application starting - version 1.2.3"
log_init "Configuration loaded from /etc/myapp.conf"
```

---

### log_sensitive

Output sensitive data to console only (never to file or journal).

**Syntax:**

```bash
log_sensitive "message"
```

**When to Use:**

* Debugging with passwords or tokens
* Displaying API keys during troubleshooting
* Showing connection strings with credentials

**Security Features:**

* **Never** written to log files
* **Never** sent to system journal
* Only displayed on console (if console output is enabled)
* Useful for debugging without compromising security

**Examples:**

```bash
log_sensitive "Database password: $DB_PASS"
log_sensitive "API token: $API_TOKEN"
log_sensitive "Connection string: $CONNECTION_STRING"
```

**⚠️ Warning:**

Even console-only logging can be risky. Use `log_sensitive` only when necessary, and never in production with console
output that could be captured or logged by terminal emulators or shell history.

**See Also:**

* [Sensitive Data Guide](sensitive-data.md)

---

## Runtime Configuration Functions

These functions allow you to change logger settings after initialization.

### set_log_level

Change the minimum log level for displayed messages.

**Syntax:**

```bash
set_log_level LEVEL
```

**Parameters:**

* `LEVEL` - Level name (DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY) or numeric value (0-7)

**Examples:**

```bash
# Enable debug logging
set_log_level DEBUG

# Show only warnings and errors
set_log_level WARN

# Using numeric values
set_log_level 7  # DEBUG
set_log_level 3  # ERROR

# Conditional debug mode
if [[ "$DEBUG_MODE" == "true" ]]; then
    set_log_level DEBUG
fi
```

**Effects:**

* Logs a CONFIG message documenting the change
* Takes effect immediately for all subsequent log messages

**See Also:**

* [Runtime Configuration Guide](runtime-configuration.md#set_log_level)
* [Log Levels](log-levels.md)

---

### set_log_format

Change the log message format template.

**Syntax:**

```bash
set_log_format "format_string"
```

**Parameters:**

* `format_string` - Format template using variables:
  * `%d` - Date and time
  * `%z` - Timezone
  * `%l` - Log level
  * `%s` - Script name
  * `%m` - Message

**Examples:**

```bash
# Minimal format
set_log_format "%m"

# Include timezone
set_log_format "%d %z [%l] %m"

# Custom separator
set_log_format "%l | %d | %m"

# JSON-like format
set_log_format '{"time":"%d","level":"%l","message":"%m"}'
```

**Effects:**

* Logs a CONFIG message documenting the change
* Takes effect immediately for all subsequent log messages

**See Also:**

* [Runtime Configuration Guide](runtime-configuration.md#set_log_format)
* [Formatting Guide](formatting.md)

---

### set_timezone_utc

Switch between UTC and local time for timestamps.

**Syntax:**

```bash
set_timezone_utc BOOLEAN
```

**Parameters:**

* `BOOLEAN` - `true` to use UTC, `false` to use local time

**Examples:**

```bash
# Switch to UTC
set_timezone_utc true

# Switch back to local time
set_timezone_utc false

# Conditional timezone
if [[ "$ENVIRONMENT" == "production" ]]; then
    set_timezone_utc true  # Use UTC in production
fi
```

**Effects:**

* Logs a CONFIG message documenting the change
* Takes effect immediately for all subsequent log messages

**See Also:**

* [Runtime Configuration Guide](runtime-configuration.md#set_timezone_utc)

---

### set_journal_logging

Enable or disable system journal logging at runtime.

**Syntax:**

```bash
set_journal_logging BOOLEAN
```

**Parameters:**

* `BOOLEAN` - `true` to enable, `false` to disable

**Returns:**

* `0` - Success
* `1` - Error (e.g., logger command not available when trying to enable)

**Examples:**

```bash
# Disable journal logging
set_journal_logging false

# Re-enable journal logging
set_journal_logging true

# Conditional journal logging
if check_logger_available; then
    set_journal_logging true
else
    log_warn "Journal logging not available"
fi
```

**Effects:**

* Logs a CONFIG message documenting the change
* Takes effect immediately for all subsequent log messages

**See Also:**

* [Runtime Configuration Guide](runtime-configuration.md#set_journal_logging)
* [Journal Logging Guide](journal-logging.md)

---

### set_journal_tag

Change the tag used for journal log entries.

**Syntax:**

```bash
set_journal_tag "tag"
```

**Parameters:**

* `tag` - String identifier for journal entries

**Examples:**

```bash
# Change tag for different components
set_journal_tag "database-sync"
# ... database operations ...
set_journal_tag "api-client"
# ... API operations ...

# Use process ID in tag
set_journal_tag "myapp-$$"

# Component-based tagging
set_journal_tag "myapp-${COMPONENT_NAME}"
```

**Effects:**

* Logs a CONFIG message using the OLD tag, documenting the change
* Takes effect immediately for all subsequent journal log entries

**See Also:**

* [Runtime Configuration Guide](runtime-configuration.md#set_journal_tag)
* [Journal Logging Guide](journal-logging.md)

---

### set_color_mode

Change color output mode for console logging.

**Syntax:**

```bash
set_color_mode MODE
```

**Parameters:**

* `MODE` - One of:
  * `auto` - Auto-detect terminal color support (default)
  * `always` - Force color output
  * `never` - Disable color output
  * `true`, `on`, `yes`, `1` - Same as `always`
  * `false`, `off`, `no`, `0` - Same as `never`

**Examples:**

```bash
# Force colors on
set_color_mode always

# Disable colors
set_color_mode never

# Auto-detect (default)
set_color_mode auto

# Conditional coloring
if [[ -t 1 ]]; then
    set_color_mode always
else
    set_color_mode never
fi
```

**Effects:**

* Logs a CONFIG message documenting the change
* Takes effect immediately for all subsequent console output

**Color Detection (auto mode):**

* Checks `NO_COLOR` environment variable
* Checks `CLICOLOR` and `CLICOLOR_FORCE` environment variables
* Tests if stdout is a terminal
* Uses `tput` to check terminal capabilities
* Checks `TERM` environment variable

**See Also:**

* [Runtime Configuration Guide](runtime-configuration.md)
* [Output Streams](output-streams.md)

---

## Public Constants

These constants are available after sourcing `logging.sh`:

### Log Level Constants

```bash
LOG_LEVEL_EMERGENCY=0  # Most severe
LOG_LEVEL_ALERT=1
LOG_LEVEL_CRITICAL=2
LOG_LEVEL_ERROR=3
LOG_LEVEL_WARN=4
LOG_LEVEL_NOTICE=5
LOG_LEVEL_INFO=6
LOG_LEVEL_DEBUG=7      # Least severe

LOG_LEVEL_FATAL=0      # Alias for EMERGENCY
```

### Current Settings

These variables reflect the current logger configuration:

```bash
CURRENT_LOG_LEVEL      # Current minimum log level (0-7)
LOG_FILE               # Current log file path (empty if not logging to file)
CONSOLE_LOG            # "true" or "false" - console output enabled
USE_JOURNAL            # "true" or "false" - journal logging enabled
JOURNAL_TAG            # Current journal tag
USE_UTC                # "true" or "false" - UTC timestamps
LOG_FORMAT             # Current format string
USE_COLORS             # "auto", "always", or "never"
LOG_STDERR_LEVEL       # Messages at/above this level go to stderr
SCRIPT_NAME            # Name of the calling script
```

### Version

```bash
BASH_LOGGER_VERSION    # Version string (e.g., "1.0.0")
```

**Example:**

```bash
source logging.sh
init_logger

echo "Logger version: $BASH_LOGGER_VERSION"
echo "Current log level: $CURRENT_LOG_LEVEL"
echo "Log file: ${LOG_FILE:-none}"

# Conditional logic based on settings
if [[ "$CURRENT_LOG_LEVEL" -ge "$LOG_LEVEL_DEBUG" ]]; then
    echo "Debug mode is enabled"
fi
```

---

## Internal Functions

The following functions are prefixed with underscore (`_`) and are **internal implementation details**. They should not
be called directly by consuming scripts:

* `_detect_color_support` - Detect terminal color capabilities
* `_should_use_colors` - Determine if colors should be used
* `_should_use_stderr` - Determine if message should go to stderr
* `_parse_config_file` - Parse INI configuration files
* `_get_log_level_value` - Convert level name to numeric value
* `_get_log_level_name` - Convert numeric value to level name
* `_get_log_level_color` - Get ANSI color code for level
* `_get_syslog_priority` - Map level to syslog priority
* `_format_log_message` - Format log message using template
* `_log_to_console` - Output formatted message to console
* `_log_message` - Core logging implementation

**Note:** Internal functions may change between versions without notice. Always use the public API functions
documented above.

---

## Related Documentation

* [Getting Started](getting-started.md) - Quick start guide
* [Initialization](initialization.md) - Detailed initialization options
* [Log Levels](log-levels.md) - Complete log level reference
* [Configuration](configuration.md) - Configuration file format
* [Runtime Configuration](runtime-configuration.md) - Changing settings at runtime
* [Formatting](formatting.md) - Message format customization
* [Journal Logging](journal-logging.md) - System journal integration
* [Output Streams](output-streams.md) - Stdout/stderr behavior
* [Sensitive Data](sensitive-data.md) - Handling secrets safely
* [Examples](examples.md) - Comprehensive code examples
* [Troubleshooting](troubleshooting.md) - Common issues and solutions
