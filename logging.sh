#!/usr/bin/env bash
#
# logging.sh - Reusable Bash Logging Module
#
# Repository: https://github.com/GingerGraham/bash-logger
#
# License: MIT License
#
# shellcheck disable=SC2034
# Note: SC2034 (unused variable) is disabled because this script is designed to be
# sourced by other scripts. Variables like LOG_LEVEL_FATAL, LOG_CONFIG_FILE, VERBOSE,
# and current_section are intentionally exported for external use or future features.
#
# Quick usage: source logging.sh && init_logger [options]
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
#
#   Runtime Configuration:
#     - set_log_level <level>           : Change log level dynamically
#     - set_log_format <format>         : Change message format
#     - set_script_name <name>          : Change script name in log messages
#     - set_timezone_utc <true|false>   : Toggle UTC timestamps
#     - set_journal_logging <true|false>: Toggle system journal logging
#     - set_journal_tag <tag>           : Change journal tag
#     - set_color_mode <auto|always|never> : Change color output
#     - set_unsafe_allow_newlines <true|false> : Allow newlines in log messages (NOT RECOMMENDED)
#     - set_unsafe_allow_ansi_codes <true|false> : Allow ANSI codes in log messages (NOT RECOMMENDED)
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

# Version (updated by release workflow)
if [[ -z "${BASH_LOGGER_VERSION:-}" ]]; then
    readonly BASH_LOGGER_VERSION="1.3.0"
fi

# Log levels (following complete syslog standard - higher number = less severe)
LOG_LEVEL_EMERGENCY=0  # System is unusable (most severe)
LOG_LEVEL_ALERT=1      # Action must be taken immediately
LOG_LEVEL_CRITICAL=2   # Critical conditions
LOG_LEVEL_ERROR=3      # Error conditions
LOG_LEVEL_WARN=4       # Warning conditions
LOG_LEVEL_NOTICE=5     # Normal but significant conditions
LOG_LEVEL_INFO=6       # Informational messages
LOG_LEVEL_DEBUG=7      # Debug information (least severe)

# Aliases for backward compatibility
LOG_LEVEL_FATAL=$LOG_LEVEL_EMERGENCY  # Alias for EMERGENCY

# Default settings (these can be overridden by init_logger)
CONSOLE_LOG="true"
LOG_FILE=""
VERBOSE="false"
CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO
USE_UTC="false" # Set to true to use UTC time in logs

# Journal logging settings
USE_JOURNAL="false"
JOURNAL_TAG=""  # Tag for syslog/journal entries

# Color settings
USE_COLORS="auto"  # Can be "auto", "always", or "never"

# ANSI color codes (using $'...' syntax for literal escape characters)
COLOR_RESET=$'\e[0m'
COLOR_BLUE=$'\e[34m'
COLOR_GREEN=$'\e[32m'
COLOR_YELLOW=$'\e[33m'
COLOR_RED=$'\e[31m'
COLOR_RED_BOLD=$'\e[31;1m'
COLOR_WHITE_ON_RED=$'\e[37;41m'
COLOR_BOLD_WHITE_ON_RED=$'\e[1;37;41m'
COLOR_PURPLE=$'\e[35m'
COLOR_CYAN=$'\e[36m'

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

# Log line length limits (defense-in-depth against excessively large messages)
# Set to 0 to disable limits.
LOG_MAX_LINE_LENGTH=4096
LOG_MAX_JOURNAL_LENGTH=4096

