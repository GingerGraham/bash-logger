# Formatting <!-- omit in toc -->

The Bash Logging Module allows you to customize the format of log messages using special placeholders.

## Table of Contents <!-- omit in toc -->

- [Default Format](#default-format)
- [Format Placeholders](#format-placeholders)
- [Setting Format at Initialization](#setting-format-at-initialization)
- [Format Examples](#format-examples)
  - [Minimal Format](#minimal-format)
  - [Standard Format (Default)](#standard-format-default)
  - [Detailed Format with Timezone](#detailed-format-with-timezone)
  - [Syslog-Style Format](#syslog-style-format)
  - [Compact Format](#compact-format)
  - [Time-Only Format](#time-only-format)
- [Timezone Display](#timezone-display)
  - [Without Timezone Placeholder](#without-timezone-placeholder)
- [Configuration File Format Setting](#configuration-file-format-setting)
- [Changing Format at Runtime](#changing-format-at-runtime)
- [Format Best Practices](#format-best-practices)
  - [1. Include Timestamp for File Logs](#1-include-timestamp-for-file-logs)
  - [2. Include Script Name for Multi-Script Logs](#2-include-script-name-for-multi-script-logs)
  - [3. Include Timezone for Distributed Systems](#3-include-timezone-for-distributed-systems)
  - [4. Minimal Format for Console Debugging](#4-minimal-format-for-console-debugging)
  - [5. Consistent Format Across Applications](#5-consistent-format-across-applications)
  - [6. Consider Log Parsing Tools](#6-consider-log-parsing-tools)
- [Format Examples by Use Case](#format-examples-by-use-case)
  - [Development Script](#development-script)
  - [Production Application](#production-application)
  - [System Service](#system-service)
  - [Multi-Timezone Deployment](#multi-timezone-deployment)
  - [Shared Log File](#shared-log-file)
  - [CLI Tool](#cli-tool)
- [Cloud and Structured Logging Formats](#cloud-and-structured-logging-formats)
  - [AWS CloudWatch Logs Format](#aws-cloudwatch-logs-format)
  - [JSON-Like Format](#json-like-format)
  - [Pipe-Delimited Format](#pipe-delimited-format)
  - [Kubernetes/Container Logs Format](#kubernetescontainer-logs-format)
  - [Splunk-Friendly Format](#splunk-friendly-format)
  - [Example: Multi-Environment Format Selection](#example-multi-environment-format-selection)
- [Special Characters in Messages](#special-characters-in-messages)
- [Escaping in Format Strings](#escaping-in-format-strings)
- [Testing Your Format](#testing-your-format)
- [Format and Color Output](#format-and-color-output)
- [Related Documentation](#related-documentation)

## Default Format

The default log message format is:

```text
%d [%l] [%s] %m
```

Which produces output like:

```text
2026-01-16 14:30:45 [INFO] [myscript.sh] Application started
```

## Format Placeholders

| Placeholder | Description   | Example                  |
| ----------- | ------------- | ------------------------ |
| `%d`        | Date and time | `2026-01-16 14:30:45`    |
| `%l`        | Log level     | `INFO`, `ERROR`, `DEBUG` |
| `%s`        | Script name   | `myscript.sh`            |
| `%m`        | Log message   | `Application started`    |
| `%z`        | Timezone      | `UTC` or `LOCAL`         |

## Setting Format at Initialization

Use the `--format` option when initializing the logger:

```bash
# Custom format
init_logger --format "[%l] %d %z [%s] %m"

# Minimal format
init_logger --format "%l: %m"

# Detailed format
init_logger --format "%d %z [%l] %s: %m"
```

## Format Examples

### Minimal Format

```bash
init_logger --format "%l: %m"
```

Output:

```text
INFO: Application started
ERROR: Failed to open file
DEBUG: Variable value: count=42
```

**When to use:**

- Quick debugging
- When context is obvious
- Console-only logging
- Minimal output requirements

### Standard Format (Default)

```bash
init_logger --format "%d [%l] [%s] %m"
```

Output:

```text
2026-01-16 14:30:45 [INFO] [myscript.sh] Application started
2026-01-16 14:30:46 [ERROR] [myscript.sh] Failed to open file
```

**When to use:**

- General purpose logging
- File logging
- Production environments
- Most use cases

### Detailed Format with Timezone

```bash
init_logger --format "%d %z [%l] [%s] %m"
```

Output:

```text
2026-01-16 14:30:45 UTC [INFO] [myscript.sh] Application started
2026-01-16 14:30:46 UTC [ERROR] [myscript.sh] Failed to open file
```

**When to use:**

- Multi-timezone deployments
- Coordinated operations
- Compliance/audit requirements
- When UTC timestamps are used

### Syslog-Style Format

```bash
init_logger --format "%d %s[$$]: [%l] %m"
```

Output:

```text
2026-01-16 14:30:45 myscript.sh[12345]: [INFO] Application started
```

Note: `$$` is a Bash variable for the current process ID.

**When to use:**

- System logs
- Service logs
- Process tracking
- Syslog integration

### Compact Format

```bash
init_logger --format "[%l] %m"
```

Output:

```text
[INFO] Application started
[ERROR] Failed to open file
```

**When to use:**

- Development
- Short-lived scripts
- When timestamp isn't needed
- Interactive use

### Time-Only Format

```bash
init_logger --format "$(date +%H:%M:%S) [%l] %m"
```

Output:

```text
14:30:45 [INFO] Application started
14:30:46 [ERROR] Failed to open file
```

**When to use:**

- Same-day logs
- Performance monitoring
- Short-term debugging
- When date is implied

## Timezone Display

The `%z` placeholder shows the timezone mode:

```bash
# Local time (default)
init_logger --format "%d %z [%l] %m"
# Output: 2026-01-16 14:30:45 LOCAL [INFO] Message

# UTC time
init_logger --utc --format "%d %z [%l] %m"
# Output: 2026-01-16 19:30:45 UTC [INFO] Message
```

### Without Timezone Placeholder

If you don't include `%z`, the timezone isn't displayed (but timestamps are still affected by the `--utc` flag):

```bash
# Local time without indicator
init_logger --format "%d [%l] %m"
# Output: 2026-01-16 14:30:45 [INFO] Message

# UTC time without indicator
init_logger --utc --format "%d [%l] %m"
# Output: 2026-01-16 19:30:45 [INFO] Message
```

## Configuration File Format Setting

Set format in configuration files:

```ini
[logging]
# Standard format
format = %d [%l] [%s] %m

# Detailed format
format = %d %z [%l] [%s] %m

# Minimal format
format = [%l] %m

# Custom format
format = %d [%s] %l: %m
```

See [Configuration](configuration.md) for more details.

## Changing Format at Runtime

Use the `set_log_format` function to change format during script execution:

```bash
#!/bin/bash
source /path/to/logging.sh

# Start with default format
init_logger

log_info "Starting processing"

# Switch to minimal format for detailed debug output
set_log_format "[%l] %m"
log_debug "Processing item 1"
log_debug "Processing item 2"

# Return to detailed format
set_log_format "%d [%l] [%s] %m"
log_info "Processing complete"
```

See [Runtime Configuration](runtime-configuration.md) for more details.

## Format Best Practices

### 1. Include Timestamp for File Logs

Always include `%d` when logging to files:

```bash
init_logger --log "/var/log/app.log" --format "%d [%l] [%s] %m"
```

### 2. Include Script Name for Multi-Script Logs

Use `%s` when multiple scripts log to the same file:

```bash
init_logger --log "/var/log/shared.log" --format "%d [%l] [%s] %m"
```

### 3. Include Timezone for Distributed Systems

Use `%z` for systems spanning multiple timezones:

```bash
init_logger --utc --format "%d %z [%l] [%s] %m"
```

### 4. Minimal Format for Console Debugging

Keep it simple for interactive development:

```bash
init_logger --format "[%l] %m"
```

### 5. Consistent Format Across Applications

Standardize format across your organization:

```bash
# Company standard format
init_logger --format "%d [%l] [%s] %m"
```

### 6. Consider Log Parsing Tools

If using log analysis tools, choose a format they can parse:

```bash
# JSON-like format for structured logging
# Note: This module doesn't produce actual JSON, but you can make it parseable
init_logger --format '%d|%l|%s|%m'
```

## Format Examples by Use Case

### Development Script

```bash
# Quick debugging - minimal format
init_logger --format "[%l] %m"
```

### Production Application

```bash
# Comprehensive logging with timezone
init_logger --log "/var/log/app/app.log" \
  --format "%d %z [%l] [%s] %m" \
  --utc
```

### System Service

```bash
# Syslog-style format with process ID
init_logger --journal --format "%d %s[$$]: %m"
```

### Multi-Timezone Deployment

```bash
# Clear timezone indication
init_logger --utc --format "%d %z [%l] [%s] %m"
```

### Shared Log File

```bash
# Include script name to distinguish sources
init_logger --log "/var/log/shared/all.log" --format "%d [%s] [%l] %m"
```

### CLI Tool

```bash
# Minimal format, all to stderr
init_logger --stderr-level DEBUG --format "%l: %m"
```

## Cloud and Structured Logging Formats

Modern cloud platforms and log aggregation services often prefer structured or semi-structured log formats. Here are
examples for common platforms:

### AWS CloudWatch Logs Format

CloudWatch Logs works well with structured formats that can be parsed:

```bash
# CloudWatch-friendly format with clear structure
init_logger --format "%d [%l] [%s] %m" --utc

# CloudWatch with key-value pairs for easy parsing
init_logger --format "timestamp=%d level=%l script=%s message=%m" --utc
```

Output:

```text
2026-01-16 14:30:45 [INFO] [myscript.sh] Application started
timestamp=2026-01-16 14:30:45 level=INFO script=myscript.sh message=Application started
```

**When to use:**

- AWS Lambda functions
- EC2 instances with CloudWatch agent
- ECS/Fargate containers
- Any AWS service that sends logs to CloudWatch

**Best practices for CloudWatch:**

- Always use UTC time (`--utc`)
- Include log level for filtering
- Keep format consistent across services
- Consider adding request IDs in the message for tracing

### JSON-Like Format

While the logging module doesn't produce true JSON, you can create a JSON-like format for log parsers:

```bash
# JSON-like format
init_logger --format '{"timestamp":"%d", "level":"%l", "script":"%s", "message":"%m"}' --utc
```

Output:

```text
{"timestamp":"2026-01-16 14:30:45", "level":"INFO", "script":"myscript.sh", "message":"Application started"}
```

**When to use:**

- Log aggregation platforms (ELK, Splunk, Datadog)
- When logs need to be parsed programmatically
- Cloud-native applications
- Microservices architectures

**Note:** This creates JSON-like output but is not guaranteed to be valid JSON if the message contains special
characters like quotes. For production use with strict JSON requirements, consider post-processing logs or using
dedicated JSON logging tools.

### Pipe-Delimited Format

A simpler structured format that's easier to parse:

```bash
# Pipe-delimited format
init_logger --format "%d|%l|%s|%m" --utc
```

Output:

```text
2026-01-16 14:30:45|INFO|myscript.sh|Application started
2026-01-16 14:30:46|ERROR|myscript.sh|Failed to open file
```

**When to use:**

- Easy parsing with `cut` or `awk`
- CSV-like log analysis
- Simple log aggregation
- When JSON is overkill

### Kubernetes/Container Logs Format

For containerized applications, a format that works well with container log drivers:

```bash
# Container-friendly format
init_logger --format "%d %z %l %s: %m" --utc

# With structured fields
init_logger --format "time=%d tz=%z level=%l source=%s msg=%m" --utc
```

Output:

```text
2026-01-16 14:30:45 UTC INFO myscript.sh: Application started
time=2026-01-16 14:30:45 tz=UTC level=INFO source=myscript.sh msg=Application started
```

**When to use:**

- Docker containers
- Kubernetes pods
- Container orchestration platforms
- When logs are collected by container runtime

### Splunk-Friendly Format

Format optimized for Splunk ingestion:

```bash
# Splunk-friendly format with clear field extraction
init_logger --format "%d source=\"%s\" level=%l %m" --utc
```

Output:

```text
2026-01-16 14:30:45 source="myscript.sh" level=INFO Application started
```

**When to use:**

- Splunk log ingestion
- When using Splunk Universal Forwarder
- Enterprise log management with Splunk

### Example: Multi-Environment Format Selection

Choose format based on deployment environment:

```bash
#!/bin/bash
source /path/to/logging.sh

# Determine environment
ENV="${DEPLOY_ENV:-development}"

case "$ENV" in
    aws|cloudwatch)
        # AWS CloudWatch format
        init_logger \
            --format "timestamp=%d level=%l script=%s message=%m" \
            --utc \
            --log "/var/log/app.log"
        ;;
    kubernetes|k8s)
        # Kubernetes format
        init_logger \
            --format "time=%d tz=%z level=%l source=%s msg=%m" \
            --utc \
            --stderr-level DEBUG
        ;;
    json)
        # JSON-like format
        init_logger \
            --format '{"timestamp":"%d", "level":"%l", "script":"%s", "message":"%m"}' \
            --utc \
            --log "/var/log/app.json"
        ;;
    development)
        # Human-readable format
        init_logger \
            --format "[%l] %d - %m" \
            --color
        ;;
    *)
        # Default format
        init_logger \
            --format "%d [%l] [%s] %m" \
            --log "/var/log/app.log"
        ;;
esac

log_info "Application started in $ENV environment"
```

## Special Characters in Messages

The logging module handles special characters in log messages:

```bash
log_info "Processing file: /path/to/file.txt"
log_info "Status: 100% complete"
log_info "Command: grep -r 'pattern' /dir/"
log_info "Line break test\nSecond line"
```

Most special characters are displayed as-is. For complex formatting in messages, consider using printf-style formatting:

```bash
# Format numbers, padding, etc. before logging
formatted_msg=$(printf "Processing: %-20s [%3d%%]" "$filename" "$percent")
log_info "$formatted_msg"
```

## Escaping in Format Strings

Format placeholders are literal strings. If you need to include a literal `%` character, you can work around it:

```bash
# This works - % not followed by a format letter
init_logger --format "%d [%l] %m (100% complete)"

# This is interpreted as format string
# init_logger --format "%d [%l] %m %d" # Second %d would be replaced
```

## Testing Your Format

Create a test script to see how your format looks:

```bash
#!/bin/bash
source /path/to/logging.sh

# Test your format
init_logger --format "[%l] %d %z - %s: %m"

log_debug "Debug message"
log_info "Info message"
log_notice "Notice message"
log_warn "Warning message"
log_error "Error message"
log_critical "Critical message"
```

## Format and Color Output

Format and color codes work together. Colors are applied to the entire line based on log level:

```bash
init_logger --format "[%l] %m" --color

log_info "This line will be colored"
log_error "This line will be colored differently"
```

Color codes are automatically stripped when output is redirected to a file:

```bash
./script.sh > output.log  # No color codes in file
```

## Related Documentation

- [Initialization](initialization.md) - Setting format at startup
- [Runtime Configuration](runtime-configuration.md) - Changing format during execution
- [Configuration](configuration.md) - Format in config files
- [Examples](examples.md) - Complete format examples
