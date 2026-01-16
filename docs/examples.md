# Examples <!-- omit in toc -->

This document provides comprehensive examples demonstrating various use cases for the Bash Logging Module.

## Table of Contents <!-- omit in toc -->

- [Basic Examples](#basic-examples)
  - [Simple Script Logging](#simple-script-logging)
  - [Logging to File with Verbose Output](#logging-to-file-with-verbose-output)
  - [Comprehensive Logging Configuration](#comprehensive-logging-configuration)
- [Configuration File Examples](#configuration-file-examples)
  - [Using a Configuration File](#using-a-configuration-file)
  - [Environment-Specific Configuration](#environment-specific-configuration)
- [CLI Tool Examples](#cli-tool-examples)
  - [CLI Tool with Separate Output Streams](#cli-tool-with-separate-output-streams)
  - [Script with Configurable Error Verbosity](#script-with-configurable-error-verbosity)
- [Dynamic Configuration Examples](#dynamic-configuration-examples)
  - [Changing Log Level Based on Command-line Arguments](#changing-log-level-based-on-command-line-arguments)
  - [Advanced Usage with Custom Format and UTC Time](#advanced-usage-with-custom-format-and-utc-time)
- [Function-Based Examples](#function-based-examples)
  - [Logging in Functions](#logging-in-functions)
  - [Error Recovery with Debug Mode](#error-recovery-with-debug-mode)
- [System Service Examples](#system-service-examples)
  - [Logging to System Journal (for systemd-based systems)](#logging-to-system-journal-for-systemd-based-systems)
  - [Systemd Service with Combined Logging](#systemd-service-with-combined-logging)
- [Cron Job Examples](#cron-job-examples)
  - [Cron Job with Error-Only Output](#cron-job-with-error-only-output)
- [Data Processing Examples](#data-processing-examples)
  - [Data Pipeline with Stream Separation](#data-pipeline-with-stream-separation)
  - [Batch Processing with Progress Logging](#batch-processing-with-progress-logging)
- [Security Examples](#security-examples)
  - [Handling Sensitive Data](#handling-sensitive-data)
  - [Secure Configuration Loading](#secure-configuration-loading)
- [Testing Examples](#testing-examples)
  - [Test Script with Verbose Output](#test-script-with-verbose-output)
- [Multi-Environment Examples](#multi-environment-examples)
  - [Environment-Aware Script](#environment-aware-script)
- [Complex Integration Example](#complex-integration-example)
  - [Full-Featured Application](#full-featured-application)
- [Related Documentation](#related-documentation)

## Basic Examples

### Simple Script Logging

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
log_debug "Configuration loaded"  # This will be logged due to verbose mode
# ... application operations ...
log_info "Application completed"
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

## Configuration File Examples

### Using a Configuration File

```bash
#!/bin/bash

# Source the logging module
source /path/to/logging.sh

# Initialize from configuration file
# All settings are defined in the INI file
init_logger --config /etc/myapp/logging.conf

log_info "Application started with config file settings"

# You can still override specific settings via CLI
# init_logger --config /etc/myapp/logging.conf --level DEBUG
```

Example configuration file (`/etc/myapp/logging.conf`):

```ini
[logging]
level = INFO
format = %d %z [%l] [%s] %m
log_file = /var/log/myapp/app.log
journal = true
tag = myapp
utc = true
color = auto
stderr_level = ERROR
```

### Environment-Specific Configuration

```bash
#!/bin/bash
source /path/to/logging.sh

# Determine environment
ENV="${APP_ENV:-production}"

# Select appropriate config file
case "$ENV" in
    development)
        init_logger --config /etc/myapp/logging-dev.conf
        ;;
    testing)
        init_logger --config /etc/myapp/logging-test.conf
        ;;
    production)
        init_logger --config /etc/myapp/logging-prod.conf
        ;;
esac

log_info "Running in $ENV environment"
```

## CLI Tool Examples

### CLI Tool with Separate Output Streams

When building a CLI tool that produces both program output and diagnostic logs, send all logs to stderr to keep stdout clean:

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
    *)
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

## Dynamic Configuration Examples

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
    --quiet)
      set_log_level ERROR
      shift
      ;;
    *)
      shift
      ;;
  esac
done

log_debug "Debug mode enabled"  # Only shows if --debug was passed
log_info "Normal operation"
```

**Note:** The logger provides `--verbose` option when called using `init_logger --verbose`, but the provided
`set_log_level` function accepts log levels based on their common names (DEBUG, INFO, WARN, ERROR) or their numeric
values (0-7). The example above uses a command line parser in the calling script to optionally enable DEBUG logging by
accepting a local argument `--debug` and then using the `set_log_level` function.

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

## Function-Based Examples

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

### Error Recovery with Debug Mode

```bash
#!/bin/bash

source /path/to/logging.sh
init_logger --level INFO

function process_with_retry() {
  local item=$1

  log_info "Processing $item"

  if ! perform_operation "$item"; then
    log_error "Operation failed, enabling debug and retrying"
    set_log_level DEBUG

    if ! perform_operation "$item"; then
      log_error "Retry also failed"
      set_log_level INFO
      return 1
    fi

    log_info "Retry succeeded"
    set_log_level INFO
  fi

  return 0
}

for item in "${items[@]}"; do
  process_with_retry "$item"
done
```

## System Service Examples

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

View with:

```bash
journalctl -t myservice -f
```

### Systemd Service with Combined Logging

```bash
#!/bin/bash
# /usr/local/bin/myservice.sh

source /usr/local/lib/logging.sh

# Log to both journal and file
init_logger \
  --journal --tag "myservice" \
  --log "/var/log/myservice/service.log" \
  --level INFO \
  --utc

log_info "Service started"

# Main service loop
while true; do
  log_debug "Checking status"

  if ! check_health; then
    log_error "Health check failed"
  fi

  sleep 60
done
```

Systemd unit file (`/etc/systemd/system/myservice.service`):

```ini
[Unit]
Description=My Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/myservice.sh
Restart=always
User=myservice
Group=myservice

[Install]
WantedBy=multi-user.target
```

## Cron Job Examples

### Cron Job with Error-Only Output

```bash
#!/bin/bash

source /path/to/logging.sh

# Log everything to file, but only errors to stderr (cron emails stderr)
init_logger \
  --log "/var/log/backup/backup.log" \
  --level INFO \
  --stderr-level ERROR

log_info "Backup job started"

if backup_database; then
  log_info "Database backup successful"
else
  log_error "Database backup failed"  # This will trigger cron email
fi

log_info "Backup job completed"
```

Crontab entry:

```cron
0 2 * * * /usr/local/bin/backup-script.sh
```

## Data Processing Examples

### Data Pipeline with Stream Separation

```bash
#!/bin/bash

source /path/to/logging.sh

# Send all logs to stderr so data can be piped
init_logger --stderr-level DEBUG --level INFO

log_info "Starting data processing"

# Read input, process, output to stdout
while IFS= read -r line; do
  log_debug "Processing line: $line"

  # Process data
  result=$(process_data "$line")

  # Output result to stdout (pipeable)
  echo "$result"
done

log_info "Processing complete"
```

Usage:

```bash
# Pipe data through processor
cat input.txt | ./process.sh | ./next-stage.sh
```

### Batch Processing with Progress Logging

```bash
#!/bin/bash

source /path/to/logging.sh
init_logger --log "/var/log/batch.log" --level INFO

FILES=(/data/*.csv)
TOTAL=${#FILES[@]}
CURRENT=0

log_info "Starting batch processing of $TOTAL files"

for file in "${FILES[@]}"; do
  ((CURRENT++))
  PERCENT=$((CURRENT * 100 / TOTAL))

  log_info "Processing [$CURRENT/$TOTAL - ${PERCENT}%]: $file"

  if process_file "$file"; then
    log_debug "Successfully processed $file"
  else
    log_error "Failed to process $file"
  fi
done

log_info "Batch processing complete: $CURRENT files processed"
```

## Security Examples

### Handling Sensitive Data

```bash
#!/bin/bash

source /path/to/logging.sh

init_logger --log "/var/log/myapp.log" --journal --tag "myapp"

# Regular logs go to file and journal
log_info "User authentication started"

# Sensitive data only appears on console (not in file or journal)
log_sensitive "Authenticating with token: $AUTH_TOKEN"

# Continue with regular logging
log_info "Authentication successful"
```

### Secure Configuration Loading

```bash
#!/bin/bash

source /path/to/logging.sh
init_logger --log "/var/log/app.log"

log_info "Loading configuration"

# Load config file
if [[ -f "/etc/myapp/config" ]]; then
  source "/etc/myapp/config"
  log_info "Configuration loaded from /etc/myapp/config"

  # Don't log actual values
  log_sensitive "Database password: $DB_PASSWORD"
  log_sensitive "API key: $API_KEY"
else
  log_error "Configuration file not found"
  exit 1
fi

log_info "Application configured successfully"
```

## Testing Examples

### Test Script with Verbose Output

```bash
#!/bin/bash

source /path/to/logging.sh

# Verbose, no colors (for CI/CD)
init_logger --verbose --no-color

log_info "Starting test suite"

run_test() {
  local test_name=$1
  log_debug "Running test: $test_name"

  if $test_name; then
    log_info "✓ $test_name passed"
    return 0
  else
    log_error "✗ $test_name failed"
    return 1
  fi
}

FAILURES=0

run_test "test_database_connection" || ((FAILURES++))
run_test "test_api_endpoint" || ((FAILURES++))
run_test "test_data_validation" || ((FAILURES++))

if [[ $FAILURES -eq 0 ]]; then
  log_info "All tests passed"
  exit 0
else
  log_error "$FAILURES tests failed"
  exit 1
fi
```

## Multi-Environment Examples

### Environment-Aware Script

```bash
#!/bin/bash

source /path/to/logging.sh

ENV="${ENVIRONMENT:-development}"

case "$ENV" in
  development)
    init_logger --verbose --color --format "[%l] %m"
    ;;
  testing)
    init_logger --level INFO --no-color --log "/tmp/test.log"
    ;;
  staging)
    init_logger \
      --level INFO \
      --log "/var/log/app/staging.log" \
      --journal --tag "app-staging" \
      --utc
    ;;
  production)
    init_logger \
      --level WARN \
      --log "/var/log/app/production.log" \
      --journal --tag "app-prod" \
      --utc \
      --format "%d %z [%l] [%s] %m"
    ;;
esac

log_info "Application started in $ENV environment"
```

## Complex Integration Example

### Full-Featured Application

```bash
#!/bin/bash

# Application: data-processor
# Purpose: Process data files with comprehensive logging

source /usr/local/lib/logging.sh

# Configuration
APP_NAME="data-processor"
ENV="${APP_ENV:-production}"
CONFIG_DIR="/etc/${APP_NAME}"

# Initialize logging based on environment
setup_logging() {
  case "$ENV" in
    development)
      init_logger \
        --level DEBUG \
        --color \
        --format "[%l] %m"
      ;;
    production)
      init_logger \
        --config "${CONFIG_DIR}/logging.conf" \
        --tag "$APP_NAME"
      ;;
  esac

  if [[ $? -ne 0 ]]; then
    echo "ERROR: Failed to initialize logging" >&2
    exit 1
  fi
}

# Parse command-line arguments
parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      --debug)
        set_log_level DEBUG
        log_info "Debug mode enabled via command line"
        shift
        ;;
      --input)
        INPUT_FILE="$2"
        shift 2
        ;;
      --output)
        OUTPUT_FILE="$2"
        shift 2
        ;;
      *)
        log_error "Unknown argument: $1"
        exit 1
        ;;
    esac
  done
}

# Main processing function
process_data() {
  local input=$1
  local output=$2

  log_info "Processing data: $input -> $output"
  log_debug "Input file size: $(stat -f%z "$input" 2>/dev/null || stat -c%s "$input") bytes"

  local line_count=0
  while IFS= read -r line; do
    ((line_count++))

    if [[ $((line_count % 1000)) -eq 0 ]]; then
      log_info "Processed $line_count lines"
    fi

    # Process line
    log_debug "Processing line $line_count: $line"

    # Error handling
    if [[ -z "$line" ]]; then
      log_warn "Empty line at line $line_count"
      continue
    fi

    # Output processing result
    echo "$processed_line" >> "$output"
  done < "$input"

  log_info "Processing complete: $line_count lines processed"
}

# Main execution
main() {
  setup_logging

  log_info "$APP_NAME starting (environment: $ENV)"

  parse_args "$@"

  if [[ -z "$INPUT_FILE" ]] || [[ -z "$OUTPUT_FILE" ]]; then
    log_error "Both --input and --output are required"
    exit 1
  fi

  if [[ ! -f "$INPUT_FILE" ]]; then
    log_error "Input file not found: $INPUT_FILE"
    exit 1
  fi

  process_data "$INPUT_FILE" "$OUTPUT_FILE"

  log_info "$APP_NAME completed successfully"
}

# Run main function
main "$@"
```

## Related Documentation

- [Getting Started](getting-started.md) - Basic usage
- [Initialization](initialization.md) - Configuration options
- [Configuration](configuration.md) - Config file usage
- [Log Levels](log-levels.md) - Understanding severity levels
- [Output Streams](output-streams.md) - Stream redirection
- [Formatting](formatting.md) - Custom formats
- [Journal Logging](journal-logging.md) - Systemd integration
- [Runtime Configuration](runtime-configuration.md) - Dynamic changes
- [Sensitive Data](sensitive-data.md) - Security considerations
