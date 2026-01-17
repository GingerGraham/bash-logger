# Bash Logger

A flexible, reusable logging module for Bash scripts that provides standardized logging functionality with various configuration options.

> [!NOTE]
> This is a expansion of the originally published [bash_logging GitHub gist](https://gist.github.com/GingerGraham/99af97eed2cd89cd047a2088947a5405) published by @GingerGraham.

## Primary artifact

The core deliverable of this repository is **[logging.sh](logging.sh)**. It is intentionally kept
as a single, self-contained (and yes, long) Bash file so you can drop it next to your
scripts and `source` it without any packaging steps. Everything else in the repo - docs,
demos, and pipeline scripts - exists to support using that file.

## Features

* Standard syslog log levels (DEBUG, INFO, WARN, ERROR, CRITICAL, etc.)
* Console output with color-coding by severity
* Configurable stdout/stderr output stream split
* Optional file output
* Optional systemd journal logging
* Customizable log format
* UTC or local time support
* INI configuration file support
* Runtime configuration changes
* Special handling for sensitive data

## Quick Start

```bash
# Source the logging module
source /path/to/logging.sh

# Initialize the logger
init_logger

# Log messages
log_info "Application started"
log_error "Something went wrong"
```

See [Getting Started](docs/getting-started.md) for detailed installation and basic usage instructions.

## Documentation

### Core Documentation

* [Getting Started](docs/getting-started.md) - Installation and basic usage
* [Log Levels](docs/log-levels.md) - Understanding severity levels
* [Initialization](docs/initialization.md) - Configuring the logger at startup
* [Configuration](docs/configuration.md) - Using configuration files

### Advanced Topics

* [Output Streams](docs/output-streams.md) - Controlling stdout/stderr behavior
* [Formatting](docs/formatting.md) - Customizing log message format
* [Journal Logging](docs/journal-logging.md) - Integration with systemd journal
* [Runtime Configuration](docs/runtime-configuration.md) - Changing settings on the fly
* [Sensitive Data](docs/sensitive-data.md) - Handling sensitive information securely

### Reference

* [Examples](docs/examples.md) - Comprehensive usage examples
* [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions

## Common Use Cases

### Basic Script Logging

```bash
source /path/to/logging.sh
init_logger
log_info "Script starting"
```

See: [Getting Started](docs/getting-started.md)

### Logging to File

```bash
init_logger --log "/var/log/myapp.log" --level INFO
```

See: [Initialization](docs/initialization.md)

### Using Configuration Files

```bash
init_logger --config /etc/myapp/logging.conf
```

See: [Configuration](docs/configuration.md)

### Journal Integration

```bash
init_logger --journal --tag "myapp"
```

See: [Journal Logging](docs/journal-logging.md)

## Testing

The project includes a comprehensive test suite to verify all functionality. To run the tests:

```bash
cd tests
./run_tests.sh
```

See [tests/README.md](tests/README.md) and [Testing](docs/testing.md) for more information.

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

The project uses pre-commit hooks for code quality checks (ShellCheck, MarkdownLint, etc.).
The CI lint workflow runs these same hooks, so tool versions are centralized in `.pre-commit-config.yaml`.
See [docs/PRE-COMMIT.md](docs/PRE-COMMIT.md) for setup instructions.

### Maintainers

This project is currently maintained by [@GingerGraham](https://github.com/GingerGraham).

## License

This module is provided under the [MIT License](LICENSE).
