# Shell Compatibility

`logging.sh` is written for **POSIX sh plus `local`**. The same file is sourced by bash, zsh,
dash, busybox ash and mksh, so `/bin/sh` scripts on Debian, Ubuntu and Alpine can use it.

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
| mksh (Android `/bin/sh`)           | Supported, with 32-bit arithmetic (see below)      |
| posh                               | Not supported: refused at load time                |
| ksh93                              | Not supported: refused at load time                |
| yash                               | Not supported: fails to parse the file             |
| fish                               | Not supported: not a POSIX shell                   |

Strict POSIX sh has no `local`. dash, busybox ash, FreeBSD `sh` and mksh all support it, so the
library uses it.

A shell that is not in the list is not tested. Where it cannot run the library safely, `logging.sh`
refuses to load (see [Load-time self-check](#load-time-self-check)). yash cannot be checked this
way, because it fails to parse the file before any check can run.

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

### Installing on Alpine and other systems without bash

`install.sh` and bpkg are bash scripts. Where bash is not installed, download the file directly
and source it with `.`:

```sh
wget https://github.com/GingerGraham/bash-logger/releases/latest/download/logging.sh
```

### Journal logging on busybox

On Alpine, `logger` is normally a symlink to `busybox`. The library runs it through the symlink,
as the applet is selected from that name, and accepts it only when the symlink and `busybox` are
both in a safe directory, and the symlink points straight at a regular `busybox` file. A symlink
that points at another symlink is rejected, because the chain could be changed after the check
and the library follows the symlink on every message. busybox `logger` writes to syslog, so
messages reach whichever syslog daemon the system runs and not the systemd journal.

A `logger` that is a symlink, and that `readlink -f` cannot resolve (`readlink` is missing, or is
older than macOS 12.3), is not used, because where the link ends cannot be checked.

## Documented Differences

The library behaves the same in every supported shell, with these exceptions.

### 32-bit arithmetic

mksh calculates with 32-bit numbers, where bash, zsh and dash use 64 bits, and some builds of
busybox ash do too. `$((2147483647 + 1))` is `-2147483648` there. The library finds out when it is
sourced, by testing for the overflow, and sets `_LOGGER_ARITH_32BIT`. It does not look at the
shell's name, so any shell with 32-bit arithmetic is covered. Two places depend on it:

* A number with more than 8 digits is read as 99999999 without being calculated. It is above every
  limit that is checked (the largest is 1048576), and four times it still fits in 32 bits.
* `_utc_timestamp_from_epoch` divides the seconds by 86400 one digit at a time, so that an epoch of
  2147483648 (2038-01-19) or more is not wrapped. Only bash and zsh call it, to make UTC timestamps
  without starting `date`. Other shells use `date -u`.

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

Shell-specific code is allowed only where a POSIX form cannot give the same result, or for the
timestamp, where it removes most of the cost of a message. It is guarded by
`_LOGGER_SHELL_FAMILY`, which is set when the file is sourced. A `BASH_VERSION` or `ZSH_VERSION`
inherited from the environment does not change it.

* script name detection (`BASH_SOURCE`, `funcfiletrace`)
* character-based truncation (`${var:0:n}`) in bash and zsh
* the executed-directly check in bash
* timestamps without a process in bash 4.2+ and zsh (see [Timestamps](#timestamps))

Each of these lines has a `shellcheck disable` directive with the reason above it.

### Load-time self-check

Every shell other than bash and zsh runs the portable code, which is written and tested for dash
and busybox ash. A shell that cannot run it correctly must not write log lines, and some do. posh
loads the file, but its `${text%%"$separator"*}` leaves the text unchanged when the pattern is a
quoted variable followed by `*`. The code that replaces a newline in a message then never
replaces it, and a message can write a second, forged log line. ksh93 has no `local`, so each
function changes the variables of its caller.

When `_LOGGER_SHELL_FAMILY` is empty, `logging.sh` runs a short check before it defines any
function. It tests the two things the sanitizing code needs:

* `local` keeps a variable local to its function, so the caller's variable is unchanged
* `${text%%"$separator"*}`, `${text%"$separator"*}`, `${text#*"$separator"}` and
  `${text##*"$separator"}` give the expected results, with a newline and with a tab as the
  separator

If a test fails, the file prints one error to stderr and stops sourcing:

```text
logging.sh: this shell cannot run bash-logger safely (<reason>).
  Supported shells: bash 3.2+, zsh, dash, busybox ash, mksh. See docs/shell-compatibility.md.
```

`.` then returns 1, so a script that runs under `set -e` stops. A script that carries on has no
log functions to call, because none was defined. Run directly, the file exits with status 1.

The check uses no command substitution and no external command, and does not run in bash or zsh,
so it costs nothing measurable. No environment variable skips it, because an override would let
the environment turn the protection off.

yash parses the whole file before it runs any of it, and rejects `${remaining:$offset:256}`
(bash and zsh only, so it never runs there). It already fails closed, with a syntax error, so the
check cannot help and yash is documented as not supported. Supporting it would mean moving the
bash-only expansions into `eval` strings, as some already are.

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
message contains an escape character.

### Timestamps

Starting `date` is most of the cost of a plain message, so bash 4.2 and later and zsh format the
time with a builtin and start no process:

* **bash 4.2 and later:** `printf -v name '%(...)T' -1`. The library tests for this when it is
  sourced, so bash 3.2 uses `date`.
* **zsh:** prompt expansion (`%D{...}`), which needs no module.
* **dash and busybox ash:** `date`.

Local time follows `TZ` the way `date` does. For UTC, the library reads the seconds since the epoch
and calculates the date and time itself, so it never changes `TZ`. If a builtin does not give a
valid result, the library uses `date`.

bash's builtin reads a coarse clock, so at the moment a second changes, a timestamp can be one
second behind what `date` prints. The difference lasts a few milliseconds at most.

Tests that replace `date` to fix the time in log lines only affect the shells that still use it.

### Known limitation: zsh signal handlers

zsh 5.9 can crash (a segmentation fault) when a signal handler runs while the interrupted code
is inside part of zsh that is not safe to enter twice. That includes the `[` builtin and
pattern-matching parameter expansions such as `${var//pattern/replacement}`, `${var#pattern}`
and `${var%pattern}`. A script that does not use this library crashes the same way, for example
with a `[` test in a trap handler while the main code is in a `[` test, and a handler that is
signalled many times a second makes it likely.

2.x did not show this, and the reason is not that it was slower. It did its string handling in
command substitutions, so the pattern matching ran in a subshell. The signal goes to the main
shell process, which was never in the middle of a pattern match, and the handler's own log call
ran its pattern matching in a subshell too. 3.0 removed those subshells to make logging faster,
which put the pattern matching in the process that receives the signal.

**What the library protects against.** In zsh, a log call that arrives while another log call is
running in the same shell is written in a subshell. The call that was interrupted resumes with
its state intact, and the message is written immediately, so a handler or an `EXIT` trap that
logs does not lose it. In a stress test with a `log_warn` handler, a `log_info` loop and about 50
`USR1` signals per second, 30 of 30 runs crashed before this protection and 0 of 30 crashed with
it. It covers `log_*`, `log_init`, `log_sensitive` and `log_to_journal`, in zsh and in `zsh --emulate
sh` (or zsh run under the name `sh`), where the library loads the `zsh/parameter` module that it
needs to install the guard. If that module cannot be loaded, the guard is not installed and zsh
behaves as it did before. The cost is one extra
process for each nested call only, and normal calls are unchanged. bash, dash and busybox ash run
traps between commands, so they do not need it and do not use it.

The subshell cannot change the shell it was started from, so the library copies back the state
that a log call sets once: the file error and journal error messages are not repeated, and
journal logging that was switched off after a failure stays off. One thing is not copied back:
if `logger` has not been found yet, a nested `log_to_journal` call looks for it again in its
own subshell, until a call outside a handler has found it.

**What it does not protect against.** A handler that logs while the script's own code is in `[`,
`${var//pattern/replacement}` or another pattern-matching expansion, because the library cannot
guard code it does not run. The same applies to a handler that logs while the library itself is
outside a log call, such as in `log_to_journal` before it reaches the log call, or in the
`set_*` functions. If a handler is signalled many times a second and the main code does this kind
of work, 30 of 30 stress runs still crashed, with or without the library.

The `set_*` functions are not protected, which matters because a `USR1` handler is a common way to
change the log level while a script runs, for example `trap 'set_log_level DEBUG' USR1`. In zsh,
do not call a `set_*` function or a `log_*` function from a handler that is signalled many times a
second while the main code does its own pattern matching or `[` tests. Keep the handler to a plain
assignment and make the call from the main code:

```sh
signal_count=0
toggle_debug=0
trap 'signal_count=$((signal_count + 1))' USR1
trap 'toggle_debug=1' USR2

while :; do
    work
    if [ "$signal_count" -gt 0 ]; then
        log_warn "Received $signal_count USR1 signal(s)"
        signal_count=0
    fi
    if [ "$toggle_debug" -eq 1 ]; then
        set_log_level DEBUG
        toggle_debug=0
    fi
done
```

A handler that runs once, such as logging on `SIGTERM` before exiting, is very unlikely to hit it.

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

Five suites run `logging.sh` under every shell in `TEST_SHELLS`:

| Suite                           | What it checks                                                           |
| ------------------------------- | ------------------------------------------------------------------------ |
| `test_shell_compat.sh`          | Each scenario in `tests/compat/scenarios/` gives the same output as bash |
| `test_validator_equivalence.sh` | The validators match the golden results in `tests/compat/golden/`        |
| `test_sanitize_equivalence.sh`  | Messages are logged exactly as 2.7.0 logged them (golden corpus)         |
| `test_posix_compat.sh`          | The documented differences above, `set -eu`, and the color bytes         |
| `test_source_guard.sh`          | Sourcing twice, the readonly constants and `_is_readonly`                |

```bash
TEST_SHELLS="bash,bash --posix,zsh,dash,busybox sh,mksh" \
TEST_REQUIRE_SHELLS="zsh dash busybox mksh" \
    ./tests/run_tests.sh test_shell_compat test_validator_equivalence \
    test_sanitize_equivalence test_posix_compat test_source_guard
```

`TEST_SHELLS` defaults to `bash`. Separate commands with commas when a command has flags. CI runs
all six shells and sets `TEST_REQUIRE_SHELLS`, so a missing shell fails instead of skipping.

On Fedora, install the shells with:

```bash
sudo dnf install zsh dash busybox mksh
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

The agreed budget for the POSIX conversion was no slowdown on bash. Compared with 2.7.0, a plain
message is now about ten times faster in bash 4.2+ and zsh, and the cost of a message grows about
linearly with its size.
