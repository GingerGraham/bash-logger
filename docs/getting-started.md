# Getting Started <!-- omit in toc -->

This guide will help you get started with the Bash Logging Module quickly.

## Table of Contents <!-- omit in toc -->

* [Workflows](#workflows)
  * [Linting Workflows](#linting-workflows)
* [Installation](#installation)
  * [Common Installation Locations](#common-installation-locations)
  * [Using the Install Script](#using-the-install-script)
  * [Manual Installation](#manual-installation)
    * [Example Installation](#example-installation)
    * [Installing from a Tagged Release](#installing-from-a-tagged-release)
      * [Verifying the Download with SHA256](#verifying-the-download-with-sha256)
  * [Install with bpkg](#install-with-bpkg)
    * [Update an existing installation:](#update-an-existing-installation)
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

bash-logger can be installed in several ways. Choose the method that best fits your needs.

### Common Installation Locations

* `/usr/local/lib/bash-logger/logging.sh` - System-wide installation
* `$HOME/.local/lib/bash-logger/logging.sh` - User-specific installation
* Project directory - Alongside your script

### Using the Install Script

The easiest way to install bash-logger is with the provided installation script. It handles downloading the latest release
and setting up the module for you. For integrity verification, see
[Verifying the Download with SHA256](#verifying-the-download-with-sha256).

**Quick Install (User):**

```bash
curl -fsSL https://raw.githubusercontent.com/GingerGraham/bash-logger/main/install.sh | bash
```

**System-wide Installation (requires sudo):**

```bash
curl -fsSL https://raw.githubusercontent.com/GingerGraham/bash-logger/main/install.sh | sudo bash -s -- --system
```

**Custom Location:**

```bash
curl -fsSL https://raw.githubusercontent.com/GingerGraham/bash-logger/main/install.sh | bash -s -- --prefix ~/tools
```

**Additional Options:**

* `--user` - Install for current user only (default)
* `--system` - Install system-wide (requires root)
* `--prefix PATH` - Custom installation prefix
* `--auto-rc` - Automatically add source line to shell RC file
* `--no-backup` - Skip backing up existing installation

For more details, see the [install script documentation](../install.sh).

### Manual Installation

If you prefer to install manually, simply place the `logging.sh` file in a directory of your choice. The module is a single, self-contained script that can
be sourced from any location.

#### Example Installation

```bash
# System-wide (requires sudo)
sudo mkdir -p /usr/local/lib/bash-logger
sudo curl -o /usr/local/lib/bash-logger/logging.sh https://raw.githubusercontent.com/GingerGraham/bash-logger/main/logging.sh
sudo chmod 644 /usr/local/lib/bash-logger/logging.sh

# User-specific
mkdir -p ~/.local/lib/bash-logger
curl -o ~/.local/lib/bash-logger/logging.sh https://raw.githubusercontent.com/GingerGraham/bash-logger/main/logging.sh
chmod 644 ~/.local/lib/bash-logger/logging.sh

# Project directory
curl -o ./logging.sh https://raw.githubusercontent.com/GingerGraham/bash-logger/main/logging.sh
chmod 644 ./logging.sh
```

#### Installing from a Tagged Release

If you prefer to use a specific stable release version instead of the main branch, you can download directly from
GitHub releases:

```bash
# Get the latest release version
LATEST_VERSION=$(curl -s https://api.github.com/repos/GingerGraham/bash-logger/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)

echo "Latest version: $LATEST_VERSION"

# Download the logging.sh file from the release
curl -L -o logging.sh "https://github.com/GingerGraham/bash-logger/releases/download/${LATEST_VERSION}/logging.sh"
chmod 644 logging.sh
```

This approach ensures you're using a stable, tagged release rather than the development version. The GitHub releases
page at [bash-logger releases](https://github.com/GingerGraham/bash-logger/releases) shows all available versions and
their release notes.

##### Verifying the Download with SHA256

It's recommended to verify the integrity of downloaded files using SHA256 checksums. Here's how to do it on different
platforms:

**Linux:**

```bash
# Download the checksum file
curl -L -o logging.sh.sha256 "https://github.com/GingerGraham/bash-logger/releases/download/${LATEST_VERSION}/logging.sh.sha256"

# Verify the file
sha256sum -c logging.sh.sha256
```

Expected output on success:

```
logging.sh: OK
```

**macOS:**

```bash
# Download the checksum file
curl -L -o logging.sh.sha256 "https://github.com/GingerGraham/bash-logger/releases/download/${LATEST_VERSION}/logging.sh.sha256"

# Verify the file (macOS uses shasum)
shasum -a 256 -c logging.sh.sha256
```

Expected output on success:

```
logging.sh: OK
```

**Windows (PowerShell):**

```powershell
# Get the latest release version
$releases = Invoke-WebRequest -Uri "https://api.github.com/repos/GingerGraham/bash-logger/releases/latest" | ConvertFrom-Json
$LATEST_VERSION = $releases.tag_name

# Download the logging.sh file
Invoke-WebRequest -Uri "https://github.com/GingerGraham/bash-logger/releases/download/$LATEST_VERSION/logging.sh" -OutFile "logging.sh"

# Download the checksum file
Invoke-WebRequest -Uri "https://github.com/GingerGraham/bash-logger/releases/download/$LATEST_VERSION/logging.sh.sha256" -OutFile "logging.sh.sha256"

# Read the expected checksum from the file
$expectedChecksum = (Get-Content logging.sh.sha256).Split()[0].ToLower()

# Calculate the actual checksum
$actualChecksum = (Get-FileHash -Path logging.sh -Algorithm SHA256).Hash.ToLower()

# Compare checksums
if ($expectedChecksum -eq $actualChecksum) {
    Write-Host "✓ Checksum verified successfully!" -ForegroundColor Green
} else {
    Write-Host "✗ Checksum mismatch! File may be corrupted or tampered with." -ForegroundColor Red
    exit 1
}
```

**Manual Verification (All Platforms):**

If you prefer to manually compare checksums:

1. Download `logging.sh.sha256` from the releases page
2. Open the file and note the checksum value (first 64 characters)
3. Calculate your file's checksum:
   * **Linux/macOS:** `sha256sum logging.sh` or `shasum -a 256 logging.sh`
   * **Windows (PowerShell):** `(Get-FileHash -Path logging.sh -Algorithm SHA256).Hash`
4. Compare the two values - they should match exactly

### Install with bpkg

For users of the [`bpkg` package manager](https://www.bpkg.sh/), bash-logger can be easily installed and managed.

For a consistent experience the configuration for `bpkg` is set to always use the global installation option.
As such, the installation location will be: `${HOME}/.local/lib/bash-logger/logging.sh`.

```bash
# Install the package
bpkg install GingerGraham/bash-logger@main

# Source in your script
source ${HOME}/.local/lib/bash-logger/logging.sh
init_logger
log_info "Installed via bpkg!"
```

**Note:** the `@main` branch reference **is required** as `bpkg` defaults to looking for
the `master` branch, which does not exist in this repository.

#### Update an existing installation:

```bash
bpkg update bash-logger
```

`bpkg` does not support true, system-wide, global installations (i.e. `/usr/local/lib`), so the recommendation
for these scenarios is to use the standard installation method described above, allowing users to determine the
best location for their system.

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

* **[API Reference](api-reference.md)** - Complete function reference
* [Log Levels](log-levels.md) - Learn about all available log levels
* [Initialization](initialization.md) - Explore all initialization options
* [Configuration](configuration.md) - Use configuration files for complex setups
* [Examples](examples.md) - See comprehensive usage examples
