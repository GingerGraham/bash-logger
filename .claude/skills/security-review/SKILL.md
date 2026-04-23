---
name: security-review
description: >
  Reviews code changes in bash-logger for security issues across all protected domains. Use this
  skill whenever adding new features that handle external input, changing sanitization behaviour,
  adding config options, or reviewing a PR for security. Covers input sanitization, file system
  safety, config injection, environment variable attacks, journal command validation, sensitive
  data handling, and unsafe flag governance.
---

# Security Review

## When to use this skill

Apply to any change that touches:

* Message processing or formatting (`_sanitize_log_message`, `_strip_ansi_codes`, format strings)
* File path handling (`init_logger`, `_parse_config_file`, `_validate_config_file_path`)
* Configuration parsing (new config keys, value parsing, `_parse_config_file`)
* Journal/`logger` integration (`_find_and_validate_logger`, `_write_to_journal`)
* Runtime setters (`set_*` functions, `--unsafe-*` flags)
* Any new public API function that accepts external input

---

## Domain 1: Input sanitization (log injection)

Every message written to file or journal passes through `_sanitize_log_message`, which calls
both `_strip_ansi_codes` (strips CSI, OSC, DCS, PM, APC sequences) and newline replacement.

**What to check:**

* New `_log_message` callers pass user-supplied content as the `$message` argument — not
  as part of `$level_name`, which is never sanitized (it comes from internal constants only).
* No new code path writes directly to `$LOG_FILE` without first calling `_sanitize_log_message`.
* If you add a new ANSI sequence type, update `_strip_ansi_codes` **and** add a test in
  `test_ansi_injection.sh`.
* Format string changes: `LOG_FORMAT` uses `%d`, `%l`, `%s`, `%m`, `%z` only. Never
  interpolate raw user data into the format string itself.

**Unsafe flags:**

`LOG_UNSAFE_ALLOW_ANSI_CODES` and `LOG_UNSAFE_ALLOW_NEWLINES` bypass sanitization. Their
setter functions (`set_unsafe_allow_*`, `--unsafe-allow-*` CLI flags) should:

* Always emit a WARNING to console when enabling
* Accept and validate boolean input — reject unrecognised values
* Write the mode change to the log file and journal so the audit trail shows the unsafe window

Never read `LOG_UNSAFE_*` inside `_format_log_message` or any library-generated output path
— only the user-message path should consult them.

---

## Domain 2: File system security (TOCTOU, symlinks, path traversal)

Log file creation in `init_logger` uses noclobber (`set -C; : > "$LOG_FILE"`) followed by
immediate validation to minimize the TOCTOU window.

**What to check:**

* No existence check (`-f`, `-e`) before file creation — this re-opens the TOCTOU window.
  Always create first, then validate.
* After any file creation: check `-L` (reject symlinks), `-e` (must exist — clearer error
  than the regular-file check alone), `-f` (must be regular file), `-w` (must be writable).
  These four checks are mandatory in that order.
* Path traversal: file paths from config must pass `_validate_config_file_path`, which
  enforces absolute paths and rejects injection patterns. CLI paths are not validated by
  `_validate_config_file_path` — if you add a new path-accepting CLI flag, apply the same
  absolute-path and injection-pattern checks.
* Never use `eval` or unquoted variable expansion in path construction.

**Test suites for this domain:**

```bash
./tests/run_tests.sh toctou_protection
./tests/run_tests.sh path_traversal
```

---

## Domain 3: Configuration file parsing (injection, length limits)

`_parse_config_file` reads untrusted INI content. All values pass through
`_validate_config_value_length` (max `CONFIG_MAX_VALUE_LENGTH` = 4096) before any
type-specific validation.

**What to check when adding a new config key:**

1. Add the key to the `case` block in `_parse_config_file`.
2. Apply the appropriate validator:
   * Free-form string → `_validate_string` with a sensible max length and `check_control_chars=true`
   * File path → `_validate_config_file_path`
   * Boolean → `_parse_bool_value`
   * Enum (e.g. log level, facility) → existing typed validator or a new allowlist `case`
   * Journal tag → `_validate_config_journal_tag`
