# Testing <!-- omit in toc -->

Comprehensive guide to the bash-logger test suite, including how to run tests, write new tests, and understand the test framework.

## Table of Contents <!-- omit in toc -->

- [Overview](#overview)
- [Running Tests](#running-tests)
  - [Run All Tests](#run-all-tests)
  - [Run Specific Test Suites](#run-specific-test-suites)
  - [Understanding Test Output](#understanding-test-output)
- [Test Suite Structure](#test-suite-structure)
  - [Test Files](#test-files)
  - [Test Coverage](#test-coverage)
- [Writing Tests](#writing-tests)
  - [Basic Test Structure](#basic-test-structure)
  - [Assertion Functions](#assertion-functions)
    - [Equality Assertions](#equality-assertions)
    - [String Assertions](#string-assertions)
    - [File Assertions](#file-assertions)
    - [Command Assertions](#command-assertions)
  - [Test Helpers](#test-helpers)
  - [Best Practices](#best-practices)
- [Adding New Tests](#adding-new-tests)
  - [Creating a New Test Suite](#creating-a-new-test-suite)
  - [Adding Tests to Existing Suite](#adding-tests-to-existing-suite)
- [Debugging Failed Tests](#debugging-failed-tests)
- [Continuous Integration](#continuous-integration)
- [Related Documentation](#related-documentation)

## Overview

The bash-logger project includes a comprehensive test suite with 103 tests across 6 test suites, validating all functionality of the logging module. The test framework is built in pure Bash and designed to be:

- **Self-contained**: No external test frameworks required
- **CI-friendly**: Clear exit codes and non-interactive
- **Developer-friendly**: Colored output and detailed error messages
- **Maintainable**: Simple structure that's easy to extend

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

### Run Specific Test Suites

Run one or more specific test suites:

```bash
cd tests
./run_tests.sh test_log_levels
./run_tests.sh test_initialization test_format
```

Available test suites:

- `test_log_levels` - Log level functionality
- `test_initialization` - Logger initialization
- `test_output` - Output routing and formatting
- `test_format` - Message format templates
- `test_config` - Configuration file parsing
- `test_runtime_config` - Runtime configuration changes

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

Total Tests:   103
Passed:        103
Failed:        0

All tests passed!
```

**Symbols**:

- ✓ (green) - Test passed
- ✗ (red) - Test failed
- ⊘ (yellow) - Test skipped

**Exit Codes**:

- `0` - All tests passed
- `1` - One or more tests failed

## Test Suite Structure

### Test Files

The test suite is organized into the following files:

**Core Infrastructure** (`tests/`):

- `run_tests.sh` - Main test runner
- `test_helpers.sh` - Assertion functions and utilities

**Test Suites** (`tests/`):

- `test_log_levels.sh` - 12 tests for log levels
- `test_initialization.sh` - 21 tests for initialization
- `test_output.sh` - 17 tests for output routing
- `test_format.sh` - 16 tests for message formatting
- `test_config.sh` - 21 tests for config file parsing
- `test_runtime_config.sh` - 16 tests for runtime changes

### Test Coverage

Current test coverage includes:

| Component             | Coverage    | Tests              |
| --------------------- | ----------- | ------------------ |
| Log Levels            | ✅ Complete | 12                 |
| Initialization        | ✅ Complete | 21                 |
| Output Routing        | ✅ Complete | 17                 |
| Message Formatting    | ✅ Complete | 16                 |
| Configuration Files   | ✅ Complete | 21                 |
| Runtime Configuration | ✅ Complete | 16                 |
| Journal Logging       | ⚠️ Basic    | Included           |
| Color Detection       | ⚠️ Limited  | Terminal-dependent |
| **Total**             |             | **103**            |

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

# Skip a test with reason
skip_test "logger command not available"
```

**Example**:

```bash
if ! check_logger_available; then
    skip_test "logger command not available"
    return
fi
```

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

2. **Make it executable**:

```bash
chmod +x tests/test_feature.sh
```

3. **Add to test runner**: Edit `tests/run_tests.sh`, add to the test files array:

```bash
test_files=(
    "$SCRIPT_DIR/test_log_levels.sh"
    "$SCRIPT_DIR/test_initialization.sh"
    "$SCRIPT_DIR/test_output.sh"
    "$SCRIPT_DIR/test_format.sh"
    "$SCRIPT_DIR/test_config.sh"
    "$SCRIPT_DIR/test_runtime_config.sh"
    "$SCRIPT_DIR/test_feature.sh"  # Add your new suite
)
```

4. **Run your new tests**:

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

1. **Review the failure message** - includes test name and reason:

   ```
   ✗ test_feature
     Reason: Expected 'value1' but got 'value2'
   ```

2. **Check test artifacts** - failed tests preserve temporary directories:

   ```
   Test artifacts in: /tmp/bash-logger-tests.XXXXXX/timestamp
   ```

3. **Run specific test** for faster iteration:

   ```bash
   ./run_tests.sh test_specific_suite
   ```

4. **Add debug output** temporarily:

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

5. **Check the logging module** - source it interactively:
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
      - name: Run tests
        run: |
          cd tests
          ./run_tests.sh
```

**Requirements**:

- Bash 4.0 or later
- Standard Unix utilities (cat, grep, wc, date, mkdir, touch)
- Optional: `logger` command for journal logging tests

**CI Characteristics**:

- Non-interactive
- Clean exit codes (0=pass, 1=fail)
- Temporary files in system temp directory
- Skips tests when dependencies unavailable
- No pager usage or interactive prompts

## Related Documentation

- [Getting Started](getting-started.md) - Basic usage of the logging module
- [Initialization](initialization.md) - Initialization options and configuration
- [Examples](examples.md) - Comprehensive usage examples
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
