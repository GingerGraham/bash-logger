# bash-logger v3.0.0 Security Audit

**Auditor:** Claude (AI security review, `security-review` skill)
**Date:** 2026-11-06
**Component:** `logging.sh` at tag `3.0.0` (`cf99ac7`)
**Previous audit:** 2026-04-18 (v2.4.0); pre-release review of PR #147 during 3.0 development
**Tracking issue:** #157
**Severity scale:** CRITICAL | HIGH | MEDIUM | LOW | INFO

---

## Executive Summary

3.0 rewrote `logging.sh` in POSIX sh. This audit reviewed the whole file at the `3.0.0` tag as code, not only the
diff. It also re-tested every finding from the pre-release review of PR #147.

**Overall security posture:** GOOD. All 10 findings from the PR #147 review are fixed and tested. No finding is
exploitable by an unprivileged attacker on a default system, so none needed a private advisory.

| ID     | Severity | Origin    | Title                                                                                 |
| ------ | -------- | --------- | ------------------------------------------------------------------------------------- |
| SEC-01 | LOW      | 3.0       | BusyBox `logger` exception accepts a chain of links through a writable directory      |
| SEC-02 | LOW      | 3.0       | Shell detection can be spoofed with an inherited version variable and a PATH file     |
| SEC-03 | LOW      | 2.x       | Config `tag` longer than 64 characters is truncated but not sanitized                 |
| SEC-04 | LOW      | 2.x       | `set_timezone_utc` and `set_journal_logging` write unvalidated values to the log      |
| SEC-05 | LOW      | 2.x       | Config `format` with control characters is used, despite a "may be stripped" warning  |
| SEC-06 | LOW      | 2.x       | `SCRIPT_NAME` from the environment is used unsanitized before `init_logger` runs      |
| INF-01 | INFO     | 2.x       | Bidirectional marks and zero-width characters are not removed                         |
| INF-02 | INFO     | 2.x       | `logger` symlinks are accepted unresolved when `readlink -f` is unavailable           |
| INF-03 | INFO     | 2.x       | Release job installs npm packages by major version, with a write token                |
| INF-04 | INFO     | 3.0       | Documentation and the `security-review` skill are out of date                         |

* 0 Critical, 0 High, 0 Medium
* 6 Low
* 4 Informational

"Origin 2.x" means the same behaviour exists in 2.7.0 (checked by running both versions).

Filed as issues: SEC-01 #160, SEC-02 #161, SEC-03 #162, SEC-04 #163, SEC-05 #164, SEC-06 #165, INF-03 #166,
INF-04 with INF-01 #167. INF-02 is included in #160.

---

## Scope and Methodology

### Scope

Everything listed in #157:

* **Sanitizers:** `_sanitize_log_message_into`, `_strip_ansi_codes_into`, `_contains_strippable_characters`,
  `_replace_line_control_chars` (the `tr` path for long text and the in-shell fallback),
  `_strip_trailing_newlines`, `_cap_message_length_into`
* **Validators:** `_validate_string`, `_contains_control_characters`, `_contains_shell_metacharacters`,
  `_has_word_after_separator`, `_validate_config_file_path`, `_validate_journal_tag`,
  `_validate_config_journal_tag`, `_validate_syslog_facility`, `_parse_bool_value`, `_parse_shell_integer`,
  `_replace_unsafe_name_characters`
* **Shell detection:** `_LOGGER_SHELL_FAMILY`
* **Read-only constants:** `_is_readonly`, `_logger_readonly`, including zsh sourcing from a function
* **Message handling:** result-variable save and restore in `_log_message`
* **Logger validation:** `_find_and_validate_logger`, `_write_to_journal`, `log_to_journal`
* **Timestamps:** `_zsh_timestamp_into`, `_bash_timestamp_into`, `_utc_timestamp_from_epoch`
* **Config parser:** `_parse_config_file`, including BOM, CRLF and quote handling
* **Environment:** every `_LOGGER_*` variable and every public global on each source
* **Runtime setters:** all `set_*` functions and their CONFIG notices

`install.sh`, the test suite and `scripts/` were out of scope, except the release workflow (INF-03).

### Methodology

* Full read of `logging.sh` at `3.0.0`, and of `logging.sh` at `2.7.0` for each finding, to classify its origin
* Tests in bash 5.2, `bash --posix`, dash, zsh 5.9 and busybox ash 1.36.1, with GNU and busybox userlands, in the
  C and C.UTF-8 locales
