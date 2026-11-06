#!/usr/bin/env bash
#
# logging.sh - Reusable Bash Logging Module
#
# Repository: https://github.com/GingerGraham/bash-logger
#
# License: MIT License
#
# Supported shells: bash 3.2+ (including --posix), zsh, dash and busybox ash.
# The code is POSIX sh plus "local" (Issue #143). Shell-specific code is used only
# behind a check of the running shell; see docs/shell-compatibility.md.
#
# shellcheck disable=SC2034
# Note: SC2034 (unused variable) is disabled because this script is designed to be
# sourced by other scripts. Variables like LOG_LEVEL_FATAL, LOG_CONFIG_FILE, VERBOSE,
# and current_section are intentionally exported for external use or future features.
#
# Quick usage: source logging.sh && init_logger [options]
#   (in a POSIX sh script: . logging.sh && init_logger [options])
#
# Public API Functions:
#   Initialization:
#     - init_logger [options]           : Initialize the logger with options
#     - check_logger_available          : Check if system logger is available
#
#   Logging Functions:
#     - log_debug, log_info, log_notice : Standard logging functions
#     - log_warn, log_error, log_critical
#     - log_alert, log_emergency, log_fatal
#     - log_init, log_sensitive         : Special purpose logging
#     - log_to_journal <level> <message>  : Force a single message to the journal
#
#   Runtime Configuration:
#     - set_log_level <level>           : Change log level dynamically
#     - set_log_format <format>         : Change message format
#     - set_script_name <name>          : Change script name in log messages
#     - set_timezone_utc <true|false>   : Toggle UTC timestamps
#     - set_journal_logging <true|false>: Toggle system journal logging
#     - set_journal_tag <tag>           : Change journal tag
#     - set_syslog_facility <facility>  : Change syslog facility
#     - set_color_mode <auto|always|never> : Change color output
#     - set_unsafe_allow_newlines <true|false> : Allow newlines in log messages (NOT RECOMMENDED)
#     - set_unsafe_allow_ansi_codes <true|false> : Allow ANSI codes in log messages (NOT RECOMMENDED)
#
#   Each set_* function announces the change with a CONFIG notice, whatever the log level.
#   On the console it goes to the same stream as a NOTICE message: stderr when the stderr
#   level is NOTICE, INFO or DEBUG, otherwise stdout. When LOG_FILE is set, the notice is
#   also appended to it without colors, even with --quiet. The journal receives it when enabled.
#
# Internal Functions (prefixed with _):
#   Functions prefixed with underscore (_) are internal implementation details
#   and should not be called directly by consuming scripts.
#
# Comprehensive documentation:
#   - Getting started: docs/getting-started.md
#   - Command-line options: docs/initialization.md
#   - Configuration files: docs/configuration.md
#   - Log levels: docs/log-levels.md
#   - Output and formatting: docs/output-streams.md, docs/formatting.md
#   - Advanced features: docs/journal-logging.md, docs/runtime-configuration.md
#   - Troubleshooting: docs/troubleshooting.md

# Returns 0 if the named variable is readonly in the current shell (internal).
# Used by the re-source guards below; must be defined before the first guard.
# It tries to unset the variable in a subshell, which fails only for a readonly variable.
# Earlier versions parsed "readonly -p" output instead. dash and busybox ash print values
# there with literal newlines, so a readonly variable whose value contained a newline and
# "readonly NAME=..." made NAME look readonly, and an environment value was then kept.
_is_readonly() {
    ! (unset "$1") 2>/dev/null
}

# The shell running this file: "bash", "zsh", or empty for any other shell (internal).
# Set on every source. A version variable alone is not enough, because it can be inherited
# from the environment, so the check also looks for a builtin only that shell has.
_LOGGER_SHELL_FAMILY=""
if [ -n "${BASH_VERSION:-}" ] && command -v shopt >/dev/null 2>&1; then
    _LOGGER_SHELL_FAMILY="bash"
elif [ -n "${ZSH_VERSION:-}" ] && command -v emulate >/dev/null 2>&1; then
    _LOGGER_SHELL_FAMILY="zsh"
fi

# Make a variable readonly and global (internal).
# zsh's readonly declares a new local variable when this file is sourced from inside a
# function, which leaves the constants empty for the rest of that function and removes
# them when it returns. typeset -g keeps them global; bash, dash and busybox ash already
# do that with readonly.
_logger_readonly() {
    if [ "$_LOGGER_SHELL_FAMILY" = "zsh" ]; then
        # typeset only runs in zsh
        # shellcheck disable=SC3044
        typeset -gr "$@"
    else
        readonly "$@"
    fi
}

# Control characters used by the sanitizers, the config parser and the color constants.
# POSIX sh has no $'...' quoting, so they are produced with printf once, at source time.
# They are readonly so a later assignment cannot weaken message sanitization.
if ! _is_readonly _LOGGER_ESC; then
    _LOGGER_ESC=$(printf '\033')
    _LOGGER_BEL=$(printf '\007')
    _LOGGER_CR=$(printf '\r')
    _LOGGER_TAB=$(printf '\t')
    _LOGGER_NEWLINE='
'
    # UTF-8 byte order mark (EF BB BF)
    _LOGGER_BOM=$(printf '\357\273\277')
    # UTF-8 encodings of the non-ASCII control characters, one per line: C1 controls
    # U+0080 to U+009F (C2 80 to C2 9F), LINE SEPARATOR U+2028 (E2 80 A8) and
    # PARAGRAPH SEPARATOR U+2029 (E2 80 A9). In a UTF-8 locale bash and zsh count these
    # as [[:cntrl:]]; dash and busybox ash do not, so _contains_control_characters
    # checks for them explicitly.
    _LOGGER_UTF8_CONTROLS=$(printf '%b\n' \
        '\0302\0200' '\0302\0201' '\0302\0202' '\0302\0203' '\0302\0204' '\0302\0205' \
        '\0302\0206' '\0302\0207' '\0302\0210' '\0302\0211' '\0302\0212' '\0302\0213' \
        '\0302\0214' '\0302\0215' '\0302\0216' '\0302\0217' '\0302\0220' '\0302\0221' \
        '\0302\0222' '\0302\0223' '\0302\0224' '\0302\0225' '\0302\0226' '\0302\0227' \
        '\0302\0230' '\0302\0231' '\0302\0232' '\0302\0233' '\0302\0234' '\0302\0235' \
        '\0302\0236' '\0302\0237' '\0342\0200\0250' '\0342\0200\0251')
    _logger_readonly _LOGGER_ESC _LOGGER_BEL _LOGGER_CR _LOGGER_TAB _LOGGER_NEWLINE _LOGGER_BOM \
        _LOGGER_UTF8_CONTROLS
fi

# Result variables of the *_into helpers. They start empty so that a value from the
# environment is never read, and _log_message restores them after each message.
_LOGGER_TEXT=""
_LOGGER_TIMESTAMP=""
_LOGGER_REPLACED=""
_LOGGER_PREFIX=""
_LOGGER_INTEGER=""
_LOGGER_TEXT_LENGTH=""
_LOGGER_COLOR=""
_LOGGER_PRIORITY=""

# Result variable of _find_caller_script. Set here so that zsh with warn_create_global does
# not warn when init_logger first sets it.
_LOGGER_CALLER_PATH=""

# Which builtin _current_timestamp_into uses, chosen by testing it here: bash 3.2 has no
# printf time format. Set on every source, so a value from the environment is not used.
_LOGGER_TIME_BUILTIN=""
if [ "$_LOGGER_SHELL_FAMILY" = "bash" ]; then
    # printf -v and its time format only run in bash
    # shellcheck disable=SC3045
    if printf -v _LOGGER_TIMESTAMP '%(%Y)T' 0 2>/dev/null && [ -n "$_LOGGER_TIMESTAMP" ]; then # bash32-compat: ignore
        _LOGGER_TIME_BUILTIN="bash"
    fi
    _LOGGER_TIMESTAMP=""
elif [ "$_LOGGER_SHELL_FAMILY" = "zsh" ]; then
    _LOGGER_TIME_BUILTIN="zsh"
fi

# Byte classes used by _text_prefix in shells that truncate by bytes. They are made on
# first use and inserted into a sed script, so they are cleared here: a value taken
# from the environment could otherwise inject sed commands.
_LOGGER_UTF8_LEAD=""
_LOGGER_UTF8_LEAD3=""
_LOGGER_UTF8_LEAD4=""
_LOGGER_UTF8_CONTINUATION=""
# A two-byte character that _text_length uses to check whether ${#} counts bytes.
# Cleared so that a value from the environment cannot change the result of that check.
_LOGGER_UTF8_PROBE=""

# Return 0 if the shell's string operations work on characters (internal).
# bash and zsh count characters in a multi-byte locale. dash always counts bytes.
# busybox ash counts characters when built with Unicode support, but its printf
# precision counts bytes, so it is treated as a byte shell for truncation.
_shell_counts_characters() {
    [ -n "$_LOGGER_SHELL_FAMILY" ]
}

# Return 0 if the locale environment selects UTF-8 (internal).
# Uses the same precedence as the C library: LC_ALL, then LC_CTYPE, then LANG.
_is_utf8_locale() {
    local active_locale="${LC_ALL:-}"
    if [ -z "$active_locale" ]; then
        active_locale="${LC_CTYPE:-}"
    fi
    if [ -z "$active_locale" ]; then
        active_locale="${LANG:-}"
    fi
    case "$active_locale" in
        *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) return 0 ;;
    esac
    return 1
}

# Set _LOGGER_CHARACTER_COUNT to the number of characters in a value (internal).
# bash and zsh count characters directly. In other shells ${#value} may count bytes,
# so values with non-ASCII bytes are counted with "wc -m", which follows the locale
# (bytes in the C locale, characters in a UTF-8 locale), as bash does.
_count_characters() {
    _LOGGER_CHARACTER_COUNT=${#1}
    if _shell_counts_characters; then
        return 0
    fi
    case "$1" in
        *[!\ -~]*)
            local counted=""
            counted=$(printf '%s' "$1" | wc -m 2>/dev/null | tr -d ' ')
            case "$counted" in
                ''|*[!0123456789]*) ;;
                *) _LOGGER_CHARACTER_COUNT="$counted" ;;
            esac
            ;;
    esac
    return 0
}

# Return 0 if a value contains a control character (internal).
# Matches what the earlier [[ $value =~ [[:cntrl:]] ]] check matched in bash: ASCII
# control characters, and in a UTF-8 locale the non-ASCII control characters as well.
_contains_control_characters() {
    case "$1" in
        *[[:cntrl:]]*) return 0 ;;
    esac
    if ! _is_utf8_locale; then
        return 1
    fi
    # Only values with a non-ASCII byte can contain a non-ASCII control character
    case "$1" in
        *[!\ -~]*) ;;
        *) return 1 ;;
    esac
    local utf8_control=""
    while IFS= read -r utf8_control; do
        case "$1" in
            *"$utf8_control"*) return 0 ;;
        esac
    done <<UTF8_CONTROLS
$_LOGGER_UTF8_CONTROLS
UTF8_CONTROLS
    return 1
}

# Return 0 if a value contains a shell metacharacter (internal).
# Characters: $ ` ; | & < > ( ) { } [ ] \
_contains_shell_metacharacters() {
    case "$1" in
        *'$'*|*'`'*|*';'*|*'|'*|*'&'*|*'<'*|*'>'*|*'('*|*')'*|*'{'*|*'}'*|*'['*|*']'*|*'\'*)
            return 0
            ;;
    esac
    return 1
}

# Return 0 if a separator is followed, after any number of spaces, by a word (internal).
# Usage: _has_word_after_separator <text> <separator> <word>
# Every occurrence of the separator is checked, including overlapping ones, as a
# regular expression search does: "a||sh" matches "|" then "sh", and "x&&&rm"
# matches "&&" then "rm" at its second "&".
_has_word_after_separator() {
    local remaining="$1"
    local separator="$2"
    local word="$3"
    local after_separator=""
    while :; do
        case "$remaining" in
            *"$separator"*) ;;
            *) return 1 ;;
        esac
        # Move to the next occurrence, then look at what follows it
        remaining="${remaining#"${remaining%%"$separator"*}"}"
        after_separator="${remaining#"$separator"}"
        # Remove leading spaces (spaces only, as in the earlier " *" regex)
        after_separator="${after_separator#"${after_separator%%[! ]*}"}"
        case "$after_separator" in
            "$word"*) return 0 ;;
        esac
        # Step one character, so an occurrence that overlaps this one is found
        remaining="${remaining#?}"
    done
}

# Set _LOGGER_REPLACED to text with every occurrence of a string replaced (internal).
# Usage: _replace_all <text> <search> <replacement>
# The search string is literal. Occurrences are replaced left to right and the
# replacement is never searched again, like ${text//search/replacement} in bash.
_replace_all() {
    local remaining="$1"
    local search="$2"
    local replacement="$3"
    local result=""
    if [ -z "$search" ]; then
        _LOGGER_REPLACED="$remaining"
        return 0
    fi
    while :; do
        case "$remaining" in
            *"$search"*) ;;
            *) break ;;
        esac
        result="${result}${remaining%%"$search"*}${replacement}"
        remaining="${remaining#*"$search"}"
    done
    _LOGGER_REPLACED="${result}${remaining}"
}

