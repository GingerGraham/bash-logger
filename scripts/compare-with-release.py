#!/usr/bin/env python3
"""Compare logging.sh with a release of the previous major version.

Runs consumer-style scripts against two copies of logging.sh (the baseline release and the
candidate) and compares stdout, stderr, the log files written and the exit status:

* the same workload under 45 bash option and locale modes and 38 zsh modes
* scenarios that exercise the public API, under bash, bash --posix and zsh

Differences that the upgrade guide documents are listed, with the reason, in
compare-with-release.json next to this script. Any other difference fails the run.

Usage:
    scripts/compare-with-release.py [options]

Options:
    --baseline FILE   baseline logging.sh (default: the configured release, read with git show)
    --candidate FILE  candidate logging.sh (default: logging.sh in the repository)
    --filter TEXT     only run cases whose "shell/case" name contains TEXT
    --jobs N          number of cases run at the same time (default: number of CPUs)
    --json-out FILE   write every difference, with both outputs, to FILE
    --strict          fail if a shell or locale needed for a case is not installed

Exit status: 0 when every difference is allowed, 1 when one is not, 2 on a setup error.

bash and zsh run the baseline, so dash and busybox ash are not compared here. The
cross-shell suites in tests/ compare them with bash.
"""

import argparse
import concurrent.futures
import difflib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG_PATH = os.path.join(REPO_ROOT, "scripts", "compare-with-release.json")
DEFAULT_TIMEOUT_SECONDS = 60
OUTPUT_NAMES = ("stdout", "stderr", "log", "status")

# The workload that runs under every shell mode. It sets --name so that the zsh results are
# not all different because 2.x could not detect the script name in zsh. Inputs whose result
# changed in 3.0 (such as the messages -n and -e) are in their own scenarios below, so that
# only those scenarios need to be allowed.
WORKLOAD = r'''
. "$LIB"
rc=$?; printf 'source rc=%s\n' "$rc"
init_logger -l "$T/app.log" --level DEBUG --format '%d %z [%l] [%s] %m' --name script.sh
printf 'init rc=%s\n' "$?"
log_debug "debug msg"; log_info "info msg"; log_notice "notice"; log_warn "warn"; log_error "error"
log_critical "crit"; log_alert "alert"; log_emergency "emerg"; log_fatal "fatal"; log_init "init"; log_sensitive "secret"
for m in '--' '%s %d %m %l %z %%' '*' '[a-z]*' '?' '~' '$HOME' '`id`' '$(id)' \
  'a&b' '&' 'x=1' '  leading' 'trailing  ' '' ' ' '"quoted"' "'single'" '#hash' '!bang' 'é ü 日本語 🙂' \
  "$(printf 'line1\nline2')" "$(printf 'tab\there')" "$(printf 'cr\rhere')" "$(printf 'trail\n\n')x" \
  "$(printf '\033[31mred\033[0m')" "$(printf '\033]0;title\007rest')" "$(printf 'bell\007x')" "$(printf 'bs\010x')" \
  "$(printf '\302\205nel')" "$(printf '\342\200\250ls')" "$(printf '\377\376bad')"; do
    log_info "$m"; printf 'rc=%s\n' "$?"
done
log_info "$(printf 'x%.0s' 1 2 3)"
long=""; i=0; while [ "$i" -lt 500 ]; do long="${long}0123456789"; i=$((i+1)); done
log_info "$long"; log_info "$long$long"
set_log_format '%l|%m|%s|%z|%Z|%D|%L|%M|%S|%%|%'; log_info "fmt"
set_log_format '%d [%l] [%s] %m'
set_script_name 'we ird/na$me'; log_info "named"
set_log_level WARN; log_info "hidden"; log_warn "shown"; set_log_level debug
set_timezone_utc true; log_info utc; set_timezone_utc false
set_color_mode always; log_error colored; log_info colored2; set_color_mode never
set_color_mode bogus; printf 'rc=%s\n' "$?"
set_syslog_facility LOCAL3; printf 'rc=%s %s\n' "$?" "$SYSLOG_FACILITY"; set_syslog_facility nope; printf 'rc=%s\n' "$?"
set_journal_tag 'tag'; printf 'rc=%s\n' "$?"; set_journal_tag 'b$d'; printf 'rc=%s\n' "$?"
set_unsafe_allow_newlines true; log_info "$(printf 'a\nb')"; set_unsafe_allow_newlines false
set_unsafe_allow_ansi_codes true; log_info "$(printf '\033[1mb\033[0m')"; set_unsafe_allow_ansi_codes false
set_unsafe_allow_ansi_codes maybe; printf 'rc=%s\n' "$?"
printf 'end level=%s stderr=%s fmt=%s name=%s\n' "$CURRENT_LOG_LEVEL" "$LOG_STDERR_LEVEL" "$LOG_FORMAT" "$SCRIPT_NAME"
'''