3. Never `eval` a config value. Never use `source` on config content.
4. Verify shell metacharacters (`$`, `` ` ``, `;`, `|`, `&`, `<`, `>`) cannot reach a
   command execution context via the new key's handling code.
5. Add the new key name to the "Valid keys" hint in the `*` fallback branch.

**Test suites for this domain:**

```bash
./tests/run_tests.sh config_security
./tests/run_tests.sh config
```

---

## Domain 4: Environment variable security

On source, `logging.sh` unsets known environment variables before setting them as `readonly`
constants (log level integers, color codes). This prevents a pre-set environment from
poisoning constants.

**What to check:**

* New global constants that should not be user-overridable: unset before assignment, then
  declare `readonly`. Follow the existing guard pattern:

  ```bash
  if ! readonly -p 2>/dev/null | grep -q "declare -[^ ]*r[^ ]* MY_CONST="; then
      unset MY_CONST 2>/dev/null || true
      readonly MY_CONST="value"
  fi
  ```

* New mutable state variables (like `LOG_FILE`): these must not be `readonly`. Ensure they
  are reset to a safe default on each `source` so pre-set environment values cannot persist.
* `LOGGER_FILE_ERROR_REPORTED` and `LOGGER_JOURNAL_ERROR_REPORTED`: explicitly unset on
  source so a pre-set env value cannot permanently suppress error reporting. Any new
  "reported once" deduplication flag needs the same treatment.
* The `IFS`, `PATH`, and other critical shell variables are not modified by the library.
  Do not add code that sets or relies on a modified `IFS`.

**Test suites for this domain:**

```bash
./tests/run_tests.sh environment_security
```

---

## Domain 5: Journal / logger command validation

`_find_and_validate_logger` resolves the `logger` binary via `command -v`, then resolves
symlinks via `readlink -f`, then validates the real path against an allowlist:
`/bin/logger`, `/usr/bin/logger`, `/usr/local/bin/logger`, `/sbin/logger`, `/usr/sbin/logger`.

Once validated, `LOGGER_PATH` is set `readonly`. A changed path after lock triggers a
warning and disables journal logging rather than accepting the new path.

**What to check:**

* All journal writes use `"$LOGGER_PATH"` (the validated path), never `logger` or
  `$(command -v logger)` directly.
* New code that invokes external commands for any purpose must apply the same
  pattern: resolve → validate location → lock as readonly.
* The tag passed to `_write_to_journal` is always validated by `_validate_journal_tag`
  before use. Never pass raw user input as the tag argument.
* Syslog facility is validated by `_validate_syslog_facility` against a strict allowlist
  before being used in a `logger -p` invocation.

---

## Domain 6: Sensitive data

`log_sensitive` routes messages to console only (`skip_file=true`, `skip_journal=true`).
It bypasses the log-level filter (`force_show=true`) so sensitive output is always visible
during interactive sessions regardless of level configuration.

**What to check:**

* `log_sensitive` must never write to `$LOG_FILE`. Verify `skip_file` is `"true"` and not
  accidentally cleared by a new parameter reordering in `_log_message`.
* `log_sensitive` must never write to the journal. Verify `skip_journal` is `"true"`.
* No new feature should add a `--log-sensitive-to-file` option or equivalent — this
  would defeat the purpose of the function.
* Documentation: any new example in `docs/` or `demo-scripts/` that shows credentials,
  tokens, or passwords must use `log_sensitive`, not `log_info` or `log_debug`.

**Test suites for this domain:**

```bash
./tests/run_tests.sh sensitive_data
```

---

## Domain 7: Script name sanitization

`_sanitize_script_name` strips everything outside `[a-zA-Z0-9._-]`. It is applied to
the auto-detected caller script name, any `--name` CLI argument, any `script_name` config
value, and `SCRIPT_NAME` at the end of `init_logger` regardless of source.

**What to check:**

* Any new place that sets `SCRIPT_NAME` must call `_sanitize_script_name` on the value.
* The sanitized name is used in the INIT log message and every subsequent log entry; an
  unsanitized name would inject arbitrary content into every log line.

---

## Security test suite map

| Area                         | Test suite(s)                   |
| ---------------------------- | ------------------------------- |
| ANSI injection               | `test_ansi_injection`           |
| Log injection (newlines)     | `test_unsafe_newlines`          |
| Path traversal               | `test_path_traversal`           |
| TOCTOU / symlink attacks     | `test_toctou_protection`        |
| Config file injection        | `test_config_security`          |
| Environment variable attacks | `test_environment_security`     |
| Sensitive data isolation     | `test_sensitive_data`           |
| Script name sanitization     | `test_script_name_sanitization` |

Run all security suites together:

```bash
./tests/run_tests.sh ansi_injection unsafe_newlines path_traversal toctou_protection \
    config_security environment_security sensitive_data script_name_sanitization
```

After any security-related change, always follow with the full suite:

```bash
./tests/run_tests.sh
```

---

## Security checklist before committing

* [ ] New external input is sanitized before being written to file, journal, or console
* [ ] No new code path bypasses `_sanitize_log_message`
* [ ] No new constant is set without unset + readonly guard against env override
* [ ] New mutable state is reset to safe default on source
* [ ] New file path handling uses noclobber → symlink check → existence check → regular-file check → writable check
* [ ] New config key uses an appropriate typed validator; metacharacter injection is not possible
* [ ] Journal command is always invoked via `$LOGGER_PATH`, not `logger` directly
* [ ] `log_sensitive` still skips file and journal (parameters not reordered)
* [ ] Any new public setter validates its input and rejects unrecognised values
* [ ] Unsafe flag changes still emit WARNING log entries
* [ ] All relevant security test suites pass
* [ ] Full test suite passes