* Re-runs of each repro from the PR #147 review
* Timing tests for the quadratic-cost findings, at the input sizes that review used
* Security suites and the full test suite, run as a non-root user (as root, the permission tests fail because root
  ignores file modes): 687 tests, 680 passed, 0 failed, 7 skipped (missing locales)

BusyBox 1.37 with musl (Alpine) was not available, so the BusyBox 1.37 bracket-expression bug could not be
reproduced directly. The only bracket expression built from a quoted variable is reviewed under
[Positive Security Observations](#positive-security-observations).

---

## PR #147 Review: Status

Each finding was re-tested against `3.0.0`.

| ID | Finding                                              | Status | Evidence                                                                                 |
| -- | ---------------------------------------------------- | ------ | ---------------------------------------------------------------------------------------- |
| N1 | Readonly guard spoofed in dash and busybox ash       | Fixed  | `_is_readonly` runs `unset` in a subshell; repro keeps `LOGGER_PATH` empty in all shells |
| N2 | `_strip_trailing_newlines` quadratic                 | Fixed  | 80,000 trailing newlines with `-U --max-line-length 0`: 0.03 s to 0.06 s in all shells   |
| N3 | `_replace_unsafe_name_characters` quadratic          | Fixed  | 128 KB `SCRIPT_NAME`: 0.03 s to 0.05 s; input capped at 8192 characters                  |
| P1 | CSI grammar narrower than ECMA-48                    | Fixed  | All five example sequences removed, GNU and busybox sed                                  |
| P2 | C0, C1, U+2028/2029 and bidi overrides not removed   | Fixed  | BS, DEL, NEL, U+009B, U+2028, U+2029, RLO, LRI removed in all shells and both locales    |
| P3 | busybox sed quadratic on unterminated OSC            | Fixed  | 240 KB of `ESC]a` with busybox sed and no length limit: 0.19 s (was 89.5 s)              |
| P4 | sed runs in the caller's locale                      | Fixed  | sed and tr run with `LC_ALL=C`; `ESC \377` loses the ESC in C.UTF-8                      |
| P5 | `log_to_journal` ignores validation                  | Fixed  | Returns when validation fails; `_write_to_journal` requires `LOGGER_PATH` to be readonly |
| P6 | `-t/--tag` not validated on the CLI                  | Fixed  | CLI runs `_validate_journal_tag`                                                         |
| P7 | Log file not rechecked for symlinks; caller umask    | Fixed  | Created as 600 (directory 700); `-L` checked before each write; residual documented      |

The informational CI item (container images and actions pinned by tag) is unchanged; see INF-03.

The three findings fixed during the 3.0 independent review still have regression tests in
`tests/test_posix_compat.sh`:

* zsh UTC timestamps: `test_posix_utc_from_epoch`, and the per-shell timestamp tests
* silent exit under `set -e` with a readonly `TZ`: `test_posix_timestamp_readonly_tz`
* swappable symlink chain in the BusyBox exception: `test_posix_busybox_logger_symlink`. This test covers a first
  hop into another directory. It does not cover a second hop, which SEC-01 shows is still accepted.

---

## Findings

### [SEC-01] BusyBox `logger` exception accepts a chain of links through a writable directory

**Severity:** LOW
**Origin:** 3.0
**Location:** `_find_and_validate_logger`, `logging.sh` lines 768-787

The exception checks two things: the first link target (`readlink`) is spelled as one of the allowed busybox
paths, and the final target (`readlink -f`) is an allowed busybox path. It does not check whether that first
target is itself a symlink. If an allowed busybox name, such as `/usr/sbin/busybox`, is a link through a directory
other users can write to, the chain is accepted and `LOGGER_PATH` is locked to the `logger` symlink. Each journal
write then follows the whole chain again, so replacing the link in the writable directory runs a different program.

Issue #157 states that the exception must not accept a chain of links through an unsafe directory.

**Precondition:** root has created an allowed busybox path as a symlink into a writable directory. That is a
misconfiguration that already endangers anything run through that path, so this is not exploitable on a default
system.

**Repro** (as root, in a disposable container; `$W` stands for a directory other users can write to):

```sh
W=/tmp/unsafe; mkdir -p "$W"
ln -s /usr/bin/busybox "$W/busybox"
ln -s /usr/sbin/busybox /usr/local/bin/logger     # first hop: an allowed busybox name
ln -s "$W/busybox" /usr/sbin/busybox              # second hop: through the writable directory
cat > chain.sh <<'EOF'
. ./logging.sh
init_logger -q --no-init-message -j
printf '#!/bin/sh\necho EVIL-RAN "$@" > /tmp/evil.out\n' > "$W/payload"; chmod +x "$W/payload"
ln -sfn "$W/payload" "$W/busybox"                  # done later by any user who can write to $W
log_info "probe"
EOF
W="$W" PATH=/usr/local/bin:/usr/bin:/bin dash chain.sh; cat /tmp/evil.out
# EVIL-RAN -p daemon.info -t chain.sh -- probe
```

**Fix:** resolve the first target against the link's directory, then require it to be a regular file, not a link,
before accepting the exception:

```sh
case "$link_target" in
    /*) link_target_path="$link_target" ;;
    *) link_target_path="${logger_found%/*}/$link_target" ;;
esac
if [ -f "$link_target_path" ] && [ ! -L "$link_target_path" ]; then
    logger_candidate="$logger_found"
fi
```

Add a case to `test_posix_busybox_logger_symlink` where the `readlink` mock reports a busybox path that is itself a
link.

---

### [SEC-02] Shell detection can be spoofed with an inherited version variable and a PATH file

**Severity:** LOW
**Origin:** 3.0
**Location:** `logging.sh` lines 76-81

The check is `[ -n "${BASH_VERSION:-}" ] && command -v shopt`. `command -v` also succeeds for an executable named
`shopt` on `PATH`, or a function. In dash or busybox ash, an inherited `BASH_VERSION` plus a `shopt` file on `PATH`
sets `_LOGGER_SHELL_FAMILY=bash`; `ZSH_VERSION` plus an `emulate` file sets it to `zsh`.

Effects, both confirmed in dash:

* `bash`: sourcing fails with "Bad substitution" at the `BASH_SOURCE[0]` check, and the shell exits with status 2.
* `zsh`: `_logger_readonly` calls `typeset`, which does not exist, so `LOG_LEVEL_*` and `COLOR_*` are never set and
  no constant is readonly. The first log call then exits the shell with "Bad substitution".

Both fail closed: the script stops rather than logging unsanitized text. The precondition is control of `PATH`,
which already lets an attacker replace `sed` and `tr`, so this is a denial of service with no extra privilege.
Issue #157 asks that inherited version variables cannot change the family, and they can.

**Repro:**

```sh
mkdir -p fakebin; printf '#!/bin/sh\nexit 0\n' > fakebin/emulate; chmod +x fakebin/emulate
PATH="$PWD/fakebin:$PATH" ZSH_VERSION=5 dash -c '. ./logging.sh; echo "$_LOGGER_SHELL_FAMILY"; log_info x'
# typeset: not found (x25), then: zsh, then: Bad substitution
```

**Fix:** accept the builtin only. `command -v` prints a full path for a file on `PATH` and the bare name for a
builtin:

```sh
if [ -n "${BASH_VERSION:-}" ] && [ "$(command -v shopt 2>/dev/null)" = "shopt" ]; then
```

The same applies to `emulate`. This costs one subshell per source. A function named `shopt` still passes, but only
the calling script can define one: dash, busybox ash and zsh do not import functions from the environment.

---

### [SEC-03] Config `tag` longer than 64 characters is truncated but not sanitized

**Severity:** LOW
**Origin:** 2.x (2.7.0 behaves the same)
**Location:** `_parse_config_file`, `tag|journal_tag` branch, lines 1205-1222

When `_validate_config_journal_tag` fails, a tag longer than 64 characters is cut to 64 and used. The
control-character and metacharacter checks are skipped for that value. Only a shorter tag goes through
`_replace_unsafe_name_characters`. A long tag can therefore carry ESC, BEL, CR and `$(...)` into `JOURNAL_TAG`,
which is passed to `logger -t`. There is no command injection (the tag is a single argument), but control
characters reach the syslog identifier and anything that displays it.

`set_journal_tag` and the CLI `-t` reject the same value.

**Repro:**

```sh
esc=$(printf '\033'); bel=$(printf '\007')
printf 'tag=%s\n' "$(printf 'A%.0s' $(seq 1 60))${esc}]0;pwn${bel}\$(id)xxxxxx" > tag.ini
dash -c '. ./logging.sh; init_logger -c ./tag.ini -q 2>/dev/null; printf "%s" "$JOURNAL_TAG" | od -c | tail -2'
# ... A A A A A A 033 ] 0 ;
```

**Fix:** sanitize after truncating, in both cases:

```sh
_text_prefix "$value" 64
_replace_unsafe_name_characters "$_LOGGER_PREFIX"
JOURNAL_TAG="$_LOGGER_REPLACED"
```

---

### [SEC-04] `set_timezone_utc` and `set_journal_logging` write unvalidated values to the log

**Severity:** LOW
**Origin:** 2.x (2.7.0 behaves the same)
**Location:** `set_timezone_utc` (line 2328), `set_journal_logging` (line 2361)

Both setters assign `$1` without validation, and their CONFIG notice includes the value. CONFIG notices are built
with `_format_log_message` and never pass through `_sanitize_log_message_into`, so a newline in the value writes a
second, forged line to the console, the log file and the journal. `CLAUDE.md` requires every public setter to
validate its input; FEAT-01 of the v2.4.0 audit added this for the `set_unsafe_*` setters only.

**Precondition:** the calling script passes untrusted data to one of these setters.

**Repro:**

```sh
dash -c '. ./logging.sh; init_logger -l ./f.log -q --no-init-message
set_timezone_utc "x
2026-11-06 00:00:00 [ERROR] [root] forged"' 2>/dev/null; cat f.log
# ... [CONFIG] [dash] Timezone setting changed from false to x
# 2026-11-06 00:00:00 [ERROR] [root] forged
```

**Fix:**

1. Validate both values with `_parse_bool_value`, as `set_unsafe_allow_newlines` does, and return 1 for anything
   else.
1. Sanitize the message part of every CONFIG notice (`_sanitize_log_message_into "$message"`) before formatting it.
   `set_log_format` puts the caller's format string in its notice, so it needs this too.

---

### [SEC-05] Config `format` with control characters is used, despite a "may be stripped" warning

**Severity:** LOW
**Origin:** 2.x (2.7.0 behaves the same)
**Location:** `_validate_config_format`, lines 938-959

`_validate_config_format` always returns 0. For a format containing control characters it prints
"contains control characters (may be stripped)", but nothing strips them. The format is used as it is for every
console line, every log file line and the INIT line, so a config file can add terminal escape sequences and a mid-line
CR to every entry. The skill treats the config file as untrusted input.

**Repro:**

```sh
esc=$(printf '\033'); cr=$(printf '\r'); bel=$(printf '\007')
printf 'format=%s\n' "${esc}[2K${cr}%d [%l] %m${esc}]0;title${bel}" > fmt.ini
dash -c '. ./logging.sh; init_logger -c ./fmt.ini -l ./f.log -q --no-init-message 2>/dev/null; log_info hi'
cat -v f.log
# ^[[2K^M2026-11-06 14:38:47 [INFO] hi^[]0;title^G
```

**Fix:** return 1 from `_validate_config_format` when control characters remain after removing the tokens, so the
existing "Skipping invalid format string, using default" branch runs, and correct the warning text. `-f` and
`set_log_format` take the format from the calling script and can stay as they are.

---

### [SEC-06] `SCRIPT_NAME` from the environment is used unsanitized before `init_logger` runs

**Severity:** LOW
**Origin:** 2.x (2.7.0 behaves the same)
**Location:** `_format_log_message_into` (`%s` token), `_write_log_message` (journal tag fallback)

`SCRIPT_NAME` is not reset on source, and it is sanitized only inside `init_logger`, `set_script_name` and the
config parser. Logging works before `init_logger` is called, and `%s` and the journal tag fallback
(`${JOURNAL_TAG:-$SCRIPT_NAME}`) then use the inherited value as it is. A newline in it forges entries in every line
logged before `init_logger`, or in every line of a script that never calls it.

**Repro:**

```sh
SCRIPT_NAME="app] forged
2026-11-06 00:00:00 [ERROR] [root" dash -c '. ./logging.sh; log_info hi'
# 2026-11-06 14:38:53 [INFO] [app] forged
# 2026-11-06 00:00:00 [ERROR] [root] hi
```

**Fix:** at the end of `logging.sh`, after the functions are defined, sanitize an inherited value:

```sh
if [ -n "${SCRIPT_NAME:-}" ]; then
    _replace_unsafe_name_characters "$SCRIPT_NAME"
    SCRIPT_NAME="$_LOGGER_REPLACED"
fi
```

Resetting `SCRIPT_NAME` on source would also close this, but would change documented behaviour.

---

### [INF-01] Bidirectional marks and zero-width characters are not removed

**Origin:** 2.x

The sanitizer removes the bidirectional embeddings, overrides and isolates (U+202A to U+202E, U+2066 to U+2069). It
keeps LEFT-TO-RIGHT MARK U+200E, RIGHT-TO-LEFT MARK U+200F, ARABIC LETTER MARK U+061C, ZERO WIDTH SPACE U+200B and
the BOM U+FEFF. The marks can only move neutral characters such as punctuation, and the zero-width characters only
hide differences between similar text, so neither reverses a line the way an override does. Recommendation: list
them in `docs/sensitive-data.md` or the sanitization docs as kept, so the behaviour is explicit.

### [INF-02] `logger` symlinks are accepted unresolved when `readlink -f` is unavailable

**Origin:** 2.x

When `readlink` is missing, or `readlink -f` fails (macOS before 12.3 has no `-f`), `_find_and_validate_logger`
validates the unresolved path. A `/usr/bin/logger` that is a link to anywhere is then accepted. Only directories
that root controls are allowed, so this needs root to create such a link. Recommendation: when resolution fails and
the candidate is a symlink (`[ -L "$logger_candidate" ]`), reject it.

### [INF-03] Release job installs npm packages by major version, with a write token

**Origin:** 2.x

`release.yml` runs `npm install -g semantic-release@24 @semantic-release/changelog@6 ...` with no lockfile, then runs
`npx semantic-release` with `PAT_TOKEN` and `contents: write`. Every release resolves the newest matching versions
and all their dependencies. A compromised package release would run with a token that can push to the repository.
The container images (`alpine:latest`, `bash:${{ matrix.bash }}`) and actions are still pinned by tag, as the PR #147
review noted; those jobs have `contents: read`. Recommendation: install from a committed `package-lock.json` with
`npm ci`, or pin exact versions, and pin actions and images by digest.

### [INF-04] Documentation and the `security-review` skill are out of date

**Origin:** 3.0

* `docs/initialization.md` ("Be Aware of Environment Variable Overrides") says `init_logger` "may use LOG_FILE from
  environment". Sourcing resets `LOG_FILE`, `LOG_FORMAT`, `USE_COLORS`, `CURRENT_LOG_LEVEL`, `LOG_STDERR_LEVEL` and
  `USE_JOURNAL`; only `SCRIPT_NAME` is inherited (see SEC-06).
* `.claude/skills/security-review/SKILL.md`:
  * The test commands (`./tests/run_tests.sh ansi_injection ...`) fail with "Test file not found"; the runner needs
    the `test_` prefix.
  * The constant guard pattern it prescribes (`readonly -p | grep "declare -..."`) is the pattern N1 showed to be
    spoofable. 3.0 uses `_is_readonly` and `_logger_readonly`.
  * It names `_sanitize_log_message` and `_strip_ansi_codes`; the message path now uses the `_into` variants.

---

## Positive Security Observations

### Read-only constants

* `_is_readonly` tests readonly status directly (`! (unset "$1")`), so no output is parsed and no external command
  runs. The N1 repro now keeps an environment `LOGGER_PATH` and `_LOGGER_ESC` out in all five shells.
* `_logger_readonly` uses `typeset -gr` in zsh. Sourcing from a function, and from a nested function, leaves
  `LOG_LEVEL_*`, `_LOGGER_ESC` and `LOGGER_PATH` global and readonly after the function returns.

### Environment variables

Every `_LOGGER_*` variable is either assigned on each source or behind a readonly guard that assigns it. The
variables inserted into sed scripts (`_LOGGER_SED_STRIP_*`, `_LOGGER_UTF8_LEAD*`, `_LOGGER_UTF8_CONTINUATION`) are
readonly or cleared on source, so an environment value cannot inject sed commands. `_LOGGER_CHARACTER_COUNT` is not
set on source, but every reader assigns it first. `LOGGER_PATH`, `SYSLOG_FACILITY`, `LOGGER_*_ERROR_REPORTED` and
the public settings are reset unless already readonly.

### Bracket expressions

The only bracket expression built from a quoted variable is `*["$_LOGGER_STRIP_C0"]*` in
`_contains_strippable_characters`. `_LOGGER_STRIP_C0` holds only bytes 0x01-0x08, 0x0B, 0x0C, 0x0E-0x1F and 0x7F: no
`-`, `]`, `^`, `!` or `\`, which are the characters a shell can read as range or negation syntax. All 32 controls
were detected in every shell and locale tested. Every other allowlist is written out unquoted, character by
character.

### Sanitizers

* The sed expressions cannot match across an ESC that does not end its sequence, so their cost is linear in all
  tested sed versions, even with no length cap.
* The message is cut to a hard cap before sanitizing, and the `tr` path handles long text in one process.
* sed and tr run with `LC_ALL=C`, so the result does not depend on the caller's locale.
* An ESC followed by a UTF-8 lead byte no longer removes half of that character.

### Message handling

`_log_message` saves and restores all eight result variables. After `log_sensitive` with a short message, a message
longer than the cap and a message with escape sequences, `set` shows no trace of the text in any shell.
`log_sensitive` still passes `skip_file=true` and `skip_journal=true`.

### Timestamps

The two `eval` strings in `_zsh_timestamp_into` are constants, and no caller data reaches them.
`_utc_timestamp_from_epoch` accepts only digits (checked by `_is_digits`) and does not assign `TZ`, so a readonly
`TZ` cannot stop the script.

### Config parser

* The BOM is removed from line 1 only, and CRLF line endings are handled by the trailing-whitespace trim.
* Quotes are removed only when the same quote opens and closes the value.
* Values are length-checked before type validation. No value is evaluated or sourced.

A BOM plus CRLF plus quoted values file produced the same settings in all shells.

### Output

Every data print uses `printf '%s\n'`; there is no `echo` or `print` in `logging.sh`, so the zsh log injection fixed
in 3.0 has no other path. The only `printf` with a variable in its format is `printf "%.${length}s"`, where
`length` is an internal number.

### Journal and log file

* `LOGGER_PATH` is executed only when it is readonly, so a path assigned any other way is refused.
* The tag and message are separate arguments, with `--` before the message, and the facility comes from an
  allowlist.
* A new log file is created with noclobber under `umask 077`. Then come the symlink, existence, regular-file and
  writable checks, in that order, and the symlink check is repeated before each write.

---

## Test Coverage Assessment

Coverage of the 3.0 changes is strong: equivalence suites compare the POSIX validators and sanitizers with recorded
2.7 results, and `test_posix_compat.sh` runs each case in every available shell. Gaps found:

| Finding | Missing test                                                                         |
| ------- | ------------------------------------------------------------------------------------ |
| SEC-01  | A busybox path that is itself a symlink, as the second hop                           |
| SEC-02  | `BASH_VERSION`/`ZSH_VERSION` from the environment with a same-named file on `PATH`   |
| SEC-03  | A config tag over 64 characters that contains control characters                     |
| SEC-04  | Invalid values for `set_timezone_utc` and `set_journal_logging`                      |
| SEC-05  | A config format with control characters                                              |
| SEC-06  | Logging before `init_logger` with `SCRIPT_NAME` from the environment                 |

---

## Comparison to Previous Audits

| Audit                  | Critical | High | Medium | Low | Info |
| ---------------------- | -------- | ---- | ------ | --- | ---- |
| v2.1.2 (2026-02-13)    | 0        | 0    | 0      | 0   | —    |
| v2.4.0 (2026-04-18)    | 0        | 0    | 0      | 4   | 1    |
| PR #147 review (3.0)   | 0        | 0    | 4      | 6   | 1    |
| v3.0.0 (this audit)    | 0        | 0    | 0      | 6   | 4    |

The PR #147 Low count includes N2, which that review rated Low/Medium.

The PR #147 Medium findings (N1, P1, P2, P3) are fixed. Four of this audit's Low findings date from 2.x and were
missed by earlier audits; the two that are new in 3.0 (SEC-01, SEC-02) are in code that 3.0 added for BusyBox and
POSIX shells.

---

## Conclusion

3.0.0 is suitable for production use. The rewrite kept the 2.x protections and fixed every finding from the
pre-release review. The remaining findings need a calling script that passes untrusted data to the library, an
untrusted config file, or a root misconfiguration. SEC-01 and SEC-03 to SEC-06 have small, local fixes. SEC-02
needs one extra subshell per source.