# Function to detect terminal color support (internal)
_detect_color_support() {
    # Default to no colors if explicitly disabled
    if [[ -n "${NO_COLOR:-}" || "${CLICOLOR:-}" == "0" ]]; then
        return 1
    fi

    # Force colors if explicitly enabled
    if [[ "${CLICOLOR_FORCE:-}" == "1" ]]; then
        return 0
    fi

    # Check if stdout is a terminal
    if [[ ! -t 1 ]]; then
        return 1
    fi

    # Check color capabilities with tput if available
    if command -v tput >/dev/null 2>&1; then
        if [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
            return 0
        fi
    fi

    # Check TERM as fallback
    if [[ -n "${TERM:-}" && "${TERM:-}" != "dumb" ]]; then
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
            return $?
            ;;
    esac
}

# Function to determine if a log level should output to stderr (internal)
# Returns 0 (true) if the given level should go to stderr
_should_use_stderr() {
    local level_value="$1"
    # Lower number = more severe, so use stderr if level <= threshold
    [[ "$level_value" -le "$LOG_STDERR_LEVEL" ]]
}

# Check if logger command is available
check_logger_available() {
    command -v logger &>/dev/null
}

# Configuration file path (set by init_logger when using -c option)
LOG_CONFIG_FILE=""

# Parse an INI-style configuration file (internal)
# Usage: _parse_config_file "/path/to/config.ini"
# Returns 0 on success, 1 on error
# Config values are applied to global variables; CLI args can override them later
_parse_config_file() {
    local config_file="$1"

    # Validate file exists and is readable
    if [[ ! -f "$config_file" ]]; then
        echo "Error: Configuration file not found: $config_file" >&2
        return 1
    fi

    if [[ ! -r "$config_file" ]]; then
        echo "Error: Configuration file not readable: $config_file" >&2
        return 1
    fi

    local line_num=0
    local current_section=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))

        # Remove leading/trailing whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[#\;] ]] && continue

        # Handle section headers [section]
        if [[ "$line" =~ ^\[([^]]+)\]$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            continue
        fi

        # Parse key = value pairs
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # Trim whitespace from key and value
            key="${key#"${key%%[![:space:]]*}"}"
            key="${key%"${key##*[![:space:]]}"}"
            value="${value#"${value%%[![:space:]]*}"}"
            value="${value%"${value##*[![:space:]]}"}"

            # Remove surrounding quotes if present
            if [[ "$value" =~ ^\"(.*)\"$ ]] || [[ "$value" =~ ^\'(.*)\'$ ]]; then
                value="${BASH_REMATCH[1]}"
            fi

            # Apply configuration based on key (case-insensitive)
            case "${key,,}" in
                level|log_level)
                    CURRENT_LOG_LEVEL=$(_get_log_level_value "$value")
                    ;;
                format|log_format)
                    LOG_FORMAT="$value"
                    ;;
                log_file|logfile|file)
                    LOG_FILE="$value"
                    ;;
                journal|use_journal)
                    case "${value,,}" in
                        true|yes|1|on)
                            if check_logger_available; then
                                USE_JOURNAL="true"
                            else
                                echo "Warning: logger command not found, journal logging disabled (config line $line_num)" >&2
                            fi
                            ;;
                        false|no|0|off)
                            USE_JOURNAL="false"
                            ;;
                        *)
                            echo "Warning: Invalid journal value '$value' at line $line_num, expected true/false" >&2
                            ;;
                    esac
                    ;;
                tag|journal_tag)
                    JOURNAL_TAG="$value"
                    ;;
                utc|use_utc)
                    case "${value,,}" in
                        true|yes|1|on)
                            USE_UTC="true"
                            ;;
                        false|no|0|off)
                            USE_UTC="false"
                            ;;
                        *)
                            echo "Warning: Invalid utc value '$value' at line $line_num, expected true/false" >&2
                            ;;
                    esac
                    ;;
                color|colour|colors|colours|use_colors)
                    case "${value,,}" in
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
                            echo "Warning: Invalid color value '$value' at line $line_num, expected auto/always/never" >&2
                            ;;
                    esac
                    ;;
                stderr_level|stderr-level)
                    LOG_STDERR_LEVEL=$(_get_log_level_value "$value")
                    ;;
                quiet|console_log)
                    case "${key,,}" in
                        quiet)
                            # quiet=true means CONSOLE_LOG=false
                            case "${value,,}" in
                                true|yes|1|on)
                                    CONSOLE_LOG="false"
                                    ;;
                                false|no|0|off)
                                    CONSOLE_LOG="true"
                                    ;;
                                *)
                                    echo "Warning: Invalid quiet value '$value' at line $line_num, expected true/false" >&2
                                    ;;
                            esac
                            ;;
                        console_log)
                            case "${value,,}" in
                                true|yes|1|on)
                                    CONSOLE_LOG="true"
                                    ;;
                                false|no|0|off)
                                    CONSOLE_LOG="false"
                                    ;;
                                *)
                                    echo "Warning: Invalid console_log value '$value' at line $line_num, expected true/false" >&2
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
                    case "${value,,}" in
                        true|yes|1|on)
                            VERBOSE="true"
                            CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG
                            ;;
                        false|no|0|off)
                            VERBOSE="false"
                            ;;
                        *)
                            echo "Warning: Invalid verbose value '$value' at line $line_num, expected true/false" >&2
                            ;;
                    esac
                    ;;
                unsafe_allow_newlines|unsafe-allow-newlines)
                    case "${value,,}" in
                        true|yes|1|on)
                            LOG_UNSAFE_ALLOW_NEWLINES="true"
                            ;;
                        false|no|0|off)
                            LOG_UNSAFE_ALLOW_NEWLINES="false"
                            ;;
                        *)
                            echo "Warning: Invalid unsafe_allow_newlines value '$value' at line $line_num, expected true/false" >&2
                            ;;
                    esac
                    ;;
                unsafe_allow_ansi_codes|unsafe-allow-ansi-codes)
                    case "${value,,}" in
                        true|yes|1|on)
                            LOG_UNSAFE_ALLOW_ANSI_CODES="true"
                            ;;
                        false|no|0|off)
                            LOG_UNSAFE_ALLOW_ANSI_CODES="false"
                            ;;
                        *)
                            echo "Warning: Invalid unsafe_allow_ansi_codes value '$value' at line $line_num, expected true/false" >&2
                            ;;
                    esac
                    ;;
                max_line_length|max-line-length|log_max_line_length|log-max-line-length)
                    if [[ "$value" =~ ^[0-9]+$ ]]; then
                        LOG_MAX_LINE_LENGTH="$value"
                    else
                        echo "Warning: Invalid max_line_length value '$value' at line $line_num, expected non-negative integer" >&2
                    fi
                    ;;
                max_journal_length|max-journal-length|journal_max_length|journal-max-line-length)
                    if [[ "$value" =~ ^[0-9]+$ ]]; then
                        LOG_MAX_JOURNAL_LENGTH="$value"
                    else
                        echo "Warning: Invalid max_journal_length value '$value' at line $line_num, expected non-negative integer" >&2
                    fi
                    ;;
                *)
                    echo "Warning: Unknown configuration key '$key' at line $line_num" >&2
                    ;;
            esac
        else
            echo "Warning: Invalid syntax at line $line_num: $line" >&2
        fi
    done < "$config_file"

    LOG_CONFIG_FILE="$config_file"

    return 0
}

