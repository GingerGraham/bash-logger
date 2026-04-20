---
name: running-tests
description: >
  Runs the bash-logger test suite — either the full suite or a targeted subset. Use this skill
  whenever running, selecting, or interpreting tests in this repository. Covers discovering
  available suites, choosing which to run after a change, correct invocation syntax, and reading
  test output.
---

# Running Tests

## Discover available suites first

Never assume which suites exist. Always discover them at runtime:

```bash
ls tests/test_*.sh | grep -v test_example.sh | grep -v test_helpers.sh | sed 's|tests/||; s|\.sh||'
```

This lists every runnable suite name. `test_example.sh` is a contributor template and `test_helpers.sh` is a shared library — neither is a runnable suite.

## Choosing: targeted vs full suite

Default to targeted. Only run the full suite for broad changes or as a pre-PR gate.

| What changed | Run |
| --- | --- |
| A specific functional area (e.g. format handling, log levels) | The matching suite(s) only |
| `logging.sh` core logic (init, output routing, sanitization) | Full suite |
| `install.sh` | `test_install` only |
| Config file parsing | `test_config` and `test_config_security` |
| Security-related code | Relevant security suites + full suite |
| New test file added | New suite only, then full suite |
| Pre-PR / CI gate | Full suite |

### Mapping changed code to suites

After discovering available suites, match by name:

* `logging.sh` format/template changes → `test_format`
* `logging.sh` level logic → `test_log_levels`
* `logging.sh` initialisation → `test_initialization`
* `logging.sh` output/stream routing → `test_output`
* Config file support → `test_config`, `test_config_security`, `test_runtime_config`
* Journal integration → `test_journal_logging`
* Sanitisation (ANSI, newlines, paths) → `test_ansi_injection`, `test_unsafe_newlines`, `test_path_traversal`, `test_script_name_sanitization`
* Security hardening → `test_environment_security`, `test_sensitive_data`, `test_config_security`, `test_toctou_protection`
* `install.sh` → `test_install`
* JUnit/CI reporting → `test_junit_output`

When in doubt about scope, run the full suite.

## Commands

### Full suite

```bash
./tests/run_tests.sh
```

Or via Make (quieter output):

```bash
make test
```

### Single suite

```bash
./tests/run_tests.sh <suite_name>
```

`<suite_name>` is the filename without the `test_` prefix **and** without `.sh`:

```bash
# Correct
./tests/run_tests.sh log_levels
./tests/run_tests.sh config
./tests/run_tests.sh initialization

# Also accepted — runner strips the extension
./tests/run_tests.sh test_log_levels.sh
```

### Multiple suites in one invocation

```bash
./tests/run_tests.sh config config_security runtime_config
```

### JUnit XML output (for CI artefacts)

```bash
make test-junit
```

## Reading output

```
✓ (green)   — passed
✗ (red)     — failed; expected/actual values printed below
⊘ (yellow)  — skipped (e.g. a zsh-only test running under bash)
```

Summary line: `Total Tests: N  Passed: N  Failed: N  Skipped: N`

Exit code `0` = all passed. Exit code `1` = at least one failure. Fix all failures before committing.

## Mistakes to avoid

* Do **not** run from inside the `tests/` directory — always run from repo root.
* Do **not** pass the full path (`tests/test_config.sh`) — pass the suite name only.
* Do **not** skip the discovery step and guess suite names — the list changes as the project grows.
* `test_helpers.sh` and `test_example.sh` are never valid suite arguments.