# Shell modes for the workload: name -> (prelude, locale the prelude needs or None)
BASH_MODES = {
    "none": ("", None),
    "set-e": ("set -e", None),
    "set-u": ("set -u", None),
    "set-eu": ("set -eu", None),
    "strict": ("set -euo pipefail", None),
    "errtrace": ("set -eE\ntrap 'printf \"ERR-TRAP %s\\n\" \"$?\"' ERR", None),
    "errtrap-noexit": ("set -E\ntrap 'printf \"ERR-TRAP\\n\"' ERR", None),
    "ifs-empty": ("IFS=", None),
    "ifs-comma": ("IFS=,", None),
    "ifs-percent": ("IFS=%", None),
    "ifs-m": ("IFS=m", None),
    "ifs-digit": ("IFS=0123456789", None),
    "ifs-s": ("IFS='sd '", None),
    "noglob": ("set -f", None),
    "allexport": ("set -a", None),
    "noclobber": ("set -C", None),
    "posix-mode": ("set -o posix", None),
    "nounset-noglob": ("set -uf", None),
    "nullglob": ("shopt -s nullglob", None),
    "failglob": ("shopt -s failglob", None),
    "extglob": ("shopt -s extglob", None),
    "dotglob": ("shopt -s dotglob", None),
    "nocasematch": ("shopt -s nocasematch", None),
    "nocaseglob": ("shopt -s nocaseglob", None),
    "globstar": ("shopt -s globstar", None),
    "xpg_echo": ("shopt -s xpg_echo", None),
    "lastpipe": ("shopt -s lastpipe", None),
    "no-patsub": ("shopt -u patsub_replacement", None),
    "globasciiranges-off": ("shopt -u globasciiranges", None),
    "localvar_inherit": ("shopt -s localvar_inherit", None),
    "localvar_unset": ("shopt -s localvar_unset", None),
    "inherit_errexit": ("set -e; shopt -s inherit_errexit", None),
    "POSIXLY": ("POSIXLY_CORRECT=1", None),
    "compat32": ("shopt -s compat32", None),
    "compat44": ("shopt -s compat44", None),
    "lc-c": ("export LC_ALL=C", None),
    "lc-posix": ("export LC_ALL=POSIX", None),
    "lc-cutf8": ("export LC_ALL=C.UTF-8", "C.UTF-8"),
    "lc-engb": ("export LC_ALL=en_GB.UTF-8", "en_GB.UTF-8"),
    "lc-tr": ("export LC_ALL=tr_TR.UTF-8", "tr_TR.UTF-8"),
    "lc-latin1": ("export LC_ALL=de_DE.ISO-8859-1", "de_DE.ISO-8859-1"),
    "lang-only": ("unset LC_ALL; export LANG=en_GB.UTF-8", "en_GB.UTF-8"),
    "tz": ("export TZ=Asia/Tokyo", None),
    "debug-trap": ("set -T\ntrap ':' DEBUG", None),
    "path-min": ("PATH=/usr/bin:/bin", None),
}

ZSH_MODES = {
    "none": ("", None),
    "err_exit": ("setopt err_exit", None),
    "err_return": ("setopt err_return", None),
    "no_unset": ("setopt no_unset", None),
    "pipefail": ("setopt pipe_fail", None),
    "strict": ("set -euo pipefail", None),
    "sh_word_split": ("setopt sh_word_split", None),
    "ksh_arrays": ("setopt ksh_arrays", None),
    "extended_glob": ("setopt extended_glob", None),
    "glob_subst": ("setopt glob_subst", None),
    "null_glob": ("setopt null_glob", None),
    "no_nomatch": ("setopt no_nomatch", None),
    "no_case_match": ("setopt no_case_match", None),
    "no_case_glob": ("setopt no_case_glob", None),
    "rc_quotes": ("setopt rc_quotes", None),
    "rc_expand_param": ("setopt rc_expand_param", None),
    "posix_builtins": ("setopt posix_builtins", None),
    "posix_strings": ("setopt posix_strings", None),
    "octal_zeroes": ("setopt octal_zeroes", None),
    "c_bases": ("setopt c_bases", None),
    "ignore_braces": ("setopt ignore_braces", None),
    "bsd_echo": ("setopt bsd_echo", None),
    "no_function_argzero": ("setopt no_function_argzero", None),
    "warn_create_global": ("setopt warn_create_global", None),
    "warn_nested_var": ("setopt warn_nested_var", None),
    "typeset_silent": ("setopt typeset_silent", None),
    "no_multibyte": ("setopt no_multibyte", None),
    "noglob": ("setopt noglob", None),
    "clobber-off": ("setopt no_clobber", None),
    "emulate-sh": ("emulate sh", None),
    "emulate-ksh": ("emulate ksh", None),
    "ifs-comma": ("IFS=,", None),
    "ifs-empty": ("IFS=", None),
    "allexport": ("setopt all_export", None),
    "lc-c": ("export LC_ALL=C", None),
    "lc-cutf8": ("export LC_ALL=C.UTF-8", "C.UTF-8"),
    "lc-tr": ("export LC_ALL=tr_TR.UTF-8", "tr_TR.UTF-8"),
    "lc-latin1": ("export LC_ALL=de_DE.ISO-8859-1", "de_DE.ISO-8859-1"),
}