# Convert log level name to numeric value (internal)
_get_log_level_value() {
    local level_name="$1"
    case "${level_name^^}" in
        "DEBUG")
            echo $LOG_LEVEL_DEBUG
            ;;
        "INFO")
            echo $LOG_LEVEL_INFO
            ;;
        "NOTICE")
            echo $LOG_LEVEL_NOTICE
            ;;
        "WARN" | "WARNING")
            echo $LOG_LEVEL_WARN
            ;;
        "ERROR" | "ERR")
            echo $LOG_LEVEL_ERROR
            ;;
        "CRITICAL" | "CRIT")
            echo $LOG_LEVEL_CRITICAL
            ;;
        "ALERT")
            echo $LOG_LEVEL_ALERT
            ;;
        "EMERGENCY" | "EMERG" | "FATAL")
            echo $LOG_LEVEL_EMERGENCY
            ;;
        *)
            # If it's a number between 0-7 (valid syslog levels), use it directly
            if [[ "$level_name" =~ ^[0-7]$ ]]; then
                echo "$level_name"
            else
                # Default to INFO if invalid
                echo $LOG_LEVEL_INFO
            fi
            ;;
    esac
}

# Get log level name from numeric value (internal)
_get_log_level_name() {
    local level_value="$1"
    case "$level_value" in
        "$LOG_LEVEL_DEBUG")
            echo "DEBUG"
            ;;
        "$LOG_LEVEL_INFO")
            echo "INFO"
            ;;
        "$LOG_LEVEL_NOTICE")
            echo "NOTICE"
            ;;
        "$LOG_LEVEL_WARN")
            echo "WARN"
            ;;
        "$LOG_LEVEL_ERROR")
            echo "ERROR"
            ;;
        "$LOG_LEVEL_CRITICAL")
            echo "CRITICAL"
            ;;
        "$LOG_LEVEL_ALERT")
            echo "ALERT"
            ;;
        "$LOG_LEVEL_EMERGENCY")
            echo "EMERGENCY"
            ;;
        *)
            echo "UNKNOWN"
            ;;
    esac
}

# Gets the ANSI color codes for a level name (internal)
_get_log_level_color() {
    local level_name="$1"
    case "$level_name" in
        "DEBUG")
            echo "${COLOR_BLUE}"
            ;;
        "INFO")
            echo ""
            ;;
        "NOTICE")
            echo "${COLOR_GREEN}"
            ;;
        "WARN")
            echo "${COLOR_YELLOW}"
            ;;
        "ERROR")
            echo "${COLOR_RED}"
            ;;
        "CRITICAL")
            echo "${COLOR_RED_BOLD}"
            ;;
        "ALERT")
            echo "${COLOR_WHITE_ON_RED}"
            ;;
        "EMERGENCY"|"FATAL")
            echo "${COLOR_BOLD_WHITE_ON_RED}"
            ;;
        "INIT")
            echo "${COLOR_PURPLE}"
            ;;
        "SENSITIVE")
            echo "${COLOR_CYAN}"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Map log level to syslog priority (internal)
_get_syslog_priority() {
    local level_value="$1"
    case "$level_value" in
        "$LOG_LEVEL_DEBUG")
            echo "debug"
            ;;
        "$LOG_LEVEL_INFO")
            echo "info"
            ;;
        "$LOG_LEVEL_NOTICE")
            echo "notice"
            ;;
        "$LOG_LEVEL_WARN")
            echo "warning"
            ;;
        "$LOG_LEVEL_ERROR")
            echo "err"
            ;;
        "$LOG_LEVEL_CRITICAL")
            echo "crit"
            ;;
        "$LOG_LEVEL_ALERT")
            echo "alert"
            ;;
        "$LOG_LEVEL_EMERGENCY")
            echo "emerg"
            ;;
        *)
            echo "notice"  # Default to notice for unknown levels
            ;;
    esac
}

# Function to sanitize log messages to prevent log injection (internal)
# Removes control characters that could break log formats or inject fake entries
_strip_ansi_codes() {
    local input="$1"

    # If unsafe mode is enabled, skip ANSI stripping and return input as-is
    if [[ "$LOG_UNSAFE_ALLOW_ANSI_CODES" == "true" ]]; then
        echo "$input"
        return
    fi

    # Remove various ANSI escape sequences using multiple patterns
    # This approach removes ANSI codes that would otherwise manipulate terminal display

    # Remove CSI (Control Sequence Introducer) sequences: ESC [ ... letter
    # Includes color codes (\e[...m), cursor movement (\e[H), clearing (\e[2J), etc.
    # Pattern: \e[ followed by zero or more digits/semicolons, followed by a letter
    local step1
    # Use direct escapes to avoid quoting issues in patterns
    # shellcheck disable=SC1117
    step1=$(printf '%s' "$input" | sed 's/\x1b\[[0-9;]*[a-zA-Z@]//g')

    # Remove OSC (Operating System Command) sequences: ESC ] ... BEL/ST
    # Pattern: \e] followed by anything up to \a (BEL) or \e\\ (ST)
    local step2
    # shellcheck disable=SC1117
    step2=$(printf '%s' "$step1" | sed 's/\x1b\][^\x07]*\x07//g')

    # Remove remaining escape sequences with specific patterns
    # This intentionally targets known dangerous escape sequences:
    # - \x1b followed by a single letter (e.g., \x1bM, \x1b7, \x1b8)
    # - \x1b followed by other non-CSI/non-OSC patterns
    # Pattern matches ESC + single char that's not '[' or ']' (already handled above)
    local step3
    # shellcheck disable=SC1117
    step3=$(printf '%s' "$step2" | sed 's/\x1b[^\[\]]//g')

    echo "$step3"
}

