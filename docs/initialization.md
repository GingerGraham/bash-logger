# Initialization <!-- omit in toc -->

The `init_logger` function is the entry point for configuring the Bash Logging Module. It must be called before using
any logging functions.

## Table of Contents <!-- omit in toc -->

* [Basic Initialization](#basic-initialization)
* [Initialization Options](#initialization-options)
* [Common Initialization Patterns](#common-initialization-patterns)
  * [Default Configuration](#default-configuration)
  * [File Logging](#file-logging)
  * [Verbose/Debug Mode](#verbosedebug-mode)
  * [Journal Logging](#journal-logging)
  * [Configuration File](#configuration-file)
  * [Custom Format](#custom-format)
  * [UTC Time](#utc-time)
  * [Color Control](#color-control)
  * [Custom Script Name](#custom-script-name)
  * [Stderr Level Configuration](#stderr-level-configuration)
* [Combining Options](#combining-options)
  * [Development Setup](#development-setup)
  * [Production Setup](#production-setup)
  * [Testing/CI Setup](#testingci-setup)
  * [CLI Tool Setup](#cli-tool-setup)
* [Return Codes](#return-codes)
  * [Error Handling](#error-handling)
  * [Common Initialization Errors](#common-initialization-errors)
* [Initialization Best Practices](#initialization-best-practices)
  * [1. Initialize Early](#1-initialize-early)
  * [2. Check Return Code](#2-check-return-code)
  * [3. Use Configuration Files for Complex Setups](#3-use-configuration-files-for-complex-setups)
  * [4. Allow Runtime Overrides](#4-allow-runtime-overrides)
  * [5. Environment-Specific Configuration](#5-environment-specific-configuration)
* [Examples by Use Case](#examples-by-use-case)
  * [Simple Script](#simple-script)
  * [Script with File Logging](#script-with-file-logging)
  * [System Service](#system-service)
  * [Development Script](#development-script)
  * [Shell RC File](#shell-rc-file)
* [Related Documentation](#related-documentation)

## Basic Initialization

```bash
# Source the module
source /path/to/logging.sh

# Initialize with defaults
init_logger
```

## Initialization Options

The `init_logger` function accepts the following options:

| Option                                          | Description                                                                         |
| ----------------------------------------------- | ----------------------------------------------------------------------------------- |
| `-c, --config FILE`                             | Load configuration from an INI file (CLI args override config values)               |
| `-l, --log, --logfile, --log-file, --file FILE` | Specify a log file to write logs to                                                 |
| `-n, --name, --script-name NAME`                | Set custom script name for log messages (overrides auto-detection)                  |
| `-q, --quiet`                                   | Disable console output                                                              |
| `-v, --verbose, --debug`                        | Set log level to DEBUG (most verbose)                                               |
| `-d, --level LEVEL`                             | Set log level (DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY or 0-7) |
| `-e, --stderr-level LEVEL`                      | Set minimum level for stderr output (default: ERROR)                                |
| `-f, --format FORMAT`                           | Set custom log format                                                               |
| `-u, --utc`                                     | Use UTC time instead of local time                                                  |
| `-j, --journal`                                 | Enable logging to systemd journal                                                   |
| `-t, --tag TAG`                                 | Set custom tag for journal logs (default: script name)                              |
| `--color, --colour`                             | Explicitly enable color output (default: auto-detect)                               |
| `--no-color, --no-colour`                       | Disable color output                                                                |
| `-U, --unsafe-allow-newlines`                   | Allow newlines in log messages (not recommended; disables sanitization)             |
| `-A, --unsafe-allow-ansi-codes`                 | Allow ANSI escape codes in log messages (not recommended; disables sanitization)    |
| `--max-line-length LENGTH`                      | Max message length before formatting for console/file output (0 = unlimited)        |
| `--max-journal-length LENGTH`                   | Max message length before formatting for journal output (0 = unlimited)             |

## Common Initialization Patterns

### Default Configuration

```bash
# Uses INFO level, console output with color auto-detection
init_logger
```

**Default behavior:**

* Log level: INFO
* Output: Console (stdout/stderr)
* Colors: Auto-detected (enabled for TTY)
* Format: `%d [%l] [%s] %m`
* Timezone: Local time

### File Logging

```bash
# Log to file with INFO level
init_logger --log "/var/log/myapp.log"

# Log to file with DEBUG level
init_logger --log "/var/log/myapp.log" --verbose

# Log to file only (no console output)
init_logger --log "/var/log/myapp.log" --quiet
```

### Verbose/Debug Mode

```bash
# Enable DEBUG level logging
init_logger --verbose

# Alternative syntax
init_logger --debug
init_logger --level DEBUG
```

### Journal Logging

```bash
# Enable systemd journal logging
init_logger --journal

# Journal with custom tag
init_logger --journal --tag "myapp"

# Journal and file logging
init_logger --journal --log "/var/log/myapp.log" --tag "myapp"
```

### Configuration File

```bash
# Load all settings from config file
init_logger --config /etc/myapp/logging.conf

# Config file with CLI overrides (CLI takes precedence)
init_logger --config logging.conf --level DEBUG

# Multiple overrides
init_logger --config logging.conf --level WARN --color --log /tmp/app.log
```

See [Configuration](configuration.md) for details on configuration files.

### Custom Format

```bash
# Custom format with all placeholders
init_logger --format "[%l] %d %z [%s] %m"

# Minimal format
init_logger --format "%l: %m"
```

See [Formatting](formatting.md) for format options.

### UTC Time

```bash
# Use UTC instead of local time
init_logger --utc

# UTC with custom format showing timezone
init_logger --utc --format "%d %z [%l] %m"
```

### Color Control

```bash
# Force colors on (even when not a TTY)
init_logger --color

# Disable colors
init_logger --no-color

# Auto-detect (default)
init_logger  # Colors enabled if stdout is a TTY
```

### Custom Script Name

By default, the logger auto-detects the calling script's name. This works well for most scenarios, but may return
"unknown" when called from shell RC files or other non-standard contexts. Use the `-n` option to set a custom name:

```bash
# Set a custom script name
init_logger --name "my-startup-script"

# Useful for shell RC files
init_logger --name "bashrc" --level INFO

# Alternative syntax
init_logger --script-name "my-app"
```

The script name appears in log messages where `%s` is used in the format string.

### Stderr Level Configuration

```bash
# Default: ERROR and above to stderr
init_logger

# Send WARN and above to stderr
init_logger --stderr-level WARN

# Send everything to stderr
init_logger --stderr-level DEBUG

# Only EMERGENCY to stderr
init_logger --stderr-level EMERGENCY
```

See [Output Streams](output-streams.md) for details.

## Combining Options

You can combine multiple options to create complex configurations:

### Development Setup

```bash
init_logger \
  --verbose \
  --color \
  --log "/tmp/dev.log" \
  --format "[%l] %d - %m"
```

### Production Setup

```bash
init_logger \
  --log "/var/log/myapp/app.log" \
  --journal \
  --tag "myapp" \
  --level INFO \
  --utc \
  --stderr-level WARN
```

### Testing/CI Setup

```bash
init_logger \
  --level DEBUG \
  --no-color \
  --stderr-level DEBUG
```

### CLI Tool Setup

```bash
# All logs to stderr, stdout free for program output
init_logger \
  --level INFO \
  --stderr-level DEBUG \
  --color
```

## Return Codes

The `init_logger` function returns:

* `0` - Successful initialization
* `1` - Error during initialization

### Error Handling

```bash
# Basic error handling
if ! init_logger --log "/var/log/myapp.log"; then
    echo "ERROR: Failed to initialize logger" >&2
    exit 1
fi

# Detailed error handling
if ! init_logger --log "/var/log/myapp.log" --journal --tag "myapp"; then
    echo "ERROR: Logger initialization failed" >&2
    echo "Check that:" >&2
    echo "  - Log directory exists and is writable" >&2
    echo "  - 'logger' command is available (for journal logging)" >&2
    exit 1
fi
```

### Common Initialization Errors

**Log file cannot be created:**

```bash
# Check directory exists and is writable
init_logger --log "/nonexistent/dir/app.log"  # Returns 1
```

**Invalid log level:**

```bash
# Valid: DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY, 0-7
init_logger --level INVALID  # Uses default (INFO)
```

## Initialization Best Practices

### 1. Initialize Early

Call `init_logger` immediately after sourcing the module:

```bash
#!/bin/bash
source /path/to/logging.sh
init_logger --log "/var/log/myapp.log"

# Now safe to use logging
log_info "Script started"
```

### 2. Check Return Code

Always check if initialization succeeded:

```bash
if ! init_logger --log "$LOG_FILE"; then
    echo "Failed to initialize logging" >&2
    exit 1
fi
```

### 3. Use Configuration Files for Complex Setups

Instead of long command lines, use config files:

```bash
# Clean and maintainable
init_logger --config /etc/myapp/logging.conf

# Instead of this
init_logger --log "/var/log/myapp.log" --journal --tag "myapp" \
  --level INFO --utc --format "%d %z [%l] %m" --stderr-level WARN
```

### 4. Allow Runtime Overrides

For scripts that use config files, allow CLI overrides:

```bash
#!/bin/bash
source /path/to/logging.sh

LOG_LEVEL="INFO"

# Parse arguments for log level override
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --debug) LOG_LEVEL="DEBUG"; shift ;;
        *) shift ;;
    esac
done

# Initialize with config file, override level if specified
init_logger --config /etc/myapp/logging.conf --level "$LOG_LEVEL"
```

### 5. Environment-Specific Configuration

Use different configurations for different environments:

```bash
#!/bin/bash
source /path/to/logging.sh

ENV="${APP_ENV:-production}"

case "$ENV" in
    development)
        init_logger --verbose --color
        ;;
    testing)
        init_logger --level DEBUG --no-color
        ;;
    production)
        init_logger --config /etc/myapp/logging.conf
        ;;
esac
```

## Examples by Use Case

### Simple Script

```bash
#!/bin/bash
source /path/to/logging.sh
init_logger
log_info "Hello, World!"
```

### Script with File Logging

```bash
#!/bin/bash
source /path/to/logging.sh
init_logger --log "/tmp/script.log" --level INFO
log_info "Logging to file"
```

### System Service

```bash
#!/bin/bash
source /path/to/logging.sh
init_logger --journal --tag "myservice" --level INFO --utc
log_info "Service started"
```

### Development Script

```bash
#!/bin/bash
source /path/to/logging.sh
init_logger --verbose --color --log "/tmp/debug.log"
log_debug "Debug information"
```

### Shell RC File

When sourcing the logger from shell RC files (`.bashrc`, `.zshrc`), auto-detection may fail. Use `--name` to set a
meaningful identifier:

```bash
# In ~/.bashrc or ~/.zshrc
source /path/to/logging.sh
init_logger --name "bashrc" --level INFO --log "$HOME/.local/log/shell.log"
log_info "Shell session started"
```

## Related Documentation

* [Configuration](configuration.md) - Using configuration files
* [Log Levels](log-levels.md) - Understanding log levels
* [Formatting](formatting.md) - Custom log formats
* [Output Streams](output-streams.md) - Stdout/stderr configuration
* [Journal Logging](journal-logging.md) - Systemd journal integration
* [Getting Started](getting-started.md) - Quick start guide