# API scenarios, run under bash, bash --posix and zsh: name -> body. Each body is a script
# that sources $LIB. $T is a temporary directory for the case, and the working directory.
SCENARIOS = {
    "source-twice": r'''
. "$LIB"
. "$LIB"
init_logger --level DEBUG
log_debug d; printf "%s\n" "$BASH_LOGGER_VERSION" | wc -l
''',
    "source-in-function": r'''
setup() { . "$LIB"; init_logger --level DEBUG; }
setup
log_debug d; log_error e; printf "%s\n" "$COLOR_RED" | od -c | head -1
''',
    "source-with-args": r'''
set -- a b c
. "$LIB"
printf "%s\n" "$#" "$1"
init_logger
log_info x
printf "%s\n" "$#"
''',
    "no-init": r'''
. "$LIB"
log_info before; log_error before2; printf "[%s]\n" "${SCRIPT_NAME:-unset}"
''',
    "no-init-strict": r'''
set -euo pipefail
. "$LIB"
log_info before; printf "ok\n"
''',
    "no-args": r'''
. "$LIB"
init_logger
log_info; printf "rc=%s\n" "$?"
''',
    "no-args-u": r'''
set -u
. "$LIB"
init_logger
(log_info); printf "rc=%s\n" "$?"
''',
    "multi-args": r'''
. "$LIB"
init_logger
log_info a b c
log_to_journal; printf "rc=%s\n" "$?"
''',
    "rc-preserved": r'''
. "$LIB"
init_logger
false; log_error "code $?"; printf "rc=%s\n" "$?"; log_debug x; printf "rc=%s\n" "$?"
''',
    "stdin-loop": r'''
. "$LIB"
init_logger
printf "a\nb\nc\n" | while IFS= read -r l; do log_info "$l"; log_info "$(printf "\033[1m$l")"; done
''',
    "stdin-redirect": r'''
. "$LIB"
init_logger -l "$T/x.log"
while IFS= read -r l; do log_warn "$l"; set_log_format "%m"; done <<EOF
one
two
three
EOF
''',
    "subshell": r'''
. "$LIB"
init_logger -l "$T/x.log"
( log_info sub; exit 3 ); printf "rc=%s\n" "$?"
v=$(log_info capture); printf "[%s]\n" "$v"
''',
    "exec-direct": r'''
"$SHELL_CMD" "$LIB"; printf "rc=%s\n" "$?"
''',
    "unknown-opt": r'''
. "$LIB"
init_logger --nope; printf "rc=%s\n" "$?"
log_info still
''',
    "all-short": r'''
. "$LIB"
init_logger -l "$T/a.log" -n nm -d DEBUG -f "%l %m" -u -q -t tg -F local1 -e WARN -U -A --no-color --max-line-length 20 --max-journal-length 30 --no-init-message; printf "rc=%s\n" "$?"
log_info "0123456789012345678901234567890"
set | grep -E "^(CONSOLE_LOG|USE_UTC|JOURNAL_TAG|SYSLOG_FACILITY|LOG_STDERR_LEVEL|LOG_UNSAFE_ALLOW_NEWLINES|LOG_UNSAFE_ALLOW_ANSI_CODES|LOG_MAX_LINE_LENGTH|LOG_MAX_JOURNAL_LENGTH|LOG_INIT_MESSAGE|USE_COLORS|VERBOSE|CURRENT_LOG_LEVEL|SCRIPT_NAME)="
''',
    "all-long": r'''
. "$LIB"
init_logger --log "$T/a.log" --name nm --level debug --format "%m" --utc --tag tg --facility LOCAL2 --stderr-level err --unsafe-allow-newlines --unsafe-allow-ansi-codes --color --verbose --debug --logfile "$T/b.log" --log-file "$T/c.log" --file "$T/d.log" --script-name nm2 --colour --no-colour; printf "rc=%s\n" "$?"
log_info x
set | grep -E "^(LOG_FILE|CONSOLE_LOG|USE_UTC|JOURNAL_TAG|SYSLOG_FACILITY|LOG_STDERR_LEVEL|USE_COLORS|VERBOSE|CURRENT_LOG_LEVEL|SCRIPT_NAME)="
''',
    "bad-max": r'''
. "$LIB"
for v in abc -1 1.5 "" 0 010 08 09 0189 99999999999999999999 " 5"; do init_logger --max-line-length "$v"; printf "rc=%s max=%s\n" "$?" "$LOG_MAX_LINE_LENGTH"; ( log_info "0123456789012345678901234567890"; printf "lrc=%s\n" "$?" ); done
''',
    "direct-var-limit": r'''
. "$LIB"
init_logger
for v in 0x10 " 10" 10abc -5 1+1 010 08 20 "" abc "2*10"; do LOG_MAX_LINE_LENGTH="$v"; ( log_info "0123456789012345678901234567890"; printf "rc=%s [%s]\n" "$?" "$v" ); done
''',
    "direct-var-level": r'''
. "$LIB"
init_logger
for v in 7 3 DEBUG "" 1+1 abc LOG_LEVEL_DEBUG; do CURRENT_LOG_LEVEL="$v"; ( log_info "i-$v"; printf "rc=%s\n" "$?"; log_error "e-$v"; printf "rc=%s\n" "$?" ); done
''',
    "direct-var-stderr": r'''
. "$LIB"
init_logger
for v in 7 0 WARN "" abc; do LOG_STDERR_LEVEL="$v"; ( log_info "i-$v"; log_error "e-$v" ); done
''',
    "direct-vars": r'''
. "$LIB"
LOG_FILE="$T/d.log"; USE_UTC=true; LOG_FORMAT="%z %m"; CONSOLE_LOG=false; log_info a; CONSOLE_LOG=true; USE_COLORS=always; log_warn b; USE_COLORS=weird; log_warn c; LOG_FILE=""; log_info d; LOG_UNSAFE_ALLOW_NEWLINES=yes; log_info "$(printf "n\nl")"; LOG_UNSAFE_ALLOW_ANSI_CODES=1; log_info "$(printf "\033[1mz")"
''',
    "env-preset": r'''
export LOG_LEVEL_DEBUG=0 COLOR_RED=evil LOGGER_PATH=/tmp/evil SYSLOG_FACILITY=evil LOGGER_FILE_ERROR_REPORTED=yes _LOGGER_ESC=x _LOGGER_TEXT=y _LOGGER_REPLACED=z _LOGGER_INTEGER=1 SCRIPT_NAME="env name"
. "$LIB"
init_logger --level DEBUG; log_debug d; log_error e; printf "%s %s %s %s\n" "$LOG_LEVEL_DEBUG" "$SYSLOG_FACILITY" "$LOGGER_PATH" "$SCRIPT_NAME"
''',
    "preset-readonly": r'''
COLOR_RED=mine; readonly COLOR_RED
LOG_FORMAT=mine
. "$LIB"
printf "rc=%s\n" "$?"
init_logger; log_error x; printf "%s %s\n" "$COLOR_RED" "$LOG_FORMAT"
''',
    "readonly-enforced": r'''
. "$LIB"
( LOG_LEVEL_DEBUG=9 ) 2>/dev/null; printf "%s\n" "$?"
( COLOR_RED=9 ) 2>/dev/null; printf "%s\n" "$?"
( BASH_LOGGER_VERSION=9 ) 2>/dev/null; printf "%s\n" "$?"
''',
    "internals": r'''
. "$LIB"
init_logger -n nm
_sanitize_log_message "$(printf "a\tb\033[1m")"
_strip_ansi_codes "$(printf "\033[1mz\033[0m")"
_truncate_log_message "0123456789012345678901234" 20
_truncate_log_message "0123" ""
_format_log_message INFO hi | sed "s/^[^[]*//"
_get_log_level_color ERROR | od -c | head -2
_get_syslog_priority 3
_sanitize_script_name "a b\$c"
_get_log_level_value warn
_get_log_level_name 4
_should_use_colors; printf "%s\n" "$?"
_should_use_stderr 2; printf "%s\n" "$?"
_validate_journal_tag "x;y"; printf "%s\n" "$?"
_validate_syslog_facility "kern"; printf "%s\n" "$?"
_log_to_console "entry" INFO 6
_log_message INFO 6 viainternal
_write_to_journal info t m; printf "%s\n" "$?"
_to_lower ABC; _parse_bool_value Yes; _parse_bool_value q; printf "%s\n" "$?"
''',
    "config-all": r'''
cat > "$T/c.ini" <<EOF
; comment
# comment
[sec]
level = debug
format = "%l %m"
log_file = $T/cfg.log
utc = yes
color = never
stderr_level = warning
quiet = false
console_log = on
script_name = "cfg name"
verbose = false
unsafe_allow_newlines = no
unsafe_allow_ansi_codes = off
max_line_length = 30
max_journal_length = 40
init_message = true
tag = "tg"
facility = LOCAL4
journal = false
nope = 1
=novalue
badline
  spaced   =   value with spaces
LEVEL=debug
EOF
. "$LIB"
init_logger -c "$T/c.ini"; printf "rc=%s\n" "$?"
log_debug "d0123456789012345678901234567890123456"
printf "%s|%s|%s|%s|%s|%s\n" "$LOG_FILE" "$CURRENT_LOG_LEVEL" "$LOG_FORMAT" "$SCRIPT_NAME" "$SYSLOG_FACILITY" "$JOURNAL_TAG"
''',
    "config-crlf-bom": r'''
printf "\357\273\277level=debug\r\nformat=%%m\r\n" > "$T/c.ini"
. "$LIB"
init_logger -c "$T/c.ini"; log_debug hi; printf "[%s][%s]\n" "$CURRENT_LOG_LEVEL" "$LOG_FORMAT"
''',
    "config-noeol": r'''
printf "level=debug" > "$T/c.ini"
. "$LIB"
init_logger --config "$T/c.ini"; log_debug hi
''',
    "config-override": r'''
printf "level=error\nformat=CFG %%m\n" > "$T/c.ini"
. "$LIB"
init_logger --level debug -c "$T/c.ini"; log_debug hi
''',
    "config-missing": r'''
. "$LIB"
init_logger -c "$T/none.ini"; printf "rc=%s\n" "$?"; log_info x
''',
    "config-empty-arg": r'''
. "$LIB"
init_logger -c ""; printf "rc=%s\n" "$?"
''',
    "config-injection": r'''
printf "log_file=/tmp/\$(id).log\nformat=\$(id) %%m\nscript_name=\$(id)\ntag=a;b\nlevel=\$(id)\n" > "$T/c.ini"
. "$LIB"
init_logger -c "$T/c.ini"; printf "rc=%s\n" "$?"; log_info x; printf "%s|%s|%s\n" "$LOG_FILE" "$SCRIPT_NAME" "$JOURNAL_TAG"
''',
    "logfile-dir": r'''
mkdir "$T/d"
. "$LIB"
init_logger -l "$T/d"; printf "rc=%s\n" "$?"
''',
    "logfile-symlink": r'''
ln -s "$T/target" "$T/l"
. "$LIB"
init_logger -l "$T/l"; printf "rc=%s\n" "$?"
''',
    "logfile-nested": r'''
. "$LIB"
init_logger -l "$T/a/b/c.log"; printf "rc=%s\n" "$?"; log_info x; cat "$T/a/b/c.log" | wc -l
''',
    "logfile-readonly": r'''
touch "$T/ro.log"; chmod 444 "$T/ro.log"
. "$LIB"
init_logger -l "$T/ro.log"; printf "rc=%s\n" "$?"
''',
    "logfile-removed": r'''
. "$LIB"
init_logger -l "$T/rm/x.log"; rm -rf "$T/rm"; log_info a; printf "rc=%s\n" "$?"; log_info b; printf "rc=%s\n" "$?"
''',
    "logfile-removed-strict": r'''
set -euo pipefail
. "$LIB"
init_logger -l "$T/rm/x.log"; rm -rf "$T/rm"; log_info a; printf "rc=%s\n" "$?"; log_info b; printf "rc=%s\n" "$?"
''',
    "journal-real": r'''
. "$LIB"
init_logger -j -t tg --level debug; printf "rc=%s use=%s path=%s\n" "$?" "$USE_JOURNAL" "$LOGGER_PATH"
log_info x; printf "rc=%s use=%s\n" "$?" "$USE_JOURNAL"
log_to_journal warn y; printf "rc=%s\n" "$?"
log_to_journal bogus y; printf "rc=%s\n" "$?"
log_to_journal 3 y z; printf "rc=%s\n" "$?"
set_journal_logging true; printf "rc=%s\n" "$?"
set_journal_logging false; printf "rc=%s\n" "$?"
check_logger_available; printf "rc=%s\n" "$?"
''',
    "journal-fake-path": r'''
mkdir "$T/bin"; printf "#!/bin/sh\necho fake\n" > "$T/bin/logger"; chmod +x "$T/bin/logger"; PATH="$T/bin:$PATH"
. "$LIB"
init_logger -j; printf "rc=%s use=%s\n" "$?" "$USE_JOURNAL"; log_to_journal info x; printf "rc=%s\n" "$?"
''',
    "journal-none": r'''
mkdir "$T/bin"; for c in date basename dirname mkdir grep sed tr tput wc; do p=$(command -v $c) && ln -s "$p" "$T/bin/$c"; done; PATH="$T/bin"
. "$LIB"
init_logger -j; printf "rc=%s use=%s\n" "$?" "$USE_JOURNAL"; log_to_journal info x; printf "rc=%s\n" "$?"; log_to_journal info y; printf "rc=%s\n" "$?"
''',
    "colors-force": r'''
. "$LIB"
export CLICOLOR_FORCE=1
init_logger; for f in log_debug log_info log_notice log_warn log_error log_critical log_alert log_emergency log_fatal log_init log_sensitive; do $f x; done; unset CLICOLOR_FORCE; NO_COLOR=1; log_error y; unset NO_COLOR; CLICOLOR=0; log_error z
''',
    "source-rc-set-e": r'''
set -e
. "$LIB"
printf "survived-source\n"
v=$(check_logger_available; printf "%s" "$?"); printf "%s\n" "$v"
''',
    "errexit-in-if": r'''
set -e
. "$LIB"
if log_info cond; then printf yes\n; fi; log_info x && printf and\n; log_info y || printf or\n
''',
    "trap-exit": r'''
. "$LIB"
init_logger
trap 'log_warn "exiting $?"' EXIT
log_info body
exit 4
''',
    # The sed removes the timestamp, which the normalization cannot match once it is cut
    "cmd-sub-capture": r'''
. "$LIB"
init_logger
out=$(log_error x 2>&1); printf "%s\n" "$out" | sed "s/^[^[]*//"
''',
    "function-caller": r'''
f() { init_logger; log_info in-f; }
. "$LIB"
f
''',
    "long-sizes": r'''
. "$LIB"
init_logger --max-line-length 0 -f "%m" -l "$T/s.log" --no-init-message -q
gen() { awk -v n="$1" -v s="$2" 'BEGIN{for(i=0;i<n;i++){printf "%s",(i%64==63)?s:"x"}}'; }
for n in 2047 2048 2049 4095 4096 4097 16383 16384 16385 70000; do log_info "$(gen $n Z)"; log_info "$(gen $n "\n")"; log_info "$(gen $n "\t")"; log_info "$(gen $n "\r")"; done
cksum < "$T/s.log"; wc -lc < "$T/s.log"
''',
    "trunc-limits": r'''
. "$LIB"
init_logger -f "%m"
for l in 1 5 13 14 15 16 100; do LOG_MAX_LINE_LENGTH=$l; log_info "abcdefghijklmnopqrstuvwxyz"; log_info "ééééééééééééééééééééééééééééééé"; done
''',
    # The scenarios below isolate behaviour that the upgrade guide documents as changed
    "echo-option-messages": r'''
. "$LIB"
init_logger -l "$T/x.log" --name script.sh
for m in -n -e -E -; do log_info "$m"; done
''',
    "backslash-message": r'''
. "$LIB"
init_logger -l "$T/x.log" --name script.sh
log_info 'back\slash\n\t\033'
''',
    "backslash-message-xpg-echo": r'''
[ -n "${BASH_VERSION:-}" ] && shopt -s xpg_echo
. "$LIB"
init_logger -l "$T/x.log" --name script.sh
log_info 'back\slash\n\t\033'
''',
    "missing-option-value": r'''
. "$LIB"
init_logger --format; printf "rc=%s\n" "$?"
''',
    "second-config-no-value": r'''
printf "level=debug\n" > "$T/c.ini"
. "$LIB"
init_logger -c "$T/c.ini" -c; printf "rc=%s\n" "$?"
''',
    "config-notice-stderr-level": r'''
. "$LIB"
init_logger --stderr-level DEBUG --name script.sh
set_log_format "%l %m"; set_log_level info
''',
    "config-notice-write-failure": r'''
set -e
. "$LIB"
init_logger -l "$T/rm/x.log" --name script.sh; rm -rf "$T/rm"
set_log_level debug; printf "survived\n"
''',
    "replaced-date-command": r'''
date() { printf "FAKE-DATE\n"; }
. "$LIB"
init_logger --name script.sh --format "%d %m"
log_info x
''',
}