# Function to sanitize log messages to prevent log injection (internal)
# Removes control characters that could break log formats or inject fake entries
_sanitize_log_message() {
    local message="$1"

    # Sanitize newlines unless unsafe newline mode is enabled
    # Control each unsafe mode independently to prevent unintended security bypasses
    if [[ "$LOG_UNSAFE_ALLOW_NEWLINES" != "true" ]]; then
        # Replace control characters with spaces to prevent log injection
        # These characters can break log formats and enable log injection attacks
        message="${message//$'\n'/ }"   # newline (LF)
        message="${message//$'\r'/ }"   # carriage return (CR)
        message="${message//$'\t'/ }"   # tab (HT)
        # Uncomment the line below if form feed characters should also be sanitized
        # message="${message//$'\f'/ }"   # form feed (FF)
    fi

    # Strip ANSI codes unless unsafe ANSI mode is enabled
    # This is independent of newline sanitization
    message=$(_strip_ansi_codes "$message")

    echo "$message"
}

# Truncate log messages to a maximum length (internal)
_truncate_log_message() {
    local message="$1"
    local limit="$2"
    local suffix="...[truncated]"

    if [[ -z "$limit" ]]; then
        echo "$message"
        return
    fi

    if [[ ! "$limit" =~ ^[0-9]+$ ]]; then
        echo "$message"
        return
    fi

    if [[ "$limit" -le 0 ]]; then
        echo "$message"
        return
    fi

    if [[ ${#message} -le $limit ]]; then
        echo "$message"
        return
    fi

    if [[ $limit -le ${#suffix} ]]; then
        echo "${message:0:$limit}"
        return
    fi

    local keep_length=$((limit - ${#suffix}))
    echo "${message:0:$keep_length}${suffix}"
}

# Function to sanitize script names to prevent shell metacharacter injection (internal)
# Replaces any character that is not alphanumeric, period, underscore, or hyphen with underscore
# This is a defense-in-depth measure to prevent potential injection attacks via crafted filenames
_sanitize_script_name() {
    local name="$1"
    # Replace any character that's not alphanumeric, period, underscore, or hyphen
    # with an underscore to prevent shell metacharacter injection
    name="${name//[^a-zA-Z0-9._-]/_}"
    echo "$name"
}

# Function to format log message (internal)
_format_log_message() {
    local level_name="$1"
    local message="$2"

    # Get timestamp in appropriate timezone
    local current_date
    local timezone_str
    if [[ "$USE_UTC" == "true" ]]; then
        current_date=$(date -u '+%Y-%m-%d %H:%M:%S')  # UTC time
        timezone_str="UTC"
    else
        current_date=$(date '+%Y-%m-%d %H:%M:%S')     # Local time
        timezone_str="LOCAL"
    fi

    # Replace format variables - zsh compatible method
    local formatted_message="$LOG_FORMAT"
    # Handle % escaping for zsh compatibility
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        # In zsh, we need a different approach
        formatted_message=${formatted_message:gs/%d/$current_date}
        formatted_message=${formatted_message:gs/%l/$level_name}
        formatted_message=${formatted_message:gs/%s/${SCRIPT_NAME:-unknown}}
        formatted_message=${formatted_message:gs/%m/$message}
        formatted_message=${formatted_message:gs/%z/$timezone_str}
    else
        # Bash version
        formatted_message="${formatted_message//%d/$current_date}"
        formatted_message="${formatted_message//%l/$level_name}"
        formatted_message="${formatted_message//%s/${SCRIPT_NAME:-unknown}}"
        formatted_message="${formatted_message//%m/$message}"
        formatted_message="${formatted_message//%z/$timezone_str}"
    fi

    echo "$formatted_message"
}

# Function to initialize logger with custom settings
init_logger() {
    # Get the calling script's name (can be overridden with -n|--name option)
    local caller_script
    if [[ -n "${BASH_SOURCE[1]:-}" ]]; then
        caller_script=$(basename "${BASH_SOURCE[1]}")
        # Sanitize to prevent shell metacharacter injection
        caller_script=$(_sanitize_script_name "$caller_script")
    else
        caller_script="unknown"
    fi

    # Variable to hold custom script name if provided
    local custom_script_name=""

    # First pass: look for config file option and process it first
    # This allows CLI arguments to override config file values
    local args=("$@")
    local i=0
    while [[ $i -lt ${#args[@]} ]]; do
        case "${args[$i]}" in
            -c|--config)
                local config_file="${args[$((i+1))]}"
                if [[ -z "$config_file" ]]; then
                    echo "Error: --config requires a file path argument" >&2
                    return 1
                fi
                if ! _parse_config_file "$config_file"; then
                    return 1
                fi
                break
                ;;
        esac
        ((i++))
    done

    # Second pass: parse all command line arguments (overrides config file)
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -c|--config)
                # Already processed in first pass, skip
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
                local level_value
                level_value=$(_get_log_level_value "$2")
                CURRENT_LOG_LEVEL=$level_value
                # If both --verbose and --level are specified, --level takes precedence
                shift 2
                ;;
            -f|--format)
                LOG_FORMAT="$2"
                shift 2
                ;;
            -j|--journal)
                if check_logger_available; then
                    USE_JOURNAL="true"
                else
                    echo "Warning: logger command not found, journal logging disabled" >&2
                fi
                shift
                ;;
            -l|--log|--logfile|--log-file|--file)
                LOG_FILE="$2"
                shift 2
                ;;
            -n|--name|--script-name)
                # Sanitize to prevent shell metacharacter injection
                custom_script_name=$(_sanitize_script_name "$2")
                shift 2
                ;;
            -q|--quiet)
                CONSOLE_LOG="false"
                shift
                ;;
            -t|--tag)
                JOURNAL_TAG="$2"
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
                local stderr_level_value
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
                if [[ -z "${2:-}" ]]; then
                    echo "Error: --max-line-length requires a value" >&2
                    return 1
                fi
                if [[ "$2" =~ ^[0-9]+$ ]]; then
                    LOG_MAX_LINE_LENGTH="$2"
                else
                    echo "Warning: Invalid max-line-length value '$2', expected non-negative integer" >&2
                fi
                shift 2
                ;;
            --max-journal-length)
                if [[ -z "${2:-}" ]]; then
                    echo "Error: --max-journal-length requires a value" >&2
                    return 1
                fi
                if [[ "$2" =~ ^[0-9]+$ ]]; then
                    LOG_MAX_JOURNAL_LENGTH="$2"
                else
                    echo "Warning: Invalid max-journal-length value '$2', expected non-negative integer" >&2
                fi
                shift 2
                ;;
            *)
                echo "Unknown parameter for logger: $1" >&2
                return 1
                ;;
        esac
    done

    # Set a global variable for the script name to use in log messages
    # Priority: CLI option > config file > auto-detected caller script
    if [[ -n "$custom_script_name" ]]; then
        # CLI option takes highest priority
        SCRIPT_NAME="$custom_script_name"
    elif [[ -z "${SCRIPT_NAME:-}" ]]; then
        # Only use auto-detected name if not already set (e.g., by config file)
        SCRIPT_NAME="$caller_script"
    fi
    # If SCRIPT_NAME was set by config file, keep that value

    # Set default journal tag if not specified but journal logging is enabled
    if [[ "$USE_JOURNAL" == "true" && -z "$JOURNAL_TAG" ]]; then
        JOURNAL_TAG="$SCRIPT_NAME"
    fi

    # Validate log file path if specified
    if [[ -n "$LOG_FILE" ]]; then
        # Get directory of log file
        LOG_DIR=$(dirname "$LOG_FILE")

        # Try to create directory if it doesn't exist
        if [[ ! -d "$LOG_DIR" ]]; then
            mkdir -p "$LOG_DIR" 2>/dev/null || {
                echo "Error: Cannot create log directory '$LOG_DIR'" >&2
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
        if [[ -L "$LOG_FILE" ]]; then
            echo "Error: Log file path is a symbolic link" >&2
            return 1
        fi

        # Check if file exists (may not have been created due to permissions)
        # This provides clearer error messaging than the regular file check alone
        if [[ ! -e "$LOG_FILE" ]]; then
            echo "Error: Cannot create log file '$LOG_FILE' (check directory permissions)" >&2
            return 1
        fi

        # Verify it's a regular file, not a device or other special file
        if [[ ! -f "$LOG_FILE" ]]; then
            echo "Error: Log file exists but is not a regular file (may be a directory or device)" >&2
            return 1
        fi

        # Verify file is writable
        if [[ ! -w "$LOG_FILE" ]]; then
            echo "Error: Log file '$LOG_FILE' is not writable" >&2
            return 1
        fi

        # Write the initialization message using the same format
        local init_message
        init_message=$(_format_log_message "INIT" "Logger initialized by $caller_script")
        echo "$init_message" >> "$LOG_FILE" 2>/dev/null || {
            echo "Error: Failed to write test message to log file" >&2
            return 1
        }

        echo "Logger: Successfully initialized with log file at '$LOG_FILE'" >&2
    fi

    # Log initialization success
    log_debug "Logger initialized with script_name='$SCRIPT_NAME': console=$CONSOLE_LOG, file=$LOG_FILE, journal=$USE_JOURNAL, colors=$USE_COLORS, log level=$(_get_log_level_name "$CURRENT_LOG_LEVEL"), stderr level=$(_get_log_level_name "$LOG_STDERR_LEVEL"), format=\"$LOG_FORMAT\""
    return 0
}

# Function to change log level after initialization
set_log_level() {
    local level="$1"
    local old_level
    old_level=$(_get_log_level_name "$CURRENT_LOG_LEVEL")
    CURRENT_LOG_LEVEL=$(_get_log_level_value "$level")
    local new_level
    new_level=$(_get_log_level_name "$CURRENT_LOG_LEVEL")

    # Create a special log entry that bypasses level checks
    local message="Log level changed from $old_level to $new_level"
    local log_entry
    log_entry=$(_format_log_message "CONFIG" "$message")

    # Always print to console if enabled
    if [[ "$CONSOLE_LOG" == "true" ]]; then
        if _should_use_colors; then
            echo -e "${COLOR_PURPLE}${log_entry}${COLOR_RESET}"
        else
            echo "${log_entry}"
        fi
    fi

    # Always write to log file if set
    if [[ -n "$LOG_FILE" ]]; then
        echo "${log_entry}" >> "$LOG_FILE" 2>/dev/null
    fi

    # Always log to journal if enabled
    if [[ "$USE_JOURNAL" == "true" ]]; then
        logger -p "daemon.notice" -t "${JOURNAL_TAG:-$SCRIPT_NAME}" "CONFIG: $message"
    fi
}

set_timezone_utc() {
    local use_utc="$1"
    local old_setting="$USE_UTC"
    USE_UTC="$use_utc"

    local message="Timezone setting changed from $old_setting to $USE_UTC"
    local log_entry
    log_entry=$(_format_log_message "CONFIG" "$message")

    # Always print to console if enabled
    if [[ "$CONSOLE_LOG" == "true" ]]; then
        if _should_use_colors; then
            echo -e "${COLOR_PURPLE}${log_entry}${COLOR_RESET}"
        else
            echo "${log_entry}"
        fi
    fi

    # Always write to log file if set
    if [[ -n "$LOG_FILE" ]]; then
        echo "${log_entry}" >> "$LOG_FILE" 2>/dev/null
    fi

    # Always log to journal if enabled
    if [[ "$USE_JOURNAL" == "true" ]]; then
        logger -p "daemon.notice" -t "${JOURNAL_TAG:-$SCRIPT_NAME}" "CONFIG: $message"
    fi
}

# Function to change log format
set_log_format() {
    local old_format="$LOG_FORMAT"
    LOG_FORMAT="$1"

    local message="Log format changed from \"$old_format\" to \"$LOG_FORMAT\""
    local log_entry
    log_entry=$(_format_log_message "CONFIG" "$message")

    # Always print to console if enabled
    if [[ "$CONSOLE_LOG" == "true" ]]; then
        if _should_use_colors; then
            echo -e "${COLOR_PURPLE}${log_entry}${COLOR_RESET}"
        else
            echo "${log_entry}"
        fi
    fi

    # Always write to log file if set
    if [[ -n "$LOG_FILE" ]]; then
        echo "${log_entry}" >> "$LOG_FILE" 2>/dev/null
    fi

    # Always log to journal if enabled
    if [[ "$USE_JOURNAL" == "true" ]]; then
        logger -p "daemon.notice" -t "${JOURNAL_TAG:-$SCRIPT_NAME}" "CONFIG: $message"
    fi
}

# Function to toggle journal logging
set_journal_logging() {
    local old_setting="$USE_JOURNAL"
    USE_JOURNAL="$1"

    # Check if logger is available when enabling
    if [[ "$USE_JOURNAL" == "true" ]]; then
        if ! check_logger_available; then
            echo "Error: logger command not found, cannot enable journal logging" >&2
            USE_JOURNAL="$old_setting"
            return 1
        fi
    fi

    local message="Journal logging changed from $old_setting to $USE_JOURNAL"
    local log_entry
    log_entry=$(_format_log_message "CONFIG" "$message")

    # Always print to console if enabled
    if [[ "$CONSOLE_LOG" == "true" ]]; then
        if _should_use_colors; then
            echo -e "${COLOR_PURPLE}${log_entry}${COLOR_RESET}"
        else
            echo "${log_entry}"
        fi
    fi

    # Always write to log file if set
    if [[ -n "$LOG_FILE" ]]; then
        echo "${log_entry}" >> "$LOG_FILE" 2>/dev/null
    fi

    # Log to journal if it was previously enabled or just being enabled
    if [[ "$old_setting" == "true" || "$USE_JOURNAL" == "true" ]]; then
        logger -p "daemon.notice" -t "${JOURNAL_TAG:-$SCRIPT_NAME}" "CONFIG: $message"
    fi
}

# Function to set journal tag
set_journal_tag() {
    local old_tag="$JOURNAL_TAG"
    JOURNAL_TAG="$1"

    local message="Journal tag changed from \"$old_tag\" to \"$JOURNAL_TAG\""
    local log_entry
    log_entry=$(_format_log_message "CONFIG" "$message")

    # Always print to console if enabled
    if [[ "$CONSOLE_LOG" == "true" ]]; then
        if _should_use_colors; then
            echo -e "${COLOR_PURPLE}${log_entry}${COLOR_RESET}"
        else
            echo "${log_entry}"
        fi
    fi

    # Always write to log file if set
    if [[ -n "$LOG_FILE" ]]; then
        echo "${log_entry}" >> "$LOG_FILE" 2>/dev/null
    fi

    # Log to journal if enabled, using the old tag
    if [[ "$USE_JOURNAL" == "true" ]]; then
        logger -p "daemon.notice" -t "${old_tag:-$SCRIPT_NAME}" "CONFIG: Journal tag changing to \"$JOURNAL_TAG\""
    fi
}

# Function to set color mode
set_color_mode() {
    local mode="$1"
    local old_setting="$USE_COLORS"

    case "$mode" in
        true|on|yes|1)
            USE_COLORS="always"
            ;;
        false|off|no|0)
            USE_COLORS="never"
            ;;
        auto)
            USE_COLORS="auto"
            ;;
        *)
            USE_COLORS="$mode"  # Set directly if it's already "always", "never", or "auto"
            ;;
    esac

    local message="Color mode changed from \"$old_setting\" to \"$USE_COLORS\""
    local log_entry
    log_entry=$(_format_log_message "CONFIG" "$message")

    # Always print to console if enabled
    if [[ "$CONSOLE_LOG" == "true" ]]; then
        if _should_use_colors; then
            echo -e "${COLOR_PURPLE}${log_entry}${COLOR_RESET}"
        else
            echo "${log_entry}"
        fi
    fi

    # Always write to log file if set
    if [[ -n "$LOG_FILE" ]]; then
        echo "${log_entry}" >> "$LOG_FILE" 2>/dev/null
    fi

    # Log to journal if enabled
    if [[ "$USE_JOURNAL" == "true" ]]; then
        logger -p "daemon.notice" -t "${JOURNAL_TAG:-$SCRIPT_NAME}" "CONFIG: $message"
    fi
}

