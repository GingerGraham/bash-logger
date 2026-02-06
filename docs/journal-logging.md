# Journal Logging <!-- omit in toc -->

The Bash Logging Module can integrate with systemd's journal logging system, making it ideal for system services and
applications running on modern Linux distributions.

## Table of Contents <!-- omit in toc -->

* [Overview](#overview)
* [Requirements](#requirements)
  * [System Requirements](#system-requirements)
  * [Check if Journal Logging is Available](#check-if-journal-logging-is-available)
  * [Installing logger](#installing-logger)
* [Enabling Journal Logging](#enabling-journal-logging)
  * [At Initialization](#at-initialization)
  * [In Configuration Files](#in-configuration-files)
  * [At Runtime](#at-runtime)
* [Journal Tags](#journal-tags)
  * [Default Tag](#default-tag)
  * [Custom Tag](#custom-tag)
  * [Tag Best Practices](#tag-best-practices)
* [Log Level Mapping](#log-level-mapping)
* [Viewing Journal Logs](#viewing-journal-logs)
  * [Basic journalctl Commands](#basic-journalctl-commands)
  * [Filtering by Priority](#filtering-by-priority)
  * [Time-Based Filtering](#time-based-filtering)
  * [Output Formats](#output-formats)
* [Use Cases](#use-cases)
  * [System Service](#system-service)
  * [Scheduled Task (Cron)](#scheduled-task-cron)
  * [Long-Running Daemon](#long-running-daemon)
  * [Combined Logging](#combined-logging)
* [Journal vs. File Logging](#journal-vs-file-logging)
  * [When to Use Journal Logging](#when-to-use-journal-logging)
  * [When to Use File Logging](#when-to-use-file-logging)
  * [When to Use Both](#when-to-use-both)
* [Sensitive Data and Journal](#sensitive-data-and-journal)
* [Journal Storage](#journal-storage)
  * [Check Journal Storage](#check-journal-storage)
  * [Configure Journal Retention](#configure-journal-retention)
* [Troubleshooting](#troubleshooting)
  * [Logger Command Not Found](#logger-command-not-found)
  * [Journal Not Receiving Logs](#journal-not-receiving-logs)
  * [Permission Issues](#permission-issues)
  * [Verifying Logs Are Received](#verifying-logs-are-received)
* [Performance Considerations](#performance-considerations)
* [Related Documentation](#related-documentation)

## Overview

Journal logging sends log messages to the systemd journal using the `logger` command. This provides:

* Centralized logging with systemd
* Integration with system logs
* Structured log metadata
* Persistent storage (when configured)
* Powerful querying with `journalctl`
* Automatic log rotation

## Requirements

### System Requirements

* systemd (standard on most modern Linux distributions)
* `logger` command (typically from the `util-linux` package)

### Check if Journal Logging is Available

```bash
# Check if logger is installed
which logger

# Check if systemd is running
systemctl --version
```

### Installing logger

If `logger` is not installed:

```bash
# Debian/Ubuntu
sudo apt-get install util-linux

# RHEL/CentOS/Fedora
sudo dnf install util-linux

# Arch Linux
sudo pacman -S util-linux
```

## Enabling Journal Logging

### At Initialization

```bash
# Enable journal logging
init_logger --journal

# With custom tag
init_logger --journal --tag "myapp"

# Combined with file logging
init_logger --journal --log "/var/log/myapp.log" --tag "myapp"
```

### In Configuration Files

```ini
[logging]
journal = true
tag = myapp
level = INFO
```

See [Configuration](configuration.md) for more details.

### At Runtime

```bash
# Enable journal logging after initialization
set_journal_logging true

# Change the tag
set_journal_tag "new-app-name"

# Disable journal logging
set_journal_logging false
```

See [Runtime Configuration](runtime-configuration.md) for more details.

## Journal Tags

Tags help identify log messages from different applications in the journal.

### Default Tag

By default, the script name is used as the tag:

```bash
# Script: /usr/local/bin/backup.sh
init_logger --journal
# Tag will be: backup.sh
```

### Custom Tag

Specify a custom tag:

```bash
# Use application name as tag
init_logger --journal --tag "myapp"

# Use service name
init_logger --journal --tag "backup-service"

# Use component name
init_logger --journal --tag "database-monitor"
```

### Tag Best Practices

1. **Use application names** - Consistent naming across deployments
2. **Keep it short** - Easier to type in journalctl commands
3. **Use hyphens** - Better than spaces for command-line use
4. **Be descriptive** - Make it clear what's logging

## Log Level Mapping

Log levels are mapped to syslog priorities:

| Module Level | Syslog Priority | journalctl Filter |
| ------------ | --------------- | ----------------- |
| DEBUG        | debug           | PRIORITY=7        |
| INFO         | info            | PRIORITY=6        |
| NOTICE       | notice          | PRIORITY=5        |
| WARN         | warning         | PRIORITY=4        |
| ERROR        | err             | PRIORITY=3        |
| CRITICAL     | crit            | PRIORITY=2        |
| ALERT        | alert           | PRIORITY=1        |
| EMERGENCY    | emerg           | PRIORITY=0        |

## Viewing Journal Logs

### Basic journalctl Commands

```bash
# View all logs with specific tag
journalctl -t myapp

# Follow logs in real-time
journalctl -f -t myapp

# View logs from current boot
journalctl -b -t myapp

# View logs from today
journalctl -t myapp --since today

# View logs from last hour
journalctl -t myapp --since "1 hour ago"
```

### Filtering by Priority

```bash
# Show only errors and above (PRIORITY <= 3)
journalctl -t myapp -p err

# Show warnings and above
journalctl -t myapp -p warning

# Show info and above
journalctl -t myapp -p info
```

### Time-Based Filtering

```bash
# Logs since specific date/time
journalctl -t myapp --since "2026-01-16 14:00:00"

# Logs until specific date/time
journalctl -t myapp --until "2026-01-16 15:00:00"

# Logs between times
journalctl -t myapp --since "10:00:00" --until "11:00:00"

# Last 100 lines
journalctl -t myapp -n 100

# Follow (like tail -f)
journalctl -t myapp -f
```

### Output Formats

```bash
# Detailed output (default)
journalctl -t myapp

# Short output (similar to syslog)
journalctl -t myapp -o short

# JSON output (for parsing)
journalctl -t myapp -o json

# JSON output (pretty-printed)
journalctl -t myapp -o json-pretty

# Only the message field
journalctl -t myapp -o cat
```

## Use Cases

### System Service

```bash
#!/bin/bash
# /usr/local/bin/myservice.sh
source /usr/local/lib/logging.sh

init_logger --journal --tag "myservice" --level INFO --utc

log_info "Service starting"
# Service logic here
log_info "Service stopped"
```

Systemd unit file:

```ini
[Unit]
Description=My Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/myservice.sh
Restart=always

[Install]
WantedBy=multi-user.target
```

View logs:

```bash
journalctl -u myservice.service -f
# or
journalctl -t myservice -f
```

### Scheduled Task (Cron)

```bash
#!/bin/bash
# /usr/local/bin/backup-script.sh
source /usr/local/lib/logging.sh

init_logger --journal --tag "backup-cron" --level INFO

log_info "Backup started"
# Backup logic here
if [[ $? -eq 0 ]]; then
    log_info "Backup completed successfully"
else
    log_error "Backup failed"
fi
```

View logs:

```bash
journalctl -t backup-cron --since today
```

### Long-Running Daemon

```bash
#!/bin/bash
source /usr/local/lib/logging.sh

init_logger --journal --log "/var/log/monitor.log" \
  --tag "monitor-daemon" --level INFO

log_info "Daemon starting"

while true; do
    # Monitoring logic
    log_debug "Checking system status"

    if [[ $status != "OK" ]]; then
        log_warn "Status check failed"
    fi

    sleep 60
done
```

### Combined Logging

Log to both journal and file:

```bash
#!/bin/bash
source /usr/local/lib/logging.sh

# Logs go to both journal and file
init_logger \
  --journal --tag "myapp" \
  --log "/var/log/myapp/app.log" \
  --level INFO

log_info "Application started"
```

**Benefits:**

* Journal for system integration and queries
* File for backups and long-term archival
* File for easy grepping and analysis

## Journal vs. File Logging

### When to Use Journal Logging

* System services and daemons
* Applications running under systemd
* When you need structured metadata
* When you want centralized system logs
* When log rotation is handled by systemd
* When you need powerful log queries

### When to Use File Logging

* Application-specific logs
* When you need custom log rotation
* When logs need to be shipped elsewhere
* When you need simple grep/awk access
* When running on systems without systemd
* When you need guaranteed log format

### When to Use Both

* Critical applications requiring redundancy
* When different teams need different formats
* When you want local files and system integration
* For compliance requiring multiple log stores

## Sensitive Data and Journal

**Important:** Sensitive data logged with `log_sensitive` is **NOT** sent to the journal:

```bash
init_logger --journal --tag "myapp"

log_info "User logged in"              # Goes to journal
log_sensitive "API Key: $API_KEY"      # Does NOT go to journal
log_info "Request processed"           # Goes to journal
```

See [Sensitive Data](sensitive-data.md) for more details.

## Journal Storage

### Check Journal Storage

```bash
# Show journal disk usage
journalctl --disk-usage

# Show journal statistics
journalctl --verify
```

### Configure Journal Retention

Edit `/etc/systemd/journald.conf`:

```ini
[Journal]
# Limit journal size
SystemMaxUse=500M

# Keep logs for 30 days
MaxRetentionSec=30d

# Keep at least 100M of logs
SystemKeepFree=100M
```

Restart journald:

```bash
sudo systemctl restart systemd-journald
```

## Troubleshooting

### Logger Command Not Found

```bash
# Check if logger is installed
which logger

# Install if missing (Debian/Ubuntu)
sudo apt-get install util-linux
```

### Journal Not Receiving Logs

```bash
# Check if systemd is running
systemctl --version

# Check journal service status
systemctl status systemd-journald

# Test logger manually
logger -t test "Test message"
journalctl -t test -n 5
```

### Permission Issues

The `logger` command typically doesn't require special permissions, but check:

```bash
# Test as current user
logger -t test "Test from $USER"
journalctl -t test -n 1
```

### Verifying Logs Are Received

```bash
#!/bin/bash
source /path/to/logging.sh

init_logger --journal --tag "test-$(date +%s)"

log_info "Test message 1"
log_error "Test error 1"

# Check immediately
journalctl -t "test-*" -n 5
```

## Performance Considerations

Journal logging is generally fast, but consider:

1. **Asynchronous by default** - `logger` returns immediately
2. **No blocking** - Won't slow down your script
3. **Buffering** - systemd handles buffering and writes
4. **Network logging** - Can be slower if sending to remote journal

To avoid oversized journal entries and reduce DoS risk, log messages are capped by default. The
journal limit matches the console/file limit unless you override it with `--max-journal-length`
or `max_journal_length` in config files (set to `0` to disable limits).

For high-throughput applications:

```bash
# Use file logging for performance-critical sections
set_journal_logging false
# ... high-throughput operations ...
set_journal_logging true
```

## Related Documentation

* [Initialization](initialization.md) - Enabling journal logging at startup
* [Configuration](configuration.md) - Journal settings in config files
* [Runtime Configuration](runtime-configuration.md) - Changing journal settings dynamically
* [Sensitive Data](sensitive-data.md) - Understanding what doesn't go to the journal
* [Examples](examples.md) - Complete journal logging examples
