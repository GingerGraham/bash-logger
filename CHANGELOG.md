# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.10.0](https://github.com/GingerGraham/bash-logger/compare/0.9.0...0.10.0) (2026-01-17)

### Features

* implement automated release workflow with semantic-release ([0cb89ca](https://github.com/GingerGraham/bash-logger/commit/0cb89ca75baf53374d91878a66bd1c2491111ee7))

### Bug Fixes

* **ci:** use glob patterns for release asset upload ([fb828d8](https://github.com/GingerGraham/bash-logger/commit/fb828d876caf00438a938c23f94bee1909b9c1b7))
* update GitHub token to use PAT_TOKEN for release workflow ([eb0da6e](https://github.com/GingerGraham/bash-logger/commit/eb0da6e7c8753206d231a17e3e456cea9ddeb011))

## [0.10.0](https://github.com/GingerGraham/bash-logger/compare/0.9.0...0.10.0) (2026-01-17)

### Features

* implement automated release workflow with semantic-release ([0cb89ca](https://github.com/GingerGraham/bash-logger/commit/0cb89ca75baf53374d91878a66bd1c2491111ee7))

### Bug Fixes

* **ci:** use glob patterns for release asset upload ([fb828d8](https://github.com/GingerGraham/bash-logger/commit/fb828d876caf00438a938c23f94bee1909b9c1b7))

## [0.10.0](https://github.com/GingerGraham/bash-logger/compare/0.9.0...0.10.0) (2026-01-17)

### Features

* implement automated release workflow with semantic-release ([0cb89ca](https://github.com/GingerGraham/bash-logger/commit/0cb89ca75baf53374d91878a66bd1c2491111ee7))

### Bug Fixes

* **ci:** use glob patterns for release asset upload ([fb828d8](https://github.com/GingerGraham/bash-logger/commit/fb828d876caf00438a938c23f94bee1909b9c1b7))

## [0.10.0](https://github.com/GingerGraham/bash-logger/compare/0.9.0...0.10.0) (2026-01-16)

### Features

* implement automated release workflow with semantic-release ([0cb89ca](https://github.com/GingerGraham/bash-logger/commit/0cb89ca75baf53374d91878a66bd1c2491111ee7))

## [Unreleased]

### Added

* Changelog file to track project changes

## [0.9.0] - 2026-01-16

### Added

* Configuration file support for persistent logger settings
* Example configuration file (`configuration/logging.conf.example`)
* Comprehensive documentation for configuration file usage
* Control over which log levels are redirected to stderr vs stdout
* Runtime configuration change support

### Changed

* Streamlined inline documentation for better readability
* Improved documentation structure and formatting across multiple files

## [0.8.0] - 2025-07-02

### Added

* Full syslog-compliant log level support (8 levels: EMERGENCY, ALERT, CRITICAL, ERROR, WARN, NOTICE, INFO, DEBUG)
* Additional log functions: `log_notice()`, `log_critical()`, `log_alert()`, `log_emergency()`
* `LOG_LEVEL_FATAL` alias for `LOG_LEVEL_EMERGENCY` for backward compatibility
* Sensitive data logging function (`log_sensitive()`) - console only, never to file or journal
* Color-coded output support with automatic terminal detection
* Manual color control options (`--color`, `--no-color`)
* Support for `NO_COLOR`, `CLICOLOR`, and `CLICOLOR_FORCE` environment variables
* Custom log format templates with variable substitution
  * Format variables: `%d` (date), `%z` (timezone), `%l` (level), `%s` (script), `%m` (message)
* UTC timestamp support (`--utc` flag and `USE_UTC` setting)
* Systemd journal integration via `logger` command
* Optional journal tagging for better log filtering
* Script name detection and inclusion in log messages
* Advanced color detection supporting multiple terminal types
* Helper functions:
  * `get_log_level_value()` - Convert log level names to numeric values
  * `get_log_level_name()` - Convert numeric values to level names
  * `check_logger_available()` - Check for systemd journal support
  * `detect_color_support()` - Intelligent terminal color capability detection
  * `should_use_colors()` - Determine if colors should be used based on settings

### Changed

* Updated shebang from `#!/bin/bash` to `#!/usr/bin/env bash` for better portability
* Renamed from `bash_logger.sh` to `logging.sh`
* Revised log level numbering to follow syslog standard (0=most severe, 7=least severe)
  * Previous: DEBUG=0, INFO=1, WARN=2, ERROR=3
  * Current: EMERGENCY=0, ALERT=1, CRITICAL=2, ERROR=3, WARN=4, NOTICE=5, INFO=6, DEBUG=7
* Enhanced `init_logger()` with additional options:
  * `-d|--level LEVEL` - Set log level by name or number
  * `-f|--format FORMAT` - Set custom log format template
  * `-j|--journal` - Enable journal logging
  * `-t|--tag TAG` - Set journal tag
  * `--utc` - Use UTC timestamps
  * `--color` / `--no-color` - Force color usage
* Improved log message formatting with customizable templates
* Enhanced error handling and validation throughout
* Better documentation in code comments

### Fixed

* Log file directory validation and permission checking
* Proper handling of log levels in filtering logic

### Development Notes

This version represents the cumulative result of approximately 13 iterative commits made
between March and July 2025 during the gist phase of development. These commits were made
without descriptive messages as features were being explored and refined. The changes listed
above reflect the complete feature set that existed by July 2, 2025, when the module reached
functional maturity before being formalized into a repository structure.

## [0.1.0] - 2025-03-03

### Added

* Initial release of reusable Bash logging module
* Basic logging functions: `log_debug()`, `log_info()`, `log_warn()`, `log_error()`
* `init_logger()` function with options:
  * `-l|--log FILE` - Write logs to file
  * `-q|--quiet` - Disable console output
  * `-v|--verbose` - Enable debug level logging
* Four log levels: DEBUG (0), INFO (1), WARN (2), ERROR (3)
* Configurable console and file output
* Timestamp inclusion in log messages (format: YYYY-MM-DD HH:MM:SS)
* Log file validation and permission checking
* Demo script (`log-demo.sh`) showing usage examples

### Implementation Details

* Pure Bash implementation with no external dependencies (except optional `logger` for journal support)
* Designed to be sourced by other scripts
* Global configuration variables for easy customization
* Safe default settings (INFO level, console output enabled)

---

## Version History

* **0.9.0** (2026-01-16): Configuration file support and stderr redirection control
* **0.8.0** (2025-07-02): Full syslog compliance, colors, journal integration, custom formatting
* **0.1.0** (2025-03-03): Initial release with basic logging functionality

## Development Notes

This project originated as a GitHub Gist and was converted to a full repository in early 2026.
The initial development (versions 0.1.0 through 0.8.0) occurred during the gist phase with
iterative improvements to functionality, documentation, and standards compliance.

Version 0.9.0 marks the transition to a formal repository structure with:

* Comprehensive test suite (103 tests across 6 test suites)
* CI/CD pipelines with automated linting (ShellCheck, MarkdownLint)
* Pre-commit hooks for code quality
* Extensive documentation (10+ markdown files)
* Demo scripts showcasing all features
* Semantic commit messages for automated release management
* Community contribution guidelines

The project is approaching a 1.0.0 stable release.

[unreleased]: https://github.com/GingerGraham/bash-logger/compare/v0.9.0...HEAD
[0.9.0]: https://github.com/GingerGraham/bash-logger/releases/tag/v0.9.0
[0.8.0]: https://github.com/GingerGraham/bash-logger/releases/tag/v0.8.0
[0.1.0]: https://github.com/GingerGraham/bash-logger/releases/tag/v0.1.0