# Function to set script name dynamically
set_script_name() {
    local old_name="$SCRIPT_NAME"
    # Sanitize to prevent shell metacharacter injection
    SCRIPT_NAME=$(_sanitize_script_name "$1")

    local message="Script name changed from \"$old_name\" to \"$SCRIPT_NAME\""
    local log_entry
    log_entry=$(_format_log_message "CONFIG" "$message")

    # Always print to console if enabled
    if [[ "$CONSOLE_LOG" == "true" ]]; then
        if _should_use_colors; then
            echo -e "${COLOR_PURPLE}${log_entry}${COLOR_RESET}"
        else
            echo "${log_entry}"
        fi
    fi

    # Always write to log file if set
    if [[ -n "$LOG_FILE" ]]; then
        echo "${log_entry}" >> "$LOG_FILE" 2>/dev/null
    fi

    # Always log to journal if enabled
    if [[ "$USE_JOURNAL" == "true" ]]; then
        logger -p "daemon.notice" -t "${JOURNAL_TAG:-$SCRIPT_NAME}" "CONFIG: $message"
    fi
}

# Function to enable/disable unsafe mode for newlines in log messages
# WARNING: Disabling sanitization can allow log injection attacks. Only use if you have
#          explicit control over all logged messages and your log parsing handles newlines safely.
set_unsafe_allow_newlines() {
    local old_setting="$LOG_UNSAFE_ALLOW_NEWLINES"
    LOG_UNSAFE_ALLOW_NEWLINES="$1"

    local safety_notice=""
    if [[ "$LOG_UNSAFE_ALLOW_NEWLINES" == "true" ]]; then
        safety_notice=" (WARNING: Log injection protection is disabled)"
    fi

    local message="Unsafe newline mode changed from $old_setting to $LOG_UNSAFE_ALLOW_NEWLINES$safety_notice"
    local log_entry
    log_entry=$(_format_log_message "CONFIG" "$message")

    # Always print to console if enabled
    if [[ "$CONSOLE_LOG" == "true" ]]; then
        # Use warning color if enabling unsafe mode
        if [[ "$LOG_UNSAFE_ALLOW_NEWLINES" == "true" ]]; then
            if _should_use_colors; then
                echo -e "${COLOR_RED}${log_entry}${COLOR_RESET}"
            else
                echo "${log_entry}"
            fi
        else
            if _should_use_colors; then
                echo -e "${COLOR_PURPLE}${log_entry}${COLOR_RESET}"
            else
                echo "${log_entry}"
            fi
        fi
    fi

    # Always write to log file if set
    if [[ -n "$LOG_FILE" ]]; then
        echo "${log_entry}" >> "$LOG_FILE" 2>/dev/null
    fi

    # Always log to journal if enabled
    if [[ "$USE_JOURNAL" == "true" ]]; then
        logger -p "daemon.notice" -t "${JOURNAL_TAG:-$SCRIPT_NAME}" "CONFIG: $message"
    fi
}

