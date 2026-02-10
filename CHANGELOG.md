# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0](https://github.com/GingerGraham/bash-logger/compare/1.3.0...2.0.0) (2026-02-09)

### ⚠ BREAKING CHANGES

* changes behaviour for messages passed to the logger and so revving to v2.x
  * Logging API interface is consistent but significant changes to how message text is handled to prevent log
    injection and other issues related to newlines and control characters.

* feat: enhance logging sanitization

* Introduced a comprehensive security review document for the bash-logger library, detailing vulnerabilities and recommendations.
* Implemented input sanitization to prevent log injection via newline, carriage return, and tab characters.
* Added a configuration option to allow unsafe logging of newlines, with appropriate warnings and documentation.
* Enhanced tests to cover new functionality related to unsafe logging and input sanitization.
* Updated troubleshooting documentation to reflect changes in newline handling and logging behavior.
* Included security research findings from 2026-02-04 for evidence

### Features

* adding defensive programming and bug fixes ([#56](https://github.com/GingerGraham/bash-logger/issues/56))
  ([62b717a](https://github.com/GingerGraham/bash-logger/commit/62b717aac4d5f23f8ae92e278756f05752637a79)),
  closes [#35](https://github.com/GingerGraham/bash-logger/issues/35)
  [#36](https://github.com/GingerGraham/bash-logger/issues/36)
  [#39](https://github.com/GingerGraham/bash-logger/issues/39)
  [#41](https://github.com/GingerGraham/bash-logger/issues/41)
  [#49](https://github.com/GingerGraham/bash-logger/issues/49)
  [#52](https://github.com/GingerGraham/bash-logger/issues/52)
  [#52](https://github.com/GingerGraham/bash-logger/issues/52)
  [#54](https://github.com/GingerGraham/bash-logger/issues/54)
* **ref:** primary git message ([a0a7a09](https://github.com/GingerGraham/bash-logger/commit/a0a7a094ab9a22be454bd3e7ebf3aff514ce3c00))

### Documentation

* adding download tracking ([001f03b](https://github.com/GingerGraham/bash-logger/commit/001f03be0ad67d4bf86011261c5e9bdaccb1fb57))

## [1.3.0](https://github.com/GingerGraham/bash-logger/compare/1.2.2...1.3.0) (2026-01-31)

### Features

* add custom script name functionality and update documentation ([#33](https://github.com/GingerGraham/bash-logger/issues/33))
  ([3eb4ba0](https://github.com/GingerGraham/bash-logger/commit/3eb4ba0ba5e18ecfa9c2ab7e3897976a96acf3d1)), closes [#28](https://github.com/GingerGraham/bash-logger/issues/28)

## [1.2.2](https://github.com/GingerGraham/bash-logger/compare/1.2.1...1.2.2) (2026-01-25)

### Bug Fixes

* adding install script option ([#21](https://github.com/GingerGraham/bash-logger/issues/21)) ([382b8bc](https://github.com/GingerGraham/bash-logger/commit/382b8bcb8cf091160ef083cce9896883eea1b71a)),
  closes [#22](https://github.com/GingerGraham/bash-logger/issues/22)
* disable journal logging by default ([#27](https://github.com/GingerGraham/bash-logger/issues/27)) ([9b378e7](https://github.com/GingerGraham/bash-logger/commit/9b378e70ff4e05041803822493a125d6e8b9511f))

## [1.2.1](https://github.com/GingerGraham/bash-logger/compare/1.2.0...1.2.1) (2026-01-21)

### Bug Fixes

* add bpkg support and update release preparation commands
  ([#14](https://github.com/GingerGraham/bash-logger/issues/14)) ([a577cfc](https://github.com/GingerGraham/bash-logger/commit/a577cfc5591848a0bdda03f053a53636506c2b05)),
  closes [#13](https://github.com/GingerGraham/bash-logger/issues/13)
* **bpkg:** resolved installation issue and updated documentation
  ([#17](https://github.com/GingerGraham/bash-logger/issues/17))
  ([1a3ff44](https://github.com/GingerGraham/bash-logger/commit/1a3ff440de9143fb686c0dc62a4c23e00904ee9c)), closes [#15](https://github.com/GingerGraham/bash-logger/issues/15)
  [#16](https://github.com/GingerGraham/bash-logger/issues/16)
* trigger manual patch release [skip ci] ([7f601e6](https://github.com/GingerGraham/bash-logger/commit/7f601e6fc87f1c9f036e5ac051a5205b4e8f248f))

### Documentation

* add Contributor Covenant Code of Conduct ([0e96703](https://github.com/GingerGraham/bash-logger/commit/0e96703ba006dfa19bfdc30ae7d6491e31361198))
* improve README formatting and clarify author attribution ([b68cc08](https://github.com/GingerGraham/bash-logger/commit/b68cc0851e8df3e86e5fa275d2d5ea01cc1fb45d))
* update SECURITY.md for clarity and formatting improvements ([fe9ddbf](https://github.com/GingerGraham/bash-logger/commit/fe9ddbf9f919f83cfe200018a376017f6ee83890))

## [1.2.0](https://github.com/GingerGraham/bash-logger/compare/1.1.0...1.2.0) (2026-01-19)

### Features

* refactor console logging ([#10](https://github.com/GingerGraham/bash-logger/issues/10)) ([b74cc31](https://github.com/GingerGraham/bash-logger/commit/b74cc31caabf22bbf0741726ad8084afd5ba812f))

## [1.1.0](https://github.com/GingerGraham/bash-logger/compare/1.0.0...1.1.0) (2026-01-19)

### Features

* enhance release packaging and documentation for standalone module ([#9](https://github.com/GingerGraham/bash-logger/issues/9)) ([8ed0017](https://github.com/GingerGraham/bash-logger/commit/8ed0017fffffbf16ed569e8e70d520a1453f306b))

### Bug Fixes

* trigger manual patch release [skip ci] ([bfd9559](https://github.com/GingerGraham/bash-logger/commit/bfd9559bad16511b014697483d5a23cf3f4b7a63))

## [1.0.0](https://github.com/GingerGraham/bash-logger/compare/0.11.0...1.0.0) (2026-01-17)

### ⚠ BREAKING CHANGES

* mark the public API stable and start the 1.x support window.

### Features

* add breaking change rule for major releases ([f6e975e](https://github.com/GingerGraham/bash-logger/commit/f6e975e51d65a3b8182bfe02023858d8f94eb88d))
* declare stable 1.0 API ([04be3f9](https://github.com/GingerGraham/bash-logger/commit/04be3f97ef3d9ed13f3332d2d44aada5bf82a148))

## [0.11.0](https://github.com/GingerGraham/bash-logger/compare/0.10.4...0.11.0) (2026-01-17)

### ⚠ BREAKING CHANGES

* mark the public API stable and start the 1.x support window.

### Features

* declare stable 1.0 API ([0cb133f](https://github.com/GingerGraham/bash-logger/commit/0cb133f56c1a2f53118fdc9b557567fa9a300bc4))

## [0.10.4](https://github.com/GingerGraham/bash-logger/compare/0.10.3...0.10.4) (2026-01-17)

### Bug Fixes

* trigger manual patch release [skip ci] ([0fe47c6](https://github.com/GingerGraham/bash-logger/commit/0fe47c6494d84869715f7be969e49ab4a450dc6c))

### Code Refactoring

* documentation for consistency and clarity ([4f3ff26](https://github.com/GingerGraham/bash-logger/commit/4f3ff26ac1c524a0eaeac325d212578258d7ba7e))

### Documentation

* enhance issue templates and add security policy documentation ([cd2b145](https://github.com/GingerGraham/bash-logger/commit/cd2b145c3ce7ee04aeb323f212ca2b74141c6d73))

## [0.10.3](https://github.com/GingerGraham/bash-logger/compare/0.10.2...0.10.3) (2026-01-17)

### Bug Fixes

* trigger manual patch release [skip ci] ([e62ad75](https://github.com/GingerGraham/bash-logger/commit/e62ad75bdff03dbc432eb4636a02fcf041382cc2))

## [0.10.2](https://github.com/GingerGraham/bash-logger/compare/0.9.0...0.10.2) (2026-01-17)

### Added

* Changelog file to track project changes

### Features

* implement automated release workflow with semantic-release
* add consumer-friendly release packages (tar.gz and zip with checksums)
* add BASH_LOGGER_VERSION constant to logging.sh for version tracking

### Bug Fixes

* **docs:** clean up duplicate CHANGELOG entries from failed releases ([456f81d](https://github.com/GingerGraham/bash-logger/commit/456f81d5ff85c055ec8008edc0a0291c6dfeefd7))
* remove redundant comments in parse_config_file function ([66414f2](https://github.com/GingerGraham/bash-logger/commit/66414f21ca93b464fa9a771ac2f71162fd93af76))
* **ci:** use glob patterns for release asset upload
* **ci:** use PAT token to work around phantom tag restrictions

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