# Scenarios that need a locale: name -> (body, locale)
LOCALE_SCENARIOS = {
    "turkish-level-names": (r'''
export LC_ALL=tr_TR.UTF-8
. "$LIB"
init_logger --level critical --name script.sh; printf "level=%s\n" "$CURRENT_LOG_LEVEL"
set_log_level info; printf "level=%s\n" "$CURRENT_LOG_LEVEL"
''', "tr_TR.UTF-8"),
}

# 2.x loops forever on these, so they stop sooner than the default
SCENARIO_TIMEOUT_SECONDS = {
    "missing-option-value": 10,
    "second-config-no-value": 10,
}

SHELL_COMMANDS = {
    "bash": ["bash"],
    "posix": ["bash", "--posix"],
    "zsh": ["zsh", "-f"],
}

TIMESTAMP_PATTERN = re.compile(rb"\d{4}-\d\d-\d\d \d\d:\d\d:\d\d")
# Line numbers in shell error messages change with any edit:
#   bash: "<LIB>: line 1848: ..."    zsh: "<LIB>:2011: ..." or "_log_message:35: ..."
BASH_LINE_PATTERN = re.compile(rb"(<LIB>: line )\d+(:)")
ZSH_LINE_PATTERN = re.compile(rb"^([A-Za-z_<>][A-Za-z0-9_<>]*:)\d+(:)", re.MULTILINE)


