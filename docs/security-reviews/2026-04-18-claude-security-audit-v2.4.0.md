# bash-logger v2.4.0 Security Audit

**Auditor:** Senior Security Researcher (Claude AI)
**Date:** 2026-04-18
**Component:** `logging.sh` v2.4.0
**Previous Audit:** 2026-02-13 (v2.1.2) — all findings resolved, posture rated EXCELLENT
**Severity Scale:** CRITICAL | HIGH | MEDIUM | LOW | INFO

---

## Executive Summary

This audit examines bash-logger v2.4.0, covering all changes introduced since the v2.1.2
follow-up audit (February 2026). The review focused on new features introduced in v2.2.x
through v2.4.0: selective journal logging (`log_to_journal`), syslog facility support, and
the init-message suppression option.

**Overall Security Posture:** EXCELLENT — unchanged from v2.1.2

**Findings Summary:**

| ID      | Severity | Type        | Title                                                                      |
| ------- | -------- | ----------- | -------------------------------------------------------------------------- |
| BUG-01  | LOW      | Bug         | `log_init()` messages unconditionally route to stderr                      |
| BUG-02  | LOW      | Bug         | `set_journal_tag()` bypasses all input validation                          |
| BUG-03  | LOW      | Bug         | `_strip_ansi_codes()` leaves DCS/PM/APC sequence bodies intact             |
| BUG-04  | LOW      | Bug         | Pre-set `LOGGER_*_ERROR_REPORTED` env vars suppress write-failure warnings |
| INFO-01 | INFO     | Docs        | `SECURITY.md` supported-versions table not updated for v2.4.0              |
| FEAT-01 | —        | Enhancement | Validate boolean input in `set_unsafe_allow_*()` functions                 |
| FEAT-02 | —        | Enhancement | `set_color_mode()` should reject unrecognised mode values                  |

* 0 Critical vulnerabilities
* 0 High vulnerabilities
* 0 Medium vulnerabilities
* 4 Low vulnerabilities
* 1 Informational / documentation item
* 2 Enhancement recommendations

**No findings block production use.**

---

## Scope and Methodology

### Changes reviewed since v2.1.2

* `log_to_journal()` — selective journal dispatch (v2.2.1)
* `set_syslog_facility()` / `--facility` option — syslog facility support (v2.3.0)
* `LOG_INIT_MESSAGE` / `--no-init-message` option — init-message suppression (v2.4.0)
* All runtime configuration setter functions
* `_strip_ansi_codes()` — ANSI sanitisation completeness
* Environment variable protection coverage

### Methodology

* Full static analysis of `logging.sh` source
* Cross-referencing runtime setters against config-parser validation paths
* Review of all public API functions for input validation consistency
* Differential analysis against previous audit findings
* Review of associated test coverage for new features

---

## Findings

### [BUG-01] `log_init()` Messages Unconditionally Route to stderr

**Severity:** LOW
**Component:** `log_init()`, `_should_use_stderr()`
**CWE:** CWE-670 (Always-Incorrect Control Flow Implementation)

**Description:**

`log_init()` passes `-1` as the level value to `_log_message()` so that INIT messages
always bypass the log-level filter (the intent). However, `-1` also causes `_should_use_stderr()`
to unconditionally return `true`, overriding the user's `--stderr-level` configuration:

```bash
# log_init() call:
log_init() {
    _log_message "INIT" -1 "$1"   # -1 bypasses level filter
}

# _should_use_stderr() check:
_should_use_stderr() {
    local level_value="$1"
    [[ "$level_value" -le "$LOG_STDERR_LEVEL" ]]  # -1 <= any positive value → always true
}
```

With the default `LOG_STDERR_LEVEL=3` (ERROR): `[[ -1 -le 3 ]]` is always true. Even
`--stderr-level EMERGENCY` (level 0) results in `[[ -1 -le 0 ]]` → true.

**Impact:**

* INIT messages always appear on stderr regardless of configuration
* Users who configure strict stderr levels (e.g., only EMERGENCY) cannot prevent INIT
  messages from polluting stderr
