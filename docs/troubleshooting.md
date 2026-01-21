# Troubleshooting <!-- omit in toc -->

This guide helps you diagnose and resolve common issues with the Bash Logging Module.

## Table of Contents <!-- omit in toc -->

* [Installation Issues](#installation-issues)
  * [Module Not Found](#module-not-found)
  * [Permission Denied](#permission-denied)
* [Initialization Issues](#initialization-issues)
  * [Logger Not Initialized](#logger-not-initialized)
  * [Initialization Fails](#initialization-fails)
* [Configuration File Issues](#configuration-file-issues)
  * [Configuration File Not Loaded](#configuration-file-not-loaded)
  * [Invalid Configuration Values](#invalid-configuration-values)
  * [CLI Arguments Not Overriding Config](#cli-arguments-not-overriding-config)
* [File Logging Issues](#file-logging-issues)
  * [No Output to Log File](#no-output-to-log-file)
  * [Log File Permission Denied](#log-file-permission-denied)
* [Journal Logging Issues](#journal-logging-issues)
  * [Journal Logs Not Appearing](#journal-logs-not-appearing)
  * [Wrong Tag in Journal](#wrong-tag-in-journal)
* [Console Output Issues](#console-output-issues)
  * [No Console Output](#no-console-output)
  * [No Colors in Output](#no-colors-in-output)
  * [Colors Appear in Log File](#colors-appear-in-log-file)
* [Output Stream Issues](#output-stream-issues)
  * [Logs Going to Wrong Stream](#logs-going-to-wrong-stream)
  * [Cannot Separate Stdout and Stderr](#cannot-separate-stdout-and-stderr)
* [Runtime Configuration Issues](#runtime-configuration-issues)
  * [set_log_level Not Working](#set_log_level-not-working)
  * [Runtime Changes Not Persisting](#runtime-changes-not-persisting)
* [Format Issues](#format-issues)
  * [Format Not Applied](#format-not-applied)
  * [Weird Characters in Output](#weird-characters-in-output)
* [Debugging Tips](#debugging-tips)
  * [Enable Verbose Mode](#enable-verbose-mode)
  * [Test with Minimal Configuration](#test-with-minimal-configuration)
  * [Verify Function Availability](#verify-function-availability)
  * [Check Initialization Return Code](#check-initialization-return-code)
  * [Test Logger Command](#test-logger-command)
* [Performance Issues](#performance-issues)
  * [Slow Logging](#slow-logging)
* [Common Error Messages](#common-error-messages)
  * ["command not found: init_logger"](#command-not-found-init_logger)
  * ["permission denied" when writing log file](#permission-denied-when-writing-log-file)
  * ["invalid log level"](#invalid-log-level)
* [Getting Help](#getting-help)
* [Related Documentation](#related-documentation)

## Installation Issues

### Module Not Found

**Problem:** `bash: logging.sh: No such file or directory`

**Solutions:**

```bash
# Check if file exists
ls -l /path/to/logging.sh

# Verify the path in your source command
source /correct/path/to/logging.sh

# Use absolute path
source /usr/local/lib/logging.sh

# Or relative to script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"
```

### Permission Denied

**Problem:** `bash: logging.sh: Permission denied`

**Solutions:**

```bash
# Check file permissions
ls -l /path/to/logging.sh

# Make file readable
chmod +r /path/to/logging.sh

# Or set appropriate permissions
chmod 644 /path/to/logging.sh
```

## Initialization Issues

### Logger Not Initialized

**Problem:** Log functions don't work, no output appears

**Solution:**

```bash
# Always call init_logger before logging
source /path/to/logging.sh
init_logger  # Don't forget this!

log_info "Now this works"
```

### Initialization Fails

**Problem:** `init_logger` returns error code 1

**Common causes:**

1. **Cannot create log file directory**

```bash
# Check directory exists and is writable
ls -ld /var/log/myapp/

# Create directory if needed
sudo mkdir -p /var/log/myapp
sudo chown $USER:$USER /var/log/myapp

# Or use a directory you have access to
init_logger --log "$HOME/logs/app.log"
```

1. **No write permission to log file**

```bash
# Check file permissions
ls -l /var/log/myapp.log

# Fix permissions
sudo chown $USER:$USER /var/log/myapp.log

# Or use a different location
init_logger --log "$HOME/app.log"
```

1. **Disk space full**

```bash
# Check disk space
df -h

# Clean up or use different location
init_logger --log "/tmp/app.log"
```

## Configuration File Issues

### Configuration File Not Loaded

**Problem:** Settings from config file are not applied

**Solutions:**

```bash
# Check file exists
ls -l /etc/myapp/logging.conf

# Verify file is readable
cat /etc/myapp/logging.conf

# Check file path in init_logger call
init_logger --config /etc/myapp/logging.conf

# Use absolute path
init_logger --config "$(pwd)/logging.conf"
```

### Invalid Configuration Values

**Problem:** Config file has invalid values, uses defaults

**Solution:**

Check configuration file format:

```ini
[logging]
# Correct
level = INFO

# Also correct
level = DEBUG
level = 7

# Incorrect - will use default
level = invalid_value

# Boolean values - correct
journal = true
journal = yes
journal = 1

# Boolean values - incorrect
journal = True  # Case-sensitive, should be lowercase
```

### CLI Arguments Not Overriding Config

**Problem:** CLI arguments don't override config file values

**Solution:**

Ensure CLI arguments come **after** the `--config` option:

```bash
# Correct - CLI overrides config
init_logger --config logging.conf --level DEBUG

# Incorrect - config file might override CLI
init_logger --level DEBUG --config logging.conf
```

## File Logging Issues

### No Output to Log File

**Problem:** Console shows logs but file is empty

**Solutions:**

```bash
# 1. Check file was created
ls -l /var/log/myapp.log

# 2. Verify initialization succeeded
if ! init_logger --log "/var/log/myapp.log"; then
    echo "Logger initialization failed" >&2
fi

# 3. Check you're logging at the right level
init_logger --log "/var/log/app.log" --level DEBUG
log_debug "This should appear"  # Won't appear if level is INFO

# 4. Check log file path is correct
init_logger --log "/var/log/app.log"
echo "Log file location: $LOG_FILE"  # If module exposes this variable
```

### Log File Permission Denied

**Problem:** Cannot write to log file

**Solutions:**

```bash
# Check current user
whoami

# Check file ownership and permissions
ls -l /var/log/myapp.log

# Fix ownership
sudo chown $USER:$USER /var/log/myapp.log

# Fix permissions
chmod 644 /var/log/myapp.log

# Or use a user-writable location
init_logger --log "$HOME/logs/app.log"
mkdir -p "$HOME/logs"
```

## Journal Logging Issues

### Journal Logs Not Appearing

**Problem:** No logs in journalctl output

**Solutions:**

```bash
# 1. Check if logger command exists
which logger
# If not found:
sudo apt-get install util-linux  # Debian/Ubuntu
sudo dnf install util-linux       # RHEL/Fedora

# 2. Test logger directly
logger -t test-tag "Test message"
journalctl -t test-tag -n 5

# 3. Check journal logging is enabled
init_logger --journal --tag "myapp"

# 4. Check systemd journal is running
systemctl status systemd-journald

# 5. View all recent journal entries
journalctl -n 50

# 6. Check for your tag specifically
journalctl -t myapp --since "1 minute ago"
```

### Wrong Tag in Journal

**Problem:** Logs appear with wrong tag

**Solution:**

```bash
# Explicitly set tag
init_logger --journal --tag "myapp"

# Verify in journal
journalctl -t myapp -n 5

# Change tag at runtime
set_journal_tag "new-tag"
```

## Console Output Issues

### No Console Output

**Problem:** No logs appear on screen

**Solutions:**

```bash
# 1. Check if quiet mode is enabled
init_logger  # Don't use --quiet

# 2. Check log level
init_logger --level DEBUG  # or --verbose

# 3. Verify you're logging at or above the current level
init_logger --level WARN
log_info "Won't show"   # INFO < WARN
log_warn "Will show"    # WARN >= WARN
log_error "Will show"   # ERROR > WARN
```

### No Colors in Output

**Problem:** Colors don't appear in console

**Solutions:**

```bash
# 1. Check if output is to a TTY
if [[ -t 1 ]]; then
    echo "stdout is a TTY"
else
    echo "stdout is not a TTY (colors disabled)"
fi

# 2. Force colors on
init_logger --color

# 3. Check terminal supports colors
echo $TERM
# Should be xterm-256color, screen, or similar

# 4. Verify colors aren't explicitly disabled
init_logger  # Don't use --no-color
```

### Colors Appear in Log File

**Problem:** ANSI color codes in log file make it hard to read

**Solution:**

This should not happen normally - colors are auto-detected. If it does:

```bash
# Explicitly disable colors for file-only logging
init_logger --log "/var/log/app.log" --quiet --no-color

# Or remove color codes from existing file
sed 's/\x1b\[[0-9;]*m//g' app.log > app-clean.log
```

## Output Stream Issues

### Logs Going to Wrong Stream

**Problem:** ERROR messages on stdout instead of stderr (or vice versa)

**Solution:**

Check stderr-level configuration:

```bash
# Default: ERROR and above to stderr
init_logger

# If you want WARN to stderr too
init_logger --stderr-level WARN

# Verify stream behavior
./script.sh 2>&1 | grep "ERROR"  # Should find errors
```

### Cannot Separate Stdout and Stderr

**Problem:** All output goes to same stream

**Solution:**

```bash
# Check script uses correct log functions
log_info "To stdout"   # Below stderr-level
log_error "To stderr"  # At or above stderr-level

# Verify stderr-level setting
init_logger --stderr-level ERROR

# Test stream separation
./script.sh > stdout.log 2> stderr.log
```

## Runtime Configuration Issues

### set_log_level Not Working

**Problem:** Changing log level doesn't affect output

**Solution:**

```bash
# Verify function is called correctly
set_log_level DEBUG  # Correct
set_log_level debug  # Case-sensitive - might not work

# Check valid values
set_log_level DEBUG   # Correct
set_log_level INFO    # Correct
set_log_level 7       # Correct (numeric)
set_log_level INVALID # Won't work

# Verify change took effect
set_log_level DEBUG
log_debug "Should now appear"
```

### Runtime Changes Not Persisting

**Problem:** Changes made with set\_\* functions don't persist

**Explanation:**

This is expected behavior - runtime changes only affect the current script execution:

```bash
# Session 1
./script.sh
# set_log_level DEBUG called
# Script ends

# Session 2
./script.sh
# Log level is back to default (INFO)

# To persist changes, modify initialization or config file
```

## Format Issues

### Format Not Applied

**Problem:** Custom format not showing in output

**Solutions:**

```bash
# 1. Check format string is valid
init_logger --format "%d [%l] %m"  # Correct

# 2. Verify you're using correct placeholders
# Valid: %d, %l, %s, %m, %z
# Invalid: %t, %L, %D, etc.

# 3. Check quotes
init_logger --format "[%l] %m"      # Correct
init_logger --format [%l] %m        # Might be interpreted as separate args

# 4. Verify at runtime
set_log_format "[%l] %m"
log_info "Test message"
```

### Weird Characters in Output

**Problem:** Strange characters or missing parts in log messages

**Solutions:**

```bash
# Check for shell interpretation of format string
init_logger --format '%d [%l] %m'  # Use single quotes

# Verify placeholders are correct
init_logger --format "%d [%l] [%s] %m"  # Correct
init_logger --format "%d [$l] [$s] $m"  # Wrong - use %

# Test with simple format first
init_logger --format "[%l] %m"
```

## Debugging Tips

### Enable Verbose Mode

```bash
# See all log messages including DEBUG
init_logger --verbose

# Or
init_logger --level DEBUG
```

### Test with Minimal Configuration

```bash
# Start simple
init_logger
log_info "Test"

# Add options one at a time
init_logger --log "/tmp/test.log"
init_logger --log "/tmp/test.log" --level DEBUG
init_logger --log "/tmp/test.log" --level DEBUG --journal
```

### Verify Function Availability

```bash
# Check if logging functions are defined
type log_info
type init_logger
type set_log_level

# Should show: "log_info is a function"
```

### Check Initialization Return Code

```bash
if ! init_logger --log "/var/log/app.log"; then
    echo "Initialization failed!" >&2
    exit 1
fi
```

### Test Logger Command

```bash
# For journal logging issues
logger -t test "Test message"
journalctl -t test -n 1
```

## Performance Issues

### Slow Logging

**Problem:** Logging slows down script significantly

**Solutions:**

```bash
# 1. Reduce log level in production
init_logger --level WARN  # Instead of DEBUG

# 2. Disable debug logging for performance-critical sections
set_log_level INFO
# ... performance-critical code ...
set_log_level DEBUG

# 3. Disable journal logging if not needed
set_journal_logging false
# ... fast operations ...
set_journal_logging true

# 4. Use quiet mode if console output not needed
init_logger --log "/var/log/app.log" --quiet
```

## Common Error Messages

### "command not found: init_logger"

**Cause:** Module not sourced

**Solution:**

```bash
source /path/to/logging.sh
init_logger
```

### "permission denied" when writing log file

**Cause:** No write permission to log file or directory

**Solution:**

```bash
# Use writable location
init_logger --log "$HOME/logs/app.log"
mkdir -p "$HOME/logs"
```

### "invalid log level"

**Cause:** Unrecognized log level name

**Solution:**

```bash
# Use valid log levels
init_logger --level DEBUG   # Correct
init_logger --level WARN    # Correct
init_logger --level ERROR   # Correct
# Not: init_logger --level TRACE
```

## Getting Help

If you're still experiencing issues:

1. **Check the documentation:**
   * [Getting Started](getting-started.md)
   * [Initialization](initialization.md)
   * [Configuration](configuration.md)

2. **Review examples:**
   * [Examples](examples.md)

3. **Test with minimal example:**

```bash
#!/bin/bash
source /path/to/logging.sh
init_logger
log_info "Test message"
```

1. **Check your Bash version:**

```bash
bash --version
# Module requires Bash 3.0 or later
```

1. **Verify file permissions:**

```bash
ls -l /path/to/logging.sh
ls -ld /var/log/
```

## Related Documentation

* [Getting Started](getting-started.md) - Basic setup
* [Initialization](initialization.md) - Configuration options
* [Configuration](configuration.md) - Config file troubleshooting
* [Journal Logging](journal-logging.md) - Journal-specific issues
* [Examples](examples.md) - Working examples to reference