def normalize_locale_name(name):
    """Normalize a locale name the way glibc lists it: en_GB.UTF-8 -> en_gb.utf8."""
    return name.lower().replace("-", "")


def installed_locales():
    try:
        listing = subprocess.run(["locale", "-a"], capture_output=True, text=True, check=False)
    except FileNotFoundError:
        return set()
    return {normalize_locale_name(line.strip()) for line in listing.stdout.splitlines()}


def snippet(body):
    """Remove the newline after the opening quotes and the one before the closing quotes."""
    return body[1:-1] if body.startswith("\n") and body.endswith("\n") else body


def build_cases():
    """Return every case as a dict: shell, name, body, locale, timeout."""
    cases = []
    for mode_name, (prelude, locale) in BASH_MODES.items():
        cases.append(dict(shell="bash", name=mode_name, body=prelude + "\n" + WORKLOAD,
                          locale=locale, timeout=DEFAULT_TIMEOUT_SECONDS))
    for mode_name, (prelude, locale) in ZSH_MODES.items():
        cases.append(dict(shell="zsh", name=mode_name, body=prelude + "\n" + WORKLOAD,
                          locale=locale, timeout=DEFAULT_TIMEOUT_SECONDS))
    cases.append(dict(shell="posix", name="workload", body=WORKLOAD,
                      locale=None, timeout=DEFAULT_TIMEOUT_SECONDS))

    all_scenarios = {name: (body, None) for name, body in SCENARIOS.items()}
    all_scenarios.update(LOCALE_SCENARIOS)
    for scenario_name, (body, locale) in all_scenarios.items():
        timeout = SCENARIO_TIMEOUT_SECONDS.get(scenario_name, DEFAULT_TIMEOUT_SECONDS)
        for shell in ("bash", "zsh", "posix"):
            cases.append(dict(shell=shell, name="x:" + scenario_name, body=snippet(body),
                              locale=locale, timeout=timeout))
    return cases