* Scripts that parse stderr for errors will receive false positives from INIT messages
* Breaks the user's ability to separate informational init output from actual errors

**Affected Versions:** All versions using the `-1` sentinel pattern (v1.x+)

**Proof of Concept:**

```bash
source logging.sh
init_logger --stderr-level EMERGENCY --no-color

# This should not appear on stderr — but it does:
log_init "Application starting" 2>/tmp/stderr_test.txt >/dev/null
cat /tmp/stderr_test.txt  # INIT message appears despite EMERGENCY threshold
```

**Recommended Fix:**

Option A (preferred) — give INIT a real level constant and bypass the filter explicitly:

```bash
# At constant initialisation:
readonly LOG_LEVEL_INIT=6   # Treat as INFO-equivalent for routing purposes

# In log_init():
log_init() {
    # Skip level filter but preserve normal stderr routing
    local saved_level="$CURRENT_LOG_LEVEL"
    CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG   # temporarily allow all
    _log_message "INIT" $LOG_LEVEL_INIT "$1"
    CURRENT_LOG_LEVEL="$saved_level"
}
```

Option B (minimal) — guard the stderr check against negative sentinel values:

```bash
_should_use_stderr() {
    local level_value="$1"
    [[ "$level_value" -ge 0 && "$level_value" -le "$LOG_STDERR_LEVEL" ]]
}
```

**Note:** `log_sensitive()` uses `skip_file=true, skip_journal=true` to control output
routing before `_should_use_stderr()` is consulted, so it is unaffected by this issue.

---

### [BUG-02] `set_journal_tag()` Bypasses All Input Validation

**Severity:** LOW
**Component:** `set_journal_tag()`
**CWE:** CWE-20 (Improper Input Validation)

**Description:**

`set_journal_tag()` assigns the caller-supplied value directly without any validation:

```bash
set_journal_tag() {
    local old_tag="$JOURNAL_TAG"
    JOURNAL_TAG="$1"      # ← no length check, no metacharacter check
    ...
}
```

In contrast, the configuration-file parser path calls `_validate_journal_tag()`, which
enforces a 64-character maximum length and rejects shell metacharacters. The runtime setter
silently bypasses both checks.

The journal tag is passed to the `logger` executable with proper quoting
(`"$LOGGER_PATH" ... -t "$tag"`), so shell command injection is not possible. However:

* Tags longer than 64 characters exceed systemd-journal's limit and may be silently truncated
  or rejected, producing an unreliable audit trail
* Tags containing control characters (including embedded NUL bytes) may corrupt journal indices
  or confuse log-analysis tooling
* A value rejected by the config-file parser can be set unimpeded via the runtime API,
  undermining users' reasonable expectation of consistent validation across both paths

**Impact:** Unreliable journal tagging when tags are set programmatically; misleading audit
trail; inconsistent security boundary between configuration paths.

**Proof of Concept:**

```bash
source logging.sh
init_logger --journal --no-color

# Config file would reject both of these; set_journal_tag() accepts both silently:
set_journal_tag "$(printf 'A%.0s' {1..200})"      # 200 chars, no error
set_journal_tag $'valid\x00hidden'                  # embedded NUL, no error
echo "Tag length: ${#JOURNAL_TAG}"                  # 200
```

**Recommended Fix:**

Add a call to the existing `_validate_journal_tag()` at the top of `set_journal_tag()`:

```bash
set_journal_tag() {
    if ! _validate_journal_tag "$1" 0; then   # 0 = not from config file
        return 1
    fi
    local old_tag="$JOURNAL_TAG"
    JOURNAL_TAG="$1"
    ...
}
```

This mirrors the pattern already established by `set_syslog_facility()` calling
`_validate_syslog_facility()`.

---

### [BUG-03] `_strip_ansi_codes()` Leaves DCS, PM, and APC Sequence Bodies Intact

**Severity:** LOW
**Component:** `_strip_ansi_codes()`
**CWE:** CWE-150 (Improper Neutralization of Escape, Meta, or Control Sequences)

**Description:**

`_strip_ansi_codes()` uses a multi-pass sed approach:

* **Step 1:** Removes CSI sequences (`\e[...letter`) — complete
* **Step 2:** Removes OSC sequences (`\e]...BEL` and `\e]...\e\\`) — complete
* **Step 3:** Removes two-character escape sequences (`\eX` where X ≠ `[`) — _partial_

Step 3 correctly removes the two-byte introducer for Device Control String (`\eP`), Privacy
Message (`\e^`), and Application Program Command (`\e_`) sequences, but the payload data and
ST terminator (`...data...\e\\`) that follows each opener is left in the output. Only OSC
(`\e]`) receives full body-stripping treatment in step 2.

**Impact:**

* Payload bytes from DCS, PM, and APC sequences survive sanitisation and appear in console
  output and log files
* DCS sequences are used by terminals for sixel graphics and Tmux passthrough; malicious
  payloads could affect terminal state
* PM and APC sequences are used by terminal multiplexers; escaped payloads could exfiltrate
  data via terminal query responses in interactive sessions
* Severity is LOW because exploitation requires attacker-controlled log input AND a terminal
  emulator that acts on these sequences in the specific way

**Proof of Concept:**

```bash
source logging.sh
init_logger --no-color

# DCS sequence: ESC P <payload> ESC \
dcs=$'\ePsixel-data-here\e\\'
result=$(_strip_ansi_codes "$dcs")
# Expected: ""
# Actual:   "sixel-data-here" + ESC + "\" remain in output

# PM sequence: ESC ^ <payload> ESC \
pm=$'\e^metadata\e\\'
result=$(_strip_ansi_codes "$pm")
# Actual:   "metadata" + ESC + "\" remain
```

**Recommended Fix:**

Insert additional passes after current step 2b, before the existing step 3, following the
same pattern used for OSC body stripping:

```bash
# Remove DCS sequences (\eP...payload...\e\\)
local step2c
step2c=$(printf '%s' "$step2b" | sed "s|${esc}P[^${esc}]*${esc}\\\\||g")

# Remove PM sequences (\e^...payload...\e\\)
local step2d
step2d=$(printf '%s' "$step2c" | sed "s|${esc}\\^[^${esc}]*${esc}\\\\||g")

# Remove APC sequences (\e_...payload...\e\\)
local step2e
step2e=$(printf '%s' "$step2d" | sed "s|${esc}_[^${esc}]*${esc}\\\\||g")

# Rename: existing step3 becomes step3 from step2e input
local step3
step3=$(printf '%s' "$step2e" | sed 's/\x1b[^[]//g')
```

Additional regression tests should be added to `tests/test_ansi_injection.sh` covering
DCS, PM, and APC payloads.

---

### [BUG-04] Pre-set `LOGGER_*_ERROR_REPORTED` Environment Variables Suppress Write-Failure Warnings

**Severity:** LOW
**Component:** `_log_message()`, `_write_to_journal()`
**CWE:** CWE-693 (Protection Mechanism Failure)

**Description:**

`_log_message()` and `_write_to_journal()` each use a global string flag to print
write-failure error messages only once (preventing log spam):

```bash
# In _log_message():
if [[ -z "${LOGGER_FILE_ERROR_REPORTED:-}" ]]; then
    echo "ERROR: Failed to write to log file" >&2
    LOGGER_FILE_ERROR_REPORTED="yes"
fi

# In _write_to_journal():
if [[ -z "${LOGGER_JOURNAL_ERROR_REPORTED:-}" ]]; then
    echo "Warning: logger command unavailable ..." >&2
    LOGGER_JOURNAL_ERROR_REPORTED="yes"
fi
```

Neither variable is unset or reset at source time. They are not included in the
environment-variable protection block that already guards `LOG_LEVEL_*` and `COLOR_*`
constants. If either is pre-set to any non-empty value in the process environment before
`logging.sh` is sourced, all write-failure warnings for that subsystem are silently
suppressed for the entire process lifetime.

An attacker with environment control (e.g., a compromised wrapper script, a crafted
`sudo` environment, or a CI pipeline with injected environment variables) can use:

```bash
export LOGGER_FILE_ERROR_REPORTED=yes
export LOGGER_JOURNAL_ERROR_REPORTED=yes
```

to ensure any failure of log delivery is invisible to the calling script and its operators,
hiding evidence of tampering with log destinations.

**Impact:**

* Write failures (disk full, permissions changed, file deleted) are silently swallowed
* Operators lose the only in-band signal that logging has failed
* Particularly relevant in security-sensitive scripts where the absence of log-delivery
  errors is treated as confirmation of successful audit logging

**Proof of Concept:**

```bash
export LOGGER_FILE_ERROR_REPORTED=injected

source logging.sh
init_logger --log /tmp/probe.log --no-color
chmod 000 /tmp/probe.log   # revoke write access after init

log_error "This fails silently"
# Expected: "ERROR: Failed to write to log file" on stderr
# Actual:   complete silence
```

**Recommended Fix:**

Add unconditional unset calls in the source-time initialisation block, mirroring the
pattern used for `LOG_LEVEL_*` constants:

```bash
# Near the top of logging.sh, in the initialisation section:
unset LOGGER_FILE_ERROR_REPORTED    2>/dev/null || true
unset LOGGER_JOURNAL_ERROR_REPORTED 2>/dev/null || true
```

These flags do not need `readonly` treatment because they are legitimately set to `"yes"`
during normal operation; only the initial value needs to be guaranteed empty on each source.

---

### [INFO-01] `SECURITY.md` Supported Versions Table Not Updated for v2.4.0

**Severity:** INFO / Documentation
**Component:** `SECURITY.md`

**Description:**

Following the release of v2.4.0, `SECURITY.md` still lists `2.3.x` and `2.2.x` as the
most recent supported versions. Version `2.4.x` is absent from the table entirely, which
could lead users to incorrectly conclude that the current release is unsupported and
discourage them from updating.

**Recommended Fix:**

Add `2.4.x` to the supported versions table and review whether `2.2.x` remains supported
or should be marked `:x:`.

---

### [FEAT-01] `set_unsafe_allow_newlines()` and `set_unsafe_allow_ansi_codes()` Should Validate Boolean Input

**Severity:** Enhancement
**Component:** `set_unsafe_allow_newlines()`, `set_unsafe_allow_ansi_codes()`

**Description:**

Both unsafe-mode setters assign the caller's argument without normalisation:

```bash
LOG_UNSAFE_ALLOW_NEWLINES="$1"
```

Values like `"True"`, `"yes"`, `"1"`, or `"enable"` are accepted silently. Because the
protection check is `!= "true"`, only the exact string `"true"` disables sanitisation —
so mistyped values leave protection _enabled_ — but the CONFIG log entry records the
incorrect value, producing a misleading audit trail.

This contrasts with every other runtime setter: `set_syslog_facility()` validates against
a whitelist, `set_log_level()` normalises via `_get_log_level_value()`.

**Recommended Enhancement:**

Add the same boolean normalisation the config parser already uses (accepts `true/false`,
`yes/no`, `on/off`, `1/0`), returning non-zero for unrecognised input.

---

### [FEAT-02] `set_color_mode()` Should Reject Unrecognised Mode Values

**Severity:** Enhancement
**Component:** `set_color_mode()`

**Description:**

The `*)` wildcard case in `set_color_mode()` sets `USE_COLORS` to whatever string is
passed, with a comment implying it handles the canonical `always/never/auto` passthrough:

```bash
*)
    USE_COLORS="$mode"  # Set directly if it's already "always", "never", or "auto"
    ;;
```

An invalid value like `"foobar"` is silently accepted, stored, and written to the CONFIG
log entry, then falls through to `_detect_color_support()` in `_should_use_colors()`.
This produces an unreliable and misleading configuration audit trail.

**Recommended Enhancement:**

Replace the wildcard with explicit acceptance of `always`, `never`, and `auto`, and
return non-zero with a descriptive error for all other values.

---

## Positive Security Observations

The following security improvements introduced since v2.1.2 were reviewed and found to
be correctly implemented:

### `log_to_journal()` — Secure Implementation

The new selective-journal function correctly:

