# Demo Scripts

This directory contains demonstration scripts that showcase the features of the bash-logger module.

## Quick Start

### Interactive Mode

Run the demo launcher with an interactive menu:

```bash
./run_demos.sh
```

### Run All Demos

Execute all demonstration scripts in sequence:

```bash
./run_demos.sh all
```

### Run Specific Demo

Run a single demonstration by name:

```bash
./run_demos.sh log-levels
./run_demos.sh formatting
./run_demos.sh journal
```

Use `./run_demos.sh --list` to see all available demo names.

## Available Demos

Each demo is self-contained and can be run independently.

### 1. Log Levels (`demo_log_levels.sh`)

Demonstrates how to use and configure different log levels:

* Default INFO level behavior
* Changing levels dynamically with `set_log_level()`
* Using `--level` parameter during initialization
* Using `--verbose` flag for DEBUG level
* All 8 syslog standard levels (DEBUG through EMERGENCY)

**Run:** `./demo_log_levels.sh` or `./run_demos.sh log-levels`

### 2. Log Formatting (`demo_formatting.sh`)

Shows various log format customization options:

* Default format
* Custom format templates
* Format placeholders (%d, %l, %s, %m, %z)
* JSON-like formats
* Runtime format changes with `set_log_format()`

**Run:** `./demo_formatting.sh` or `./run_demos.sh formatting`

### 3. Timezone Settings (`demo_timezone.sh`)

Demonstrates UTC vs local time in log messages:

* Enabling UTC timestamps with `--utc` flag
* Switching between UTC and local time at runtime
* Displaying timezone information in log format

**Run:** `./demo_timezone.sh` or `./run_demos.sh timezone`

### 4. Journal Logging (`demo_journal.sh`)

Shows systemd journal integration:

* Enabling journal logging with `--journal` flag
* Using custom journal tags
* Dynamic journal logging control
* Verifying sensitive messages don't go to journal

**Note:** Requires the `logger` command to be available.

**Run:** `./demo_journal.sh` or `./run_demos.sh journal`

### 5. Color Settings (`demo_colors.sh`)

Demonstrates color output configuration:

* Auto-detection of terminal color support
* Forcing colors on with `--color`
* Forcing colors off with `--no-color`
* Runtime color mode changes

**Run:** `./demo_colors.sh` or `./run_demos.sh colors`

### 6. Stderr Levels (`demo_stderr.sh`)

Shows how to control which messages go to stderr vs stdout:

* Default stderr behavior (ERROR and above)
* Configuring stderr level with `--stderr-level`
* Testing output stream separation
* Redirecting specific log levels

**Run:** `./demo_stderr.sh` or `./run_demos.sh stderr`

### 7. Combined Features (`demo_combined.sh`)

Demonstrates using multiple features together:

* UTC time + custom format + colors + journal logging
* Initializing with multiple options at once

**Run:** `./demo_combined.sh` or `./run_demos.sh combined`

### 8. Quiet Mode (`demo_quiet.sh`)

Shows how to suppress console output:

* Using `--quiet` flag
* Verifying logs still go to file and journal
* Useful for background scripts

**Run:** `./demo_quiet.sh` or `./run_demos.sh quiet`

### 9. Configuration Files (`demo_config.sh`)

Demonstrates loading settings from INI files:

* Creating and using configuration files
* Loading config with `--config` parameter
* CLI options overriding config file settings
* Multiple configuration profiles

**Run:** `./demo_config.sh` or `./run_demos.sh config`

### 10. Log Injection Prevention (`demo_unsafe_newlines.sh`)

Demonstrates newline sanitization and the unsafe mode override:

* Default secure behavior that removes newlines
* Unsafe mode that preserves newlines (with warnings)
* CLI, config file, and runtime toggles
* Security guidance and best practices

**Run:** `./demo_unsafe_newlines.sh` or `./run_demos.sh unsafe-newlines`

## Log Files

All demos create log files in the `../logs/` directory:

* `demo_log_levels.log`
* `demo_formatting.log`
* `demo_timezone.log`
* `demo_journal.log`
* `demo_colors.log`
* `demo_stderr.log`
* `demo_combined.log`
* `demo_quiet.log`
* `demo_config.log`

**Note:** The log injection prevention demo uses a temporary directory so it can show
side-by-side secure vs unsafe output without overwriting other demo logs.

## Original Comprehensive Demo

The original comprehensive demo script (`log_demo.sh`) has been preserved and contains all features in a single file.
This may be useful for seeing all features in one continuous run, but the individual demos are recommended for learning and testing specific features.

## Writing Your Own Scripts

Each demo script follows a simple pattern that you can use as a template:

```bash
#!/bin/bash
# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Path to logger module
LOGGER_PATH="${PARENT_DIR}/logging.sh"

# Source the logger module
source "$LOGGER_PATH"

# Initialize logger
init_logger --log "/path/to/logfile.log"

# Use logging functions
log_info "Your message here"
```

See the individual demo scripts for more complete examples.

## Troubleshooting

### Logger Command Not Found

Some demos (journal logging, combined features, quiet mode) require the `logger` command for systemd journal integration. If not available, those features will be automatically skipped.

### Permission Denied

Make sure the demo scripts are executable:

```bash
chmod +x *.sh
```

### Log Directory Not Found

The demos automatically create the `../logs/` directory if it doesn't exist.

## More Information

For complete documentation, see:

* [Getting Started Guide](../docs/getting-started.md)
* [Configuration Documentation](../docs/configuration.md)
* [Examples](../docs/examples.md)