def run_case(case, library_path):
    """Run one case against one copy of logging.sh and return its normalized results."""
    temp_dir = tempfile.mkdtemp(prefix="cmp")
    script_path = os.path.join(temp_dir, "script.sh")
    with open(script_path, "w", encoding="utf-8") as script_file:
        script_file.write(case["body"])

    shell_command = SHELL_COMMANDS[case["shell"]]
    environment = {
        "PATH": "/usr/local/bin:/usr/bin:/bin",
        "HOME": os.environ.get("HOME", "/tmp"),
        "TERM": "dumb",
        "LIB": library_path,
        "T": temp_dir,
        "SHELL_CMD": shell_command[0],
        "TZ": "UTC",
        "LC_ALL": "C.UTF-8",
    }
    try:
        completed = subprocess.run(shell_command + [script_path], env=environment,
                                   capture_output=True, timeout=case["timeout"],
                                   cwd=temp_dir, stdin=subprocess.DEVNULL, check=False)
        stdout, stderr, status = completed.stdout, completed.stderr, str(completed.returncode)
    except subprocess.TimeoutExpired as timeout_error:
        stdout = timeout_error.stdout or b""
        stderr = timeout_error.stderr or b""
        status = "TIMEOUT"

    log_contents = b""
    for directory, _, file_names in sorted(os.walk(temp_dir)):
        for file_name in sorted(file_names):
            if not file_name.endswith(".log"):
                continue
            try:
                with open(os.path.join(directory, file_name), "rb") as log_file:
                    log_contents += file_name.encode() + b":\n" + log_file.read()
            except OSError:
                log_contents += file_name.encode() + b": unreadable\n"
    shutil.rmtree(temp_dir, ignore_errors=True)

    def normalize(data):
        data = TIMESTAMP_PATTERN.sub(b"<TS>", data)
        data = data.replace(temp_dir.encode(), b"<T>").replace(library_path.encode(), b"<LIB>")
        data = BASH_LINE_PATTERN.sub(rb"\1N\2", data)
        data = ZSH_LINE_PATTERN.sub(rb"\1N\2", data)
        return data

    return {"stdout": normalize(stdout), "stderr": normalize(stderr),
            "log": normalize(log_contents), "status": status.encode()}