* Validates the level name via an exhaustive `case` statement before any action
* Short-circuits silently when the message is below the current log level (no discovery side-effects)
* Uses the existing `_LOGGER_DISCOVERY_DONE` fast-path to avoid redundant path validation
* Performs an explicit `LOGGER_PATH` executability check before calling `_log_message()`
* Emits a single deduplication-guarded warning when `logger` is absent
* Passes `force_journal=true` to `_log_message()` correctly; `skip_journal` in `log_sensitive()` still takes precedence
* Prevents double-dispatch when `USE_JOURNAL=true` by passing the message through `_log_message` only once

### Syslog Facility Support — Correct Validation

`set_syslog_facility()` calls `_validate_syslog_facility()` before assignment and returns
non-zero on invalid input, following the correct defensive pattern. The facility is also
lowercased before storage and use.

### `LOG_INIT_MESSAGE` — Correct Environment Isolation

The new v2.4.0 variable uses an unconditional assignment (`LOG_INIT_MESSAGE="true"`) at
source time, which overrides any pre-existing environment value. This is the correct
approach and consistent with how `LOG_UNSAFE_ALLOW_NEWLINES` and `LOG_UNSAFE_ALLOW_ANSI_CODES`
are initialised.

---

## Test Coverage Assessment

| Finding | Existing Test Coverage                                                                 | Recommended New Tests                                                                                |
| ------- | -------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| BUG-01  | None — no test for stderr routing of `log_init`                                        | `test_initialization.sh`: assert `log_init` does not write to stderr when `--stderr-level EMERGENCY` |
| BUG-02  | `test_journal_logging.sh` covers `log_to_journal` but not `set_journal_tag` validation | `test_runtime_configuration.sh` (or new file): oversized tag, tag with control chars                 |
| BUG-03  | `test_ansi_injection.sh` covers CSI/OSC but not DCS/PM/APC bodies                      | Add DCS, PM, APC body-stripping tests to `test_ansi_injection.sh`                                    |
| BUG-04  | `test_environment_security.sh` covers `LOG_LEVEL_*` and `COLOR_*` but not error flags  | Add pre-set `LOGGER_FILE_ERROR_REPORTED` / `LOGGER_JOURNAL_ERROR_REPORTED` tests                     |

---

## Comparison to Previous Audits

| Metric          | v1.2.1 (Feb 2026) | v2.1.2 (Feb 2026) | v2.4.0 (Apr 2026)         |
| --------------- | ----------------- | ----------------- | ------------------------- |
| Critical        | 0                 | 0                 | 0                         |
| High            | 0                 | 0                 | 0                         |
| Medium          | 2                 | 0                 | 0                         |
| Low             | 3                 | 0                 | 4                         |
| Enhancements    | 4                 | 2                 | 2                         |
| Security Tests  | ~20               | 70+               | 70+ (new gaps identified) |
| Overall Posture | GOOD              | EXCELLENT         | EXCELLENT                 |

The four LOW findings represent defence-in-depth gaps and API consistency issues introduced
or exposed by features added since v2.1.2. None involve the core sanitisation or
path-validation mechanisms, which remain sound.

---

## Conclusion

bash-logger v2.4.0 maintains an **EXCELLENT** security posture. The core protections
established in v2.1.2 — secure-by-default input sanitisation, readonly constant protection,
validated logger path, symlink rejection, and defence-in-depth layering — are intact and
undiminished.

The four LOW bugs are all correctable in a focused patch release. The two enhancement
requests improve API consistency and audit-trail reliability without touching security
controls. No findings require immediate action from a production-safety perspective.

**Recommended next action:** Address BUG-04 (error-flag env protection) and BUG-02
(set_journal_tag validation) as highest-priority, since both directly affect the
integrity of the audit trail. BUG-01 and BUG-03 can follow in the same release.

---

**Audit Status:** ✅ COMPLETE
**Next Review:** Recommended after next major feature addition or 6–12 months
**Report Version:** 1.0
**Auditor:** Claude (AI Reviewer) — Senior Security Researcher role
**Date:** 2026-04-18
