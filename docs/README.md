# Bash Logger Documentation

Welcome to the bash-logger documentation! This directory contains comprehensive guides for using bash-logger.

## Getting Started

New to bash-logger? Start here:

* **[Getting Started](getting-started.md)** - Installation and first steps
* **[Examples](examples.md)** - Comprehensive code examples

## Core Guides

Essential documentation for common use cases:

* **[Log Levels](log-levels.md)** - Understanding severity levels (DEBUG, INFO, WARN, ERROR, etc.)
* **[Initialization](initialization.md)** - Setting up the logger with command-line options
* **[Configuration](configuration.md)** - Using INI configuration files for persistent settings
* **[Output Streams](output-streams.md)** - Controlling stdout/stderr behavior

## Advanced Topics

Deep dives into specific features:

* **[Formatting](formatting.md)** - Customizing log message templates
* **[Journal Logging](journal-logging.md)** - Integration with systemd journal
* **[Runtime Configuration](runtime-configuration.md)** - Changing settings without reinitialization
* **[Sensitive Data](sensitive-data.md)** - Secure handling of passwords and secrets

## Reference

* **[API Reference](api-reference.md)** - Complete function reference
* **[Troubleshooting](troubleshooting.md)** - Common issues and solutions
* **[Shell Compatibility](shell-compatibility.md)** - Supported shells (bash, zsh, dash, busybox ash) and their differences
* **[Upgrading to 3.0](upgrading-to-3.0.md)** - What changed from 2.x
* **[Testing](testing.md)** - Guide to the test suite
* **[Writing Tests](writing-tests.md)** - Contributor guide for writing and structuring tests
* **[Releases](releases.md)** - Release process and versioning

## Contributing

* **[PRE-COMMIT](PRE-COMMIT.md)** - Setting up pre-commit hooks for development
* **[logging.sh Architecture Reference](../architecture/logging-sh-reference.md)** - How `logging.sh` is structured: every internal function, the call graph and the
  design patterns (describes version 3.0.3)
* **[Test Suite Reference](../architecture/tests-reference.md)** - How the test suite is structured: the runner, the helper library, every suite and the cross-shell
  machinery (describes version 3.0.3)

## Quick Links

* [Main README](../README.md) - Project overview
* [Contributing Guidelines](../CONTRIBUTING.md) - How to contribute
* [Changelog](../CHANGELOG.md) - Version history

## Need Help?

* Check the [Troubleshooting Guide](troubleshooting.md)
* Review [Examples](examples.md) for code samples
* [Open an issue](https://github.com/GingerGraham/bash-logger/issues/new/choose) on GitHub
