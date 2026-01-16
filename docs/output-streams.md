# Output Streams <!-- omit in toc -->

The Bash Logging Module intelligently splits console output between stdout and stderr based on message severity, following Unix conventions.

## Table of Contents <!-- omit in toc -->

- [Default Behavior](#default-behavior)
- [Why Split Output Streams?](#why-split-output-streams)
  - [Unix Philosophy](#unix-philosophy)
  - [Example Benefit](#example-benefit)
- [Configuring the Stderr Threshold](#configuring-the-stderr-threshold)
  - [Stderr Level Reference](#stderr-level-reference)
- [Practical Use Cases](#practical-use-cases)
  - [Separating Normal Output from Errors](#separating-normal-output-from-errors)
  - [Suppressing Errors](#suppressing-errors)
  - [Capturing Only Errors](#capturing-only-errors)
  - [Sending All Output to Stderr](#sending-all-output-to-stderr)
  - [All Output to Stdout](#all-output-to-stdout)
- [Configuration File Settings](#configuration-file-settings)
- [Stream Redirection Examples](#stream-redirection-examples)
  - [Save All Output to File](#save-all-output-to-file)
  - [Separate Files for Normal and Error Output](#separate-files-for-normal-and-error-output)
  - [Silent Execution](#silent-execution)
  - [Show Only Errors](#show-only-errors)
  - [Swap Streams](#swap-streams)
- [Color Output and Streams](#color-output-and-streams)
- [Debugging Stream Behavior](#debugging-stream-behavior)
- [Common Patterns by Script Type](#common-patterns-by-script-type)
  - [System Administration Script](#system-administration-script)
  - [Data Processing Pipeline](#data-processing-pipeline)
  - [Background Service](#background-service)
  - [Interactive Script](#interactive-script)
  - [Cron Job](#cron-job)
- [Best Practices](#best-practices)
  - [1. Use Default Split for Most Scripts](#1-use-default-split-for-most-scripts)
  - [2. Use DEBUG for CLI Tools](#2-use-debug-for-cli-tools)
  - [3. Use WARN for Strict Error Monitoring](#3-use-warn-for-strict-error-monitoring)
  - [4. Document Stream Behavior](#4-document-stream-behavior)
  - [5. Test Stream Behavior](#5-test-stream-behavior)
- [File and Journal Logging](#file-and-journal-logging)
- [Related Documentation](#related-documentation)

## Default Behavior

By default, the logging module splits console output:

- **stdout**: DEBUG, INFO, NOTICE, WARN (normal operation messages)
- **stderr**: ERROR, CRITICAL, ALERT, EMERGENCY (error messages)

This follows the Unix convention where stdout contains normal output that can be piped or captured, while stderr contains error output that should be visible even when stdout is redirected.

## Why Split Output Streams?

### Unix Philosophy

In Unix/Linux systems:

- **stdout** - Standard output for program results and normal operational messages
- **stderr** - Standard error for diagnostics, warnings, and error messages

This separation allows:

- Capturing program output while seeing errors on screen
- Redirecting output without losing error messages
- Chaining commands with pipes while preserving error visibility

### Example Benefit

```bash
# Capture normal output to file, errors still visible on screen
./myscript.sh > output.txt

# If all output went to stdout, errors would be hidden in the file
# With stream splitting, errors appear on screen while output goes to file
```

## Configuring the Stderr Threshold

Use the `--stderr-level` option to change which log levels go to stderr:

```bash
# Default behavior: ERROR and above to stderr
init_logger

# Send WARN and above to stderr
init_logger --stderr-level WARN

# Send everything to stderr
init_logger --stderr-level DEBUG

# Send only EMERGENCY to stderr (almost everything to stdout)
init_logger --stderr-level EMERGENCY
```

### Stderr Level Reference

| Stderr Level    | To Stderr          | To Stdout                 |
| --------------- | ------------------ | ------------------------- |
| DEBUG           | DEBUG and above    | None                      |
| INFO            | INFO and above     | DEBUG                     |
| NOTICE          | NOTICE and above   | DEBUG, INFO               |
| WARN            | WARN and above     | DEBUG, INFO, NOTICE       |
| ERROR (default) | ERROR and above    | DEBUG, INFO, NOTICE, WARN |
| CRITICAL        | CRITICAL and above | DEBUG through ERROR       |
| ALERT           | ALERT and above    | DEBUG through CRITICAL    |
| EMERGENCY       | EMERGENCY only     | DEBUG through ALERT       |

## Practical Use Cases

### Separating Normal Output from Errors

Capture normal logs while keeping errors visible:

```bash
#!/bin/bash
source /path/to/logging.sh

# Default split: errors to stderr, normal logs to stdout
init_logger

log_info "Processing items..."
log_debug "Item 1 processed"
log_warn "Item 2 had warnings"
log_error "Item 3 failed"
log_info "Processing complete"

# Run: ./script.sh > output.log
# Result: output.log contains INFO, DEBUG, WARN messages
#         ERROR messages appear on screen
```

### Suppressing Errors

Hide error messages while keeping normal output:

```bash
# Run script, showing only normal operation (hide errors)
./myscript.sh 2>/dev/null
```

**When to use:**

- Running in cron jobs where errors are logged elsewhere
- When you know errors are expected and harmless
- Testing scripts where error output is noisy

### Capturing Only Errors

Capture only error messages to a file:

```bash
# Capture only errors, discard normal output
./myscript.sh 2> errors.log 1>/dev/null

# Or more concisely
./myscript.sh > /dev/null 2> errors.log
```

**When to use:**

- Monitoring for errors in background processes
- Creating error logs separate from normal logs
- Alerting on any stderr output

### Sending All Output to Stderr

For CLI tools, keep stdout clean for program output:

```bash
#!/bin/bash
source /path/to/logging.sh

# Send all log messages to stderr
init_logger --stderr-level DEBUG --level INFO

log_info "Processing input..."

# Program output goes to stdout (can be piped)
echo "result1"
echo "result2"
echo "result3"

log_info "Processing complete"

# Run: ./mytool.sh > results.txt
# Result: results.txt contains only "result1", "result2", "result3"
#         Log messages appear on screen (stderr)
```

**When to use:**

- CLI tools that produce data output
- Scripts that generate reports or data
- Tools designed to be used in pipes

### All Output to Stdout

Send everything to stdout (rare use case):

```bash
# Only EMERGENCY goes to stderr
init_logger --stderr-level EMERGENCY
```

**When to use:**

- When stderr is monitored for critical alerts only
- Legacy systems expecting all logs on stdout
- Specific logging infrastructure requirements

## Configuration File Settings

Configure stderr level in INI files:

```ini
[logging]
# Default: ERROR and above to stderr
stderr_level = ERROR

# Send warnings to stderr too
# stderr_level = WARN

# Send everything to stderr (CLI tool pattern)
# stderr_level = DEBUG
```

See [Configuration](configuration.md) for more details.

## Stream Redirection Examples

### Save All Output to File

```bash
# Capture both stdout and stderr to same file
./script.sh > output.log 2>&1

# Modern syntax (Bash 4+)
./script.sh &> output.log
```

### Separate Files for Normal and Error Output

```bash
# Normal logs to output.log, errors to errors.log
./script.sh > output.log 2> errors.log
```

### Silent Execution

```bash
# Discard all output
./script.sh > /dev/null 2>&1

# Modern syntax
./script.sh &> /dev/null
```

### Show Only Errors

```bash
# Discard stdout, show stderr
./script.sh > /dev/null
```

### Swap Streams

```bash
# Send stderr to stdout and stdout to stderr (rare)
./script.sh 3>&1 1>&2 2>&3 3>&-
```

## Color Output and Streams

Color codes are applied based on TTY detection:

```bash
# Colors enabled automatically for TTY
./script.sh

# Colors disabled when redirecting stdout
./script.sh > output.log

# Force colors even when redirecting
init_logger --color
./script.sh > output.log  # Colors in file (usually not desired)

# Disable colors explicitly
init_logger --no-color
./script.sh  # No colors even on TTY
```

## Debugging Stream Behavior

To see which stream messages go to:

```bash
#!/bin/bash
source /path/to/logging.sh

init_logger --stderr-level ERROR

# These go to stdout
log_debug "This is DEBUG"
log_info "This is INFO"
log_notice "This is NOTICE"
log_warn "This is WARN"

# These go to stderr
log_error "This is ERROR"
log_critical "This is CRITICAL"

# Test: ./script.sh > stdout.txt
# stdout.txt will contain: DEBUG, INFO, NOTICE, WARN
# Screen will show: ERROR, CRITICAL
```

## Common Patterns by Script Type

### System Administration Script

```bash
# Normal operations to stdout, errors to stderr
init_logger --level INFO --stderr-level ERROR --log /var/log/admin.log
```

### Data Processing Pipeline

```bash
# Data to stdout, all logs to stderr
init_logger --stderr-level DEBUG
process_data | next_stage
```

### Background Service

```bash
# Everything to log file, errors also to stderr
init_logger --log /var/log/service.log --stderr-level ERROR
```

### Interactive Script

```bash
# All output to console, normal split
init_logger --level INFO --stderr-level ERROR --color
```

### Cron Job

```bash
# Only errors visible (cron emails stderr)
init_logger --level WARN --stderr-level WARN --log /var/log/cron-job.log
```

## Best Practices

### 1. Use Default Split for Most Scripts

The default `ERROR` threshold works well for most use cases:

```bash
init_logger  # ERROR and above to stderr
```

### 2. Use DEBUG for CLI Tools

Keep stdout clean for data output:

```bash
init_logger --stderr-level DEBUG
echo "data output"  # Clean stdout
```

### 3. Use WARN for Strict Error Monitoring

When you want to treat warnings as errors:

```bash
init_logger --stderr-level WARN
# Now warnings appear in stderr monitoring
```

### 4. Document Stream Behavior

Tell users what to expect:

```bash
#!/bin/bash
# This script sends normal logs to stdout and errors to stderr
# Run: ./script.sh > output.log     # Capture output, see errors
# Run: ./script.sh 2> errors.log    # Capture errors only
```

### 5. Test Stream Behavior

Verify your script works with common redirections:

```bash
# Test all output
./script.sh

# Test stdout capture
./script.sh > /dev/null

# Test stderr capture
./script.sh 2> /dev/null

# Test both captured
./script.sh &> /dev/null
```

## File and Journal Logging

Note that stream configuration only affects console output. File and journal logging always receive all messages at or above the configured log level, regardless of stderr-level:

```bash
init_logger --log /tmp/app.log --stderr-level ERROR --level DEBUG

log_debug "Debug message"
# Console: Goes to stdout (DEBUG < ERROR)
# File: Written to /tmp/app.log (DEBUG >= DEBUG)
```

## Related Documentation

- [Initialization](initialization.md) - Setting stderr-level at startup
- [Configuration](configuration.md) - Stderr-level in config files
- [Log Levels](log-levels.md) - Understanding log severity
- [Examples](examples.md) - Complete examples with stream redirection
