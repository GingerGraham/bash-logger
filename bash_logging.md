# Bash Logging Module

A flexible, reusable logging module for Bash scripts that provides standardized logging functionality with various configuration options.

## Features

- Standard syslog log levels (DEBUG, INFO, WARN, ERROR, CRITICAL, etc.)
- Console output with color-coding by severity
- Configurable stdout/stderr output stream split
- Optional file output
- Optional systemd journal logging
- Customizable log format
- UTC or local time support
- Runtime configuration changes
- Special handling for sensitive data

## Installation

Simply place the `logging.sh` file in a directory of your choice.

## Basic Usage

```bash
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

## Initialization Options

The `init_logger` function accepts the following options:

| Option | Description |
|--------|-------------|
| `-l, --log, --logfile, --log-file, --file FILE` | Specify a log file to write logs to |
| `-q, --quiet` | Disable console output |
| `-v, --verbose, --debug` | Set log level to DEBUG (most verbose) |
| `-d, --level LEVEL` | Set log level (DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY or 0-7) |
| `-e, --stderr-level LEVEL` | Set minimum level for stderr output (default: ERROR). Messages at this level and above go to stderr, below go to stdout |
| `-f, --format FORMAT` | Set custom log format |
| `-u, --utc` | Use UTC time instead of local time |
| `-j, --journal` | Enable logging to systemd journal |
| `-t, --tag TAG` | Set custom tag for journal logs (default: script name) |
| `--color --colour` | Explicitly enable color output (default: auto-detect) |
| `--no-color --no-colour` | Disable color output | 

Example:

```bash
# Initialize logger with file output, journal logging, and DEBUG level
init_logger --log "/var/log/myscript.log" --level DEBUG --journal --tag "myapp"
```

## Log Levels

The module supports standard syslog levels, from most to least severe:

| Level | Numeric Value | Function | Syslog Priority |
|-------|---------------|----------|----------------|
| EMERGENCY | 0 | `log_emergency` | emerg |
| ALERT | 1 | `log_alert` | alert |
| CRITICAL | 2 | `log_critical` | crit |
| ERROR | 3 | `log_error` | err |
| WARN | 4 | `log_warn` | warning |
| NOTICE | 5 | `log_notice` | notice |
| INFO | 6 | `log_info` | info |
| DEBUG | 7 | `log_debug` | debug |
| SENSITIVE | - | `log_sensitive` | (not sent to syslog) |

Messages with a level lower than the current log level are suppressed.

Sensitive messages are logged at the INFO level but are not written to log files or the journal. They are only displayed on the console.

## Custom Log Format

You can customize the log format using special placeholders:

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `%d` | Date and time | `2025-03-03 12:34:56` |
| `%l` | Log level | `INFO` |
| `%s` | Script name | `myscript.sh` |
| `%m` | Log message | `Operation completed successfully` |
| `%z` | Timezone | `UTC` or `LOCAL` |

The default format is: `%d [%l] [%s] %m`

Example of custom format:

```bash
init_logger --format "[%l] %d %z [%s] %m"
```

## Output Stream Configuration

By default, the logging module splits console output between stdout and stderr based on severity:

- **stdout**: DEBUG, INFO, NOTICE, WARN (normal operation messages)
- **stderr**: ERROR, CRITICAL, ALERT, EMERGENCY (error messages)

This follows the Unix convention where stdout contains normal output that can be piped or captured, while stderr contains error output that should be visible even when stdout is redirected.

### Configuring the Stderr Threshold

You can change which log levels go to stderr using the `--stderr-level` option:

```bash
# Default behavior: ERROR and above to stderr
init_logger

# Send WARN and above to stderr
init_logger --stderr-level WARN

# Send everything to stderr (useful for scripts where all output is diagnostic)
init_logger --stderr-level DEBUG

