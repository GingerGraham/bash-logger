---
name: writing-tests
description: >
  Adds new tests to the bash-logger test suite. Covers creating new test suites, adding tests to
  existing suites, correct use of assertions, isolation patterns, and the mandatory call
  registration pattern. Use this skill whenever writing, extending, or fixing tests in the tests/
  directory.
---

# Writing Tests

Full assertion API reference is in `docs/testing.md`. Full contributor guide is in `docs/writing-tests.md`. This skill is the step-by-step agent workflow.

## Step 1 — Find the right file

```bash
ls tests/test_*.sh | grep -v test_example.sh | grep -v test_helpers.sh
```

* If a suite covering this area already exists, add to it.
* If not, create `tests/test_<feature>.sh` by copying the template:

```bash
cp tests/test_example.sh tests/test_<feature>.sh
chmod +x tests/test_<feature>.sh
```

Never modify `test_example.sh` — it is the contributor template.

## Step 2 — Write the function

```bash
test_<feature>_<scenario>() {
    start_test "<Human-readable description of what is being tested>"

    init_logger --level DEBUG --quiet

    local log_file="$TEST_DIR/test.log"
    LOG_FILE="$log_file"

    # ... test logic ...

    pass_test
}
```

Rules:

* Function name must start with `test_` and be unique within the file
* `start_test` **must** be the first line — it re-sources `logging.sh` and creates `$TEST_DIR`
* `pass_test` **must** be the last line of every passing path
* Do **not** source `logging.sh` at the top of the suite file — that runs before `$TEST_DIR` exists

## Step 3 — Register the function at the bottom of the file

```bash
# At the very bottom of the suite file:
test_<feature>_<scenario>
```

**This is mandatory.** Defining the function without calling it is a silent no-op — the runner will not discover it.

## Step 4 — Use `$TEST_DIR` for all file I/O

```bash
# Correct
local log_file="$TEST_DIR/test.log"

# Wrong — causes race conditions in parallel execution
local log_file="/tmp/test.log"
```

`$TEST_DIR` is a unique directory per test. Always use it for log files and any other file I/O.

## Step 5 — Assert correctly

Every assertion must be followed by `|| return`. Omitting it means a failed assertion does not stop the test and subsequent code runs against invalid state.

### Most common

```bash
assert_file_contains "$log_file" "expected string" "context message" || return
assert_file_not_contains "$log_file" "unexpected" "context message" || return
assert_equals "expected" "$actual" "context message" || return
assert_not_equals "unexpected" "$actual" "context message" || return
assert_file_exists "$path" || return
assert_file_not_exists "$path" || return
```

### Testing which stream output goes to

```bash
bash -c "
    source '$PROJECT_ROOT/logging.sh'
    init_logger
    log_error 'message'
" >"$TEST_DIR/stdout" 2>"$TEST_DIR/stderr"

assert_file_contains "$TEST_DIR/stderr" "message" || return
assert_file_not_contains "$TEST_DIR/stdout" "message" || return
```

### Exit codes

```bash
assert_success "some_function arg" || return
assert_failure "some_function bad_arg" || return
```

### Skipping conditionally

```bash
if [[ -z "${ZSH_VERSION:-}" ]]; then
    skip_test "Not running in zsh"
    return
fi
```

## Step 6 — Cover other shells when behaviour must match

`logging.sh` is POSIX sh plus `local` and also runs in bash `--posix`, zsh, dash and busybox ash. The suites run under bash. If the new behaviour must be the same in every shell, add a
scenario instead of (or as well as) a bash test:

* Create `tests/compat/scenarios/<name>.sh`: a short POSIX sh script starting with `# shellcheck shell=sh`, which sources `"$LOGGER_ROOT/logging.sh"` and writes any log file to
  `"$SCENARIO_DIR/test.log"`. An optional `# compat-locale: C.UTF-8` header line sets the locale (default `C`).
* No registration is needed. `test_shell_compat` runs every scenario under each shell in `TEST_SHELLS` and compares the results with bash.
* List a shell and scenario that is expected to differ in `tests/compat/known_failures.txt` (`<shell command>|<scenario file name>`). Never add an entry to hide a new regression.
* Do **not** regenerate the golden files in `tests/compat/golden/` from the current `logging.sh`. They record behaviour before the POSIX conversion.
* Helpers for loops over shells are in `tests/test_helpers.sh`: `test_shell_list`, `require_shell`, `run_with_logger_in_shell`, `shell_counts_characters`, `run_with_timeout`.

See [Tests that run under more than one shell](../../../docs/writing-tests.md#tests-that-run-under-more-than-one-shell).

## Step 7 — Run your suite, then the full suite

```bash
# New suite only first
./tests/run_tests.sh <suite_name>

# Then confirm no regressions
./tests/run_tests.sh
```

After any change to `logging.sh`, also run the cross-shell suites (see the `running-tests` skill):

```bash
TEST_SHELLS="bash,bash --posix,zsh,dash,busybox sh" ./tests/run_tests.sh test_shell_compat test_validator_equivalence test_sanitize_equivalence test_posix_compat
```

## Checklist before committing

* [ ] Function called at the bottom of the suite file
* [ ] `start_test` is the first line of every test function
* [ ] `pass_test` is the last line of every passing path
* [ ] Every assertion uses `|| return`
* [ ] All file I/O uses `$TEST_DIR`
* [ ] `init_logger` called after `start_test`, not at suite top-level
* [ ] Suite passes: `./tests/run_tests.sh <suite_name>`
* [ ] Full suite still passes: `./tests/run_tests.sh`
* [ ] If `logging.sh` changed: cross-shell run passes with `TEST_SHELLS` (or each skipped shell is reported)
* [ ] If the behaviour must match across shells: scenario added in `tests/compat/scenarios/`