# Set _LOGGER_REPLACED to text with every character that is not a letter, digit,
# period, underscore or hyphen replaced by an underscore (internal).
# In shells that work on bytes (dash), each byte of a multi-byte character is replaced.
# The allowed characters are listed one by one rather than as ranges such as a-z, because
# what a range matches depends on the locale in some shells (for example bash 3.2 without
# globasciiranges). They are written unquoted in each pattern: busybox 1.37 with musl
# treated a backslash as allowed when the list came from a quoted variable containing "-".
_replace_unsafe_name_characters() {
    local remaining="$1"
    local result=""
    local safe_prefix=""
    while :; do
        case "$remaining" in
            *[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-]*) ;;
            *) break ;;
        esac
        safe_prefix="${remaining%%[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-]*}"
        result="${result}${safe_prefix}_"
        remaining="${remaining#"$safe_prefix"}"
        remaining="${remaining#?}"
    done
    _LOGGER_REPLACED="${result}${remaining}"
}

# Parse a non-negative integer the way bash arithmetic reads it (internal).
# Sets _LOGGER_INTEGER and returns 0, or returns 1 if the value is not all digits.
# A leading 0 means octal, as in bash, so 010 is 8 and 08 is invalid (returns 1).
# Values with more than 15 significant digits are set to 999999999999999: large
# enough for every range check here, and safe from overflow in every shell.
_parse_shell_integer() {
    local digits="$1"
    case "$digits" in
        ''|*[!0123456789]*) return 1 ;;
    esac
    local value=0
    case "$digits" in
        0?*)
            # Octal
            case "$digits" in
                *[89]*) return 1 ;;
            esac
            digits="${digits#"${digits%%[!0]*}"}"
            if [ "${#digits}" -gt 15 ]; then
                _LOGGER_INTEGER=999999999999999
                return 0
            fi
            local digit=""
            while [ -n "$digits" ]; do
                digit="${digits%"${digits#?}"}"
                digits="${digits#?}"
                value=$((value * 8 + digit))
            done
            ;;
        *)
            if [ "${#digits}" -gt 15 ]; then
                value=999999999999999
            else
                value="$digits"
            fi
            ;;
    esac
    _LOGGER_INTEGER="$value"
    return 0
}

# Set _LOGGER_PREFIX to the first <length> characters of text (internal).
# bash and zsh count characters, as ${text:0:length} always has.
# Other shells count bytes (printf precision), and a multi-byte UTF-8 character cut
# at the end is removed, so the result is never an invalid UTF-8 sequence.
_text_prefix() {
    local text="$1"
    local length="$2"
    if _shell_counts_characters; then
        # substring expansion only runs in bash and zsh
        # shellcheck disable=SC3057
        _LOGGER_PREFIX="${text:0:$length}"
        return 0
    fi
    if [ -z "$_LOGGER_UTF8_LEAD" ]; then
        # Byte classes for UTF-8 lead and continuation bytes, made once on first use
        _LOGGER_UTF8_LEAD=$(printf '[\300-\377]')
        _LOGGER_UTF8_LEAD3=$(printf '[\340-\377]')
        _LOGGER_UTF8_LEAD4=$(printf '[\360-\377]')
        _LOGGER_UTF8_CONTINUATION=$(printf '[\200-\277]')
    fi
    # The x keeps a trailing newline that command substitution would remove.
    # sed only edits the last line ($), where a cut character can be.
    _LOGGER_PREFIX=$(
        printf "%.${length}s" "$text" | LC_ALL=C sed \
            -e "\$ s/${_LOGGER_UTF8_LEAD4}${_LOGGER_UTF8_CONTINUATION}${_LOGGER_UTF8_CONTINUATION}\$//" \
            -e "\$ s/${_LOGGER_UTF8_LEAD3}${_LOGGER_UTF8_CONTINUATION}\$//" \
            -e "\$ s/${_LOGGER_UTF8_LEAD}\$//"
        printf 'x'
    )
    _LOGGER_PREFIX="${_LOGGER_PREFIX%x}"
}

# Set _LOGGER_TEXT_LENGTH to the length of text, counted the way _text_prefix
# counts: characters in bash and zsh, bytes in other shells (internal).
# Only text longer than a quarter of the limit can exceed it in bytes, so short text
# is measured without starting a process.
_text_length() {
    local text="$1"
    local limit="$2"
    _LOGGER_TEXT_LENGTH=${#text}
    if _shell_counts_characters; then
        return 0
    fi
    if [ $((_LOGGER_TEXT_LENGTH * 4)) -le "$limit" ]; then
        return 0
    fi
    # A shell that counts this two-byte character as 2 already counts bytes (dash, and
    # busybox outside a UTF-8 locale), so no process is needed. Checked on every call
    # because busybox follows changes to the locale variables.
    if [ -z "$_LOGGER_UTF8_PROBE" ]; then
        _LOGGER_UTF8_PROBE=$(printf '\303\251')
    fi
    if [ "${#_LOGGER_UTF8_PROBE}" -eq 2 ]; then
        return 0
    fi
    local byte_count=""
    byte_count=$(printf '%s' "$text" | LC_ALL=C wc -c | tr -d ' ')
    case "$byte_count" in
        ''|*[!0123456789]*) ;;
        *) _LOGGER_TEXT_LENGTH="$byte_count" ;;
    esac
}

# Remove trailing newlines from the value of _LOGGER_TEXT (internal).
# Earlier versions passed messages through command substitution, which removes
# trailing newlines; this keeps that result without starting a subshell.
_strip_trailing_newlines() {
    while :; do
        case "$_LOGGER_TEXT" in
            *"$_LOGGER_NEWLINE") _LOGGER_TEXT="${_LOGGER_TEXT%"$_LOGGER_NEWLINE"}" ;;
            *) return 0 ;;
        esac
    done
}

# Version (updated by release workflow)
# Guard against re-initialization when sourced multiple times
# Use readonly status instead of emptiness to avoid environment bypass
if ! _is_readonly BASH_LOGGER_VERSION; then
    _logger_readonly BASH_LOGGER_VERSION="2.7.0"

    # Unset potentially malicious environment variables before setting internal constants
    # Only unset if not already readonly (which would indicate re-sourcing)
    # This protects against environment variable override attacks
    for var in LOG_LEVEL_EMERGENCY LOG_LEVEL_ALERT LOG_LEVEL_CRITICAL LOG_LEVEL_ERROR \
               LOG_LEVEL_WARN LOG_LEVEL_NOTICE LOG_LEVEL_INFO LOG_LEVEL_DEBUG LOG_LEVEL_FATAL; do
        if ! _is_readonly "$var"; then
            unset "$var" 2>/dev/null || true
        fi
    done

    # Unset deduplication flags that gate write-failure warnings.
    # These flags are mutable (legitimately set to "yes" during normal operation) so they
    # are not readonly, but they must start empty on each fresh source to prevent a
    # pre-existing environment value from permanently suppressing error reporting.
    unset LOGGER_FILE_ERROR_REPORTED    2>/dev/null || true
    unset LOGGER_JOURNAL_ERROR_REPORTED 2>/dev/null || true

    # Log levels (following complete syslog standard - higher number = less severe)
    # These are readonly to prevent malicious override after initialization
    _logger_readonly LOG_LEVEL_EMERGENCY=0  # System is unusable (most severe)
    _logger_readonly LOG_LEVEL_ALERT=1      # Action must be taken immediately
    _logger_readonly LOG_LEVEL_CRITICAL=2   # Critical conditions
    _logger_readonly LOG_LEVEL_ERROR=3      # Error conditions
    _logger_readonly LOG_LEVEL_WARN=4       # Warning conditions
    _logger_readonly LOG_LEVEL_NOTICE=5     # Normal but significant conditions
    _logger_readonly LOG_LEVEL_INFO=6       # Informational messages
    _logger_readonly LOG_LEVEL_DEBUG=7      # Debug information (least severe)
    _logger_readonly LOG_LEVEL_INIT=6       # Initialization messages (maps to INFO for stderr routing)

    # Aliases for backward compatibility
    _logger_readonly LOG_LEVEL_FATAL=$LOG_LEVEL_EMERGENCY  # Alias for EMERGENCY
fi

# Default settings (these can be overridden by init_logger)
CONSOLE_LOG="true"
LOG_FILE=""
VERBOSE="false"
CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO
USE_UTC="false" # Set to true to use UTC time in logs
LOG_INIT_MESSAGE="true" # Set to false to suppress the INIT message written to the log file on init_logger

# Journal logging settings
USE_JOURNAL="false"
JOURNAL_TAG=""  # Tag for syslog/journal entries
if ! _is_readonly SYSLOG_FACILITY; then
    unset SYSLOG_FACILITY 2>/dev/null || true
fi
SYSLOG_FACILITY="${SYSLOG_FACILITY:-daemon}"  # Syslog facility for journal entries

# Color settings
USE_COLORS="auto"  # Can be "auto", "always", or "never"

# Initialize color constants only once (guard against re-sourcing)
if [ -z "${COLOR_RESET:-}" ] || ! _is_readonly COLOR_RESET; then
    # Unset potentially malicious color variables before setting them
    # Only unset if not already readonly (which would indicate re-sourcing)
    for var in COLOR_RESET COLOR_BLUE COLOR_GREEN COLOR_YELLOW COLOR_RED \
               COLOR_RED_BOLD COLOR_WHITE_ON_RED COLOR_BOLD_WHITE_ON_RED \
               COLOR_PURPLE COLOR_CYAN; do
        if ! _is_readonly "$var"; then
            unset "$var" 2>/dev/null || true
        fi
    done

    # ANSI color codes, built from the literal escape character in _LOGGER_ESC
    # These are readonly to prevent malicious override after initialization
    _logger_readonly COLOR_RESET="${_LOGGER_ESC}[0m"
    _logger_readonly COLOR_BLUE="${_LOGGER_ESC}[34m"
    _logger_readonly COLOR_GREEN="${_LOGGER_ESC}[32m"
    _logger_readonly COLOR_YELLOW="${_LOGGER_ESC}[33m"
    _logger_readonly COLOR_RED="${_LOGGER_ESC}[31m"
    _logger_readonly COLOR_RED_BOLD="${_LOGGER_ESC}[31;1m"
    _logger_readonly COLOR_WHITE_ON_RED="${_LOGGER_ESC}[37;41m"
    _logger_readonly COLOR_BOLD_WHITE_ON_RED="${_LOGGER_ESC}[1;37;41m"
    _logger_readonly COLOR_PURPLE="${_LOGGER_ESC}[35m"
    _logger_readonly COLOR_CYAN="${_LOGGER_ESC}[36m"
fi

# Stream output settings
# Messages at this level and above (more severe) go to stderr, below go to stdout
# Default: ERROR (level 3) and above to stderr
LOG_STDERR_LEVEL=$LOG_LEVEL_ERROR

# Default log format
# Format variables:
#   %d = date and time (YYYY-MM-DD HH:MM:SS)
#   %z = timezone (UTC or LOCAL)
#   %l = log level name (DEBUG, INFO, WARN, ERROR)
#   %s = script name
#   %m = message
# Example:
#   "[%l] %d [%s] %m" => "[INFO] 2025-03-03 12:34:56 [myscript.sh] Hello world"
#  "%d %z [%l] [%s] %m" => "2025-03-03 12:34:56 UTC [INFO] [myscript.sh] Hello world"
LOG_FORMAT="%d [%l] [%s] %m"

# Security: Allow newlines in log messages (NOT RECOMMENDED)
# When false (default), newlines and carriage returns are sanitized to prevent log injection
# Set to true ONLY if you have explicit control over all logged messages and log parsing is tolerant
LOG_UNSAFE_ALLOW_NEWLINES="false"

# Security: Allow ANSI escape codes in log messages (NOT RECOMMENDED)
# When false (default), ANSI escape sequences are stripped from incoming messages to prevent
# terminal manipulation attacks. ANSI codes in library-generated output (colors) are preserved.
# Set to true ONLY if you have explicit control over all logged messages and trust their source.
LOG_UNSAFE_ALLOW_ANSI_CODES="false"

# Maximum message length before formatting (defense-in-depth against excessively large messages)
# Truncation is applied to the message portion before adding timestamp, level, and script name.
# Final formatted output may exceed these limits. Set to 0 to disable limits.
LOG_MAX_LINE_LENGTH=4096
LOG_MAX_JOURNAL_LENGTH=4096

# Configuration value validation limits
# Maximum length for configuration file values (defense against malicious/malformed configs)
if ! _is_readonly CONFIG_MAX_VALUE_LENGTH; then
    _logger_readonly CONFIG_MAX_VALUE_LENGTH=4096
    # Maximum length for file paths in configuration
    _logger_readonly CONFIG_MAX_PATH_LENGTH=4096