# Send only EMERGENCY to stderr (almost everything to stdout)
init_logger --stderr-level EMERGENCY
```

### Practical Use Cases

**Separating normal output from errors:**

```bash
# Run script, capturing normal logs to file while errors show on screen
./myscript.sh > output.log
```

**Suppressing errors while keeping normal output:**

```bash
# Run script, showing only normal operation (hide errors)
./myscript.sh 2>/dev/null
```

**Capturing only errors:**

```bash
# Run script, capturing only error messages
./myscript.sh 2> errors.log 1>/dev/null
```

**Sending all output to stderr (common for CLI tools):**

```bash
init_logger --stderr-level DEBUG
# Now all log messages go to stderr, leaving stdout free for program output
```

## Runtime Configuration

You can change configuration at runtime using these functions:

```bash
# Change log level
set_log_level DEBUG      # Set to DEBUG level
set_log_level NOTICE     # Set to NOTICE level
set_log_level WARN       # Set to WARN level
set_log_level CRITICAL   # Set to CRITICAL level

# Change timezone setting
set_timezone_utc true   # Use UTC time
set_timezone_utc false  # Use local time

# Change log format
set_log_format "[%l] %d [%s] - %m"

# Enable/disable journal logging
set_journal_logging true   # Enable journal logging
set_journal_logging false  # Disable journal logging

# Change journal tag
set_journal_tag "new-tag"  # Set new tag for journal logs
```

## Journal Logging

The module can log to the systemd journal using the `logger` command. This is particularly useful for applications running as systemd services or on systems like Fedora Linux.

### Requirements

- The `logger` command must be installed (typically part of the `util-linux` package)
- The system should use systemd (standard on most modern Linux distributions)

### Configuration

Enable journal logging with the `-j` or `--journal` flag during initialization:

```bash
init_logger --journal
```

You can specify a custom tag with `-t` or `--tag`:

```bash
init_logger --journal --tag "myapp"
```

If no tag is specified, the script name is used as the default tag.

### Viewing Journal Logs

Journal logs can be viewed using the `journalctl` command:

```bash
# View logs with specific tag
journalctl -t myapp

# Follow logs in real-time
journalctl -f -t myapp

# View logs for the current boot
journalctl -b -t myapp
```

### Log Level Mapping

Log levels are mapped to syslog priorities as follows:

| Log Level | Syslog Priority |
|-----------|----------------|
| DEBUG | debug |
| INFO | info |
| NOTICE | notice |
| WARN | warning |
| ERROR | err |
| CRITICAL | crit |
| ALERT | alert |
| EMERGENCY | emerg |

## Example Use Cases

### Basic Script Logging

```bash
#!/bin/bash

# Source the logging module
source /path/to/logging.sh

# Initialize with default settings
init_logger

log_info "Script starting"
log_debug "Debug information" 
# ... script operations ...
log_warn "Warning: resource usage high"
log_info "Script completed"
```

### Logging to File with Verbose Output

```bash
#!/bin/bash

# Source the logging module
source /path/to/logging.sh

# Initialize with file output and verbose mode
init_logger --log "/tmp/myapp.log" --verbose

log_info "Application starting"
log_debug "Configuration loaded" # This will be logged due to verbose mode
# ... application operations ...
log_info "Application completed"
```

### Logging to System Journal (for systemd-based systems)

```bash
#!/bin/bash

# Source the logging module
source /path/to/logging.sh

# Initialize with journal logging
init_logger --journal --tag "myservice"

log_info "Service starting"
# ... service operations ...
log_error "Error encountered: $error_message"
log_info "Service completed"
```

### Comprehensive Logging Configuration

```bash
#!/bin/bash

# Source the logging module
source /path/to/logging.sh

# Initialize with multiple outputs and custom format
init_logger \
  --log "/var/log/myapp.log" \
  --journal \
  --tag "myapp" \
  --format "%d %z [%l] [%s] %m" \
  --utc \
  --level INFO

log_info "Application initialized with comprehensive logging"
```

### CLI Tool with Separate Output Streams

When building a CLI tool that produces both program output and diagnostic logs, you can send all logs to stderr to keep stdout clean for the actual output:

```bash
#!/bin/bash

