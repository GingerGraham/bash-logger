# Configuration <!-- omit in toc -->

The Bash Logging Module supports loading configuration from INI-style files. This is useful for centralizing logging
configuration across multiple scripts, allowing users to customize logging without modifying scripts, and separating
configuration from code.

## Table of Contents <!-- omit in toc -->

* [Configuration File Format](#configuration-file-format)
* [Configuration Keys](#configuration-keys)
  * [Boolean Values](#boolean-values)
  * [Key Aliases](#key-aliases)
* [Using Configuration Files](#using-configuration-files)
  * [Basic Usage](#basic-usage)
  * [With CLI Overrides](#with-cli-overrides)
* [Configuration Precedence](#configuration-precedence)
  * [Example Precedence](#example-precedence)
* [Configuration Examples](#configuration-examples)
  * [Development Configuration](#development-configuration)
  * [Production Configuration](#production-configuration)
  * [Testing Configuration](#testing-configuration)
  * [Silent File-Only Logging](#silent-file-only-logging)
  * [Verbose Console-Only Logging](#verbose-console-only-logging)
* [User-Configurable Applications](#user-configurable-applications)
* [Environment-Specific Configuration](#environment-specific-configuration)
* [Dynamic Configuration Paths](#dynamic-configuration-paths)
  * [XDG Base Directory Specification](#xdg-base-directory-specification)
  * [Multiple Config Locations](#multiple-config-locations)
* [Example Configuration File](#example-configuration-file)
* [Configuration Best Practices](#configuration-best-practices)
  * [1. Provide Example Configuration](#1-provide-example-configuration)
  * [2. Use Comments Liberally](#2-use-comments-liberally)
  * [3. Separate Per-Environment Configs](#3-separate-per-environment-configs)
  * [4. Document Required vs Optional Settings](#4-document-required-vs-optional-settings)
  * [5. Version Configuration Files](#5-version-configuration-files)
* [Related Documentation](#related-documentation)

## Configuration File Format

Configuration files use the INI format with a `[logging]` section:

```ini
# logging.conf - Example configuration file
# Lines starting with # or ; are comments
# Blank lines are ignored

[logging]
# Log level: DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY
level = INFO

# Log message format
# Variables: %d=datetime, %z=timezone, %l=level, %s=script, %m=message
format = %d [%l] [%s] %m

# Log file path (leave empty to disable file logging)
log_file = /var/log/myapp.log

# Script name for log messages (overrides auto-detection)
# Useful when sourcing from shell RC files or for custom identifiers
# script_name = myapp

# Enable systemd journal logging: true/false
journal = false

# Journal/syslog tag (defaults to script name)
tag = myapp

# Use UTC timestamps: true/false
utc = false

# Color mode: auto, always, never
color = auto

# Minimum level for stderr output
stderr_level = ERROR

# Disable console output: true/false
quiet = false

# Enable debug logging: true/false
verbose = false

# Allow newlines in log messages: true/false
# Warning: true disables sanitization and can allow log injection
unsafe_allow_newlines = false
```

## Configuration Keys

| Key                     | Aliases                                     | Values                                                            | Default           | Description                              |
| ----------------------- | ------------------------------------------- | ----------------------------------------------------------------- | ----------------- | ---------------------------------------- |
| `level`                 | `log_level`                                 | DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY, 0-7 | `INFO`            | Minimum log level                        |
| `format`                | `log_format`                                | Format string                                                     | `%d [%l] [%s] %m` | Log message format                       |
| `log_file`              | `logfile`, `file`                           | Path                                                              | (none)            | Log file path                            |
| `script_name`           | `scriptname`, `name`                        | String                                                            | auto-detected     | Script name in log messages              |
| `journal`               | `use_journal`                               | true/false, yes/no, on/off, 1/0                                   | `true`            | Enable journal logging                   |
| `tag`                   | `journal_tag`                               | String                                                            | script name       | Journal/syslog tag                       |
| `utc`                   | `use_utc`                                   | true/false, yes/no, on/off, 1/0                                   | `false`           | Use UTC timestamps                       |
| `color`                 | `colour`, `colors`, `colours`, `use_colors` | auto, always, never                                               | `auto`            | Color mode                               |
| `stderr_level`          | `stderr-level`                              | Log level                                                         | `ERROR`           | Minimum level for stderr                 |
| `quiet`                 | -                                           | true/false, yes/no, on/off, 1/0                                   | `false`           | Disable console output                   |
| `console_log`           | -                                           | true/false, yes/no, on/off, 1/0                                   | `true`            | Enable console output (inverse of quiet) |
| `verbose`               | -                                           | true/false, yes/no, on/off, 1/0                                   | `false`           | Enable DEBUG level                       |
| `unsafe_allow_newlines` | `unsafe-allow-newlines`                     | true/false, yes/no, on/off, 1/0                                   | `false`           | Allow newlines in log messages (unsafe)  |

### Boolean Values

Boolean settings accept multiple formats:

* `true`, `yes`, `on`, `1` - Enable the option
* `false`, `no`, `off`, `0` - Disable the option

### Key Aliases

Many keys have aliases for flexibility:

```ini
# All of these are equivalent
log_file = /var/log/app.log
logfile = /var/log/app.log
file = /var/log/app.log

# All of these are equivalent
journal = true
use_journal = yes

# All of these are equivalent
color = auto
colour = auto
colors = auto
use_colors = auto
```

## Using Configuration Files

### Basic Usage

```bash
#!/bin/bash
source /path/to/logging.sh

# Load configuration from file
init_logger --config /etc/myapp/logging.conf

log_info "Logging configured from file"
```

### With CLI Overrides

CLI arguments take precedence over configuration file values:

```bash
# Load config but override log level
init_logger --config logging.conf --level DEBUG

# Multiple overrides
init_logger --config logging.conf --level WARN --color --log /tmp/app.log
```

## Configuration Precedence

When using both a configuration file and CLI arguments, settings are applied in this order:

1. **Default values** - Built-in defaults
2. **Configuration file** - Values from the config file override defaults
3. **CLI arguments** - Command-line arguments override everything

### Example Precedence

```ini
# logging.conf
[logging]
level = INFO
color = never
log_file = /var/log/app.log
```

```bash
# Config says INFO, CLI says DEBUG -> DEBUG wins
# Config says never, CLI says --color -> color wins
# Config says /var/log/app.log, no CLI override -> /var/log/app.log used
init_logger --config logging.conf --level DEBUG --color
```

**Result:**

* Level: DEBUG (from CLI)
* Color: always (from CLI)
* Log file: /var/log/app.log (from config)

## Configuration Examples

### Development Configuration

```ini
# dev-logging.conf
[logging]
level = DEBUG
verbose = true
color = always
format = [%l] %d - %m
log_file = /tmp/dev.log
stderr_level = DEBUG
```

### Production Configuration

```ini
# prod-logging.conf
[logging]
level = INFO
color = auto
format = %d %z [%l] [%s] %m
log_file = /var/log/myapp/app.log
journal = true
tag = myapp
utc = true
stderr_level = WARN
quiet = false
```

### Testing Configuration

```ini
# test-logging.conf
[logging]
level = DEBUG
color = never
format = [%l] %m
log_file = /tmp/test.log
stderr_level = DEBUG
quiet = false
```

### Silent File-Only Logging

```ini
# silent-logging.conf
[logging]
level = INFO
log_file = /var/log/myapp.log
quiet = true
journal = false
```

### Verbose Console-Only Logging

```ini
# console-logging.conf
[logging]
level = DEBUG
verbose = true
color = always
quiet = false
# log_file is not set - no file logging
journal = false
```

## User-Configurable Applications

Allow users to customize logging without modifying your script:

```bash
#!/bin/bash
source /path/to/logging.sh

# Default config location
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/myapp/logging.conf"

# Allow user to specify different config
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --log-config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --debug)
            DEBUG_MODE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Initialize logger
if [[ -f "$CONFIG_FILE" ]]; then
    # Use config file with optional debug override
    if [[ "$DEBUG_MODE" == "true" ]]; then
        init_logger --config "$CONFIG_FILE" --level DEBUG
    else
        init_logger --config "$CONFIG_FILE"
    fi
else
    # Fall back to defaults
    init_logger --level INFO
fi

log_info "Application started"
```

## Environment-Specific Configuration

Use different configurations for different environments:

```bash
#!/bin/bash
source /path/to/logging.sh

# Determine environment
ENV="${APP_ENV:-production}"
CONFIG_DIR="/etc/myapp"

# Select appropriate config file
case "$ENV" in
    development)
        CONFIG_FILE="$CONFIG_DIR/logging-dev.conf"
        ;;
    testing)
        CONFIG_FILE="$CONFIG_DIR/logging-test.conf"
        ;;
    staging)
        CONFIG_FILE="$CONFIG_DIR/logging-staging.conf"
        ;;
    production)
        CONFIG_FILE="$CONFIG_DIR/logging-prod.conf"
        ;;
    *)
        echo "Unknown environment: $ENV" >&2
        exit 1
        ;;
esac

# Initialize with environment-specific config
if [[ -f "$CONFIG_FILE" ]]; then
    init_logger --config "$CONFIG_FILE"
else
    echo "Configuration file not found: $CONFIG_FILE" >&2
    exit 1
fi

log_info "Application started in $ENV environment"
```

## Dynamic Configuration Paths

### XDG Base Directory Specification

```bash
#!/bin/bash
source /path/to/logging.sh

# Follow XDG Base Directory specification
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIG_FILE="$CONFIG_HOME/myapp/logging.conf"

# Create config directory if needed
mkdir -p "$(dirname "$CONFIG_FILE")"

# Use config if it exists, otherwise use defaults
if [[ -f "$CONFIG_FILE" ]]; then
    init_logger --config "$CONFIG_FILE"
else
    # First run - create default config
    cat > "$CONFIG_FILE" << 'EOF'
[logging]
level = INFO
color = auto
format = %d [%l] [%s] %m
EOF
    init_logger --config "$CONFIG_FILE"
fi
```

### Multiple Config Locations

Search for config files in multiple locations:

```bash
#!/bin/bash
source /path/to/logging.sh

# Search locations in order of preference
CONFIG_LOCATIONS=(
    "$HOME/.config/myapp/logging.conf"
    "$HOME/.myapp/logging.conf"
    "/etc/myapp/logging.conf"
)

CONFIG_FILE=""
for location in "${CONFIG_LOCATIONS[@]}"; do
    if [[ -f "$location" ]]; then
        CONFIG_FILE="$location"
        break
    fi
done

if [[ -n "$CONFIG_FILE" ]]; then
    init_logger --config "$CONFIG_FILE"
    log_info "Using config: $CONFIG_FILE"
else
    init_logger --level INFO
    log_info "Using default configuration"
fi
```

## Example Configuration File

An example configuration file (`logging.conf.example`) is included with the module:

```bash
# Copy and customize the example
cp logging.conf.example /etc/myapp/logging.conf

# Edit for your needs
vim /etc/myapp/logging.conf
```

## Configuration Best Practices

### 1. Provide Example Configuration

Include a `logging.conf.example` file with your project:

```ini
# logging.conf.example
# Copy this file and customize for your environment
# cp logging.conf.example logging.conf

[logging]
# Log level (DEBUG, INFO, WARN, ERROR, etc.)
level = INFO

# Log file location (leave empty to disable file logging)
log_file = /var/log/myapp/app.log

# Use color output (auto, always, never)
color = auto

# Enable journal logging (true/false)
journal = false
```

### 2. Use Comments Liberally

Help users understand options:

```ini
[logging]
# Log level controls verbosity
# DEBUG: Most verbose, all messages
# INFO: Normal operation messages
# WARN: Warnings and errors only
# ERROR: Errors only
level = INFO
```

### 3. Separate Per-Environment Configs

Maintain separate files for each environment:

```text
/etc/myapp/
├── logging-dev.conf
├── logging-test.conf
├── logging-staging.conf
└── logging-prod.conf
```

### 4. Document Required vs Optional Settings

```ini
[logging]
# REQUIRED: Log level
level = INFO

# OPTIONAL: Log file (comment out to disable file logging)
# log_file = /var/log/myapp.log

# OPTIONAL: Journal logging (requires 'logger' command)
# journal = true
```

### 5. Version Configuration Files

Track configuration changes:

```ini
# logging.conf
# Version: 2.1.0
# Last updated: 2026-01-15

[logging]
level = INFO
```

## Related Documentation

* [Initialization](initialization.md) - Using `init_logger` with config files
* [Formatting](formatting.md) - Format string options
* [Output Streams](output-streams.md) - Stderr level configuration
* [Journal Logging](journal-logging.md) - Journal configuration options
* [Examples](examples.md) - Complete configuration examples
