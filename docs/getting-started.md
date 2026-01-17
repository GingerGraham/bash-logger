# Getting Started <!-- omit in toc -->

This guide will help you get started with the Bash Logging Module quickly.

## Table of Contents <!-- omit in toc -->

* [Workflows](#workflows)
  * [Linting Workflows](#linting-workflows)
* [Installation](#installation)
  * [Common Installation Locations](#common-installation-locations)
  * [Example Installation](#example-installation)
* [Basic Usage](#basic-usage)
* [Your First Script](#your-first-script)
* [Common Options](#common-options)
  * [Enable Verbose Output](#enable-verbose-output)
  * [Log to a File](#log-to-a-file)
  * [Quiet Mode](#quiet-mode)
  * [Custom Log Level](#custom-log-level)
* [Quick Reference](#quick-reference)
  * [Logging Functions](#logging-functions)
  * [Common Initialization Patterns](#common-initialization-patterns)
* [Exit Codes](#exit-codes)
* [Next Steps](#next-steps)

## Workflows

The repository includes GitHub Actions workflows to ensure code quality and consistency.

### Linting Workflows

* **Lint Bash Scripts**: Applies ShellCheck linting for all bash scripts in pull requests destined for the main branch.
* **Lint Markdown Files**: Applies MarkdownLint for all markdown files in pull requests destined for the main branch.
* [Next Steps](#next-steps)

## Installation

Simply place the `logging.sh` file in a directory of your choice. The module is a single, self-contained script that can
be sourced from any location.

### Common Installation Locations

* `/usr/local/lib/logging.sh` - System-wide installation
* `$HOME/.local/lib/logging.sh` - User-specific installation
* Project directory - Alongside your script

### Example Installation

```bash
# System-wide (requires sudo)
sudo curl -o /usr/local/lib/logging.sh https://raw.githubusercontent.com/GingerGraham/bash-logger/main/logging.sh
sudo chmod +x /usr/local/lib/logging.sh

# User-specific
mkdir -p ~/.local/lib
curl -o ~/.local/lib/logging.sh https://raw.githubusercontent.com/GingerGraham/bash-logger/main/logging.sh
chmod +x ~/.local/lib/logging.sh

# Project directory
curl -o ./logging.sh https://raw.githubusercontent.com/GingerGraham/bash-logger/main/logging.sh
chmod +x ./logging.sh
```

## Basic Usage

The simplest way to use the logging module:

```bash
#!/bin/bash

# Source the logging module
source /path/to/logging.sh

# Initialize the logger with defaults
init_logger

# Log messages at different levels
log_debug "This is a debug message"
log_info "This is an info message"
log_warn "This is a warning message"
log_error "This is an error message"
log_fatal "This is a fatal error message"
```

## Your First Script

Create a file called `hello_logging.sh`:

```bash
#!/bin/bash

# Source the logging module
source ./logging.sh

# Initialize with default settings
init_logger

# Log some messages
log_info "Hello, logging!"
log_info "The current date is: $(date)"
log_debug "This debug message won't appear (log level is INFO by default)"

# Enable verbose mode to see debug messages
log_info "Enabling debug mode..."
set_log_level DEBUG

log_debug "Now you can see debug messages!"
log_info "Script completed successfully"
```

Run it:

```bash
chmod +x hello_logging.sh
./hello_logging.sh
```

## Common Options

### Enable Verbose Output

```bash
# Show all messages including debug
init_logger --verbose
```

### Log to a File

```bash
# Log to file in addition to console
init_logger --log "/tmp/myapp.log"
```

### Quiet Mode

```bash
# Only log to file, no console output
init_logger --log "/var/log/myapp.log" --quiet
```

### Custom Log Level

```bash
# Set specific log level
init_logger --level WARN  # Only show WARN and above
```

## Quick Reference

### Logging Functions

| Function        | Level     | Default Visibility   | When to Use                      |
| --------------- | --------- | -------------------- | -------------------------------- |
| `log_debug`     | DEBUG     | Hidden               | Detailed debugging information   |
| `log_info`      | INFO      | Shown                | General informational messages   |
| `log_notice`    | NOTICE    | Shown                | Normal but significant events    |
| `log_warn`      | WARN      | Shown                | Warning messages                 |
| `log_error`     | ERROR     | Shown                | Error conditions                 |
| `log_critical`  | CRITICAL  | Shown                | Critical conditions              |
| `log_alert`     | ALERT     | Shown                | Action must be taken immediately |
| `log_emergency` | EMERGENCY | Shown                | System is unusable               |
| `log_sensitive` | -         | Shown (console only) | Sensitive data (console only)    |

### Common Initialization Patterns

```bash
# Default behavior
init_logger

# Development/debugging
init_logger --verbose --color

# Production with file logging
init_logger --log "/var/log/myapp.log" --level INFO

# System service with journal
init_logger --journal --tag "myapp" --level INFO

# Configuration file
init_logger --config /etc/myapp/logging.conf
```

## Exit Codes

The `init_logger` function returns:

* `0` - Successful initialization
* `1` - Error (e.g., unable to create log file)

Example error handling:

```bash
if ! init_logger --log "/var/log/myapp.log"; then
    echo "Failed to initialize logger" >&2
    exit 1
fi
```

## Next Steps

* [Log Levels](log-levels.md) - Learn about all available log levels
* [Initialization](initialization.md) - Explore all initialization options
* [Configuration](configuration.md) - Use configuration files for complex setups
* [Examples](examples.md) - See comprehensive usage examples