def apply_baseline_rewrites(results, shell, case_name, rewrites):
    """Rewrite baseline output where the upgrade guide documents a change everywhere."""
    for rewrite in rewrites:
        if shell not in rewrite["shells"] or case_name in rewrite.get("except_cases", []):
            continue
        pattern = re.compile(rewrite["pattern"].encode())
        replacement = rewrite["replacement"].encode()
        for output_name in ("stdout", "stderr", "log"):
            results[output_name] = pattern.sub(replacement, results[output_name])
    return results


def find_allowance(allowed_differences, shell, case_name, differing_outputs):
    for index, allowance in enumerate(allowed_differences):
        if shell not in allowance["shells"] or case_name != allowance["case"]:
            continue
        if set(differing_outputs) <= set(allowance["outputs"]):
            return index
    return None


def print_difference(baseline, candidate, output_name, max_lines=20):
    baseline_lines = baseline[output_name].decode("utf-8", "replace").splitlines()
    candidate_lines = candidate[output_name].decode("utf-8", "replace").splitlines()
    diff_lines = list(difflib.unified_diff(baseline_lines, candidate_lines,
                                           "baseline", "candidate", lineterm="", n=1))
    print(f"    {output_name}:")
    for line in diff_lines[:max_lines]:
        print("      " + line[:200])
    if len(diff_lines) > max_lines:
        print(f"      ... {len(diff_lines) - max_lines} more lines")


