# Bash Logger Test Suite

This directory contains comprehensive tests for the bash-logger module.

> **📖 For detailed testing documentation**, see [docs/testing.md](../docs/testing.md)

## Quick Start

### Run All Tests

```bash
cd tests
./run_tests.sh
```

### Run Specific Test Suite

```bash
./run_tests.sh test_log_levels
./run_tests.sh test_initialization test_format
```

## Test Suites

The test suite includes 103 tests across 6 test suites:

* **test_log_levels.sh** (12 tests) - Log level functionality
* **test_initialization.sh** (21 tests) - Logger initialization
* **test_output.sh** (17 tests) - Output routing and formatting
* **test_format.sh** (16 tests) - Message format templates
* **test_config.sh** (21 tests) - Configuration file parsing
* **test_runtime_config.sh** (16 tests) - Runtime configuration changes

## Test Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Bash Logger Test Suite
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Running test_log_levels...
  ✓ Log level constants are defined
  ✓ FATAL is alias for EMERGENCY
  ...
✓ test_log_levels: 12 passed

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Test Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total Tests:   103
Passed:        103
Failed:        0

All tests passed!
```

## Documentation

For comprehensive information about the test suite, see:

* **[Testing Documentation](../docs/testing.md)** - Complete guide including:
  * Running tests
  * Understanding test output
  * Writing new tests
  * Assertion functions reference
  * Best practices
  * Debugging failed tests
  * CI integration

## Files in This Directory

* **run_tests.sh** - Main test runner
* **test_helpers.sh** - Assertion functions and test utilities
* **test\_\*.sh** - Individual test suites

## Requirements

* Bash 4.0 or later
* Standard Unix utilities (cat, grep, wc, date, mkdir, touch)
* Optional: `logger` command (for journal logging tests)
