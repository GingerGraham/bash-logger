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
  * [Understanding Error Messages Without Path Disclosure](#understanding-error-messages-without-path-disclosure)
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
  * [Newlines Replaced With Spaces](#newlines-replaced-with-spaces)
  * [Log Lines Exceed Max Length](#log-lines-exceed-max-length)
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
  * ["Configuration file not found" / "Configuration file not readable"](#configuration-file-not-found--configuration-file-not-readable)
  * ["Cannot create log directory" / "Cannot create log file"](#cannot-create-log-directory--cannot-create-log-file)
  * ["Log file path is a symbolic link"](#log-file-path-is-a-symbolic-link)
  * ["Log file is not writable" / "Failed to write to log file"](#log-file-is-not-writable--failed-to-write-to-log-file)
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

1. **Symbolic link or irregular file type**

```bash
# Error: "Log file path is a symbolic link"
# This is a security protection against TOCTOU attacks

# Check what the file actually is
ls -l /path/to/logfile.log

# If it's a symlink:
file /path/to/logfile.log

# Solution: Remove the symlink and use a direct path
rm /path/to/logfile.log
init_logger --log "/path/to/logfile.log"

# Error: "Log file exists but is not a regular file (may be a directory or device)"
# This prevents logging to devices or directories

# Check the file type
ls -ld /path/to/logfile.log

# If it's a directory, use a file path instead:
init_logger --log "/path/to/logfile.log/app.log"  # Add filename

# If it's a device or special file, use a regular file path
init_logger --log "$HOME/logs/app.log"
```

**Note:** bash-logger rejects symbolic links for security reasons. This prevents attackers from redirecting your logs to sensitive system files. Always use direct file paths for log files.

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

**Problem:** Config file has invalid values, logger sanitizes input or uses defaults

**Common Validation Errors:**

1. **Invalid Log Level**

```ini
[logging]
# Incorrect - will use default (INFO) and display warning
level = INVALID_LEVEL
level = TRACE  # Not a valid level name

# Correct values
level = DEBUG     # or INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY
level = 7         # Numeric values 0-7 are also valid
```

Error message:

```
Warning: Invalid log level 'INVALID_LEVEL' at line 2, using INFO
  Hint: Valid levels are: DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY (or 0-7)
```

1. **Invalid File Path**

```ini
[logging]
# Incorrect - must be absolute path
log_file = relative/path/file.log

# Incorrect - contains suspicious patterns
log_file = /tmp/$(whoami).log
log_file = /var/log/app.log; rm -rf /

# Correct - absolute path, no shell metacharacters
log_file = /var/log/myapp.log
log_file = /home/user/.local/share/myapp/logs/app.log
```

Error messages:

```
Error: Configuration value for 'log_file' at line 3 must be an absolute path (got: 'relative/path/file.log')
  Hint: Skipping invalid log file path

Error: Configuration value for 'log_file' at line 4 contains suspicious patterns
  Hint: Skipping invalid log file path
```

1. **Invalid Numeric Range**

```ini
[logging]
# Incorrect - exceeds maximum (1MB = 1,048,576)
max_line_length = 999999999

# Incorrect - not a number
max_line_length = unlimited

# Correct
max_line_length = 8192
max_line_length = 0  # 0 means unlimited
```

Error message:

```
Warning: Invalid max_line_length value '999999999' at line 2, expected integer 0-1048576
  Hint: Using default value of 4096
```

1. **Invalid Journal Tag**

```ini
[logging]
# Contains shell metacharacters - will be sanitized
tag = myapp-$(hostname)

# Too long - will be truncated
tag = this_is_a_very_long_tag_that_exceeds_the_sixty_four_character_maximum_length

# Correct
tag = myapp
tag = my_app-service
```

Warning messages:

```
Warning: Journal tag at line 2 contains shell metacharacters (will be sanitized)
  Hint: Sanitized journal tag to remove shell metacharacters

Error: Journal tag at line 3 exceeds maximum length of 64 (actual: 79)
  Hint: Truncated journal tag to 64 characters
```

1. **Invalid Boolean Value**

```ini
[logging]
# Incorrect - case-sensitive, must be lowercase
journal = True
verbose = YES

# Correct boolean values
journal = true   # or false, yes, no, on, off, 1, 0
verbose = yes
```

Error message:

```
Warning: Invalid journal value 'True' at line 2, expected true/false
```

1. **Unknown Configuration Key**

```ini
[logging]
# Typo or unsupported key
levl = INFO         # Should be 'level'
debug_mode = true   # Not a valid key
```

Warning message:

```
Warning: Unknown configuration key 'levl' at line 2
  Hint: Valid keys are: level, format, log_file, journal, tag, utc, color,
        stderr_level, quiet, console_log, script_name, verbose,
        unsafe_allow_newlines, unsafe_allow_ansi_codes, max_line_length, max_journal_length
```

**Resolution:**

The logger will:

* Use default values for invalid settings
* Sanitize values that can be fixed (e.g., remove shell metacharacters from tags)
* Display warnings with hints about the correct format
* Continue initialization with corrected values

**Validation Summary:**

| Configuration Item   | Validation                                         | On Error                                    |
| -------------------- | -------------------------------------------------- | ------------------------------------------- |
| `level`              | Valid level name or 0-7                            | Use INFO, display warning with valid values |
| `log_file`           | Absolute path, no control chars, no shell patterns | Skip file logging, display error            |
| `tag`                | Max 64 chars, no control chars                     | Truncate or sanitize, display warning       |
| `max_line_length`    | Integer 0-1,048,576                                | Use default (4096), display warning         |
| `max_journal_length` | Integer 0-1,048,576                                | Use default (4096), display warning         |
| Boolean values       | true/false, yes/no, on/off, 1/0 (case-insensitive) | Display warning, keep previous value        |
| All values           | Max 4,096 characters                               | Truncate, display warning                   |
| Unknown keys         | N/A                                                | Display warning with list of valid keys     |

**Solution:**

Check configuration file format and ensure all values meet the requirements listed above. Pay attention to:

* Log levels must be uppercase or numeric
* File paths must be absolute and start with `/`
* Numeric values must be within valid ranges
* Boolean values must be lowercase

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

### Understanding Error Messages Without Path Disclosure

**Background:** For security reasons (defense-in-depth against information disclosure, CWE-209), error messages
from bash-logger do not disclose file paths. This prevents potential attackers from learning about your system's
directory structure through error messages.

**Problem:** Error messages don't show the specific path that failed, making debugging harder

**Solutions:**

When you see errors like:

* `Error: Configuration file not found`
* `Error: Cannot create log directory`
* `Error: Log file is not writable`
* `Error: Log file path is a symbolic link`

Here's how to debug them:

**1. Verify Your Configuration Sources**

Check where your paths are defined:

```bash
# For configuration files, check the --config argument
init_logger --config /path/to/config.conf --verbose

# For log files, check the --log argument
init_logger --log /path/to/logfile.log --verbose

# Or check environment variables
echo "LOG_FILE: $LOG_FILE"
echo "LOG_CONFIG_FILE: $LOG_CONFIG_FILE"
```

**2. Test Path Components Individually**

```bash
# Test if directory exists
test -d "$HOME/logs" && echo "Directory exists" || echo "Directory missing"

# Test if file is writable
test -w "$HOME/logs/app.log" && echo "Writable" || echo "Not writable"

# Test if path is a symlink
test -L "$HOME/logs/app.log" && echo "Is symlink!" || echo "Not a symlink"

# Test file type
test -f "$HOME/logs/app.log" && echo "Regular file" || echo "Not a regular file"

# Test directory permissions
ls -ld "$HOME/logs"
```

**3. Enable Verbose/Debug Mode**

Debug messages include initialization details:

```bash
init_logger --log /path/to/app.log --verbose

# Output will show:
# Logger initialized with script_name='yourscript.sh': console=true,
# file=/path/to/app.log, journal=false, colors=auto, log level=DEBUG, ...
```

**4. Check Configuration File Contents**

```bash
# Verify config file path and contents
cat /path/to/config.conf

# Check for typos in paths
grep -E 'log_file|logfile|file' /path/to/config.conf
```

**5. Look at the Hints**

Error messages include actionable hints:

| Error Message                    | Hint Provided                                | What to Check                            |
| -------------------------------- | -------------------------------------------- | ---------------------------------------- |
| Configuration file not found     | Check the --config argument                  | Verify path passed to init_logger        |
| Configuration file not readable  | Check file permissions                       | Run `ls -l` on config file               |
| Cannot create log directory      | Check --log argument and parent permissions  | Verify parent directory is writable      |
| Log file path is a symbolic link | Verify --log doesn't point to symlink        | Security check, use regular file         |
| Cannot create log file           | Check directory permissions                  | Verify directory exists and is writable  |
| Log file is not a regular file   | Check --log argument                         | Might be pointing to directory or device |
| Log file is not writable         | Check file permissions                       | Run `chmod` or use different location    |
| Failed to write to log file      | Check permissions, disk space, or if deleted | Check `df -h` for disk space             |

**6. Common Path Issues**

```bash
# Issue: Relative path that doesn't exist
init_logger --log logs/app.log  # ❌ May fail if 'logs' doesn't exist

# Solution: Create directory first or use absolute path
mkdir -p logs
init_logger --log logs/app.log  # ✓ Works

# Or use absolute path
init_logger --log "$PWD/logs/app.log"  # ✓ Works

# Issue: No permission to create parent directories
init_logger --log /var/log/myapp/app.log  # ❌ May fail if /var/log/myapp doesn't exist

# Solution: Create directory with proper permissions first
sudo mkdir -p /var/log/myapp
sudo chown $USER:$USER /var/log/myapp
init_logger --log /var/log/myapp/app.log  # ✓ Works

# Issue: Accidentally pointing to a directory
init_logger --log /tmp/myapp  # ❌ If /tmp/myapp is a directory

# Solution: Add filename
init_logger --log /tmp/myapp/app.log  # ✓ Works
```

**Why This Approach?**

Not displaying paths in error messages is a security best practice:

* Prevents information disclosure (CWE-209)
* Reduces reconnaissance data for attackers
* Protects usernames in $HOME paths
* Provides defense-in-depth

The paths are still available through:

* Command-line arguments you passed
* Configuration files you created
* Environment variables you set
* Debug output when using `--verbose`

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

### Newlines Replaced With Spaces

**Problem:** Multi-line messages are flattened into a single line

**Cause:** bash-logger sanitizes newline, carriage return, and tab characters by default
to prevent log injection attacks.

**Solutions:**

```bash
# Preferred: Keep the secure default and sanitize input yourself if needed
safe_input=${user_input//$'\n'/ }
safe_input=${safe_input//$'\r'/ }
safe_input=${safe_input//$'\t'/ }
log_info "User input: $safe_input"

# If you fully control inputs and accept the risk (NOT RECOMMENDED):
init_logger --unsafe-allow-newlines

# Or enable it at runtime (NOT RECOMMENDED):
set_unsafe_allow_newlines true
```

**Warning:** Allowing newlines can enable log injection and audit log forgery.

### Log Lines Exceed Max Length

**Problem:** Final log output exceeds the `--max-line-length` setting

**Explanation:** The `--max-line-length` option truncates the **message portion** before
formatting. The final output includes timestamp, level, and script name added after
truncation, which can push the total line length beyond the specified limit.

**Example:**

```bash
# With --max-line-length 50
init_logger --max-line-length 50 --format "%d [%l] [%s] %m"

log_info "This is a very long message that exceeds fifty characters"
# Output (approx 90 chars total):
# 2025-02-10 15:30:45 [INFO] [script.sh] This is a very lo...[truncated]
# The message is truncated to 50 chars, but prefix adds ~40 more
```

**Solutions:**

```bash
# Option 1: Account for prefix length when setting limit
# If format adds ~40 chars, use --max-line-length of 60 for ~100 char final lines
init_logger --max-line-length 60

# Option 2: Use simpler format to reduce prefix overhead
init_logger --format "[%l] %m" --max-line-length 100

# Option 3: Disable truncation if precise line length not critical
init_logger --max-line-length 0  # Unlimited
```

**References:** See [Configuration](configuration.md) for details on `max_line_length` setting.

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

### "Configuration file not found" / "Configuration file not readable"

**Cause:** Config file path is incorrect or file has wrong permissions

**Solution:**

See [Understanding Error Messages Without Path Disclosure](#understanding-error-messages-without-path-disclosure) for detailed debugging steps.

```bash
# Verify config file exists
ls -l /path/to/config.conf

# Check it's readable
cat /path/to/config.conf

# Use absolute path
init_logger --config "$(pwd)/config.conf"
```

### "Cannot create log directory" / "Cannot create log file"

**Cause:** No permissions to create directory or file

**Solution:**

See [Understanding Error Messages Without Path Disclosure](#understanding-error-messages-without-path-disclosure) for detailed debugging steps.

```bash
# Check parent directory exists and is writable
ls -ld /var/log/

# Create directory manually with proper permissions
mkdir -p "$HOME/logs"
init_logger --log "$HOME/logs/app.log"
```

### "Log file path is a symbolic link"

**Cause:** Log file path points to a symbolic link (security check)

**Solution:**

See [Understanding Error Messages Without Path Disclosure](#understanding-error-messages-without-path-disclosure) for detailed debugging steps.

```bash
# Remove symlink and use direct path
rm /path/to/symlink.log
init_logger --log /path/to/actual.log

# Or find where symlink points and use target
ls -l /path/to/symlink.log  # shows -> /actual/path.log
init_logger --log /actual/path.log
```

**Note:** bash-logger rejects symbolic links for security reasons to prevent log redirection attacks.

### "Log file is not writable" / "Failed to write to log file"

**Cause:** File exists but lacks write permissions, or disk is full

**Solution:**

See [Understanding Error Messages Without Path Disclosure](#understanding-error-messages-without-path-disclosure) for detailed debugging steps.

```bash
# Check file permissions
ls -l "$LOG_FILE_PATH"

# Fix permissions
chmod 644 "$LOG_FILE_PATH"

# Check disk space
df -h /path/to/log/directory/
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
