# Testing <!-- omit in toc -->

Comprehensive guide to the bash-logger test suite, including how to run tests, write new tests, and understand the test framework.

## Table of Contents <!-- omit in toc -->

* [Overview](#overview)
* [Running Tests](#running-tests)
  * [Run All Tests](#run-all-tests)
    * [Parallel Execution](#parallel-execution)
  * [Run Specific Test Suites](#run-specific-test-suites)
  * [Understanding Test Output](#understanding-test-output)
* [Code Coverage and Static Analysis](#code-coverage-and-static-analysis)
  * [Prerequisites](#prerequisites)
  * [Coverage with kcov](#coverage-with-kcov)
  * [JUnit XML Output](#junit-xml-output)
  * [SonarQube Integration](#sonarqube-integration)
    * [Setting Up the SonarQube Token](#setting-up-the-sonarqube-token)
    * [Configuring sonar-project.properties](#configuring-sonar-projectproperties)
    * [Running the Scanner](#running-the-scanner)
  * [Running the Full Analysis Pipeline](#running-the-full-analysis-pipeline)
* [Test Suite Structure](#test-suite-structure)
  * [Test Files](#test-files)
  * [Test Coverage](#test-coverage)
* [Writing Tests](#writing-tests)
  * [Basic Test Structure](#basic-test-structure)
  * [Assertion Functions](#assertion-functions)
    * [Equality Assertions](#equality-assertions)
    * [String Assertions](#string-assertions)
    * [File Assertions](#file-assertions)
    * [Command Assertions](#command-assertions)
  * [Test Helpers](#test-helpers)
  * [Best Practices](#best-practices)
* [Adding New Tests](#adding-new-tests)
  * [Creating a New Test Suite](#creating-a-new-test-suite)
  * [Adding Tests to Existing Suite](#adding-tests-to-existing-suite)
* [Debugging Failed Tests](#debugging-failed-tests)
* [Continuous Integration](#continuous-integration)
  * [Comparing with the Previous Major Release](#comparing-with-the-previous-major-release)
* [Related Documentation](#related-documentation)

## Overview

The bash-logger project includes a comprehensive Bash-based test suite. To see the current
number of test suites and individual tests, run `bash tests/run_tests.sh` and check the
summary output. The test framework is built in pure Bash and designed to be:

* **Self-contained**: No external test frameworks required
* **CI-friendly**: Clear exit codes and non-interactive
* **Developer-friendly**: Colored output and detailed error messages
* **Maintainable**: Simple structure that's easy to extend

## Running Tests

### Run All Tests

From the project root:

```bash
cd tests
./run_tests.sh
```

Or from anywhere in the project:

```bash
./tests/run_tests.sh
```

#### Parallel Execution

The test runner automatically detects available CPU cores and runs tests in parallel (capped at 8 jobs). You can override this with the `-j` or `--parallel` option:

```bash
# Auto-detected parallelism (default behavior)
./run_tests.sh

# Run with 4 parallel jobs (explicit)
./run_tests.sh -j 4

# Run with 8 parallel jobs (explicit)
./run_tests.sh -j 8

# Combine with other options
./run_tests.sh -j 8 --junit
```

**Environment Variable Override:**

Set `TEST_PARALLEL_JOBS` to control parallelism without command-line flags:

```bash
# Useful for CI/CD pipelines
export TEST_PARALLEL_JOBS=4
./run_tests.sh

# Or inline
TEST_PARALLEL_JOBS=4 ./run_tests.sh
```

**Failing when too many tests are skipped:**

Set `TEST_MAX_SKIPPED` to a non-negative integer to fail the run when it skips more tests
than that. A future environment change then cannot silently reduce coverage:

```bash
# At most 10 skipped tests are allowed
TEST_MAX_SKIPPED=10 ./tests/run_tests.sh
```

The guard runs after the summary. It exits 1 with the skip count when the threshold is
exceeded, and also exits 1 when the value is not a non-negative integer. CI uses it in the
`test-alpine` job (see [Other CI jobs](#other-ci-jobs)).

**Stopping at the first failure:**

Use `--fail-fast` (or `-x`) to stop the runner immediately after the first suite that
contains failures. This is the fastest way to isolate a broken test during development
or when diagnosing `make sonar-analysis` failures:

```bash
# Stop at first failing suite
./tests/run_tests.sh --fail-fast

# Or via Make
make test-fail-fast
```

In sequential mode the runner stops right after the failing suite and prints the "Failed Tests"
summary immediately. `--fail-fast` always runs sequentially: if parallel jobs are configured
(via `-j N` or `TEST_PARALLEL_JOBS`), the flag overrides them to ensure the run truly stops
at the first failure.

**Crashed and empty suites:**

Every dispatched suite is isolated in a subshell in both parallel and sequential modes.
The runner waits for each suite's PID and checks its exit status and result file.
A nonzero exit, an early exit before completion (even `exit 0`), missing or incomplete
results, or a completed suite reporting zero tests makes the runner exit with status 1.
The final summary names the suite and its exit status; empty suites report `reported 0 tests`.
The last 20 lines of a crashed or empty suite's combined stdout/stderr are printed for diagnosis.

Completed passes, assertion failures and skips are preserved when the worker can write its
exit snapshot. A suite error adds one failed test to those completed results; an interrupted
test is represented by that error rather than counted twice. If the worker cannot write a complete
result snapshot (for example, its exit trap was replaced), the suite contributes one error; partial results are discarded.
A suite that skips every test has a nonzero test count and continues to pass.
Sequential mode continues with the next suite after a crash unless `--fail-fast` is enabled.

**Performance Impact:**

* **Sequential** (`-j 1`): ~5+ minutes for full suite
* **4 parallel jobs**: ~2-3 minutes
* **8 parallel jobs**: ~1-2 minutes

**Recommendations:**

* **Local development**: Auto-detection works well (runs up to 8 parallel jobs)
* **CI/CD**: Set `TEST_PARALLEL_JOBS=4` for GitHub Actions or similar (2-4 core runners)
* **Pre-commit hooks**: Configured to use `-j 8` explicitly for faster commits
* Systems with many cores (16+) benefit from the 8-job cap to avoid I/O contention

The `make test` target and pre-commit hooks take advantage of the auto-detected parallelism for optimal local performance.

### Run Specific Test Suites

Run one or more specific test suites:

```bash
cd tests
./run_tests.sh test_log_levels
./run_tests.sh test_initialization test_format
```

Available test suites:

* `test_ansi_injection` - ANSI escape sanitization and related security tests
* `test_concurrent_access` - Concurrency and parallel logging behavior
* `test_config` - Configuration file parsing and behavior
* `test_config_security` - Security hardening for configuration input
* `test_edge_cases` - Boundary and unusual input handling
* `test_environment_security` - Environment-based security checks
* `test_error_conditions` - Error handling and defensive behavior
* `test_format` - Message format templates and formatting behavior
* `test_fuzzing` - Fuzz-style robustness checks
* `test_initialization` - Logger initialization behavior
* `test_install` - Installation and setup scripts
* `test_journal_logging` - Journal-specific behavior and forced journal logging
* `test_junit_output` - JUnit XML report generation
* `test_license_year` - Copyright year update script for the LICENSE file
* `test_log_levels` - Log level functionality
* `test_mixed_sanitization_modes` - Combined sanitization mode behavior
* `test_output` - Output routing and stream behavior
* `test_path_traversal` - Path traversal protections
* `test_resource_limits` - Resource and size limit behavior
* `test_runner` - Crash containment, suite accounting, empty suites and runner diagnostics
* `test_runtime_config` - Runtime configuration changes
* `test_script_name_sanitization` - Script and tag name sanitization
* `test_sensitive_data` - Sensitive data handling protections
* `test_toctou_protection` - TOCTOU/race-condition protections
* `test_unsafe_newlines` - Unsafe newline mode behavior

### Understanding Test Output

The test runner provides colored, hierarchical output:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Bash Logger Test Suite
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Running test_log_levels...
  ✓ Log level constants are defined
  ✓ FATAL is alias for EMERGENCY
  ✓ get_log_level_value converts names to numbers
  ...
✓ test_log_levels: 12 passed

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Test Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total Tests:   466
Passed:        461
Failed:        0
Skipped:       5

All tests passed!
```

**Symbols**:

* ✓ (green) - Test passed
* ✗ (red) - Test failed
* ⊘ (yellow) - Test skipped

**Exit Codes**:

* `0` - All tests passed
* `1` - One or more tests failed

## Code Coverage and Static Analysis

The project supports code coverage reporting and static analysis via SonarQube. These tools
are available through Makefile targets but require additional setup as they depend on
external tools and services.

> **Note:** These features are primarily used by the maintainer for local analysis against
> a private SonarQube instance. They are documented here for completeness and for
> contributors who wish to run similar analysis.

### Prerequisites

The coverage and SonarQube targets require the following tools:

| Tool                                                                                            | Purpose                                    | Installation                                                                                |
| ----------------------------------------------------------------------------------------------- | ------------------------------------------ | ------------------------------------------------------------------------------------------- |
| [kcov](https://github.com/SimonKagstrom/kcov)                                                   | Code coverage for Bash scripts             | `sudo dnf install kcov` (Fedora) or `sudo apt install kcov` (Debian/Ubuntu)                 |
| [sonar-scanner](https://docs.sonarqube.org/latest/analyzing-source-code/scanners/sonarscanner/) | SonarQube CLI scanner                      | Download from SonarQube docs or use package manager                                         |
| [secret-tool](https://wiki.gnome.org/Projects/Libsecret)                                        | GNOME Keyring CLI for secure token storage | `sudo dnf install libsecret` (Fedora) or `sudo apt install libsecret-tools` (Debian/Ubuntu) |

Additionally, you need:

* **Access to a SonarQube server** - The project's `sonar-project.properties` is configured
  for the maintainer's private instance. You'll need to modify this file for your own server.
* **SonarQube authentication token** - Stored securely in the GNOME Keyring (see below).

### Coverage with kcov

[kcov](https://github.com/SimonKagstrom/kcov) provides code coverage for Bash scripts by
instrumenting the script execution and tracking which lines are executed.

```bash
# Run tests with coverage
make coverage
```

This executes:

```bash
kcov --include-path=./logging.sh coverage-report ./tests/run_tests.sh
```

**Output:**

* Coverage report is generated in `coverage-report/`
* HTML report: `coverage-report/run_tests.sh/index.html`
* SonarQube-compatible XML: `coverage-report/run_tests.sh/sonarqube.xml`

### JUnit XML Output

The test runner can generate JUnit XML reports for CI systems and SonarQube:

```bash
# Run tests with JUnit XML output
make test-junit
```

Or directly:

```bash
./tests/run_tests.sh --junit
```

**Output:**

* JUnit XML report: `test-reports/junit.xml`
* The report follows the SonarQube Generic Test Execution format
* Crashed or empty suites add a synthetic `<testCase>` with an `<error>` element,
  including the suite name, exit status and output tail. Completed assertion failures
  retain their `<failure>` elements, and skipped tests retain `<skipped>` elements.

### SonarQube Integration

SonarQube provides static analysis, code quality metrics, and aggregates coverage data.

#### Setting Up the SonarQube Token

The project uses `secret-tool` (GNOME Keyring) to securely store the SonarQube authentication
token rather than embedding it in files or environment variables.

**Store your token:**

```bash
secret-tool store --label='SonarQube Token' service sonarqube account scanner
```

You'll be prompted to enter your token. This stores it securely in the GNOME Keyring.

**Verify the token is stored:**

```bash
secret-tool lookup service sonarqube account scanner
```

#### Configuring sonar-project.properties

The project includes a `sonar-project.properties` file configured for the maintainer's
private SonarQube instance. To use your own server, update:

```properties
# Update the host URL (add this line if using a different server)
sonar.host.url=https://your-sonarqube-server.example.com

# Optionally update project key if needed
sonar.projectKey=bash-logger
```

#### Running the Scanner

```bash
# Run SonarQube scanner
make sonar
```

Before running the scanner, this target automatically syncs the version number from
`logging.sh` (`BASH_LOGGER_VERSION`) to `sonar-project.properties` (`sonar.projectVersion`),
ensuring the version reported to SonarQube always matches the source code.

The scanner reads configuration from `sonar-project.properties` and uploads:

* Source code for analysis
* Coverage report from `coverage-report/run_tests.sh/sonarqube.xml`
* Test execution report from `test-reports/junit.xml`

### Running the Full Analysis Pipeline

To run coverage, tests with JUnit output, and SonarQube scan in sequence:

```bash
make sonar-analysis
```

This runs the following targets in order:

1. `coverage` - Generates coverage report via kcov
2. `test-junit` - Generates JUnit XML test report
3. `sonar` - Uploads everything to SonarQube

**Debugging a failing `sonar-analysis`:**

When `make sonar-analysis` fails it can be hard to spot the failing test in 500+ lines.
Use `make coverage-debug` to run the kcov pass in fail-fast mode — it stops at the first
failure and prints the test name immediately:

```bash
make coverage-debug
```

Once the failing test is identified, run that suite alone without kcov to confirm whether
the failure is kcov-specific (e.g. due to kcov setting `BASH_ENV` or the DEBUG trap
slowing execution):

```bash
./tests/run_tests.sh <suite_name>
```

**Cleaning up reports:**

```bash
make clean
```

This removes `coverage-report/` and `test-reports/` directories along with other temporary files.

## Test Suite Structure

### Test Files

The test suite is organized into the following files:

**Core Infrastructure** (`tests/`):

* `run_tests.sh` - Main test runner
* `test_helpers.sh` - Assertion functions and utilities

**Test Suites** (`tests/`):

`run_tests.sh` discovers test suites automatically using `test_*.sh`
(excluding `test_helpers.sh` and `test_example.sh`).

Current runnable suite files include:

* `test_ansi_injection.sh`
* `test_concurrent_access.sh`
* `test_config.sh`
* `test_config_security.sh`
* `test_edge_cases.sh`
* `test_environment_security.sh`
* `test_error_conditions.sh`
* `test_format.sh`
* `test_fuzzing.sh`
* `test_initialization.sh`
* `test_install.sh`
* `test_journal_logging.sh`
* `test_junit_output.sh`
* `test_license_year.sh`
* `test_log_levels.sh`
* `test_mixed_sanitization_modes.sh`
* `test_output.sh`
* `test_path_traversal.sh`
* `test_posix_compat.sh`
* `test_resource_limits.sh`
* `test_runtime_config.sh`
* `test_sanitize_equivalence.sh`
* `test_script_name_sanitization.sh`
* `test_sensitive_data.sh`
* `test_shell_compat.sh`
* `test_source_guard.sh`
* `test_toctou_protection.sh`
* `test_unsafe_newlines.sh`
* `test_validator_equivalence.sh`
* `test_zsh_compat.sh`

### Test Coverage

Current test coverage includes:

* Core logging behavior: ✅ Extensive
  Notes: levels, output streams, formatting, initialization.
* Configuration handling: ✅ Extensive
  Notes: parsing, validation, and security-focused config tests.
* Journal logging: ✅ Extensive
  Notes: initialization, runtime toggles, and forced per-call journal writes.
* Security hardening: ✅ Extensive
  Notes: sensitive data, path traversal, ANSI/newline handling, and TOCTOU.
* Reliability and robustness: ✅ Extensive
  Notes: concurrency, fuzzing, edge cases, and resource limits.
* CI/reporting integrations: ✅ Covered
  Notes: JUnit XML output and SonarQube-related flow.

Use `./tests/run_tests.sh` to get the authoritative, current totals on your machine.

## Writing Tests

### Basic Test Structure

Every test follows this pattern:

```bash
test_feature_name() {
    start_test "Human-readable test description"

    # Setup
    init_logger --options
    local log_file="$TEST_DIR/test.log"
    LOG_FILE="$log_file"

    # Execute
    log_info "Test message"

    # Assert
    assert_file_contains "$log_file" "Test message" || return

    # Mark as passed
    pass_test
}
```

**Key Points**:

1. Function name should start with `test_`
2. Always call `start_test` with a descriptive message
3. Use `$TEST_DIR` for temporary files
4. Return early on assertion failure with `|| return`
5. Call `pass_test` at the end

### Assertion Functions

All assertion functions are defined in `test_helpers.sh`.

#### Equality Assertions

```bash
# Assert two values are equal
assert_equals "expected" "actual" "optional message"

# Assert two values are different
assert_not_equals "unexpected" "actual" "optional message"
```

**Example**:

```bash
assert_equals "$LOG_LEVEL_INFO" "$CURRENT_LOG_LEVEL" || return
```

#### String Assertions

```bash
# Assert string contains substring
assert_contains "haystack" "needle" "optional message"

# Assert string doesn't contain substring
assert_not_contains "haystack" "needle" "optional message"

# Assert string matches regex pattern
assert_matches "string" "pattern" "optional message"
```

**Example**:

```bash
local output="[INFO] Test message"
assert_contains "$output" "[INFO]" || return
assert_matches "$output" "\[INFO\].*Test" || return
```

#### File Assertions

```bash
# File existence
assert_file_exists "path/to/file" "optional message"
assert_file_not_exists "path/to/file" "optional message"

# File content
assert_file_contains "path/to/file" "text" "optional message"
assert_file_not_contains "path/to/file" "text" "optional message"

# File size
assert_file_empty "path/to/file" "optional message"
assert_file_not_empty "path/to/file" "optional message"
```

**Example**:

```bash
local log_file="$TEST_DIR/test.log"
log_info "Test"
assert_file_exists "$log_file" || return
assert_file_contains "$log_file" "Test" || return
```

#### Command Assertions

```bash
# Assert command succeeds (exit code 0)
assert_success command arg1 arg2

# Assert command fails (non-zero exit code)
assert_failure command arg1 arg2
```

**Example**:

```bash
assert_success check_logger_available
```

### Test Helpers

Additional helper functions available:

```bash
# Capture combined stdout/stderr
capture_output OUTPUT_VAR command args

# Capture streams separately
capture_streams STDOUT_VAR STDERR_VAR command args

# Run command with logger sourced
run_with_logger "init_logger && log_info 'test'"

# Run command with logger sourced under a named shell (may include flags)
run_with_logger_in_shell "bash --posix" "init_logger && log_info 'test'"
run_with_logger_in_shell "zsh" "init_logger && log_info 'test'"

# Skip the test if a shell is not installed (fail instead if it is listed
# in TEST_REQUIRE_SHELLS)
require_shell zsh || return 0

# Skip a test with reason
skip_test "logger command not available"

# Print the shells in TEST_SHELLS, one per line (default: bash)
test_shell_list

# Return 0 for shells whose string operations count characters (bash, zsh)
shell_counts_characters "busybox sh"

# Run a command and stop it after a number of seconds (works on macOS)
run_with_timeout 30 some_command args
```

#### Cross-Shell Tests

Suites run in bash. To check behaviour under another shell, run the library in
a child shell with `run_with_logger_in_shell`, and guard the test with
`require_shell`:

```bash
test_example_cross_shell() {
    start_test "Message is logged in bash, bash --posix and zsh"

    require_shell zsh || return 0

    local shell_command
    for shell_command in "bash" "bash --posix" "zsh"; do
        output=$(run_with_logger_in_shell "$shell_command" "init_logger --no-color; log_info hi" 2>&1)
        assert_contains "$output" "hi" "shell: $shell_command" || return
    done

    pass_test
}
```

Use `|| return 0` after `require_shell`: the skip or failure is already
recorded, and a non-zero status from the last test in a suite is reported by
the runner as a suite crash.

When zsh is not installed, these tests skip. Set `TEST_REQUIRE_SHELLS` to a
space-separated list of shells that must be present, so the tests fail instead
of silently skipping. CI sets `TEST_REQUIRE_SHELLS="zsh dash busybox"`:

```bash
TEST_REQUIRE_SHELLS=zsh ./tests/run_tests.sh
```

Set `TEST_MAX_SKIPPED` to bound the number of tests a run may skip; exceeding it fails the
run (see [Failing when too many tests are skipped](#failing-when-too-many-tests-are-skipped)).

#### Shell Matrix Suites

`test_shell_compat.sh`, `test_validator_equivalence.sh`, `test_sanitize_equivalence.sh` and
`test_posix_compat.sh` run the library under every shell in `TEST_SHELLS` (default `bash`).
Separate commands with commas when a command has flags:

```bash
TEST_SHELLS="bash,bash --posix,zsh,dash,busybox sh" \
    ./tests/run_tests.sh test_shell_compat test_validator_equivalence \
    test_sanitize_equivalence test_posix_compat
```

* **`test_shell_compat.sh`** runs each script in `tests/compat/scenarios/` under bash and under
  each other shell, and compares stdout, stderr, the log file and the exit status (timestamps
  masked). To cover new behaviour, add a scenario: a short POSIX sh script that sources
  `"$LOGGER_ROOT/logging.sh"` and writes any log file to `"$SCENARIO_DIR/test.log"`. A
  `# compat-locale: C.UTF-8` header line runs it in that locale (default `C`). Shell/scenario
  pairs that are expected to differ for now are listed in `tests/compat/known_failures.txt`.
  `long_multiline.sh` covers line control characters in messages of every size, either side
  of the lengths where the sanitizer switches to `tr`.
* **`test_validator_equivalence.sh`** runs the validators over the corpus in
  `tests/compat/golden/` and compares with golden results recorded from the bash regular
  expressions the validators used before the POSIX conversion. Do not regenerate the golden
  files from current code; see `tests/compat/generate_validator_golden.sh`.
* **`test_sanitize_equivalence.sh`** logs a fixed corpus of messages (line control characters,
  ANSI sequences, UTF-8, token-like text, and sizes around the `tr` limits) in three modes and
  compares the log output with golden results recorded from bash at 2.7.0, before the POSIX
  conversion. See `tests/compat/generate_sanitize_golden.sh`; it leaves out the messages
  `-n`, `-e` and `-E`, which 2.7.0 logged as empty lines.
* **`test_posix_compat.sh`** checks the behaviour documented in
  [Shell Compatibility](shell-compatibility.md).

**Example**:

```bash
if ! check_logger_available; then
    skip_test "logger command not available"
    return
fi
```

#### Using a Stub logger in Tests

Journal tests use a stub script in place of the system `logger`. The library runs a `logger` only when `LOGGER_PATH` has been validated and made readonly, so a stub needs the following.
`tests/test_journal_logging.sh` has the pattern (`_create_stub_logger` writes the stub and a capture file in `$TEST_DIR`):

```bash
result=$(bash -c "
    source '$PROJECT_ROOT/logging.sh'

    # Assign after sourcing, because sourcing sets LOGGER_PATH to '' unless it is already readonly.
    # Make the value readonly: the library refuses a LOGGER_PATH that is not.
    LOGGER_PATH='$STUB_LOGGER'; readonly LOGGER_PATH

    # Stop the library from looking for the real logger. Without this, journal logging is disabled
    # when a real logger is installed, because its path differs from the locked one.
    _find_and_validate_logger() { return 0; }
    check_logger_available() { return 0; }

    init_logger --no-color --quiet
    log_to_journal INFO 'message for the stub'
" 2>&1)

assert_file_contains "$STUB_CAPTURE" "message for the stub" || return
```

* A stub that is assigned to `LOGGER_PATH` but not made readonly is never run. This is the usual reason a test that worked on 2.x stops capturing journal calls.
* Do the assignment in the same shell that runs the library, inside the `bash -c` script. A test function that sets the variable does not affect the child shell.
* The two function overrides are internal. If they change, update every suite that uses them. See [Journal Logging](journal-logging.md#using-a-stub-logger-in-tests).

### Best Practices

1. **Descriptive Names**: Use clear, specific test names

   ```bash
   # Good
   test_error_messages_go_to_stderr()

   # Bad
   test_stderr()
   ```

2. **Isolated Tests**: Each test should be independent

   ```bash
   # Each test gets fresh logger state via setup_test
   test_feature_one() {
       start_test "..."
       init_logger --level INFO
       # Test specific to INFO level
   }

   test_feature_two() {
       start_test "..."
       init_logger --level DEBUG
       # Independent - doesn't affect other tests
   }
   ```

3. **Use Temporary Files**: Always use `$TEST_DIR` for test files

   ```bash
   local log_file="$TEST_DIR/my_test.log"
   LOG_FILE="$log_file"
   ```

4. **Clear Assertions**: Add descriptive messages for complex assertions

   ```bash
   assert_equals "$expected" "$actual" "Level should be INFO after init" || return
   ```

5. **Test Edge Cases**: Include boundary conditions and error cases

   ```bash
   test_empty_message()
   test_very_long_message()
   test_invalid_log_level()
   ```

## Adding New Tests

### Creating a New Test Suite

To add a completely new test suite:

1. **Create the test file**: `tests/test_feature.sh`

```bash
#!/usr/bin/env bash
#
# test_feature.sh - Tests for new feature
#
# Tests:
# - Brief description of what's tested

# Individual test functions
test_feature_works() {
    start_test "Feature works as expected"

    init_logger --quiet
    local log_file="$TEST_DIR/test.log"
    LOG_FILE="$log_file"

    # Your test logic here
    log_info "Test"

    assert_file_contains "$log_file" "Test" || return

    pass_test
}

test_feature_edge_case() {
    start_test "Feature handles edge case"

    # Your test logic

    pass_test
}

# Call all test functions
test_feature_works
test_feature_edge_case
```

1. **Make it executable**:

```bash
chmod +x tests/test_feature.sh
```

1. **No test runner edit required**: `tests/run_tests.sh` auto-discovers
   `test_*.sh` files in `tests/` (excluding `test_helpers.sh` and `test_example.sh`).

1. **Run your new tests**:

```bash
cd tests
./run_tests.sh test_feature
```

### Adding Tests to Existing Suite

To add tests to an existing suite:

1. **Add test function** to the appropriate file
2. **Call the function** at the bottom of the file
3. **Run the suite** to verify

Example - adding to `test_log_levels.sh`:

```bash
# Add this function
test_custom_log_level() {
    start_test "Custom log level works"

    # Your test implementation

    pass_test
}

# Add this call at the bottom
test_log_level_constants
test_fatal_alias
# ... existing calls ...
test_custom_log_level  # Add your new test
```

## Debugging Failed Tests

When a test fails:

1. **Use fail-fast to isolate the suite** - re-run with `--fail-fast` so the runner stops
   immediately after the first failure, keeping it at the top of the output:

   ```bash
   make test-fail-fast
   # or
   ./tests/run_tests.sh --fail-fast
   ```

2. **Review the failure message** - includes test name and reason:

   ```
   ✗ test_feature
     Reason: Expected 'value1' but got 'value2'
   ```

3. **Check test artifacts** - failed tests preserve temporary directories:

   ```
   Test artifacts in: /tmp/bash-logger-tests.XXXXXX/timestamp
   ```

4. **Run specific test** for faster iteration:

   ```bash
   ./run_tests.sh test_specific_suite
   ```

5. **Add debug output** temporarily:

   ```bash
   test_feature() {
       start_test "..."

       # Add debug output
       echo "DEBUG: variable=$variable" >&2
       echo "DEBUG: log_file contents:" >&2
       cat "$log_file" >&2

       assert_equals "expected" "$variable" || return
       pass_test
   }
   ```

6. **Check the logging module** - source it interactively:

   ```bash
   source logging.sh
   init_logger --level DEBUG
   log_info "Test"
   ```

## Continuous Integration

The test suite is designed to work seamlessly in CI environments:

**GitHub Actions Example**:

```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install zsh, dash and busybox
        run: sudo apt-get update && sudo apt-get install -y zsh dash busybox
      - name: Run tests
        env:
          TEST_SHELLS: bash,bash --posix,zsh,dash,busybox sh
          TEST_REQUIRE_SHELLS: zsh dash busybox
        run: |
          cd tests
          ./run_tests.sh
```

**Requirements**:

* Bash 3.2 or later (the Bash 3.2 that macOS ships as `/bin/bash` is supported)
* Standard Unix utilities (cat, grep, wc, date, mkdir, touch)
* Optional: `logger` command for journal logging tests
* Optional: `zsh`, `dash` and `busybox` for cross-shell tests (required when listed in
  `TEST_REQUIRE_SHELLS`)
* Optional: `bc` for accurate test timing in JUnit XML output (durations show as 0 if unavailable)

The CI workflow also runs the full suite on macOS under `/bin/bash` 3.2 with the BSD userland
(`test-macos-bash32` in `.github/workflows/tests.yml`). Write tests so they run on both: avoid
Bash 4+ syntax, and avoid GNU-only options such as `date +%s%N` or `sed -i` without a suffix.

Other jobs in the same workflow:

* `test-bash-versions` runs the suite in the `bash:4.2`, `bash:4.4` and `bash:5.1` Docker
  images (the RHEL 7, RHEL 8 and Ubuntu 22.04 era versions). The images are Alpine based, so
  the tests run with musl and BusyBox tools, and the stub scripts they write must not assume
  `/bin/bash` or GNU `sed`.
* `test-alpine` runs the suite on `alpine:latest` with every supported shell, using the real
  BusyBox and musl of a default Alpine system. It sets `TEST_MAX_SKIPPED=10`, so a change that
  silently skips the UTF-8 tests again fails the job instead of shrinking coverage.
* `compare-with-release` runs `scripts/compare-with-release.py`, described below.

### Comparing with the Previous Major Release

`scripts/compare-with-release.py` runs consumer-style scripts against `logging.sh` from the
last release of the previous major version and against the working copy. It covers 45 bash
option and locale modes, 38 zsh modes, and 59 API scenarios under bash, `bash --posix`
and zsh, and compares stdout, stderr, log files and exit status.

```bash
python3 -I scripts/compare-with-release.py
```

The release to compare with, and the differences that are allowed, are in
`scripts/compare-with-release.json`. Each allowed difference names its section of the upgrade
guide. When a change alters behaviour on purpose, document it in the upgrade guide, then add a
narrow scenario for it and allow only that scenario. Do not allow a whole shell mode.

Options: `--filter TEXT` runs only cases whose `shell/case` name contains `TEXT`,
`--json-out FILE` writes both outputs of every difference, and `--strict` fails when zsh or a
locale is missing. Full coverage needs the `en_GB.UTF-8`, `tr_TR.UTF-8` and
`de_DE.ISO-8859-1` locales; on Fedora, install `glibc-langpack-en`, `glibc-langpack-tr` and
`glibc-langpack-de`.

**CI Characteristics**:

* Non-interactive
* Clean exit codes (0=pass, 1=fail)
* Temporary files in system temp directory
* Skips tests when dependencies unavailable
* No pager usage or interactive prompts

## Related Documentation

* [Writing Tests](writing-tests.md) - Contributor guide: how to write and structure tests,
  with annotated examples and common pitfalls
* [Getting Started](getting-started.md) - Basic usage of the logging module
* [Initialization](initialization.md) - Initialization options and configuration
* [Examples](examples.md) - Comprehensive usage examples
* [Troubleshooting](troubleshooting.md) - Common issues and solutions