# Function to enable/disable unsafe mode for ANSI codes in log messages
# WARNING: Disabling sanitization can allow terminal manipulation attacks. Only use if you have
#          explicit control over all logged messages and trust their source.
set_unsafe_allow_ansi_codes() {
    local old_setting="$LOG_UNSAFE_ALLOW_ANSI_CODES"
    LOG_UNSAFE_ALLOW_ANSI_CODES="$1"

    local safety_notice=""
    if [[ "$LOG_UNSAFE_ALLOW_ANSI_CODES" == "true" ]]; then
        safety_notice=" (WARNING: ANSI code injection protection is disabled)"
    fi

    local message="Unsafe ANSI codes mode changed from $old_setting to $LOG_UNSAFE_ALLOW_ANSI_CODES$safety_notice"
    local log_entry
    log_entry=$(_format_log_message "CONFIG" "$message")

    # Always print to console if enabled
    if [[ "$CONSOLE_LOG" == "true" ]]; then
        # Use warning color if enabling unsafe mode
        if [[ "$LOG_UNSAFE_ALLOW_ANSI_CODES" == "true" ]]; then
            if _should_use_colors; then
                echo -e "${COLOR_RED}${log_entry}${COLOR_RESET}"
            else
                echo "${log_entry}"
            fi
        else
            if _should_use_colors; then
                echo -e "${COLOR_PURPLE}${log_entry}${COLOR_RESET}"
            else
                echo "${log_entry}"
            fi
        fi
    fi

    # Always write to log file if set
    if [[ -n "$LOG_FILE" ]]; then
        echo "${log_entry}" >> "$LOG_FILE" 2>/dev/null
    fi

    # Always log to journal if enabled
    if [[ "$USE_JOURNAL" == "true" ]]; then
        logger -p "daemon.notice" -t "${JOURNAL_TAG:-$SCRIPT_NAME}" "CONFIG: $message"
    fi
}

