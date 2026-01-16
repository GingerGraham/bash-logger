# Runtime Configuration <!-- omit in toc -->

The Bash Logging Module allows you to change configuration settings during script execution, providing flexibility for different phases of operation.

## Table of Contents <!-- omit in toc -->

- [Overview](#overview)
- [Available Functions](#available-functions)
  - [set\_log\_level](#set_log_level)
  - [set\_timezone\_utc](#set_timezone_utc)
  - [set\_log\_format](#set_log_format)
  - [set\_journal\_logging](#set_journal_logging)
  - [set\_journal\_tag](#set_journal_tag)
- [Use Cases](#use-cases)
  - [Conditional Debug Mode](#conditional-debug-mode)
  - [Phase-Based Logging](#phase-based-logging)
  - [Dynamic Format Changes](#dynamic-format-changes)
  - [Conditional Journal Logging](#conditional-journal-logging)
  - [Timezone Switching](#timezone-switching)
  - [Environment-Based Settings](#environment-based-settings)
  - [Error Recovery](#error-recovery)
  - [Temporary Format Change](#temporary-format-change)
  - [Tag-Based Component Logging](#tag-based-component-logging)
- [Runtime vs. Initialization](#runtime-vs-initialization)
  - [When to Use Initialization Options](#when-to-use-initialization-options)
  - [When to Use Runtime Functions](#when-to-use-runtime-functions)
- [Best Practices](#best-practices)
  - [1. Document Runtime Changes](#1-document-runtime-changes)
  - [2. Restore Original Settings](#2-restore-original-settings)
  - [3. Use Functions for Common Patterns](#3-use-functions-for-common-patterns)
  - [4. Be Cautious with Production Changes](#4-be-cautious-with-production-changes)
  - [5. Log Configuration Changes](#5-log-configuration-changes)
- [Limitations](#limitations)
  - [Cannot Change After Initialization](#cannot-change-after-initialization)
  - [No Persistence](#no-persistence)
- [Examples](#examples)
  - [Debug Mode Toggle](#debug-mode-toggle)
  - [Adaptive Logging](#adaptive-logging)
- [Related Documentation](#related-documentation)

## Overview

Runtime configuration functions let you modify logging behavior without reinitializing the logger. This is useful for:

- Enabling debug mode for specific operations
- Changing log format for different sections
- Temporarily disabling journal logging
- Adjusting settings based on conditions

## Available Functions

### set_log_level

Change the minimum log level for displayed messages.

**Syntax:**

```bash
set_log_level LEVEL
```

**Parameters:**

- `LEVEL` - DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY, or 0-7

**Examples:**

```bash
# Enable debug logging
set_log_level DEBUG

# Show only warnings and errors
set_log_level WARN

# Show only errors and above
set_log_level ERROR

# Using numeric values
set_log_level 7  # DEBUG
set_log_level 4  # WARN
```

### set_timezone_utc

Switch between UTC and local time for timestamps.

**Syntax:**

```bash
set_timezone_utc BOOLEAN
```

**Parameters:**

- `BOOLEAN` - `true` to use UTC, `false` to use local time

**Examples:**

```bash
# Switch to UTC time
set_timezone_utc true

# Switch to local time
set_timezone_utc false
```

### set_log_format

Change the log message format.

**Syntax:**

```bash
set_log_format FORMAT
```

**Parameters:**

- `FORMAT` - Format string with placeholders

**Examples:**

```bash
# Change to minimal format
set_log_format "[%l] %m"

# Change to detailed format
set_log_format "%d %z [%l] [%s] %m"

# Change to custom format
set_log_format "%d [%s] %l: %m"
```

See [Formatting](formatting.md) for format options.

### set_journal_logging

Enable or disable systemd journal logging.

**Syntax:**

```bash
set_journal_logging BOOLEAN
```

**Parameters:**

- `BOOLEAN` - `true` to enable, `false` to disable

**Examples:**

```bash
# Enable journal logging
set_journal_logging true

# Disable journal logging
set_journal_logging false
```

### set_journal_tag

Change the tag used for journal/syslog entries.

**Syntax:**

```bash
set_journal_tag TAG
```

**Parameters:**

- `TAG` - String identifier for journal entries

**Examples:**

```bash
# Change journal tag
set_journal_tag "new-tag"

# Use component name
set_journal_tag "database-backup"

# Use operation name
set_journal_tag "cleanup-job"
```

## Use Cases

### Conditional Debug Mode

Enable debug logging based on command-line arguments:

```bash
#!/bin/bash
source /path/to/logging.sh

# Initialize with default level
init_logger --level INFO

# Parse command line arguments
for arg in "$@"; do
    if [[ "$arg" == "--debug" ]]; then
        set_log_level DEBUG
        log_debug "Debug mode enabled"
    fi
done

log_info "Application starting"
log_debug "This only shows if --debug was passed"
```

### Phase-Based Logging

Use different log levels for different phases:

```bash
#!/bin/bash
source /path/to/logging.sh

init_logger --log "/var/log/app.log"

# Initialization phase - verbose
set_log_level DEBUG
log_debug "Loading configuration"
log_debug "Connecting to database"

# Normal operation - standard
set_log_level INFO
log_info "Processing data"

# Critical phase - errors only
set_log_level ERROR
log_info "This won't show"
log_error "This will show"
```

### Dynamic Format Changes

Change format for different sections:

```bash
#!/bin/bash
source /path/to/logging.sh

init_logger --format "%d [%l] [%s] %m"

log_info "Starting processing"

# Switch to minimal format for detailed debug output
set_log_format "[%l] %m"
set_log_level DEBUG

for i in {1..100}; do
    log_debug "Processing item $i"
done

# Return to detailed format
set_log_format "%d [%l] [%s] %m"
set_log_level INFO

log_info "Processing complete"
```

### Conditional Journal Logging

Enable journal logging only for specific conditions:

```bash
#!/bin/bash
source /path/to/logging.sh

init_logger --level INFO

# Enable journal logging for production environment
if [[ "${ENV}" == "production" ]]; then
    set_journal_logging true
    set_journal_tag "myapp-prod"
    log_info "Journal logging enabled for production"
fi

log_info "Application running"
```

### Timezone Switching

Switch timezone based on operation:

```bash
#!/bin/bash
source /path/to/logging.sh

init_logger --format "%d %z [%l] %m"

# Local time for user-facing messages
set_timezone_utc false
log_info "Script started at local time"

# UTC for API calls or distributed operations
set_timezone_utc true
log_info "Making API call"
# ... API operations ...

# Back to local time
set_timezone_utc false
log_info "Script completed at local time"
```

### Environment-Based Settings

Adjust settings based on environment:

```bash
#!/bin/bash
source /path/to/logging.sh

init_logger --log "/var/log/app.log"

case "${ENVIRONMENT}" in
    development)
        set_log_level DEBUG
        set_log_format "[%l] %m"
        ;;
    testing)
        set_log_level INFO
        set_log_format "%d [%l] %m"
        ;;
    production)
        set_log_level WARN
        set_log_format "%d %z [%l] [%s] %m"
        set_timezone_utc true
        set_journal_logging true
        set_journal_tag "myapp"
        ;;
esac

log_info "Environment: ${ENVIRONMENT}"
```

### Error Recovery

Increase logging detail when errors occur:

```bash
#!/bin/bash
source /path/to/logging.sh

init_logger --level INFO

function process_item() {
    local item=$1

    if ! some_operation "$item"; then
        # Error occurred - enable debug mode for troubleshooting
        log_error "Error processing $item, enabling debug mode"
        set_log_level DEBUG

        # Retry with debug output
        log_debug "Retrying $item with debug output"
        if ! some_operation "$item"; then
            log_error "Retry failed for $item"
            return 1
        fi

        # Restore normal log level
        set_log_level INFO
    fi

    return 0
}

for item in "${items[@]}"; do
    process_item "$item"
done
```

### Temporary Format Change

Change format temporarily for specific output:

```bash
#!/bin/bash
source /path/to/logging.sh

init_logger

# Save current format (if needed for restoration)
ORIGINAL_FORMAT="%d [%l] [%s] %m"

log_info "Starting data export"

# Use minimal format for data listing
set_log_format "%m"
log_info "Record 1"
log_info "Record 2"
log_info "Record 3"

# Restore original format
set_log_format "$ORIGINAL_FORMAT"

log_info "Export complete"
```

### Tag-Based Component Logging

Change journal tag based on component:

```bash
#!/bin/bash
source /path/to/logging.sh

init_logger --journal --tag "main"

function database_operations() {
    set_journal_tag "myapp-database"
    log_info "Starting database operations"
    # ... database work ...
    log_info "Database operations complete"
}

function api_operations() {
    set_journal_tag "myapp-api"
    log_info "Starting API operations"
    # ... API work ...
    log_info "API operations complete"
}

log_info "Application starting"
database_operations
api_operations
set_journal_tag "main"
log_info "Application complete"
```

## Runtime vs. Initialization

### When to Use Initialization Options

Use initialization options (`init_logger`) for:

- Default configuration
- Settings that apply to entire script
- Static configuration from files
- Initial setup

```bash
# Set baseline configuration
init_logger --log "/var/log/app.log" --level INFO --journal
```

### When to Use Runtime Functions

Use runtime functions for:

- Dynamic changes during execution
- Conditional settings
- Temporary changes
- Phase-based configuration

```bash
# Change during execution
if [[ "$error_count" -gt 10 ]]; then
    set_log_level DEBUG  # Investigate issues
fi
```

## Best Practices

### 1. Document Runtime Changes

Make it clear when and why settings change:

```bash
# Enabling debug mode for complex operation
log_info "Starting complex calculation"
set_log_level DEBUG
# ... complex operation ...
set_log_level INFO
log_info "Complex calculation complete"
```

### 2. Restore Original Settings

If you change settings temporarily, restore them:

```bash
ORIGINAL_LEVEL="INFO"
set_log_level DEBUG
# ... temporary debug section ...
set_log_level "$ORIGINAL_LEVEL"
```

### 3. Use Functions for Common Patterns

Encapsulate common runtime configuration patterns:

```bash
enable_debug_mode() {
    set_log_level DEBUG
    set_log_format "[%l] %m"
    log_debug "Debug mode enabled"
}

disable_debug_mode() {
    set_log_level INFO
    set_log_format "%d [%l] [%s] %m"
    log_info "Debug mode disabled"
}
```

### 4. Be Cautious with Production Changes

Avoid frequently changing settings in production:

```bash
# Good: Set once based on environment
if [[ "$ENV" == "production" ]]; then
    set_log_level WARN
fi

# Bad: Constantly changing levels
set_log_level DEBUG
set_log_level INFO
set_log_level DEBUG  # Confusing
```

### 5. Log Configuration Changes

Log when you change important settings:

```bash
log_info "Changing log level to DEBUG for diagnostics"
set_log_level DEBUG

log_info "Restoring log level to INFO"
set_log_level INFO
```

## Limitations

### Cannot Change After Initialization

Some settings can only be set at initialization:

- Log file path (`--log`)
- Console output (`--quiet`)
- Stderr level (`--stderr-level`)
- Color mode (`--color` / `--no-color`)

To change these, you must reinitialize the logger.

### No Persistence

Runtime changes don't persist across script executions. If you need persistent changes, modify your initialization or configuration file.

## Examples

### Debug Mode Toggle

```bash
#!/bin/bash
source /path/to/logging.sh

init_logger

DEBUG_MODE=false

# Function to toggle debug mode
toggle_debug() {
    if [[ "$DEBUG_MODE" == "true" ]]; then
        DEBUG_MODE=false
        set_log_level INFO
        log_info "Debug mode disabled"
    else
        DEBUG_MODE=true
        set_log_level DEBUG
        log_info "Debug mode enabled"
    fi
}

# Use in script
log_info "Starting work"
toggle_debug  # Enable
log_debug "Debug info"
toggle_debug  # Disable
log_debug "This won't show"
```

### Adaptive Logging

```bash
#!/bin/bash
source /path/to/logging.sh

init_logger --level INFO

ERROR_COUNT=0

function process_item() {
    if ! operation; then
        ((ERROR_COUNT++))

        # After 5 errors, enable debug mode
        if [[ $ERROR_COUNT -eq 5 ]]; then
            log_warn "High error rate, enabling debug mode"
            set_log_level DEBUG
        fi

        return 1
    fi
    return 0
}
```

## Related Documentation

- [Initialization](initialization.md) - Setting initial configuration
- [Log Levels](log-levels.md) - Understanding log levels
- [Formatting](formatting.md) - Format string options
- [Journal Logging](journal-logging.md) - Journal configuration
- [Examples](examples.md) - Complete examples
