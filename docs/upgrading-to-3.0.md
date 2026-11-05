# Upgrading to 3.0 <!-- omit in toc -->

3.0 rewrites `logging.sh` in POSIX sh plus `local`, so it also runs in dash and busybox ash. It is a
major release because some edge-case behaviour changed. Most bash scripts need no changes.

No public function, `init_logger` option, configuration key or documented variable was removed
or renamed.

## Table of Contents <!-- omit in toc -->

* [Changes in bash and zsh](#changes-in-bash-and-zsh)
* [CONFIG notices](#config-notices)
* [Changes in zsh only](#changes-in-zsh-only)
* [New behaviour in dash and busybox ash](#new-behaviour-in-dash-and-busybox-ash)
* [Internal names](#internal-names)
* [Checking your scripts](#checking-your-scripts)
* [Staying on 2.x](#staying-on-2x)

## Changes in bash and zsh

* **Messages `-n`, `-e` and `-E` are logged.** 2.x logged an empty message for these, including
  when they were what remained after ANSI codes were stripped.
* **A missing option value is an error.** `init_logger --format` (or `--level`, `--log`, `--name`,
  `--tag`, `--stderr-level`) as the last argument now prints `requires a value` and returns 1.
  In bash, 2.x looped forever. A second `--config` with no value does the same.
* **A line limit that is invalid octal disables truncation.** With `LOG_MAX_LINE_LENGTH` or
  `LOG_MAX_JOURNAL_LENGTH` set to a value such as `08`, `09` or `0189`, 2.x printed shell errors
  and lost the message under bash, or exited a script running with `set -e`. 3.0 logs the full
  message. A leading `0` still means octal, so `010` is 8.
* **A failed log file write prints one error.** The shell's own redirection error (for example
  `Is a directory`) no longer appears next to the logger's `Failed to write to log file` message.
* **Levels must be plain numbers.** `CURRENT_LOG_LEVEL` is documented as 0 to 7, and the
  `set_log_level` and `init_logger --level` interfaces are unchanged. If a script assigns the
  variable directly, values that are not numbers are no longer evaluated as arithmetic:
  `CURRENT_LOG_LEVEL=LOG_LEVEL_ERROR` used to mean 3, and now stops filtering. Use
  `CURRENT_LOG_LEVEL=$LOG_LEVEL_ERROR` or `set_log_level ERROR`.
* **`shopt -s xpg_echo` no longer affects messages.** With that option set, 2.x expanded
  backslash sequences in messages. Data is now printed with `printf`.
* **Level names work in a Turkish locale.** In `tr_TR.UTF-8`, 2.x treated names containing `i`,
  such as `info` and `critical`, as invalid. `--level critical` silently became `INFO`, and
  `log_to_journal info` returned an error.
* **Timestamps do not start `date` in bash 4.2+ and zsh.** The output is the same. If your tests
  replace `date` to fix the time in log lines, that no longer has an effect in these shells.

## CONFIG notices

The notices that the `set_*` functions print, such as `Log format changed`, changed in two ways:

* **They follow the stderr level.** They go to the same stream as a NOTICE message. With the
  default stderr level (`ERROR`) they stay on stdout, as in 2.x. With `--stderr-level` set to
  `NOTICE`, `INFO` or `DEBUG`, they now go to stderr. In 2.x they always went to stdout, which
  could corrupt the output of a script that captures its stdout.
* **A failed log file write is handled like any other message.** It is reported once, and the
  notice goes to stderr. In 2.x the failure was silent, and it exited a script running with
  `set -e`.

See [Runtime Configuration Notices](output-streams.md#runtime-configuration-notices).

## Changes in zsh only

* **The script name is detected.** Log lines show the calling script's name. 2.x showed
  `unknown`. Use `--name` if you need a fixed value. If you parse logs for `[unknown]`, update
  that pattern.
* **Backslash sequences in messages are logged as written.** 2.x expanded them, so a message
  containing `\n` could write a second log line and bypass newline sanitization. A message of
  exactly `-` is also logged now.
* **`set -u` works.** Sourcing the library under `set -u` or `setopt no_unset` failed in 2.x.
* **A leading `0` in a line limit means octal,** as it does in bash. `010` is 8, and `08` disables
  truncation.
* **Sourcing from inside a function works correctly.** The constants stay global, and the logger
  path lock now applies in zsh as it does in other shells.
* **Frequent signals with logging handlers can crash zsh 5.9.** This is a zsh bug that 3.0 exposes.
  See the [known limitation](shell-compatibility.md#known-limitation-zsh-signal-handlers).

## New behaviour in dash and busybox ash

These shells could not source 2.x. A few details differ from bash and zsh, such as truncation
counting bytes. See [Shell Compatibility](shell-compatibility.md#documented-differences).

## Internal names

The library adds internal functions and variables. Internal function names start with `_` and
variable names start with `_LOGGER_`. If your script defines one of these names, rename yours:

`_append_to_log_file`, `_bash_timestamp_into`, `_contains_control_characters`,
`_contains_shell_metacharacters`, `_count_characters`, `_current_timestamp_into`,
`_find_caller_script`, `_format_log_message_into`, `_get_log_level_color_into`,
`_get_syslog_priority_into`, `_has_word_after_separator`, `_is_digits`, `_is_utf8_locale`,
`_log_set_config_to_console`, `_log_set_config_to_file`, `_logger_readonly`,
`_parse_shell_integer`, `_replace_all`, `_replace_line_control_chars`,
`_replace_unsafe_name_characters`, `_require_option_value`, `_sanitize_log_message_into`,
`_shell_counts_characters`, `_strip_ansi_codes_into`, `_strip_trailing_newlines`, `_text_length`,
`_text_prefix`, `_truncate_log_message_into`, `_utc_timestamp_from_epoch`, `_write_log_message`,
`_zsh_timestamp_into`.

No internal function was removed.

## Checking your scripts

Search your scripts and log tooling for:

* `CURRENT_LOG_LEVEL=` or `LOG_STDERR_LEVEL=` with a value that is not a number
* zsh scripts or log parsers that expect `[unknown]` as the script name
* scripts that use `--stderr-level NOTICE`, `INFO` or `DEBUG` and read `CONFIG` notices from stdout
* functions or variables with the names listed above

To compare the two versions on one of your scripts:

```bash
curl -fsSLO https://github.com/GingerGraham/bash-logger/releases/download/2.7.0/logging.sh
```

Point the script at that file, run it, then point it at 3.0 and compare the output.

## Staying on 2.x

Only 3.x receives fixes. To stay on 2.7.0 while you test:

* **Install script:**
  `curl -fsSL https://raw.githubusercontent.com/GingerGraham/bash-logger/main/install.sh | INSTALL_VERSION=2.7.0 bash`
* **bpkg:** `bpkg install GingerGraham/bash-logger@2.7.0`
* **workbench:** `wb track bash-logger --tag 2.7.0`
* **Manual:** download `logging.sh` from the [2.7.0 release](https://github.com/GingerGraham/bash-logger/releases/tag/2.7.0)
