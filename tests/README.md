# Bash Logger Test Suite

This directory contains comprehensive tests for the bash-logger module.

> **📖 For detailed testing documentation**, see [docs/testing.md](../docs/testing.md)

## Quick Start

### Run All Tests

```bash
cd tests
./run_tests.sh
```

Tests automatically run in parallel using detected CPU cores (capped at 8 jobs, due to diminishing returns above this).

### Run Tests with Custom Parallelism

Override the auto-detected parallelism if needed:

```bash
# Explicitly use 8 parallel jobs
./run_tests.sh -j 8

# Use 4 parallel jobs (good for CI environments)
./run_tests.sh -j 4

# Or use environment variable
TEST_PARALLEL_JOBS=4 ./run_tests.sh
```

### Run Specific Test Suite

```bash
./run_tests.sh test_log_levels
./run_tests.sh test_initialization test_format

# Specific tests with parallel execution
./run_tests.sh -j 4 test_log_levels test_format
```

## Test Suites

Each `tests/test_*.sh` file is one suite. List the current suites and run them to get the current number of tests:

```bash
ls test_*.sh
./run_tests.sh
```

The suites fall into these areas:

* **Levels, initialization and output** - `test_log_levels`, `test_initialization`, `test_output`, `test_source_guard`, `test_journal_logging`
* **Formatting** - `test_format`
* **Configuration** - `test_config`, `test_runtime_config`
* **Security: message content** - `test_ansi_injection`, `test_unsafe_newlines`, `test_mixed_sanitization_modes`, `test_script_name_sanitization`, `test_sensitive_data`
* **Security: files, environment and input** - `test_path_traversal`, `test_toctou_protection`, `test_environment_security`, `test_config_security`, `test_fuzzing`
* **Robustness** - `test_edge_cases`, `test_error_conditions`, `test_concurrent_access`, `test_resource_limits`
* **Cross-shell compatibility** - `test_shell_compat`, `test_posix_compat`, `test_zsh_compat`, `test_validator_equivalence`, `test_sanitize_equivalence`, `test_bash32_compat_check`
* **Repository tooling and test infrastructure** - `test_install`, `test_license_year`, `test_junit_output`, `test_runner`

`test_example.sh` is a template for new suites and `test_helpers.sh` is the shared library. The runner does not run either of them.

## Test Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Bash Logger Test Suite
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Running test_log_levels...
  ✓ Log level constants are defined
  ✓ FATAL is alias for EMERGENCY
  ...
✓ test_log_levels: N passed

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Test Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total Tests:   N
Passed:        N
Failed:        0
Skipped:       0

All tests passed!
```

## Cross-Shell Runs

The library runs in bash 3.2+, bash `--posix`, zsh, dash and busybox ash. The test runner itself runs under bash. Four suites run `logging.sh` under every shell listed in `TEST_SHELLS`,
which defaults to `bash`: `test_shell_compat`, `test_validator_equivalence`, `test_sanitize_equivalence` and `test_posix_compat`. Run them after any change to `logging.sh`:

```bash
TEST_SHELLS="bash,bash --posix,zsh,dash,busybox sh" \
    ./run_tests.sh test_shell_compat test_validator_equivalence test_sanitize_equivalence test_posix_compat
```

A shell that is not installed is skipped, unless it is named in `TEST_REQUIRE_SHELLS`. For `TEST_REQUIRE_SHELLS`, the scenario format and the golden files, see
[Shell Matrix Suites](../docs/testing.md#shell-matrix-suites).

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
* **compat/** - Scenarios, golden files and known failures for the cross-shell suites

## Requirements

* Bash 3.2 or later (the Bash 3.2 that macOS ships as `/bin/bash` is supported)
* Standard Unix utilities (cat, grep, wc, date, mkdir, touch)
* Optional: `logger` command (for journal logging tests)
* Optional: `zsh`, `dash` and `busybox` (for cross-shell runs)
