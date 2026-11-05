# Shell Compatibility

`logging.sh` is written for **POSIX sh plus `local`**. The same file is sourced by bash, zsh,
dash and busybox ash, so `/bin/sh` scripts on Debian, Ubuntu and Alpine can use it.

## Table of Contents

* [Supported Shells](#supported-shells)
* [Sourcing the Library](#sourcing-the-library)
* [Documented Differences](#documented-differences)
* [Design](#design)
* [Testing Across Shells](#testing-across-shells)
* [Performance](#performance)

## Supported Shells

| Shell                              | Status                                             |
| ---------------------------------- | -------------------------------------------------- |
| bash 3.2 and later                 | Supported, including the bash 3.2 that macOS ships |
| bash in POSIX mode (`--posix`)     | Supported                                          |
| zsh                                | Supported                                          |
| dash (Debian and Ubuntu `/bin/sh`) | Supported                                          |
| busybox ash (Alpine `/bin/sh`)     | Supported                                          |
| ksh93                              | Not supported: no `local` in POSIX-style functions |
| fish                               | Not supported: not a POSIX shell                   |

Strict POSIX sh has no `local`. dash, busybox ash, FreeBSD `sh` and mksh all support it, so the
library uses it.

## Sourcing the Library

Use `.` in a POSIX sh script. `source` works in bash and zsh.

```sh
#!/bin/sh
. /path/to/logging.sh
init_logger --log /var/log/myscript.log
log_info "Started"
```

The external commands the library uses are the POSIX ones that every target system provides:
`date`, `sed`, `tr`, `grep`, `basename`, `dirname`, `mkdir`, `readlink`, `wc` and, for journal
logging, `logger`.

## Documented Differences

The library behaves the same in every supported shell, with these exceptions.

### Script name detection

When `init_logger` is called without `--name`, the script name in log messages comes from:

| Shell         | Source          | Result                             |
| ------------- | --------------- | ---------------------------------- |
| bash          | `BASH_SOURCE`   | The file that called `init_logger` |
| zsh           | `funcfiletrace` | The file that called `init_logger` |
| dash, busybox | `$0`            | The script being run               |

The results differ in two cases:

* `init_logger` is called from a file that the main script sources. bash and zsh report that
  file. dash and busybox report the main script.
* Commands come from `sh -c '...'` or standard input. bash reports `unknown`. dash, busybox and
  zsh report the shell's name.

Use `--name` (or `set_script_name`) when the exact name matters.

### Truncation counts characters or bytes

`LOG_MAX_LINE_LENGTH`, `LOG_MAX_JOURNAL_LENGTH` and the configuration value limits are measured
in:

* **characters** in bash and zsh (in a UTF-8 locale; bytes in the C locale)
* **bytes** in dash and busybox ash

A multi-byte UTF-8 character is never cut in half. When the limit falls inside a character, that
character is removed, so the result can be up to three bytes shorter than the limit.

For ASCII text the result is identical in every shell.

### Name and tag sanitization of multi-byte characters

Script names and journal tags keep only letters, digits, `.`, `_` and `-`. Every other character
becomes `_`. In dash each byte of a multi-byte character is replaced, so `é` becomes `__` instead
of `_`.

### Running logging.sh directly

`bash logging.sh` prints a usage message and exits with status 1, because the file is meant to be
sourced. POSIX sh has no reliable way to detect this, so in dash and busybox ash running the file
directly does nothing.

### Length checks use characters in every shell

Validation limits (for example the 64-character journal tag limit) count characters in every shell,
as bash does. In dash, a value with non-ASCII bytes that is over the limit in bytes is counted again
with `wc -m`.

## Design

### Decision

The core library uses a single implementation in POSIX sh plus `local` (Issue #143). This replaces
the earlier preference for bash-specific syntax in `logging.sh`. Other options were considered and
rejected:

* **A separate `logging-posix.sh`**: two copies of the same security controls would drift apart.
* **Bash-only fast paths everywhere**: two code paths to test and review for every function.

Shell-specific code is allowed only where a POSIX form cannot give the same result, guarded by
`BASH_VERSION` or `ZSH_VERSION`:

* script name detection (`BASH_SOURCE`, `funcfiletrace`)
* character-based truncation (`${var:0:n}`) in bash and zsh
* the executed-directly check in bash

Each of these lines has a `shellcheck disable` directive with the reason above it.

### Security validators

The validators used to rely on bash regular expressions (`=~`). They now use `case` patterns and
parameter expansion. `tests/test_validator_equivalence.sh` proves that they accept and reject
exactly the same inputs as the regular expressions did, using golden files generated from the
earlier code. Two details needed explicit handling:

* In a UTF-8 locale bash treats the C1 control characters (U+0080 to U+009F) and U+2028 and
  U+2029 as `[[:cntrl:]]`. dash and busybox do not, so the library checks for their UTF-8
  encodings itself.
* Bash arithmetic reads a number with a leading `0` as octal. The numeric checks keep that rule,
  so `max_line_length = 010` is still 8 and `08` is still rejected.

### Avoiding subshells

Earlier versions passed every message through four or more command substitutions, each of which
starts a subshell. The internal helpers now set a result variable instead (for example
`_sanitize_log_message_into` sets `_LOGGER_TEXT`), and ANSI stripping only starts `sed` when the
message contains an escape character. A plain message now starts one process, for the timestamp
(`date`), and that process is now most of the cost of each message.

### Long messages

Newlines, carriage returns and tabs are replaced before truncation, so a large message (for
example captured command output passed to `log_error`) is sanitized in full. To keep the cost
roughly linear in the message length:

* Above 2,048 characters in dash and busybox, or 16,384 in bash and zsh, a message that contains
  one of these characters is passed through one `tr` process.
* Shorter messages use pattern substitution in bash and zsh, and an in-shell loop in other
  shells, with no extra process.
* If `tr` fails, the in-shell replacement is used, so a message is never lost or left
  unsanitized.

The original helpers (`_sanitize_log_message`, `_strip_ansi_codes`, `_truncate_log_message`,
`_format_log_message` and others) still print their result, for existing callers and tests.

## Testing Across Shells

Four suites run `logging.sh` under every shell in `TEST_SHELLS`:

| Suite                           | What it checks                                                           |
| ------------------------------- | ------------------------------------------------------------------------ |
| `test_shell_compat.sh`          | Each scenario in `tests/compat/scenarios/` gives the same output as bash |
| `test_validator_equivalence.sh` | The validators match the golden results in `tests/compat/golden/`        |
| `test_sanitize_equivalence.sh`  | Messages are logged exactly as 2.7.0 logged them (golden corpus)         |
| `test_posix_compat.sh`          | The documented differences above, `set -eu`, and the color bytes         |

```bash
TEST_SHELLS="bash,bash --posix,zsh,dash,busybox sh" \
TEST_REQUIRE_SHELLS="zsh dash busybox" \
    ./tests/run_tests.sh test_shell_compat test_validator_equivalence \
    test_sanitize_equivalence test_posix_compat
```

`TEST_SHELLS` defaults to `bash`. Separate commands with commas when a command has flags. CI runs
all five shells and sets `TEST_REQUIRE_SHELLS`, so a missing shell fails instead of skipping.

On Fedora, install the shells with:

```bash
sudo dnf install zsh dash busybox
```

`scripts/check-posix-compat.sh` runs `shellcheck --shell=dash` on `logging.sh` and fails on any
`SC3xxx` finding. It runs as a pre-commit hook and in the lint workflow.

## Performance

`scripts/bench-logging.sh` reports the median time per message for each shell and scenario:

```bash
scripts/bench-logging.sh bash dash "busybox sh" zsh
scripts/bench-logging.sh --scenario plain --scenario lines-64k dash
```

The scenarios cover plain, filtered, console, custom-format, ANSI and UTF-8 messages, single
lines of 4 KB and 100 KB, and multi-line messages from 4 KB to 256 KB. Run the script with
`--help` for the list.

* A run that fails, or whose log file does not have the expected number of lines, prints
  `FAIL` and stops the script.
* `--baseline FILE` measures another copy of `logging.sh` in every shell and fails when a
  scenario is more than `--max-ratio` (default 1.15) slower, unless the difference is under
  100 microseconds. A shell the baseline cannot run in is reported as `baseline unavailable`.
* `--max-scaling` (default 32) fails when the 256 KB multi-line message costs more than that
  many times the 16 KB one. Linear growth is 16.

CI runs every scenario in every shell against the base branch and uploads the results.

The agreed budget for the POSIX conversion was no slowdown on bash. A plain message is now about
three times faster in bash and zsh than before the conversion, and the cost of a message grows
about linearly with its size.