source /path/to/logging.sh

# Send all log messages to stderr, keeping stdout for program output
init_logger --stderr-level DEBUG --level INFO

log_info "Processing input..."

# Program output goes to stdout (can be piped)
echo "result1"
echo "result2"

log_info "Processing complete"

# Usage: ./mytool.sh > results.txt
# Log messages appear on screen, results go to file
```

### Script with Configurable Error Verbosity

```bash
#!/bin/bash

source /path/to/logging.sh

# Default: only errors to stderr
STDERR_LEVEL="ERROR"

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --warnings-to-stderr)
      STDERR_LEVEL="WARN"
      shift
      ;;
    --all-to-stderr)
      STDERR_LEVEL="DEBUG"
      shift
      ;;
  esac
done

init_logger --stderr-level "$STDERR_LEVEL" --level DEBUG

log_debug "Debug info"
log_info "Starting operation"
log_warn "Warning: disk space low"
log_error "Error: file not found"
```

### Changing Log Level Based on Command-line Arguments

```bash
#!/bin/bash

# Source the logging module
source /path/to/logging.sh

# Basic initialization
init_logger

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --debug)
      set_log_level DEBUG
      shift
      ;;
    # Other arguments...
  esac
done

log_debug "Debug mode enabled"  # Only shows if --debug was passed
log_info "Normal operation"
```

**Note:** For clarity, the logger provides in `logging.sh` enables `DEBUG` logging through the `--verbose` option when called using `init_logger --verbose` however the provided `set_log_level` function accepts log levels based on their common names (DEBUG, INFO, WARN, ERROR, FATAL) or their numeric values (0, 1, 2, 3, 4). The example above uses a command line parser in the calling script to optionally enable `DEBUG` logging by accepting a local argument `--debug` and then using the `set_log_level` function to enable `DEBUG` logging.

### Advanced Usage with Custom Format and UTC Time

```bash
#!/bin/bash

# Source the logging module
source /path/to/logging.sh

# Initialize with custom format and UTC time
init_logger --format "%d %z [%l] [%s] %m" --utc

log_info "Starting processing job"

# Later, change format for a specific part of the script
set_log_format "[%l] %m"
log_info "Using simplified format"

# Return to original format
set_log_format "%d %z [%l] [%s] %m"
log_info "Back to detailed format"
```

### Logging in Functions

```bash
#!/bin/bash

source /path/to/logging.sh
init_logger --log "/var/log/myapp.log"

function process_item() {
  local item=$1
  log_debug "Processing item: $item"
  
  # Processing logic...
  if [[ "$item" == "important" ]]; then
    log_info "Found important item"
  fi
  
  # Error handling
  if [[ "$?" -ne 0 ]]; then
    log_error "Failed to process item: $item"
    return 1
  fi
  
  log_debug "Completed processing item: $item"
  return 0
}

log_info "Starting batch processing"
process_item "test"
process_item "important"
log_info "Batch processing complete"
```

## Sensitive Data

For sensitive data that should never be written to log files or the journal, use the `log_sensitive` function:

```bash
#!/bin/bash

source /path/to/logging.sh

init_logger --log "/var/log/myapp.log" --journal --tag "myapp"

# This will ONLY appear in the console, not in log files or journal
log_sensitive "Sensitive data: $SECRET"
```

The `log_sensitive` function will only output to the console and never to log files or the system journal. It is your responsibility to ensure that your console session is not being recorded or that any console logging is not accessible to unauthorized users.

## Exit Codes

The `init_logger` function returns:
- `0` on successful initialization
- `1` on error (e.g., unable to create log file)

## Troubleshooting

If you encounter issues:

1. Ensure that `logging.sh` is sourced using the correct path
2. Check write permissions if using file logging
3. Verify log directory exists or can be created
4. Ensure you're using valid log level names
5. For journal logging, verify the `logger` command is available
6. Check systemd journal logs with `journalctl -f` to see if logs are being received

## License

This module is provided under the MIT License.