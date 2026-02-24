# Writing Tests for bash-logger <!-- omit in toc -->

A practical guide for contributors writing new tests. This document is about *how to think
about* testing in this project — what to test, how to structure it, and the mistakes to avoid.
For the full assertion and helper API reference, see [Testing](testing.md).

## Table of Contents <!-- omit in toc -->

* [Your first test](#your-first-test)
  * [The complete walkthrough](#the-complete-walkthrough)
  * [The start\_test / || return / pass\_test pattern](#the-start_test---return--pass_test-pattern)
* [Choosing the right assertion](#choosing-the-right-assertion)
  * [Prefer file assertions for log output](#prefer-file-assertions-for-log-output)
  * [When to use output capture instead](#when-to-use-output-capture-instead)
* [Test isolation](#test-isolation)
  * [Why logging.sh is re-sourced on every test](#why-loggingsh-is-re-sourced-on-every-test)
  * [How TEST\_DIR works and why it matters for parallel execution](#how-test_dir-works-and-why-it-matters-for-parallel-execution)
* [Common patterns](#common-patterns)
  * [A message appears in the log file](#a-message-appears-in-the-log-file)
  * [Output goes to stderr not stdout](#output-goes-to-stderr-not-stdout)
  * [A flag or config option is respected](#a-flag-or-config-option-is-respected)
  * [Invalid input is handled gracefully](#invalid-input-is-handled-gracefully)
  * [A test is skipped when a dependency is unavailable](#a-test-is-skipped-when-a-dependency-is-unavailable)
* [What not to do](#what-not-to-do)
* [Getting started quickly](#getting-started-quickly)

## Your first test

### The complete walkthrough

Here is the smallest complete test you can write:

```bash
test_info_message_written_to_file() {
    start_test "INFO message is written to the log file"

    init_logger --level INFO --quiet
    local log_file="$TEST_DIR/test.log"
    LOG_FILE="$log_file"

    log_info "hello from test"

    assert_file_contains "$log_file" "hello from test" || return

    pass_test
}

test_info_message_written_to_file
```

Every line has a reason.

**`test_info_message_written_to_file()`** — The function name starts with `test_` by convention.
The name describes exactly what is being verified, not how. A reader should understand the
intent without reading the body.

**`start_test "INFO message is written to the log file"`** — This registers the test with the
runner and sets the human-readable name used in output and JUnit reports. It also calls
`setup_test` internally, which re-sources `logging.sh` and creates a fresh `$TEST_DIR`.
You must call this before anything else.

**`init_logger --level INFO --quiet`** — Initialises the logger. `--quiet` suppresses console
output so test output is clean. `--level INFO` sets the minimum severity. You need
`init_logger` before calling any `log_*` function.

**`local log_file="$TEST_DIR/test.log"`** — Declares a variable for the log path. Using a
`local` variable avoids polluting the surrounding scope. The path is under `$TEST_DIR`, which
is a unique per-test directory — see [Test isolation](#test-isolation) below.

**`LOG_FILE="$log_file"`** — Tells the logger where to write. After `init_logger`, you can
assign `LOG_FILE` to override the default (none). The logger creates the file on first write.

**`log_info "hello from test"`** — The code under test. Call it exactly as a real script would.

**`assert_file_contains "$log_file" "hello from test" || return`** — The assertion checks that
the string appears in the file. The `|| return` is critical — see the next section.

**`pass_test`** — Marks the test as passed. If execution reaches this line, all assertions
passed. If any assertion before it failed, `pass_test` is never called.

**`test_info_message_written_to_file`** — Tests are ordinary functions; they do nothing unless
called. Every function you define must be called at the bottom of the suite file.

### The start\_test / || return / pass\_test pattern

This is the lifecycle every test follows:

```
start_test → (do things) → assert ... || return → pass_test
```

The `|| return` after each assertion is not optional. Here is what happens without it:

```bash
# WRONG — do not do this
assert_file_contains "$log_file" "Expected string"
assert_file_contains "$log_file" "Another string"
pass_test
```

If the first assertion fails, `fail_test` is called internally, but execution continues. The
second assertion then runs too — possibly calling `fail_test` again on the same test, producing
misleading output. Then `pass_test` runs and marks the test as passed even though it failed.

The correct form:

```bash
# CORRECT
assert_file_contains "$log_file" "Expected string" || return
assert_file_contains "$log_file" "Another string" || return
pass_test
```

Each `|| return` says "if the assertion returned non-zero, exit this function immediately". The
test runner sees that `pass_test` was never called and counts the test as failed. The failure
message from the first failing assertion is preserved.

When testing internal values rather than assertions, use the same pattern:

```bash
[[ "$CURRENT_LOG_LEVEL" -eq "$LOG_LEVEL_INFO" ]] || { fail_test "Wrong level"; return; }
```

## Choosing the right assertion

### Prefer file assertions for log output

bash-logger writes to files. The most direct way to verify logging behaviour is to check the
file that the logger actually wrote:

```bash
init_logger --level DEBUG --quiet
local log_file="$TEST_DIR/test.log"
LOG_FILE="$log_file"

log_error "disk full"

assert_file_contains "$log_file" "disk full" || return
assert_file_contains "$log_file" "[ERROR]" || return
```

File assertions (`assert_file_contains`, `assert_file_not_contains`) are preferred because:

* They test the real output path — the same file a production script would write to.
* They are not affected by buffering or stream routing differences between subshells and the
  current shell.
* When a test fails, the file is left on disk (see `teardown_test` in `test_helpers.sh`) and
  you can inspect it directly.

### When to use output capture instead

Some behaviour can only be verified by capturing stdout or stderr — for example, testing that
`log_error` goes to stderr while `log_info` goes to stdout. For these cases, use a subshell
with explicit redirects:

```bash
bash -c "
    source '$PROJECT_ROOT/logging.sh'
    init_logger
    log_error 'something failed'
" >"$TEST_DIR/stdout" 2>"$TEST_DIR/stderr"

assert_file_contains "$TEST_DIR/stderr" "something failed" || return
assert_file_not_contains "$TEST_DIR/stdout" "something failed" || return
```

Writing the streams to files under `$TEST_DIR` and then using `assert_file_contains` keeps the
assertion style consistent and leaves the files available for debugging on failure.

Avoid `capture_output` and `capture_streams` for logging output tests. Those helpers merge or
capture the output of a command in the *current shell*, where the logger state is already
initialised. A subshell gives you a clean environment each time.

## Test isolation

### Why logging.sh is re-sourced on every test

`start_test` calls `setup_test`, which contains:

```bash
source "$PROJECT_ROOT/logging.sh"
```

This re-sources the module before every single test. The reason is that `logging.sh` maintains
global state: `LOG_FILE`, `LOG_LEVEL`, `QUIET_MODE`, and several other variables. Without
re-sourcing, state from one test leaks into the next. For example, if test A sets
`LOG_FILE=/tmp/a.log` and test B forgets to set `LOG_FILE`, test B writes to test A's file —
a subtle failure that is hard to diagnose.

Re-sourcing resets everything to defaults. This is why you do not need to call a "reset" or
"teardown" yourself between tests.

This also means you should not source `logging.sh` at the top of a suite file. If you do, it
runs once before any test, before `setup_test` has run, and before `$TEST_DIR` exists. The
per-test re-source inside `setup_test` is the correct mechanism.

### How TEST\_DIR works and why it matters for parallel execution

`$TEST_DIR` is created by `setup_test` as:

```bash
TEST_DIR="$TEST_TMP_DIR/$(date +%s%N)"
```

Each test gets a path that includes a nanosecond timestamp, making it unique. The parent
`$TEST_TMP_DIR` is a per-suite temporary directory created by the runner before sourcing the
suite file.

The runner can execute multiple test suites in parallel (it defaults to using all available
cores, capped at 8). Each parallel job runs in its own subshell with its own `$TEST_TMP_DIR`.
Test suites do not share state.

What this means for you:

* Always use `$TEST_DIR` for any file your test reads or writes. Never use a fixed path like
  `/tmp/test.log` — that path is shared across all parallel runs and will cause intermittent
  failures.
* Never write to `$TEST_TMP_DIR` directly. Write to `$TEST_DIR`, which is unique to your test.
* Do not assume test functions within the same suite run in isolation from each other at the
  file-system level — they share the same `$TEST_TMP_DIR` but each has its own `$TEST_DIR`
  subdirectory.

## Common patterns

These are the scenarios you will encounter most often. Each example is complete and can be
adapted directly.

### A message appears in the log file

This is the most common pattern. Use it whenever you are verifying that something *is* logged.

```bash
test_warn_message_in_file() {
    start_test "WARN message is written to the log file"

    # Initialise with --quiet so nothing appears on the terminal during tests.
    # --level DEBUG ensures all severity levels are enabled for this test.
    init_logger --level DEBUG --quiet
    local log_file="$TEST_DIR/test.log"
    LOG_FILE="$log_file"  # Direct file output to our test directory

    log_warn "low disk space"

    # assert_file_contains uses grep -F (fixed string), not a regex.
    assert_file_contains "$log_file" "low disk space" || return
    assert_file_contains "$log_file" "[WARN]" || return

    pass_test
}

test_warn_message_in_file
```

### Output goes to stderr not stdout

Use a subshell so you can separate the two streams cleanly.

```bash
test_error_goes_to_stderr() {
    start_test "ERROR messages go to stderr, not stdout"

    # Run the logger in a subshell and redirect each stream to a file.
    # $PROJECT_ROOT is exported by the test runner — always available.
    bash -c "
        source '$PROJECT_ROOT/logging.sh'
        init_logger
        log_error 'permission denied'
    " >"$TEST_DIR/stdout" 2>"$TEST_DIR/stderr"

    # Error output must appear on stderr.
    assert_file_contains "$TEST_DIR/stderr" "permission denied" || return
    # It must not also appear on stdout.
    assert_file_not_contains "$TEST_DIR/stdout" "permission denied" || return

    pass_test
}

test_error_goes_to_stderr
```

### A flag or config option is respected

Test the flag's effect directly by verifying observable output, not by checking internal
variables.

```bash
test_log_level_filtering() {
    start_test "DEBUG messages are suppressed when level is INFO"

    init_logger --level INFO --quiet
    local log_file="$TEST_DIR/test.log"
    LOG_FILE="$log_file"

    log_debug "this should not appear"
    log_info  "this should appear"

    # The debug message must be absent.
    assert_file_not_contains "$log_file" "this should not appear" || return
    # The info message must be present.
    assert_file_contains "$log_file" "this should appear" || return

    pass_test
}

test_log_level_filtering
```

### Invalid input is handled gracefully

Verify that the library does not crash or produce nonsense output when given unexpected input.
Use `assert_success` or `assert_failure` to check exit behaviour:

```bash
test_empty_message_does_not_crash() {
    start_test "Logging an empty string does not crash"

    init_logger --level DEBUG --quiet
    local log_file="$TEST_DIR/test.log"
    LOG_FILE="$log_file"

    # The library should handle an empty string without exiting non-zero.
    log_info "" || { fail_test "log_info returned non-zero for empty string"; return; }

    pass_test
}

test_empty_message_does_not_crash
```

### A test is skipped when a dependency is unavailable

Some tests require optional system commands (for example, `logger` for journal logging). Skip
gracefully rather than failing:

```bash
test_journal_logging_writes_entry() {
    start_test "Journal logging writes an entry via logger"

    # Skip if the system logger command is not available.
    if ! command -v logger >/dev/null 2>&1; then
        skip_test "logger command not available"
        return
    fi

    init_logger --journal --quiet
    log_info "journal test entry"

    # Verify the entry appeared in the journal (implementation detail:
    # bash-logger calls `logger` internally, so we check its side effect).
    pass_test
}

test_journal_logging_writes_entry
```

`skip_test` records the test as skipped in the summary and JUnit output. Always `return`
immediately after calling it — execution must not continue into the test body.

## What not to do

**Forgetting `|| return` after an assertion**

```bash
# WRONG
assert_file_contains "$log_file" "expected text"
assert_file_contains "$log_file" "other text"
pass_test  # Always reached, even if assertions failed
```

Execution continues after a failed assertion. The test will call `pass_test` despite having
failed. Always write `assert_file_contains "$log_file" "expected text" || return`.

**Writing to a fixed path instead of `$TEST_DIR`**

```bash
# WRONG
local log_file="/tmp/test.log"
LOG_FILE="$log_file"
```

The runner executes suites in parallel. Two tests using `/tmp/test.log` simultaneously will
corrupt each other's output and produce non-deterministic failures. Use
`local log_file="$TEST_DIR/test.log"` — `$TEST_DIR` is unique per test.

**Sourcing `logging.sh` at the top of a suite file**

```bash
# WRONG — place this at the top of a suite file
source "$PROJECT_ROOT/logging.sh"
```

`$TEST_DIR` does not exist yet when the file is first sourced by the runner. Re-sourcing
`logging.sh` inside each test (via `start_test` → `setup_test`) is the correct mechanism.
Any state you set at file scope will persist across tests and break isolation.

**Testing internal variables rather than observable output**

```bash
# WRONG
assert_equals "6" "$_log_level_numeric"
```

Internal variable names and values are implementation details that can change. Test what the
library *does* — the content of the log file, the exit code of a function, which stream a
message appears on — not the private state it uses to do it.

**Registering a function but forgetting to call it**

```bash
# WRONG — function is defined but never invoked
test_new_feature() {
    start_test "New feature works"
    # ...
    pass_test
}
# Missing: test_new_feature
```

Tests are ordinary shell functions. Defining them does nothing. Every test function must be
called at the bottom of the suite file. The runner does not auto-discover function names — it
sources the file and relies on the calls at the bottom to run the tests.

## Getting started quickly

Copy `tests/test_example.sh` as your starting point. It is a working suite with three annotated
example tests that demonstrate the patterns described here.

For the full assertion API reference, see [Testing](testing.md).