fi

# Function to detect terminal color support (internal)
_detect_color_support() {
    # Default to no colors if explicitly disabled
    if [ -n "${NO_COLOR:-}" ] || [ "${CLICOLOR:-}" = "0" ]; then
        return 1
    fi

    # Force colors if explicitly enabled
    if [ "${CLICOLOR_FORCE:-}" = "1" ]; then
        return 0
    fi

    # Check if stdout is a terminal
    if [ ! -t 1 ]; then
        return 1
    fi

    # Check color capabilities with tput if available
    if command -v tput >/dev/null 2>&1; then
        local color_count=""
        color_count=$(tput colors 2>/dev/null)
        case "$color_count" in
            ''|*[!0123456789]*) color_count=0 ;;
        esac
        if [ "$color_count" -ge 8 ]; then
            return 0
        fi
    fi

    # Check TERM as fallback
    if [ -n "${TERM:-}" ] && [ "${TERM:-}" != "dumb" ]; then
        case "${TERM:-}" in
            xterm*|rxvt*|ansi|linux|screen*|tmux*|vt100|vt220|alacritty)
                return 0
                ;;
        esac
    fi

    return 1  # Default to no colors
}

# Function to determine if colors should be used (internal)
_should_use_colors() {
    case "$USE_COLORS" in
        "always")
            return 0
            ;;
        "never")
            return 1
            ;;
        "auto"|*)
            _detect_color_support
            return "$?"
            ;;
    esac
}

# Function to determine if a log level should output to stderr (internal)
# Returns 0 (true) if the given level should go to stderr
_should_use_stderr() {
    local level_value="$1"
    # Lower number = more severe, so use stderr if level <= threshold
    [ "$level_value" -le "$LOG_STDERR_LEVEL" ] 2>/dev/null
}

# Path to validated logger command (set by _find_and_validate_logger)
# Keep mutable until first successful validation, then lock as readonly.
# Guard assignment for re-source safety when LOGGER_PATH was already locked.
if ! _is_readonly LOGGER_PATH; then
    LOGGER_PATH=""
fi
# Internal flag: set to "true" by _find_and_validate_logger on every exit path
# (success and failure alike). Used by log_to_journal to skip discovery only when
# LOGGER_PATH is already set — i.e. a previous discovery succeeded and locked the path.
# When LOGGER_PATH is empty (prior discovery failed or logger was not found), discovery
# is always retried so that logger becoming available mid-session is handled correctly.
# Not readonly — resetting to "false" on re-source is correct (new context must re-validate).
_LOGGER_DISCOVERY_DONE="false"

# Find and validate the logger command to prevent PATH manipulation attacks
# This function finds the logger executable and validates it's in a safe system location
# Returns 0 if logger is found and valid, 1 otherwise
_find_and_validate_logger() {
    # Try to find logger command
    local logger_candidate=""
    logger_candidate=$(command -v logger 2>/dev/null)

    if [ -z "$logger_candidate" ]; then
        USE_JOURNAL="false"
        _LOGGER_DISCOVERY_DONE="true"
        return 1
    fi

    # Resolve any symlinks to get the real path
    local logger_found="$logger_candidate"
    if command -v readlink >/dev/null 2>&1; then
        logger_candidate=$(readlink -f "$logger_candidate" 2>/dev/null || printf '%s\n' "$logger_candidate")
    fi

    # busybox selects the applet from the name it is run as, so a logger symlink to a busybox
    # in a safe directory has to be run through the symlink, which must also be in one. It must
    # point straight at busybox: a link in another directory along the way could be changed
    # after this check, and the symlink is what runs on every message.
    case "$logger_candidate" in
        /bin/busybox|/usr/bin/busybox|/sbin/busybox|/usr/sbin/busybox)
            case "$logger_found" in
                /bin/logger|/usr/bin/logger|/usr/local/bin/logger|/sbin/logger|/usr/sbin/logger)
                    local link_target=""
                    link_target=$(readlink "$logger_found" 2>/dev/null)
                    case "$link_target" in
                        /bin/busybox|/usr/bin/busybox|/sbin/busybox|/usr/sbin/busybox|\
                        busybox|../bin/busybox|../../bin/busybox)
                            logger_candidate="$logger_found"
                            ;;
                    esac
                    ;;
            esac
            ;;
    esac

    # Validate logger is in a safe system location
    # Accept: /bin, /usr/bin, /usr/local/bin, /sbin, /usr/sbin
    case "$logger_candidate" in
        /bin/logger|/usr/bin/logger|/usr/local/bin/logger|/sbin/logger|/usr/sbin/logger)
            # If LOGGER_PATH is already locked, only accept the same validated path.
            # This preserves immutability while still allowing repeat availability checks.
            if _is_readonly LOGGER_PATH; then
                if [ "$LOGGER_PATH" = "$logger_candidate" ]; then
                    _LOGGER_DISCOVERY_DONE="true"
                    return 0
                fi
                printf '%s\n' "Warning: logger path changed after validation: $logger_candidate" >&2
                printf '%s\n' "  Locked logger path is: $LOGGER_PATH" >&2
                printf '%s\n' "  Journal logging disabled for security" >&2
                USE_JOURNAL="false"
                _LOGGER_DISCOVERY_DONE="true"
                return 1
            fi

            LOGGER_PATH="$logger_candidate"
            _logger_readonly LOGGER_PATH
            _LOGGER_DISCOVERY_DONE="true"
            return 0
            ;;
        *)
            # Logger found but in unexpected location - could be malicious
            printf '%s\n' "Warning: logger found at unexpected location: $logger_candidate" >&2
            printf '%s\n' "  Expected: /bin, /usr/bin, /usr/local/bin, /sbin, or /usr/sbin" >&2
            printf '%s\n' "  Journal logging disabled for security" >&2
            USE_JOURNAL="false"
            _LOGGER_DISCOVERY_DONE="true"
            return 1
            ;;
    esac
}

# Check if logger command is available (legacy compatibility wrapper)
check_logger_available() {
    _find_and_validate_logger
}

# Configuration file path (set by init_logger when using -c option)
LOG_CONFIG_FILE=""

# Validate a string value using shared guard checks (internal)
# Checks: empty (optional), max length, and control characters (optional)
# Returns 0 if valid, 1 otherwise
_validate_string() {
    local value="$1"
    local max_length="$2"
    local label="$3"
    local allow_empty="${4:-false}"
    local check_control_chars="${5:-true}"

    if [ "$allow_empty" != "true" ] && [ -z "$value" ]; then
        printf '%s\n' "Error: Empty $label" >&2
        return 1
    fi

    # ${#value} counts bytes in dash, so the character count is only worked out
    # when the value is longer than the limit
    if [ "${#value}" -gt "$max_length" ]; then
        _count_characters "$value"
        if [ "$_LOGGER_CHARACTER_COUNT" -gt "$max_length" ]; then
            printf '%s\n' "Error: $label exceeds maximum length of $max_length (actual: $_LOGGER_CHARACTER_COUNT)" >&2
            return 1
        fi
    fi

    if [ "$check_control_chars" = "true" ] && _contains_control_characters "$value"; then
        printf '%s\n' "Error: $label contains control characters" >&2
        return 1
    fi

    return 0
}

# Validate configuration value length (internal)
# Returns 0 if valid, 1 if too long
_validate_config_value_length() {
    local value="$1"
    local max_length="$2"
    local key="$3"
    local line_num="$4"
    local label="Configuration value for '$key' at line $line_num"

    if ! _validate_string "$value" "$max_length" "$label" "true" "false"; then
        return 1
    fi

    return 0
}