# Logs to console (internal)
_log_to_console() {
    local log_entry="$1"
    local level_name="$2"
    local level_value="$3"

    local use_stderr=false
    if _should_use_stderr "$level_value"; then
        use_stderr=true
    fi

    local output="${log_entry}"

    if _should_use_colors; then
        local log_color
        log_color=$(_get_log_level_color "$level_name")
        output="${log_color}${output}${COLOR_RESET}"
    fi

    if [[ "$use_stderr" == true ]]; then
        echo -e "${output}" >&2 # Log to stderr
    else
        echo -e "${output}"
    fi
}

# Function to log messages with different severity levels (internal)
_log_message() {
    local level_name="$1"
    local level_value="$2"
    local message="$3"
    local skip_file="${4:-false}"
    local skip_journal="${5:-false}"

    # Skip logging if message level is more verbose than current log level
    # With syslog-style levels, HIGHER values are LESS severe (more verbose)
    if [[ "$level_value" -gt "$CURRENT_LOG_LEVEL" ]]; then
        return
    fi

    # Sanitize message to prevent log injection via control characters
    local sanitized_message
    sanitized_message=$(_sanitize_log_message "$message")

    local console_message
    console_message=$(_truncate_log_message "$sanitized_message" "$LOG_MAX_LINE_LENGTH")

    # Format the log entry
    local log_entry
    log_entry=$(_format_log_message "$level_name" "$console_message")

    # If CONSOLE_LOG is true, print to console
    if [[ "$CONSOLE_LOG" == "true" ]]; then
        _log_to_console "$log_entry" "$level_name" "$level_value"
    fi

    # If LOG_FILE is set and not empty, append to the log file (without colors)
    # Skip writing to the file if skip_file is true
    if [[ -n "$LOG_FILE" && "$skip_file" != "true" ]]; then
        echo "${log_entry}" >> "$LOG_FILE" 2>/dev/null || {
            # Only print the error once to avoid spam
            if [[ -z "$LOGGER_FILE_ERROR_REPORTED" ]]; then
                echo "ERROR: Failed to write to log file: $LOG_FILE" >&2
                LOGGER_FILE_ERROR_REPORTED="yes"
            fi

            # Print the original message to stderr to not lose it
            echo "${log_entry}" >&2
        }
    fi

    # If journal logging is enabled and logger is available, log to the system journal
    # Skip journal logging if skip_journal is true
    if [[ "$USE_JOURNAL" == "true" && "$skip_journal" != "true" ]]; then
        if check_logger_available; then
            # Map our log level to syslog priority
            local syslog_priority
            syslog_priority=$(_get_syslog_priority "$level_value")

            # Use the logger command to send to syslog/journal
            # Strip any ANSI color codes from the message
            local journal_message
            journal_message=$(_truncate_log_message "$sanitized_message" "$LOG_MAX_JOURNAL_LENGTH")
            local plain_message
            plain_message=$(_strip_ansi_codes "$journal_message")
            logger -p "daemon.${syslog_priority}" -t "${JOURNAL_TAG:-$SCRIPT_NAME}" "$plain_message"
        fi
    fi
}