def read_baseline_from_git(version, destination):
    show = subprocess.run(["git", "-C", REPO_ROOT, "show", f"{version}:logging.sh"],
                          capture_output=True, check=False)
    if show.returncode != 0:
        sys.stderr.write(f"Cannot read logging.sh at {version}: "
                         f"{show.stderr.decode(errors='replace').strip()}\n"
                         f"Fetch the tag with: git fetch origin tag {version}\n")
        sys.exit(2)
    with open(destination, "wb") as baseline_file:
        baseline_file.write(show.stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--baseline", help="baseline logging.sh")
    parser.add_argument("--candidate", default=os.path.join(REPO_ROOT, "logging.sh"),
                        help="candidate logging.sh")
    parser.add_argument("--filter", default="", help='only cases whose "shell/case" contains this')
    parser.add_argument("--jobs", type=int, default=os.cpu_count() or 2)
    parser.add_argument("--json-out", help="write the differences to this file")
    parser.add_argument("--strict", action="store_true",
                        help="fail if a shell or locale needed for a case is missing")
    arguments = parser.parse_args()

    with open(CONFIG_PATH, encoding="utf-8") as config_file:
        config = json.load(config_file)

    work_dir = tempfile.mkdtemp(prefix="compare-with-release")
    try:
        if arguments.baseline:
            baseline_path = os.path.abspath(arguments.baseline)
        else:
            baseline_path = os.path.join(work_dir, f"logging-{config['baseline_version']}.sh")
            read_baseline_from_git(config["baseline_version"], baseline_path)
        candidate_path = os.path.abspath(arguments.candidate)
        return compare(arguments, config, baseline_path, candidate_path)
    finally:
        shutil.rmtree(work_dir, ignore_errors=True)


def compare(arguments, config, baseline_path, candidate_path):
    locales = installed_locales()
    missing_shells = {name for name, command in SHELL_COMMANDS.items()
                      if shutil.which(command[0]) is None}

    cases_to_run = []
    skipped = []
    for case in build_cases():
        label = f"{case['shell']}/{case['name']}"
        if arguments.filter and arguments.filter not in label:
            continue
        if case["shell"] in missing_shells:
            skipped.append((label, f"{SHELL_COMMANDS[case['shell']][0]} is not installed"))
        elif case["locale"] and normalize_locale_name(case["locale"]) not in locales:
            skipped.append((label, f"locale {case['locale']} is not installed"))
        else:
            cases_to_run.append(case)

    def run_both(case):
        baseline = run_case(case, baseline_path)
        baseline = apply_baseline_rewrites(baseline, case["shell"], case["name"],
                                           config["baseline_rewrites"])
        candidate = run_case(case, candidate_path)
        return case, baseline, candidate

    allowed_differences = config["allowed_differences"]
    used_allowances = set()
    unexpected = []
    allowed = []
    json_records = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, arguments.jobs)) as pool:
        for case, baseline, candidate in pool.map(run_both, cases_to_run):
            differing = [name for name in OUTPUT_NAMES if baseline[name] != candidate[name]]
            if not differing:
                continue
            json_records.append({
                "shell": case["shell"], "case": case["name"], "outputs": differing,
                "baseline": {name: baseline[name].decode("latin1") for name in differing},
                "candidate": {name: candidate[name].decode("latin1") for name in differing},
            })
            allowance_index = find_allowance(allowed_differences, case["shell"], case["name"],
                                             differing)
            if allowance_index is None:
                unexpected.append((case, baseline, candidate, differing))
            else:
                used_allowances.add(allowance_index)
                allowed.append((case, differing, allowed_differences[allowance_index]))

    if arguments.json_out:
        with open(arguments.json_out, "w", encoding="utf-8") as json_file:
            json.dump(json_records, json_file, indent=1)

    print(f"Baseline:  {baseline_path} ({config['baseline_version']})")
    print(f"Candidate: {candidate_path}")
    print(f"Cases run: {len(cases_to_run)}, differing: {len(json_records)}, "
          f"allowed: {len(allowed)}, unexpected: {len(unexpected)}, skipped: {len(skipped)}")

    for label, reason in skipped:
        print(f"SKIPPED    {label}: {reason}")
    for case, differing, allowance in sorted(allowed, key=lambda item: item[0]["name"]):
        print(f"ALLOWED    {case['shell']}/{case['name']} {differing}: {allowance['reason']}")
    for case, baseline, candidate, differing in unexpected:
        print(f"UNEXPECTED {case['shell']}/{case['name']} {differing}")
        for output_name in differing:
            print_difference(baseline, candidate, output_name)

    # An allowance that matched nothing may be out of date. It is only reported, because a
    # filtered or partial run cannot tell.
    if not arguments.filter and not skipped:
        for index, allowance in enumerate(allowed_differences):
            if index not in used_allowances:
                print(f"NOTE       allowance not used: {allowance['case']} "
                      f"({', '.join(allowance['shells'])})")

    if unexpected:
        config_name = os.path.relpath(CONFIG_PATH, REPO_ROOT)
        print(f"\n{len(unexpected)} difference(s) are not in {config_name}. Fix the change, "
              f"or document it in {config['upgrade_guide']} and allow it there.")
        return 1
    if skipped and arguments.strict:
        print("\nSome cases were skipped and --strict is set.")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