# Validate file path from configuration (internal)
# Checks that path is absolute, doesn't contain control characters or dangerous patterns
# Returns 0 if valid, 1 otherwise
_validate_config_file_path() {
    local path="$1"
    local key="$2"
    local line_num="$3"
    local label="Configuration value for '$key' at line $line_num"

    if ! _validate_string "$path" "$CONFIG_MAX_PATH_LENGTH" "$label" "true" "true"; then
        return 1
    fi

    # Check for empty path
    if [ -z "$path" ]; then
        return 0  # Empty is valid (means disabled)
    fi

    # Must be absolute path (starts with /)
    case "$path" in
        /*) ;;
        *)
            printf '%s\n' "Error: Configuration value for '$key' at line $line_num must be an absolute path (got: '$path')" >&2
            return 1
            ;;
    esac

    # Check for suspicious shell metacharacter patterns that could indicate injection attempts
    # Allow normal path characters but reject dangerous patterns
    # Note: We check for common command injection patterns. These are the same patterns
    # as the earlier regular expression (\$\(|`|; *rm|; *dd|\| *sh|&& *(rm|dd)), where
    # " *" means any number of spaces (not tabs).
    local suspicious="false"
    case "$path" in
        *'$('*|*'`'*) suspicious="true" ;;
    esac
    if [ "$suspicious" = "false" ]; then
        if _has_word_after_separator "$path" ";" "rm" \
            || _has_word_after_separator "$path" ";" "dd" \
            || _has_word_after_separator "$path" "|" "sh" \
            || _has_word_after_separator "$path" "&&" "rm" \
            || _has_word_after_separator "$path" "&&" "dd"; then
            suspicious="true"
        fi
    fi
    if [ "$suspicious" = "true" ]; then
        printf '%s\n' "Error: Configuration value for '$key' at line $line_num contains suspicious patterns" >&2
        return 1
    fi

    return 0
}

# Validate format string from configuration (internal)
# Checks for excessively long format strings and dangerous patterns
# Returns 0 if valid, 1 otherwise
_validate_config_format() {
    local format="$1"
    local line_num="$2"

    # Check for control characters (except standard format specifiers)
    # Allow normal format variables like %d, %l, %s, %m, %z
    local clean_format="$format"
    # Remove valid format specifiers
    _replace_all "$clean_format" "%d" ""
    _replace_all "$_LOGGER_REPLACED" "%l" ""
    _replace_all "$_LOGGER_REPLACED" "%s" ""
    _replace_all "$_LOGGER_REPLACED" "%m" ""
    _replace_all "$_LOGGER_REPLACED" "%z" ""
    clean_format="$_LOGGER_REPLACED"

    # Check remaining string for control characters (excluding valid format specifiers)
    if ! _validate_string "$clean_format" "$CONFIG_MAX_VALUE_LENGTH" "configuration format at line $line_num" "true" "true" >/dev/null 2>&1; then
        printf '%s\n' "Warning: Configuration format at line $line_num contains control characters (may be stripped)" >&2
    fi

    return 0
}

# Validate journal tag from configuration (internal)
# Checks for reasonable length and dangerous characters
# Returns 0 if valid, 1 otherwise
_validate_config_journal_tag() {
    local tag="$1"
    local key="$2"
    local line_num="$3"
    local max_tag_length=64

    # Handle empty tag explicitly to preserve single-warning behavior
    if [ -z "$tag" ]; then
        printf '%s\n' "Warning: Empty journal tag at line $line_num" >&2
        return 1
    fi

    if ! _validate_string "$tag" "$max_tag_length" "journal tag at line $line_num" "false" "true"; then
        _count_characters "$tag"
        if [ "$_LOGGER_CHARACTER_COUNT" -gt "$max_tag_length" ]; then
            printf '%s\n' "  Hint: Truncating to maximum length" >&2
        fi
        return 1
    fi

    # Check for shell metacharacters that could cause issues
    if _contains_shell_metacharacters "$tag"; then
        printf '%s\n' "Warning: Journal tag at line $line_num contains shell metacharacters (will be sanitized)" >&2
        return 1
    fi

    return 0
}

# Validate journal tag value (internal)
# Checks for reasonable length and dangerous characters
# Returns 0 if valid, 1 otherwise
_validate_journal_tag() {
    local tag="$1"
    local max_tag_length=64

    if [ -z "$tag" ]; then
        printf '%s\n' "Warning: Empty journal tag" >&2
        return 1
    fi

    if ! _validate_string "$tag" "$max_tag_length" "journal tag" "false" "true"; then
        return 1
    fi

    # Check for shell metacharacters that could cause issues
    if _contains_shell_metacharacters "$tag"; then
        printf '%s\n' "Warning: Journal tag contains shell metacharacters" >&2
        return 1
    fi

    return 0
}

# Print the argument in lowercase (internal).
# Portable replacement for ${var,,}, which bash 3.2 and zsh do not support.
# Only used during initialisation, config parsing and set_* functions, so the
# extra process is not on the per-message path.
# LC_ALL=C keeps the mapping ASCII-only: in some locales (e.g. Turkish) 'I'
# lowercases to a dotless i, which would break keyword matching.
_to_lower() {
    printf '%s' "$1" | LC_ALL=C tr '[:upper:]' '[:lower:]'
}

# Validate syslog facility value (internal)
# Returns 0 if valid, 1 otherwise
_validate_syslog_facility() {
    local facility="$1"

    # Normalize facility to lowercase for case-insensitive validation
    local facility_normalized=""
    facility_normalized="$(_to_lower "$facility")"

    case "$facility_normalized" in
        kern|user|mail|daemon|auth|syslog|lpr|news|uucp|cron|authpriv|ftp|local0|local1|local2|local3|local4|local5|local6|local7)
            return 0
            ;;
        *)
            printf '%s\n' "Warning: Invalid syslog facility '$facility'" >&2
            printf '%s\n' "  Valid facilities: kern, user, mail, daemon, auth, syslog, lpr, news, uucp, cron, authpriv, ftp, local0-local7" >&2
            return 1
            ;;
    esac
}

# Parse a boolean string value to a canonical "true" or "false" (internal)
# Accepts: true/yes/on/1 -> prints "true"; false/no/off/0 -> prints "false"
# Returns 0 on success, 1 for unrecognised input (prints nothing)
_parse_bool_value() {
    local input=""
    input="$(_to_lower "$1")"
    case "$input" in
        true|yes|on|1)   printf '%s\n' "true";  return 0 ;;
        false|no|off|0)  printf '%s\n' "false"; return 0 ;;
        *)               return 1 ;;
    esac
}

# Parse an INI-style configuration file (internal)
# Usage: _parse_config_file "/path/to/config.ini"
# Returns 0 on success, 1 on error
# Config values are applied to global variables; CLI args can override them later
_parse_config_file() {
    local config_file="$1"

    # Validate file exists and is readable
    if [ ! -f "$config_file" ]; then
        printf '%s\n' "Error: Configuration file not found" >&2
        printf '%s\n' "  Hint: Check the --config argument and verify the file path is correct" >&2
        return 1
    fi

    if [ ! -r "$config_file" ]; then
        printf '%s\n' "Error: Configuration file not readable" >&2
        printf '%s\n' "  Hint: Check file permissions and ensure the process has read access" >&2
        return 1
    fi

    # Lines are classified with case patterns and split with parameter expansion,
    # which every supported shell handles the same way. These give the same results
    # as the earlier regular expressions:
    #   section     ^\[([^]]+)\]$     "[", one or more characters other than "]", "]"
    #   key=value   ^([^=]+)=(.*)$    at least one character before the first "="
    #   quoted      ^"(.*)"$ ^'(.*)'$ at least two characters, same quote at both ends
    local line=""
    local line_num=0
    local current_section=""
    local section_name=""
    local key=""
    local value=""

    while IFS= read -r line || [ -n "$line" ]; do
        line_num=$((line_num + 1))

        # Strip UTF-8 BOM (EF BB BF) from the first line if present
        if [ "$line_num" -eq 1 ]; then
            line="${line#"$_LOGGER_BOM"}"
        fi

        # Remove leading/trailing whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        # Skip empty lines and comments
        case "$line" in
            ''|'#'*|';'*) continue ;;
        esac

        # Handle section headers [section]
        case "$line" in
            '['*']')
                section_name="${line#"["}"
                section_name="${section_name%"]"}"
                case "$section_name" in
                    ''|*']'*) ;;
                    *)
                        current_section="$section_name"
                        continue
                        ;;
                esac
                ;;
        esac

        # Parse key = value pairs: the key is everything before the first "=" and must
        # not be empty
        case "$line" in
            '='*)
                # Empty key
                printf '%s\n' "Warning: Invalid syntax at line $line_num: $line" >&2
                continue
                ;;
            *=*)
                ;;
            *)
                # No "=" at all
                printf '%s\n' "Warning: Invalid syntax at line $line_num: $line" >&2
                continue
                ;;
        esac
        key="${line%%=*}"
        value="${line#*=}"

        # Trim whitespace from key and value
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"

        # Remove surrounding quotes if present
        case "$value" in
            '"'*'"'|"'"*"'")
                value="${value#?}"
                value="${value%?}"
                ;;
        esac

        # Validate value length for all config values (defense-in-depth)
        if ! _validate_config_value_length "$value" "$CONFIG_MAX_VALUE_LENGTH" "$key" "$line_num"; then
            printf '%s\n' "  Hint: Truncating value to maximum allowed length" >&2
            _text_prefix "$value" "$CONFIG_MAX_VALUE_LENGTH"
            value="$_LOGGER_PREFIX"
        fi

        # Apply configuration based on key (case-insensitive)
        case "$(_to_lower "$key")" in
            level|log_level)
                CURRENT_LOG_LEVEL=$(_get_log_level_value "$value" "$line_num")
                ;;
            format|log_format)
                # Validate format string
                if _validate_config_format "$value" "$line_num"; then
                    LOG_FORMAT="$value"
                else
                    printf '%s\n' "  Hint: Skipping invalid format string, using default" >&2
                fi
                ;;
            log_file|logfile|file)
                # Validate file path
                if _validate_config_file_path "$value" "$key" "$line_num"; then
                    LOG_FILE="$value"
                else
                    printf '%s\n' "  Hint: Skipping invalid log file path" >&2
                fi
                ;;
            journal|use_journal)
                case "$(_to_lower "$value")" in
                    true|yes|1|on)
                        if check_logger_available; then
                            USE_JOURNAL="true"
                        else
                            printf '%s\n' "Warning: logger command not found, journal logging disabled (config line $line_num)" >&2
                        fi
                        ;;
                    false|no|0|off)
                        USE_JOURNAL="false"
                        ;;
                    *)
                        printf '%s\n' "Warning: Invalid journal value '$value' at line $line_num, expected true/false" >&2
                        ;;
                esac
                ;;
            tag|journal_tag)
                if _validate_config_journal_tag "$value" "$key" "$line_num"; then
                    JOURNAL_TAG="$value"
                else
                    # Truncate or sanitize if validation failed
                    _count_characters "$value"
                    if [ "$_LOGGER_CHARACTER_COUNT" -gt 64 ]; then
                        _text_prefix "$value" 64
                        JOURNAL_TAG="$_LOGGER_PREFIX"
                        printf '%s\n' "  Hint: Truncated journal tag to 64 characters" >&2
                    else
                        # Strip problematic characters
                        _replace_unsafe_name_characters "$value"
                        JOURNAL_TAG="$_LOGGER_REPLACED"
                        printf '%s\n' "  Hint: Sanitized journal tag to remove shell metacharacters" >&2
                    fi
                fi
                ;;
            facility|syslog_facility)
                if _validate_syslog_facility "$value"; then
                    SYSLOG_FACILITY="$(_to_lower "$value")"
                else
                    printf '%s\n' "  Hint: Skipping invalid syslog facility at line $line_num" >&2
                fi
                ;;
            utc|use_utc)
                case "$(_to_lower "$value")" in
                    true|yes|1|on)
                        USE_UTC="true"
                        ;;
                    false|no|0|off)
                        USE_UTC="false"
                        ;;
                    *)
                        printf '%s\n' "Warning: Invalid utc value '$value' at line $line_num, expected true/false" >&2
                        ;;
                esac
                ;;
            color|colour|colors|colours|use_colors)
                case "$(_to_lower "$value")" in
                    auto)
                        USE_COLORS="auto"
                        ;;
                    always|true|yes|1|on)
                        USE_COLORS="always"
                        ;;
                    never|false|no|0|off)
                        USE_COLORS="never"
                        ;;
                    *)
                        printf '%s\n' "Warning: Invalid color value '$value' at line $line_num, expected auto/always/never" >&2
                        ;;
                esac
                ;;
            stderr_level|stderr-level)
                LOG_STDERR_LEVEL=$(_get_log_level_value "$value" "$line_num")
                ;;
            quiet|console_log)
                case "$(_to_lower "$key")" in
                    quiet)
                        # quiet=true means CONSOLE_LOG=false
                        case "$(_to_lower "$value")" in
                            true|yes|1|on)
                                CONSOLE_LOG="false"
                                ;;
                            false|no|0|off)
                                CONSOLE_LOG="true"
                                ;;
                            *)
                                printf '%s\n' "Warning: Invalid quiet value '$value' at line $line_num, expected true/false" >&2
                                ;;
                        esac
                        ;;
                    console_log)
                        case "$(_to_lower "$value")" in
                            true|yes|1|on)
                                CONSOLE_LOG="true"
                                ;;
                            false|no|0|off)
                                CONSOLE_LOG="false"
                                ;;
                            *)
                                printf '%s\n' "Warning: Invalid console_log value '$value' at line $line_num, expected true/false" >&2
                                ;;
                        esac
                        ;;
                esac
                ;;
            script_name|scriptname|name)
                # Sanitize to prevent shell metacharacter injection
                SCRIPT_NAME=$(_sanitize_script_name "$value")
                ;;
            verbose)
                case "$(_to_lower "$value")" in
                    true|yes|1|on)
                        VERBOSE="true"
                        CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG
                        ;;
                    false|no|0|off)
                        VERBOSE="false"
                        ;;
                    *)
                        printf '%s\n' "Warning: Invalid verbose value '$value' at line $line_num, expected true/false" >&2
                        ;;
                esac
                ;;
            unsafe_allow_newlines|unsafe-allow-newlines)
                if ! LOG_UNSAFE_ALLOW_NEWLINES=$(_parse_bool_value "$value"); then
                    printf '%s\n' "Warning: Invalid unsafe_allow_newlines value '$value' at line $line_num, expected true/false" >&2
                fi
                ;;
            unsafe_allow_ansi_codes|unsafe-allow-ansi-codes)
                if ! LOG_UNSAFE_ALLOW_ANSI_CODES=$(_parse_bool_value "$value"); then
                    printf '%s\n' "Warning: Invalid unsafe_allow_ansi_codes value '$value' at line $line_num, expected true/false" >&2
                fi
                ;;
            max_line_length|max-line-length|log_max_line_length|log-max-line-length)
                # Read as bash arithmetic does (a leading 0 means octal); the value is
                # stored as written
                if _parse_shell_integer "$value" && [ "$_LOGGER_INTEGER" -le 1048576 ]; then
                    LOG_MAX_LINE_LENGTH="$value"
                else
                    printf '%s\n' "Warning: Invalid max_line_length value '$value' at line $line_num, expected integer 0-1048576" >&2
                    printf '%s\n' "  Hint: Using default value of 4096" >&2
                fi
                ;;
            max_journal_length|max-journal-length|journal_max_length|journal-max-line-length)
                # Read as bash arithmetic does (a leading 0 means octal); the value is
                # stored as written
                if _parse_shell_integer "$value" && [ "$_LOGGER_INTEGER" -le 1048576 ]; then
                    LOG_MAX_JOURNAL_LENGTH="$value"
                else
                    printf '%s\n' "Warning: Invalid max_journal_length value '$value' at line $line_num, expected integer 0-1048576" >&2
                    printf '%s\n' "  Hint: Using default value of 4096" >&2
                fi
                ;;
            init_message|log_init_message)
                case "$(_to_lower "$value")" in
                    true|yes|1|on)
                        LOG_INIT_MESSAGE="true"
                        ;;
                    false|no|0|off)
                        LOG_INIT_MESSAGE="false"
                        ;;
                    *)
                        printf '%s\n' "Warning: Invalid init_message value '$value' at line $line_num, expected true/false" >&2
                        ;;
                esac
                ;;
            *)
                printf '%s\n' "Warning: Unknown configuration key '$key' at line $line_num" >&2
                printf '%s\n' "  Hint: Valid keys are: level, format, log_file, journal, tag, utc, color," >&2
                printf '%s\n' "        stderr_level, quiet, console_log, script_name, verbose," >&2
                printf '%s\n' "        unsafe_allow_newlines, unsafe_allow_ansi_codes, max_line_length, max_journal_length," >&2
                printf '%s\n' "        init_message" >&2
                ;;
        esac
    done < "$config_file"

    LOG_CONFIG_FILE="$config_file"

    return 0
}

# Convert log level name to numeric value (internal)
_get_log_level_value() {
    local level_name=""
    # LC_ALL=C keeps the mapping ASCII-only: in a Turkish locale 'i' does not map to 'I'
    level_name="$(printf '%s' "$1" | LC_ALL=C tr '[:lower:]' '[:upper:]')"
    local line_num="${2:-}"
    case "${level_name}" in
        "DEBUG")
            printf '%s\n' "$LOG_LEVEL_DEBUG"
            ;;
        "INFO")
            printf '%s\n' "$LOG_LEVEL_INFO"
            ;;
        "NOTICE")
            printf '%s\n' "$LOG_LEVEL_NOTICE"
            ;;
        "WARN" | "WARNING")
            printf '%s\n' "$LOG_LEVEL_WARN"
            ;;
        "ERROR" | "ERR")
            printf '%s\n' "$LOG_LEVEL_ERROR"
            ;;
        "CRITICAL" | "CRIT")
            printf '%s\n' "$LOG_LEVEL_CRITICAL"
            ;;
        "ALERT")
            printf '%s\n' "$LOG_LEVEL_ALERT"
            ;;
        "EMERGENCY" | "EMERG" | "FATAL")
            printf '%s\n' "$LOG_LEVEL_EMERGENCY"
            ;;
        [01234567])
            # A number between 0-7 (valid syslog levels) is used directly
            printf '%s\n' "$level_name"
            ;;
        *)
            # Warn if line number provided (config file context)
            if [ -n "$line_num" ]; then
                printf '%s\n' "Warning: Invalid log level '$level_name' at line $line_num, using INFO" >&2
                printf '%s\n' "  Hint: Valid levels are: DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY (or 0-7)" >&2
            fi
            # Default to INFO if invalid
            printf '%s\n' "$LOG_LEVEL_INFO"
            ;;
    esac
}

# Get log level name from numeric value (internal)
_get_log_level_name() {
    local level_value="$1"
    case "$level_value" in
        "$LOG_LEVEL_DEBUG")
            printf '%s\n' "DEBUG"
            ;;
        "$LOG_LEVEL_INFO")
            printf '%s\n' "INFO"
            ;;
        "$LOG_LEVEL_NOTICE")
            printf '%s\n' "NOTICE"
            ;;
        "$LOG_LEVEL_WARN")
            printf '%s\n' "WARN"
            ;;
        "$LOG_LEVEL_ERROR")
            printf '%s\n' "ERROR"
            ;;
        "$LOG_LEVEL_CRITICAL")
            printf '%s\n' "CRITICAL"
            ;;
        "$LOG_LEVEL_ALERT")
            printf '%s\n' "ALERT"
            ;;
        "$LOG_LEVEL_EMERGENCY")
            printf '%s\n' "EMERGENCY"
            ;;
        *)
            printf '%s\n' "UNKNOWN"
            ;;
    esac
}

# Gets the ANSI color codes for a level name (internal)
_get_log_level_color() {
    _get_log_level_color_into "$1"
    printf '%s\n' "$_LOGGER_COLOR"
}

# Set _LOGGER_COLOR to the ANSI color codes for a level name (internal)
_get_log_level_color_into() {
    case "$1" in
        "DEBUG") _LOGGER_COLOR="${COLOR_BLUE}" ;;
        "INFO") _LOGGER_COLOR="" ;;
        "NOTICE") _LOGGER_COLOR="${COLOR_GREEN}" ;;
        "WARN") _LOGGER_COLOR="${COLOR_YELLOW}" ;;
        "ERROR") _LOGGER_COLOR="${COLOR_RED}" ;;
        "CRITICAL") _LOGGER_COLOR="${COLOR_RED_BOLD}" ;;
        "ALERT") _LOGGER_COLOR="${COLOR_WHITE_ON_RED}" ;;
        "EMERGENCY"|"FATAL") _LOGGER_COLOR="${COLOR_BOLD_WHITE_ON_RED}" ;;
        "INIT") _LOGGER_COLOR="${COLOR_PURPLE}" ;;
        "SENSITIVE") _LOGGER_COLOR="${COLOR_CYAN}" ;;
        *) _LOGGER_COLOR="" ;;
    esac
}

# Map log level to syslog priority (internal)
_get_syslog_priority() {
    _get_syslog_priority_into "$1"
    printf '%s\n' "$_LOGGER_PRIORITY"
}

# Set _LOGGER_PRIORITY to the syslog priority for a log level (internal)
_get_syslog_priority_into() {
    case "$1" in
        "$LOG_LEVEL_DEBUG") _LOGGER_PRIORITY="debug" ;;
        "$LOG_LEVEL_INFO") _LOGGER_PRIORITY="info" ;;
        "$LOG_LEVEL_NOTICE") _LOGGER_PRIORITY="notice" ;;
        "$LOG_LEVEL_WARN") _LOGGER_PRIORITY="warning" ;;
        "$LOG_LEVEL_ERROR") _LOGGER_PRIORITY="err" ;;
        "$LOG_LEVEL_CRITICAL") _LOGGER_PRIORITY="crit" ;;
        "$LOG_LEVEL_ALERT") _LOGGER_PRIORITY="alert" ;;
        "$LOG_LEVEL_EMERGENCY") _LOGGER_PRIORITY="emerg" ;;
        *) _LOGGER_PRIORITY="notice" ;;  # Default to notice for unknown levels
    esac
}

# Write to system journal safely (internal)
# Disables journal logging after first logger availability/execution failure
_write_to_journal() {
    local priority="$1"
    local tag="$2"
    local message="$3"
    local force_when_disabled="${4:-false}"

    if [ "$force_when_disabled" != "true" ] && [ "$USE_JOURNAL" != "true" ]; then
        return 0
    fi

    if [ -z "$LOGGER_PATH" ] || [ ! -x "$LOGGER_PATH" ]; then
        if [ -z "${LOGGER_JOURNAL_ERROR_REPORTED:-}" ]; then
            printf '%s\n' "Warning: logger command unavailable at '$LOGGER_PATH'" >&2
            printf '%s\n' "  Journal logging disabled to prevent repeated failures" >&2
            LOGGER_JOURNAL_ERROR_REPORTED="yes"
        fi
        USE_JOURNAL="false"
        return 1
    fi

    "$LOGGER_PATH" -p "${SYSLOG_FACILITY}.${priority}" -t "$tag" -- "$message" 2>/dev/null || {
        if [ -z "${LOGGER_JOURNAL_ERROR_REPORTED:-}" ]; then
            printf '%s\n' "Warning: logger command failed; disabling journal logging" >&2
            LOGGER_JOURNAL_ERROR_REPORTED="yes"
        fi
        USE_JOURNAL="false"
        return 1
    }

    return 0
}

# Function to sanitize log messages to prevent log injection (internal)
# Removes control characters that could break log formats or inject fake entries
_strip_ansi_codes() {
    _strip_ansi_codes_into "$1"
    printf '%s\n' "$_LOGGER_TEXT"
}

# Set _LOGGER_TEXT to text with ANSI escape sequences removed (internal).
# Same result as _strip_ansi_codes, without a subshell for the caller.
_strip_ansi_codes_into() {
    _LOGGER_TEXT="$1"

    # If unsafe mode is enabled, skip ANSI stripping and return input as-is
    if [ "$LOG_UNSAFE_ALLOW_ANSI_CODES" = "true" ]; then
        return 0
    fi

    # Every pattern below starts with ESC, so text without ESC is unchanged and sed
    # is not started. Trailing newlines are still removed, as the sed path does.
    case "$_LOGGER_TEXT" in
        *"$_LOGGER_ESC"*) ;;
        *)
            _strip_trailing_newlines
            return 0
            ;;
    esac

    # Remove ANSI escape sequences that would otherwise manipulate terminal display.
    #
    # All patterns run in one sed process, in the order listed below. Each pattern is its
    # own -e expression and is written to work with both GNU and BSD sed (macOS):
    #   * -E (extended regex) is used because BSD sed has no \| alternation in basic regex
    #   * a loop label is its own -e expression, because BSD sed ends a label at a newline
    #     and not at a semicolon
    #   * the escape character is inserted as a literal byte, because BSD sed does not
    #     recognise \x1b
    #   * ^ is escaped because it is an anchor everywhere in an extended regex
    local esc="$_LOGGER_ESC"
    local bel="$_LOGGER_BEL"

    # 1. CSI (Control Sequence Introducer): ESC [ parameters letter
    #    Includes color codes (\e[...m), cursor movement (\e[H), clearing (\e[2J), etc.
    #    Also handles DEC private modes (e.g., \e[?25l, \e[?1049h) and other parameter
    #    bytes: [<=>?!] plus digits and semicolons, then a letter or @
    # 2. OSC (Operating System Command), BEL terminated: ESC ] ... BEL
    # 3. OSC, ST terminated: ESC ] ... ESC \
    #    The payload is any char except ESC, or ESC when not followed by \, so embedded
    #    codes such as \e[31m do not end the match early. The loop removes consecutive
    #    sequences. A substitution earlier in the script can set the t flag, which costs
    #    one extra pass through the loop and nothing else.
    # 4. OSC, ST terminated, without embedded escapes (second pass)
    # 5. DCS (Device Control String): ESC P ... ESC \
    #    Carries device control payloads (e.g. Sixel graphics, DECRQSS responses).
    #    The payload and the ST terminator are removed along with the opener.
    # 6. PM (Privacy Message): ESC ^ ... ESC \
    # 7. APC (Application Program Command): ESC _ ... ESC \
    # 8. Remaining escape sequences (simplified fallback): ESC and the next character
    _LOGGER_TEXT=$(printf '%s' "$_LOGGER_TEXT" | sed -E \
        -e "s/${esc}\[[0-9;<?>=!]*[a-zA-Z@]//g" \
        -e "s/${esc}][^${bel}]*${bel}//g" \
        -e ':osc_st_loop' \
        -e "s/${esc}]([^${esc}]|${esc}[^\\\\])*${esc}\\\\//g" \
        -e 't osc_st_loop' \
        -e "s/${esc}][^${esc}]*${esc}\\\\//g" \
        -e "s/${esc}P[^${esc}]*${esc}\\\\//g" \
        -e "s/${esc}\^[^${esc}]*${esc}\\\\//g" \
        -e "s/${esc}_[^${esc}]*${esc}\\\\//g" \
        -e "s/${esc}[^[]//g")
}

# Set _LOGGER_REPLACED to text with newline, carriage return and tab replaced by spaces
# (internal). This runs before truncation and a message can be large (for example captured
# command output), so the cost must not grow with the square of the message length.
#   Long text with something to replace: one tr process. Above the limits below, this is
#     cheaper than the in-shell replacement, including zsh pattern substitution.
#   bash and zsh otherwise: pattern substitution
#   other shells otherwise, or if tr fails: the _replace_all loop, which is quadratic but
#     needs no external command
_replace_line_control_chars() {
    local text="$1"
    local tr_above_length=2048
    if _shell_counts_characters; then
        tr_above_length=16384
    fi
    if [ "${#text}" -gt "$tr_above_length" ]; then
        case "$text" in
            *"$_LOGGER_NEWLINE"*|*"$_LOGGER_CR"*|*"$_LOGGER_TAB"*) ;;
            *)
                _LOGGER_REPLACED="$text"
                return 0
                ;;
        esac
        # tr leaves no trailing newline for command substitution to remove
        if _LOGGER_REPLACED=$(printf '%s' "$text" | LC_ALL=C tr '\n\r\t' '   '); then
            return 0
        fi
    fi
    if _shell_counts_characters; then
        # Pattern substitution only runs in bash and zsh
        # shellcheck disable=SC3060
        text="${text//$_LOGGER_NEWLINE/ }"
        # shellcheck disable=SC3060
        text="${text//$_LOGGER_CR/ }"
        # shellcheck disable=SC3060
        text="${text//$_LOGGER_TAB/ }"
        _LOGGER_REPLACED="$text"
        return 0
    fi
    _replace_all "$text" "$_LOGGER_NEWLINE" " "
    _replace_all "$_LOGGER_REPLACED" "$_LOGGER_CR" " "
    _replace_all "$_LOGGER_REPLACED" "$_LOGGER_TAB" " "
}

# Function to sanitize log messages to prevent log injection (internal)
# Removes control characters that could break log formats or inject fake entries
_sanitize_log_message() {
    _sanitize_log_message_into "$1"
    printf '%s\n' "$_LOGGER_TEXT"
}

# Set _LOGGER_TEXT to the sanitized message (internal).
# Same result as _sanitize_log_message, without a subshell for the caller.
_sanitize_log_message_into() {
    local message="$1"

    # Sanitize newlines if not in unsafe mode
    # This is independent from ANSI code stripping to prevent security bypass
    if [ "$LOG_UNSAFE_ALLOW_NEWLINES" != "true" ]; then
        # Replace control characters with spaces to prevent log injection
        # These characters can break log formats and enable log injection attacks
        # newline (LF), carriage return (CR) and tab (HT)
        _replace_line_control_chars "$message"
        message="$_LOGGER_REPLACED"
    fi

    # Strip ANSI codes from user input to prevent terminal manipulation
    # This is independent from newline sanitization
    _strip_ansi_codes_into "$message"
    _strip_trailing_newlines
}

# Truncate log messages to a maximum length (internal)
_truncate_log_message() {
    _truncate_log_message_into "$1" "$2"
    printf '%s\n' "$_LOGGER_TEXT"
}

# Set _LOGGER_TEXT to the message truncated to a limit (internal).
# Same result as _truncate_log_message, without a subshell for the caller.
# The limit counts characters in bash and zsh and bytes in other shells; a
# multi-byte UTF-8 character is never cut in half (see _text_prefix).
_truncate_log_message_into() {
    local message="$1"
    local limit="$2"
    local suffix="...[truncated]"
    _LOGGER_TEXT="$message"

    if [ -z "$limit" ]; then
        return 0
    fi

    # Not a number (or invalid octal such as 08): no truncation
    if ! _parse_shell_integer "$limit"; then
        return 0
    fi
    limit="$_LOGGER_INTEGER"

    if [ "$limit" -le 0 ]; then
        return 0
    fi

    _text_length "$message" "$limit"
    if [ "$_LOGGER_TEXT_LENGTH" -le "$limit" ]; then
        return 0
    fi

    if [ "$limit" -le "${#suffix}" ]; then
        _text_prefix "$message" "$limit"
        _LOGGER_TEXT="$_LOGGER_PREFIX"
        return 0
    fi

    _text_prefix "$message" "$((limit - ${#suffix}))"
    _LOGGER_TEXT="${_LOGGER_PREFIX}${suffix}"
}

# Function to sanitize script names to prevent shell metacharacter injection (internal)
# Replaces any character that is not alphanumeric, period, underscore, or hyphen with underscore
# This is a defense-in-depth measure to prevent potential injection attacks via crafted filenames
_sanitize_script_name() {
    # Replace any character that's not alphanumeric, period, underscore, or hyphen
    # with an underscore to prevent shell metacharacter injection
    _replace_unsafe_name_characters "$1"
    printf '%s\n' "$_LOGGER_REPLACED"
}

# Function to format log message (internal)
_format_log_message() {
    _format_log_message_into "$1" "$2"
    printf '%s\n' "$_LOGGER_TEXT"
}

# Set _LOGGER_TIMESTAMP to the current time, in UTC when USE_UTC is true (internal).
# Starting date is most of the cost of a message, so bash 4.2+ and zsh use their builtins.
# Any other shell, or a builtin result that fails the checks below, uses date.
_current_timestamp_into() {
    _LOGGER_TIMESTAMP=""
    case "$_LOGGER_TIME_BUILTIN" in
        bash) _bash_timestamp_into ;;
        zsh) _zsh_timestamp_into ;;
    esac
    case "$_LOGGER_TIMESTAMP" in
        [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' '[0-9][0-9]:[0-9][0-9]:[0-9][0-9]) return 0 ;;
    esac
    if [ "$USE_UTC" = "true" ]; then
        _LOGGER_TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S')
    else
        _LOGGER_TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    fi
}

# Set _LOGGER_TIMESTAMP to the UTC date and time of seconds since the epoch (internal).
# The arithmetic converts days to a calendar date (Howard Hinnant's civil_from_days). It avoids
# changing TZ: an assignment to TZ fails if the caller made it readonly, which exits the script
# under set -e and in POSIX mode, and in zsh it only reaches localtime if exported.
_utc_timestamp_from_epoch() {
    local epoch="$1"
    local shifted_days="$((epoch / 86400 + 719468))"
    local second_of_day="$((epoch % 86400))"
    local era="$((shifted_days / 146097))"
    local day_of_era="$((shifted_days - era * 146097))"
    local year_of_era="$(((day_of_era - day_of_era / 1460 + day_of_era / 36524 - day_of_era / 146096) / 365))"
    local day_of_year="$((day_of_era - (365 * year_of_era + year_of_era / 4 - year_of_era / 100)))"
    local shifted_month="$(((5 * day_of_year + 2) / 153))"
    local day="$((day_of_year - (153 * shifted_month + 2) / 5 + 1))"
    local month="$((shifted_month < 10 ? shifted_month + 3 : shifted_month - 9))"
    local year="$((year_of_era + era * 400 + (month <= 2 ? 1 : 0)))"
    local hour="$((second_of_day / 3600))"
    local minute="$((second_of_day % 3600 / 60))"
    local second="$((second_of_day % 60))"
    case "$month" in ?) month="0$month" ;; esac
    case "$day" in ?) day="0$day" ;; esac
    case "$hour" in ?) hour="0$hour" ;; esac
    case "$minute" in ?) minute="0$minute" ;; esac
    case "$second" in ?) second="0$second" ;; esac
    _LOGGER_TIMESTAMP="${year}-${month}-${day} ${hour}:${minute}:${second}"
}

# Set _LOGGER_TIMESTAMP with the bash printf time format (internal).
_bash_timestamp_into() {
    if [ "$USE_UTC" = "true" ]; then
        local epoch=""
        # printf -v and its time format only run in bash
        # shellcheck disable=SC3045
        printf -v epoch '%(%s)T' -1 2>/dev/null # bash32-compat: ignore
        if _is_digits "$epoch"; then
            _utc_timestamp_from_epoch "$epoch"
        fi
    else
        # shellcheck disable=SC3045
        printf -v _LOGGER_TIMESTAMP '%(%Y-%m-%d %H:%M:%S)T' -1 2>/dev/null # bash32-compat: ignore
    fi
}

# Set _LOGGER_TIMESTAMP with zsh prompt expansion, which needs no module (internal).
# This syntax is a parse error in some POSIX shells, so it is in strings passed to eval.
# The strings are constants: no caller data reaches eval.
_zsh_timestamp_into() {
    emulate -L zsh
    if [ "$USE_UTC" = "true" ]; then
        local epoch=""
        eval 'epoch=${(%):-%D{%s}}'
        if _is_digits "$epoch"; then
            _utc_timestamp_from_epoch "$epoch"
        fi
    else
        eval '_LOGGER_TIMESTAMP=${(%):-%D{%Y-%m-%d %H:%M:%S}}'
    fi
}

# Set _LOGGER_TEXT to the formatted log entry (internal).
# Same result as _format_log_message, without a subshell for the caller.
_format_log_message_into() {
    local level_name="$1"
    local message="$2"

    # Get timestamp in appropriate timezone
    local current_date=""
    local timezone_str=""
    if [ "$USE_UTC" = "true" ]; then
        timezone_str="UTC"
    else
        timezone_str="LOCAL"
    fi
    _current_timestamp_into
    current_date="$_LOGGER_TIMESTAMP"

    # Expand format tokens in a single left-to-right pass.
    # Each %X token is replaced once and inserted values are never re-scanned,
    # so message content cannot be read as a token or as replacement syntax
    # (e.g. '&' under bash 5.2 patsub_replacement). Behaves the same in every
    # supported shell. Unknown tokens, '%%' and a trailing '%' are kept literally.
    local remaining="$LOG_FORMAT"
    local formatted_message=""
    local token=""
    while :; do
        case "$remaining" in
            *%*) ;;
            *) break ;;
        esac
        formatted_message="${formatted_message}${remaining%%\%*}"
        remaining="${remaining#*\%}"
        # First character of what follows the %
        token="${remaining%"${remaining#?}"}"
        case "$token" in
            d) formatted_message="${formatted_message}${current_date}" ;;
            l) formatted_message="${formatted_message}${level_name}" ;;
            s) formatted_message="${formatted_message}${SCRIPT_NAME:-unknown}" ;;
            m) formatted_message="${formatted_message}${message}" ;;
            z) formatted_message="${formatted_message}${timezone_str}" ;;
            *) formatted_message="${formatted_message}%${token}" ;;
        esac
        remaining="${remaining#?}"
    done
    _LOGGER_TEXT="${formatted_message}${remaining}"
}

# Set _LOGGER_CALLER_PATH to the file that called init_logger (internal).
# Must be called directly from init_logger: the call depth is fixed.
#   bash: BASH_SOURCE[2] (this function, init_logger, then the caller)
#   zsh:  funcfiletrace[2], which is "file:line" for the same caller; emulate -L
#         gives 1-based arrays here even when the caller set ksh_arrays
#   other shells: $0. In a script that runs ". logging.sh" this is the calling
#         script. It is the shell's name when commands come from -c or stdin.
_find_caller_script() {
    _LOGGER_CALLER_PATH=""
    if [ "$_LOGGER_SHELL_FAMILY" = "bash" ]; then
        # BASH_SOURCE is only read in bash
        # shellcheck disable=SC3028,SC3054
        _LOGGER_CALLER_PATH="${BASH_SOURCE[2]:-}"
    elif [ "$_LOGGER_SHELL_FAMILY" = "zsh" ]; then
        emulate -L zsh
        # funcfiletrace is a zsh array
        # shellcheck disable=SC2154,SC3054
        _LOGGER_CALLER_PATH="${funcfiletrace[2]:-}"
        _LOGGER_CALLER_PATH="${_LOGGER_CALLER_PATH%:*}"
    else
        _LOGGER_CALLER_PATH="$0"
    fi
}

# Return 0 if a value is one or more digits (internal)
_is_digits() {
    case "$1" in
        ''|*[!0123456789]*) return 1 ;;
    esac
    return 0
}

# Check that an init_logger option has a value after it (internal).
# Usage: _require_option_value "$@"   (with the option as $1)
# Without this, "shift 2" fails at the end of the arguments: bash then loops forever
# and POSIX shells exit the calling script.
_require_option_value() {
    if [ "$#" -lt 2 ]; then
        printf '%s\n' "Error: $1 requires a value" >&2
        return 1
    fi
    return 0
}

# Function to initialize logger with custom settings
init_logger() {
    # Get the calling script's name (can be overridden with -n|--name option)
    _find_caller_script
    local caller_path="$_LOGGER_CALLER_PATH"
    local caller_script="unknown"
    if [ -n "$caller_path" ]; then
        caller_script=$(_sanitize_script_name "$(basename "$caller_path")")
    fi

    # Variable to hold custom script name if provided
    local custom_script_name=""

    # First pass: look for config file option and process it first
    # This allows CLI arguments to override config file values
    # Iterates "$@" directly rather than an indexed array, because zsh arrays
    # are 1-based and bash arrays are 0-based
    local first_pass_arg=""
    local expect_config_path="false"
    for first_pass_arg in "$@"; do
        if [ "$expect_config_path" = "true" ]; then
            if [ -z "$first_pass_arg" ]; then
                printf '%s\n' "Error: --config requires a file path argument" >&2
                return 1
            fi
            if ! _parse_config_file "$first_pass_arg"; then
                return 1
            fi
            expect_config_path="false"
            break
        fi
        case "$first_pass_arg" in
            -c|--config) expect_config_path="true" ;;
        esac
    done
    if [ "$expect_config_path" = "true" ]; then
        printf '%s\n' "Error: --config requires a file path argument" >&2
        return 1
    fi

    # Second pass: parse all command line arguments (overrides config file)
    while [ "$#" -gt 0 ]; do
        case $1 in
            -c|--config)
                # Already processed in first pass, which only checks the first --config
                _require_option_value "$@" || return 1
                shift 2
                ;;
            --color|--colour)
                USE_COLORS="always"
                shift
                ;;
            --no-color|--no-colour)
                USE_COLORS="never"
                shift
                ;;
            -d|--level)
                _require_option_value "$@" || return 1
                local level_value=""
                level_value=$(_get_log_level_value "$2")
                CURRENT_LOG_LEVEL=$level_value
                # If both --verbose and --level are specified, --level takes precedence
                shift 2
                ;;
            -f|--format)
                _require_option_value "$@" || return 1
                LOG_FORMAT="$2"
                shift 2
                ;;
            -j|--journal)
                if _find_and_validate_logger; then
                    USE_JOURNAL="true"
                else
                    printf '%s\n' "Warning: logger command not available or not in safe location, journal logging disabled" >&2
                fi
                shift
                ;;
            -l|--log|--logfile|--log-file|--file)
                _require_option_value "$@" || return 1
                LOG_FILE="$2"
                shift 2
                ;;
            -n|--name|--script-name)
                _require_option_value "$@" || return 1
                # Sanitize to prevent shell metacharacter injection
                custom_script_name=$(_sanitize_script_name "$2")
                shift 2
                ;;
            -q|--quiet)
                CONSOLE_LOG="false"
                shift
                ;;
            -t|--tag)
                _require_option_value "$@" || return 1
                JOURNAL_TAG="$2"
                shift 2
                ;;
            -F|--facility)
                if [ -z "${2:-}" ]; then
                    printf '%s\n' "Error: --facility requires a value" >&2
                    return 1
                fi
                if _validate_syslog_facility "$2"; then
                    SYSLOG_FACILITY="$(_to_lower "$2")"
                else
                    printf '%s\n' "  Hint: Keeping existing syslog facility '$SYSLOG_FACILITY'" >&2
                fi
                shift 2
                ;;
            -u|--utc)
                USE_UTC="true"
                shift
                ;;
            -v|--verbose|--debug)
                VERBOSE="true"
                CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG
                shift
                ;;
            -e|--stderr-level)
                _require_option_value "$@" || return 1
                local stderr_level_value=""
                stderr_level_value=$(_get_log_level_value "$2")
                LOG_STDERR_LEVEL=$stderr_level_value
                shift 2
                ;;
            -U|--unsafe-allow-newlines)
                LOG_UNSAFE_ALLOW_NEWLINES="true"
                shift
                ;;
            -A|--unsafe-allow-ansi-codes)
                LOG_UNSAFE_ALLOW_ANSI_CODES="true"
                shift
                ;;
            --max-line-length)
                if [ -z "${2:-}" ]; then
                    printf '%s\n' "Error: --max-line-length requires a value" >&2
                    return 1
                fi
                if _is_digits "$2"; then
                    LOG_MAX_LINE_LENGTH="$2"
                else
                    printf '%s\n' "Warning: Invalid max-line-length value '$2', expected non-negative integer" >&2
                fi
                shift 2
                ;;
            --max-journal-length)
                if [ -z "${2:-}" ]; then
                    printf '%s\n' "Error: --max-journal-length requires a value" >&2
                    return 1
                fi
                if _is_digits "$2"; then
                    LOG_MAX_JOURNAL_LENGTH="$2"
                else
                    printf '%s\n' "Warning: Invalid max-journal-length value '$2', expected non-negative integer" >&2
                fi
                shift 2
                ;;
            --no-init-message)
                LOG_INIT_MESSAGE="false"
                shift
                ;;
            *)
                printf '%s\n' "Unknown parameter for logger: $1" >&2
                return 1
                ;;
        esac
    done

    # Set a global variable for the script name to use in log messages
    # Priority: CLI option > config file > auto-detected caller script
    if [ -n "$custom_script_name" ]; then
        # CLI option takes highest priority
        SCRIPT_NAME="$custom_script_name"
    elif [ -z "${SCRIPT_NAME:-}" ]; then
        # Only use auto-detected name if not already set (e.g., by config file)
        SCRIPT_NAME="$caller_script"
    fi
    # If SCRIPT_NAME was set by config file, keep that value

    # Always sanitize SCRIPT_NAME regardless of source (env var, config, CLI, or auto-detected)
    # to prevent log injection via control characters in the init message and all log entries
    SCRIPT_NAME=$(_sanitize_script_name "$SCRIPT_NAME")

    # Set default journal tag if not specified but journal logging is enabled
    if [ "$USE_JOURNAL" = "true" ] && [ -z "$JOURNAL_TAG" ]; then
        JOURNAL_TAG="$SCRIPT_NAME"
    fi

    # Validate log file path if specified
    if [ -n "$LOG_FILE" ]; then
        # Get directory of log file
        LOG_DIR=$(dirname "$LOG_FILE")

        # Try to create directory if it doesn't exist
        if [ ! -d "$LOG_DIR" ]; then
            mkdir -p "$LOG_DIR" 2>/dev/null || {
                printf '%s\n' "Error: Cannot create log directory" >&2
                printf '%s\n' "  Hint: Check the --log argument (or LOG_FILE environment variable) and parent directory permissions" >&2
                return 1
            }
        fi

        # Secure file creation to mitigate TOCTOU race condition (Issue #38, #52)
        # Always attempt atomic file creation with noclobber (safe on existing files)
        # Removing existence check eliminates TOCTOU window where attacker could
        # create symlink between check and creation attempt
        (set -C; : > "$LOG_FILE") 2>/dev/null || true

        # Immediately validate file security to minimize TOCTOU window
        # Reject symbolic links to prevent log redirection attacks
        if [ -L "$LOG_FILE" ]; then
            printf '%s\n' "Error: Log file path is a symbolic link" >&2
            printf '%s\n' "  Hint: Verify the --log argument doesn't point to a symbolic link for security" >&2
            return 1
        fi

        # Check if file exists (may not have been created due to permissions)
        # This provides clearer error messaging than the regular file check alone
        if [ ! -e "$LOG_FILE" ]; then
            printf '%s\n' "Error: Cannot create log file (check directory permissions)" >&2
            printf '%s\n' "  Hint: Verify the log directory exists and the process has write permissions" >&2
            return 1
        fi

        # Verify it's a regular file, not a device or other special file
        if [ ! -f "$LOG_FILE" ]; then
            printf '%s\n' "Error: Log file exists but is not a regular file (may be a directory or device)" >&2
            printf '%s\n' "  Hint: Check the --log argument (or LOG_FILE environment variable) and verify it points to a regular file" >&2
            return 1
        fi

        # Verify file is writable
        if [ ! -w "$LOG_FILE" ]; then
            printf '%s\n' "Error: Log file is not writable" >&2
            printf '%s\n' "  Hint: Check file permissions and ensure the process has write access" >&2
            return 1
        fi

        # Write the initialization message using the same format
        # Can be suppressed with --no-init-message (or init_message=false in config)
        if [ "$LOG_INIT_MESSAGE" = "true" ]; then
            _format_log_message_into "INIT" "Logger initialized by $SCRIPT_NAME"
            { printf '%s\n' "$_LOGGER_TEXT" >> "$LOG_FILE"; } 2>/dev/null || {
                printf '%s\n' "Error: Failed to write initialization message to log file" >&2
                printf '%s\n' "  Hint: Verify the file is writable and disk space is available" >&2
                return 1
            }
        fi

        printf '%s\n' "Logger: Successfully initialized with log file enabled" >&2
    fi

    # Log initialization success
    log_debug "Logger initialized with script_name='$SCRIPT_NAME': console=$CONSOLE_LOG, file=$LOG_FILE, journal=$USE_JOURNAL, colors=$USE_COLORS, log level=$(_get_log_level_name "$CURRENT_LOG_LEVEL"), stderr level=$(_get_log_level_name "$LOG_STDERR_LEVEL"), format=\"$LOG_FORMAT\""
    return 0
}

# Print a set_* function's CONFIG notice to the console (internal)
# Routed like a NOTICE message, so it follows LOG_STDERR_LEVEL instead of always using stdout.
# Arguments: $1 = formatted log entry, $2 = color (optional, defaults to COLOR_PURPLE)
_log_set_config_to_console() {
    local log_entry="$1"
    local log_entry_color="${2:-$COLOR_PURPLE}"

    if [ "$CONSOLE_LOG" != "true" ]; then
        return 0
    fi

    local output="${log_entry}"
    if _should_use_colors; then
        output="${log_entry_color}${log_entry}${COLOR_RESET}"
    fi

    if _should_use_stderr "$LOG_LEVEL_NOTICE"; then
        printf '%s\n' "${output}" >&2
    else
        printf '%s\n' "${output}"
    fi
    return 0
}

# Append a set_* function's CONFIG notice to the log file (internal)
# Written without colors, whatever the console, stderr level or log level settings.
# Does nothing when LOG_FILE is empty.
# Arguments: $1 = formatted log entry
_log_set_config_to_file() {
    if [ -n "$LOG_FILE" ]; then
        _append_to_log_file "$1"
    fi
    return 0
}

# Function to change log level after initialization
set_log_level() {
    local level="$1"
    local old_level=""
    old_level=$(_get_log_level_name "$CURRENT_LOG_LEVEL")
    CURRENT_LOG_LEVEL=$(_get_log_level_value "$level")
    local new_level=""
    new_level=$(_get_log_level_name "$CURRENT_LOG_LEVEL")

    # Create a special log entry that bypasses level checks
    local message="Log level changed from $old_level to $new_level"
    local log_entry=""
    log_entry=$(_format_log_message "CONFIG" "$message")

    _log_set_config_to_console "${log_entry}"
    _log_set_config_to_file "${log_entry}"

    # Always log to journal if enabled
    _write_to_journal "notice" "${JOURNAL_TAG:-$SCRIPT_NAME}" "CONFIG: $message"
}

set_timezone_utc() {
    local use_utc="$1"
    local old_setting="$USE_UTC"
    USE_UTC="$use_utc"

    local message="Timezone setting changed from $old_setting to $USE_UTC"
    local log_entry=""
    log_entry=$(_format_log_message "CONFIG" "$message")

    _log_set_config_to_console "${log_entry}"
    _log_set_config_to_file "${log_entry}"

    # Always log to journal if enabled
    _write_to_journal "notice" "${JOURNAL_TAG:-$SCRIPT_NAME}" "CONFIG: $message"
}

# Function to change log format
set_log_format() {
    local old_format="$LOG_FORMAT"
    LOG_FORMAT="$1"

    local message="Log format changed from \"$old_format\" to \"$LOG_FORMAT\""
    local log_entry=""
    log_entry=$(_format_log_message "CONFIG" "$message")

    _log_set_config_to_console "${log_entry}"
    _log_set_config_to_file "${log_entry}"

    # Always log to journal if enabled
    _write_to_journal "notice" "${JOURNAL_TAG:-$SCRIPT_NAME}" "CONFIG: $message"
}

# Function to toggle journal logging
set_journal_logging() {
    local old_setting="$USE_JOURNAL"
    USE_JOURNAL="$1"

    # Check if logger is available when enabling journal logging
    if [ "$USE_JOURNAL" = "true" ]; then
        if ! check_logger_available; then
            printf '%s\n' "Error: logger command not found, cannot enable journal logging" >&2
            USE_JOURNAL="$old_setting"
            return 1
        fi
    fi

    local message="Journal logging changed from $old_setting to $USE_JOURNAL"
    local log_entry=""
    log_entry=$(_format_log_message "CONFIG" "$message")

    _log_set_config_to_console "${log_entry}"
    _log_set_config_to_file "${log_entry}"

    # Log to journal if it was previously enabled or just being enabled
    # Only attempt journal write when logger path is set
    if [ "$old_setting" = "true" ] || [ "$USE_JOURNAL" = "true" ]; then
        _write_to_journal "notice" "${JOURNAL_TAG:-$SCRIPT_NAME}" "CONFIG: $message" "true"
    fi
}

# Function to set journal tag
set_journal_tag() {
    if ! _validate_journal_tag "$1"; then
        return 1
    fi

    local old_tag="$JOURNAL_TAG"
    JOURNAL_TAG="$1"

    local message="Journal tag changed from \"$old_tag\" to \"$JOURNAL_TAG\""
    local log_entry=""
    log_entry=$(_format_log_message "CONFIG" "$message")

    _log_set_config_to_console "${log_entry}"
    _log_set_config_to_file "${log_entry}"

    # Log to journal if enabled, using the old tag
    _write_to_journal "notice" "${old_tag:-$SCRIPT_NAME}" "CONFIG: Journal tag changing to \"$JOURNAL_TAG\""
}

# Function to set syslog facility
set_syslog_facility() {
    local old_facility="$SYSLOG_FACILITY"

    if ! _validate_syslog_facility "$1"; then
        return 1
    fi

    SYSLOG_FACILITY="$(_to_lower "$1")"

    local message="Syslog facility changed from \"$old_facility\" to \"$SYSLOG_FACILITY\""
    local log_entry=""
    log_entry=$(_format_log_message "CONFIG" "$message")

    _log_set_config_to_console "${log_entry}"
    _log_set_config_to_file "${log_entry}"

    # Always log to journal if enabled
    _write_to_journal "notice" "${JOURNAL_TAG:-$SCRIPT_NAME}" "CONFIG: $message"
}

# Function to set color mode
set_color_mode() {
    local mode="$1"
    local old_setting="$USE_COLORS"
    local new_value=""

    case "$mode" in
        true|on|yes|1)
            new_value="always"
            ;;
        false|off|no|0)
            new_value="never"
            ;;
        auto|always|never)
            new_value="$mode"
            ;;
        *)
            printf '%s\n' "Error: set_color_mode: unrecognised mode '$mode'" >&2
            printf '%s\n' "  Valid modes: auto, always, never (or: true/false, on/off, yes/no, 1/0)" >&2
            return 1
            ;;
    esac

    USE_COLORS="$new_value"

    local message="Color mode changed from \"$old_setting\" to \"$USE_COLORS\""
    local log_entry=""
    log_entry=$(_format_log_message "CONFIG" "$message")

    _log_set_config_to_console "${log_entry}"
    _log_set_config_to_file "${log_entry}"

    # Log to journal if enabled
    _write_to_journal "notice" "${JOURNAL_TAG:-$SCRIPT_NAME}" "CONFIG: $message"
}

# Function to set script name dynamically
set_script_name() {
    local old_name="$SCRIPT_NAME"
    # Sanitize to prevent shell metacharacter injection
    SCRIPT_NAME=$(_sanitize_script_name "$1")

    local message="Script name changed from \"$old_name\" to \"$SCRIPT_NAME\""
    local log_entry=""
    log_entry=$(_format_log_message "CONFIG" "$message")

    _log_set_config_to_console "${log_entry}"
    _log_set_config_to_file "${log_entry}"

    # Always log to journal if enabled
    _write_to_journal "notice" "${JOURNAL_TAG:-$SCRIPT_NAME}" "CONFIG: $message"
}

# Function to enable/disable unsafe mode for newlines in log messages
# WARNING: Disabling sanitization can allow log injection attacks. Only use if you have
#          explicit control over all logged messages and your log parsing handles newlines safely.
set_unsafe_allow_newlines() {
    local new_value=""
    new_value=$(_parse_bool_value "$1") || {
        printf '%s\n' "Error: set_unsafe_allow_newlines: invalid value '$1'" >&2
        printf '%s\n' "  Valid values: true, false, yes, no, on, off, 1, 0" >&2
        return 1
    }
    local old_setting="$LOG_UNSAFE_ALLOW_NEWLINES"
    LOG_UNSAFE_ALLOW_NEWLINES="$new_value"

    local safety_notice=""
    if [ "$LOG_UNSAFE_ALLOW_NEWLINES" = "true" ]; then
        safety_notice=" (WARNING: Log injection protection is disabled)"
    fi

    local message="Unsafe newline mode changed from $old_setting to $LOG_UNSAFE_ALLOW_NEWLINES$safety_notice"
    local log_entry=""
    log_entry=$(_format_log_message "CONFIG" "$message")

    # Use warning color if enabling unsafe mode
    local log_entry_color=""
    if [ "$LOG_UNSAFE_ALLOW_NEWLINES" = "true" ]; then
        log_entry_color="${COLOR_RED}"
    fi
    _log_set_config_to_console "${log_entry}" "${log_entry_color}"
    _log_set_config_to_file "${log_entry}"

    # Always log to journal if enabled
    _write_to_journal "notice" "${JOURNAL_TAG:-$SCRIPT_NAME}" "CONFIG: $message"
}

# Function to enable/disable unsafe mode for ANSI codes in log messages
# WARNING: Disabling sanitization can allow terminal manipulation attacks. Only use if you have
#          explicit control over all logged messages and trust their source.
set_unsafe_allow_ansi_codes() {
    local new_value=""
    new_value=$(_parse_bool_value "$1") || {
        printf '%s\n' "Error: set_unsafe_allow_ansi_codes: invalid value '$1'" >&2
        printf '%s\n' "  Valid values: true, false, yes, no, on, off, 1, 0" >&2
        return 1
    }
    local old_setting="$LOG_UNSAFE_ALLOW_ANSI_CODES"
    LOG_UNSAFE_ALLOW_ANSI_CODES="$new_value"

    local safety_notice=""
    if [ "$LOG_UNSAFE_ALLOW_ANSI_CODES" = "true" ]; then
        safety_notice=" (WARNING: ANSI code injection protection is disabled)"
    fi

    local message="Unsafe ANSI codes mode changed from $old_setting to $LOG_UNSAFE_ALLOW_ANSI_CODES$safety_notice"
    local log_entry=""
    log_entry=$(_format_log_message "CONFIG" "$message")

    # Use warning color if enabling unsafe mode
    local log_entry_color=""
    if [ "$LOG_UNSAFE_ALLOW_ANSI_CODES" = "true" ]; then
        log_entry_color="${COLOR_RED}"
    fi
    _log_set_config_to_console "${log_entry}" "${log_entry_color}"
    _log_set_config_to_file "${log_entry}"

    # Always log to journal if enabled
    _write_to_journal "notice" "${JOURNAL_TAG:-$SCRIPT_NAME}" "CONFIG: $message"
}

# Logs to console (internal)
_log_to_console() {
    local log_entry="$1"
    local level_name="$2"
    local level_value="$3"

    local use_stderr="false"
    if _should_use_stderr "$level_value"; then
        use_stderr="true"
    fi

    local output="${log_entry}"

    if _should_use_colors; then
        _get_log_level_color_into "$level_name"
        output="${_LOGGER_COLOR}${output}${COLOR_RESET}"
    fi

    if [ "$use_stderr" = "true" ]; then
        printf '%s\n' "${output}" >&2 # Log to stderr
    else
        printf '%s\n' "${output}"
    fi
    return 0
}

# Append a formatted entry to LOG_FILE (internal)
# A failed write is reported once, and the entry goes to stderr so it is not lost.
_append_to_log_file() {
    { printf '%s\n' "$1" >> "$LOG_FILE"; } 2>/dev/null || {
        # Only print the error once to avoid spam
        if [ -z "${LOGGER_FILE_ERROR_REPORTED:-}" ]; then
            printf '%s\n' "ERROR: Failed to write to log file" >&2
            printf '%s\n' "  Hint: Check file permissions, disk space, or if the log file was deleted" >&2
            LOGGER_FILE_ERROR_REPORTED="yes"
        fi

        # Print the original message to stderr to not lose it
        printf '%s\n' "$1" >&2
    }
    return 0
}

# Function to log messages with different severity levels (internal)
_log_message() {
    # Skip logging if message level is more verbose than current log level
    # With syslog-style levels, HIGHER values are LESS severe (more verbose)
    # force_show=true ($7) bypasses this filter (used by log_init to always show)
    if [ "${7:-false}" != "true" ] && [ "$2" -gt "$CURRENT_LOG_LEVEL" ] 2>/dev/null; then
        return 0
    fi

    # The *_into helpers return results in global variables. Restoring them afterwards means:
    #   * a trap handler that logs while another message is in progress cannot replace it
    #   * no message text, including log_sensitive text, stays in the shell's variables
    local saved_text="$_LOGGER_TEXT"
    local saved_timestamp="$_LOGGER_TIMESTAMP"
    local saved_replaced="$_LOGGER_REPLACED"
    local saved_prefix="$_LOGGER_PREFIX"
    local saved_integer="$_LOGGER_INTEGER"
    local saved_text_length="$_LOGGER_TEXT_LENGTH"
    local saved_color="$_LOGGER_COLOR"
    local saved_priority="$_LOGGER_PRIORITY"
    local write_status=0

    _write_log_message "$@" || write_status=$?

    _LOGGER_TEXT="$saved_text"
    _LOGGER_TIMESTAMP="$saved_timestamp"
    _LOGGER_REPLACED="$saved_replaced"
    _LOGGER_PREFIX="$saved_prefix"
    _LOGGER_INTEGER="$saved_integer"
    _LOGGER_TEXT_LENGTH="$saved_text_length"
    _LOGGER_COLOR="$saved_color"
    _LOGGER_PRIORITY="$saved_priority"
    return "$write_status"
}

# Write one message to the console, log file and journal (internal)
_write_log_message() {
    local level_name="$1"
    local level_value="$2"
    local message="$3"
    local skip_file="${4:-false}"
    local skip_journal="${5:-false}"
    local force_journal="${6:-false}"

    # The helpers below set _LOGGER_TEXT instead of printing, so no subshell is started
    # for each step of every message

    # Sanitize message to prevent log injection via control characters
    _sanitize_log_message_into "$message"
    local sanitized_message="$_LOGGER_TEXT"

    _truncate_log_message_into "$sanitized_message" "$LOG_MAX_LINE_LENGTH"
    local console_message="$_LOGGER_TEXT"

    # Format the log entry
    _format_log_message_into "$level_name" "$console_message"
    local log_entry="$_LOGGER_TEXT"

    # If CONSOLE_LOG is true, print to console
    if [ "$CONSOLE_LOG" = "true" ]; then
        _log_to_console "$log_entry" "$level_name" "$level_value"
    fi

    # If LOG_FILE is set and not empty, append to the log file (without colors)
    # Skip writing to the file if skip_file is true
    if [ -n "$LOG_FILE" ] && [ "$skip_file" != "true" ]; then
        _append_to_log_file "${log_entry}"
    fi

    # If journal logging is enabled or force_journal is true, log to the system journal.
    # skip_journal takes precedence — it overrides force_journal when true.
    if [ "$skip_journal" != "true" ] \
        && { [ "$USE_JOURNAL" = "true" ] || [ "$force_journal" = "true" ]; }; then
        # Map our log level to syslog priority
        _get_syslog_priority_into "$level_value"
        local syslog_priority="$_LOGGER_PRIORITY"

        # Use the logger command to send to syslog/journal
        # Strip any ANSI color codes from the message
        _truncate_log_message_into "$sanitized_message" "$LOG_MAX_JOURNAL_LENGTH"
        _strip_ansi_codes_into "$_LOGGER_TEXT"
        local plain_message="$_LOGGER_TEXT"

        # Pass force_when_disabled=true when force_journal=true and USE_JOURNAL=false so
        # _write_to_journal does not short-circuit the write.
        local write_forced="false"
        if [ "$force_journal" = "true" ] && [ "$USE_JOURNAL" != "true" ]; then
            write_forced="true"
        fi
        # The journal write status is the function's status, as before
        _write_to_journal "$syslog_priority" "${JOURNAL_TAG:-$SCRIPT_NAME}" "$plain_message" "$write_forced"
        return
    fi
    return 0
}

# Helper functions for different log levels
log_debug() {
    _log_message "DEBUG" "$LOG_LEVEL_DEBUG" "$1"
}

log_info() {
    _log_message "INFO" "$LOG_LEVEL_INFO" "$1"
}

log_notice() {
    _log_message "NOTICE" "$LOG_LEVEL_NOTICE" "$1"
}

log_warn() {
    _log_message "WARN" "$LOG_LEVEL_WARN" "$1"
}

log_error() {
    _log_message "ERROR" "$LOG_LEVEL_ERROR" "$1"
}

log_critical() {
    _log_message "CRITICAL" "$LOG_LEVEL_CRITICAL" "$1"
}

log_alert() {
    _log_message "ALERT" "$LOG_LEVEL_ALERT" "$1"
}

log_emergency() {
    _log_message "EMERGENCY" "$LOG_LEVEL_EMERGENCY" "$1"
}

# Alias for backward compatibility
log_fatal() {
    _log_message "FATAL" "$LOG_LEVEL_EMERGENCY" "$1"
}

log_init() {
    _log_message "INIT" "$LOG_LEVEL_INIT" "$1" "false" "false" "false" "true"
}

# Function for sensitive logging - console only, never to file or journal
log_sensitive() {
    _log_message "SENSITIVE" "$LOG_LEVEL_INFO" "$1" "true" "true"
}

# Log a single message directly to the system journal, regardless of USE_JOURNAL state.
# Respects the current log level, sanitization, and truncation rules.
# If the logger command is not available, emits a warning to stderr.
#
# Usage: log_to_journal LEVEL MESSAGE
#
# Parameters:
#   LEVEL   - Log level name (DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY)
#   MESSAGE - The message to log
#
# Returns:
#   0 - Success
#   1 - Invalid level or logger not available
log_to_journal() {
    if [ $# -lt 2 ]; then
        printf '%s\n' "Usage: log_to_journal LEVEL MESSAGE" >&2
        return 1
    fi

    local level_name=""
    level_name="$(printf '%s' "$1" | LC_ALL=C tr '[:lower:]' '[:upper:]')"
    shift
    local message="$*"

    # Validate and normalise the level name to the canonical form used by _log_message
    local canonical_level=""
    case "${level_name}" in
        DEBUG)                  canonical_level="DEBUG" ;;
        INFO)                   canonical_level="INFO" ;;
        NOTICE)                 canonical_level="NOTICE" ;;
        WARN|WARNING)           canonical_level="WARN" ;;
        ERROR|ERR)              canonical_level="ERROR" ;;
        CRITICAL|CRIT)          canonical_level="CRITICAL" ;;
        ALERT)                  canonical_level="ALERT" ;;
        EMERGENCY|EMERG|FATAL)  canonical_level="EMERGENCY" ;;
        [0-7])
            # Numeric syslog level — resolve to its canonical name
            canonical_level=$(_get_log_level_name "${level_name}")
            ;;
        *)
            printf '%s\n' "Error: log_to_journal: unrecognised level '$level_name'" >&2
            printf '%s\n' "  Valid levels: DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY (or 0-7)" >&2
            return 1
            ;;
    esac

    local level_value=""
    level_value=$(_get_log_level_value "$canonical_level")

    # Short-circuit: silently suppress messages that fall below the current log level,
    # matching the behaviour of all other log functions — no warning, no discovery.
    if [ "$level_value" -gt "$CURRENT_LOG_LEVEL" ]; then
        return 0
    fi

    # Fast-path: skip discovery only when LOGGER_PATH is already set (a prior successful
    # discovery locked the path as readonly). If LOGGER_PATH is empty — regardless of
    # whether _LOGGER_DISCOVERY_DONE is true — retry discovery so that logger becoming
    # available mid-session (installed, PATH corrected, etc.) is handled correctly.
    if [ "$_LOGGER_DISCOVERY_DONE" != "true" ] || [ -z "$LOGGER_PATH" ]; then
        check_logger_available
    fi

    # Abort before any writes if logger is still unavailable after attempted discovery.
    if [ -z "$LOGGER_PATH" ] || [ ! -x "$LOGGER_PATH" ]; then
        # Mirror _write_to_journal: only warn once to avoid noisy stderr spam when
        # logger is missing or untrusted. Subsequent calls still fail but stay quiet.
        if [ -z "${LOGGER_JOURNAL_ERROR_REPORTED:-}" ]; then
            printf '%s\n' "WARNING: log_to_journal called but logger command is not available" >&2
            LOGGER_JOURNAL_ERROR_REPORTED="yes"
        fi
        return 1
    fi

    _log_message "$canonical_level" "$level_value" "$message" "false" "false" "true"
}

# Only execute initialization if this script is being run directly
# If it's being sourced, the sourcing script should call init_logger
# POSIX sh has no reliable way to tell, so this check only runs in bash.
# BASH_SOURCE is only read in bash
# shellcheck disable=SC3028,SC3054
if [ "$_LOGGER_SHELL_FAMILY" = "bash" ] && [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    printf '%s\n' "This script is designed to be sourced by other scripts, not executed directly."
    printf '%s\n' "Usage: source logging.sh"
    exit 1
fi