# Helper functions for different log levels
log_debug() {
    _log_message "DEBUG" $LOG_LEVEL_DEBUG "$1"
}

log_info() {
    _log_message "INFO" $LOG_LEVEL_INFO "$1"
}

log_notice() {
    _log_message "NOTICE" $LOG_LEVEL_NOTICE "$1"
}

log_warn() {
    _log_message "WARN" $LOG_LEVEL_WARN "$1"
}

log_error() {
    _log_message "ERROR" $LOG_LEVEL_ERROR "$1"
}

log_critical() {
    _log_message "CRITICAL" $LOG_LEVEL_CRITICAL "$1"
}

log_alert() {
    _log_message "ALERT" $LOG_LEVEL_ALERT "$1"
}

log_emergency() {
    _log_message "EMERGENCY" $LOG_LEVEL_EMERGENCY "$1"
}

# Alias for backward compatibility
log_fatal() {
    _log_message "FATAL" $LOG_LEVEL_EMERGENCY "$1"
}

log_init() {
    _log_message "INIT" -1 "$1"  # Using -1 to ensure it always shows
}

# Function for sensitive logging - console only, never to file or journal
log_sensitive() {
    _log_message "SENSITIVE" $LOG_LEVEL_INFO "$1" "true" "true"
}

# Only execute initialization if this script is being run directly
# If it's being sourced, the sourcing script should call init_logger
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is designed to be sourced by other scripts, not executed directly."
    echo "Usage: source logging.sh"
    exit 1
fi