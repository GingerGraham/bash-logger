# shellcheck shell=sh
# shellcheck disable=SC2034  # the settings reset here are read by logging.sh
#
# validator_driver.sh - Run the logging.sh validators over an input corpus (Issue #143)
#
# Usage: <shell> validator_driver.sh <logging.sh> <corpus file> [check...]
#
# Written in POSIX sh so the same driver runs in every shell under test.
#
# Corpus format: one input per line, "<id><TAB><encoded>". <encoded> is a printf
# format string in which every byte other than A-Z, a-z and 0-9 is written as a
# three-digit octal escape (\ooo), so any byte except NUL can be stored on one line.
#
# Output: one line per check and input:
#   <check><TAB><id><TAB><status><TAB><cksum of stdout, stderr and settings>
# The checksum covers what a check prints to stdout and stderr and the settings it
# leaves, so a change in what is printed (not only accept/reject) is detected.
#
# With VALIDATOR_DRIVER_ISOLATE=1 each check runs in a subshell, and a check that
# exits the shell is reported with status "crash" and checksum "-". The golden
# files are generated this way; the equivalence test runs without it.

logging_script="$1"
corpus_file="$2"
shift 2

# shellcheck source=../../logging.sh disable=SC1091
. "$logging_script"

work_dir="${TMPDIR:-/tmp}/validator-driver.$$"
mkdir -p "$work_dir" || exit 1
trap 'rm -rf "$work_dir"' EXIT

tab=$(printf '\t')
truncate_sample="abcdefghijklmnopqrstuvwxyz0123456789"

# Checks are kept one per line and read with "while read", because zsh does not
# split an unquoted variable into words
all_checks="string
string_no_cntrl
config_file_path
config_journal_tag
journal_tag
config_format
log_level_value
truncate_limit
sanitize_script_name
init_max_line_length
parse_line
parse_format
parse_log_file
parse_tag
parse_level
parse_max_line_length
parse_script_name
parse_facility
parse_utc"
if [ "$#" -gt 0 ]; then
    selected_checks=""
    for requested_check in "$@"; do
        selected_checks="${selected_checks}${requested_check}
"
    done
else
    selected_checks="$all_checks"
fi

# Restore the settings that config parsing and init_logger can change
reset_settings() {
    CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO
    LOG_STDERR_LEVEL=$LOG_LEVEL_ERROR
    LOG_FORMAT="%d [%l] [%s] %m"
    LOG_FILE=""
    JOURNAL_TAG=""
    SCRIPT_NAME="driver"
    SYSLOG_FACILITY="daemon"
    USE_UTC="false"
    USE_COLORS="auto"
    CONSOLE_LOG="true"
    VERBOSE="false"
    LOG_MAX_LINE_LENGTH=4096
    LOG_MAX_JOURNAL_LENGTH=4096
    LOG_UNSAFE_ALLOW_NEWLINES="false"
    LOG_UNSAFE_ALLOW_ANSI_CODES="false"
    LOG_INIT_MESSAGE="true"
}

# Print the settings, so a check also records what it changed
print_settings() {
    printf 'level=%s|stderr=%s|format=%s|file=%s|tag=%s|name=%s|facility=%s|utc=%s|max=%s|jmax=%s\n' \
        "$CURRENT_LOG_LEVEL" "$LOG_STDERR_LEVEL" "$LOG_FORMAT" "$LOG_FILE" "$JOURNAL_TAG" \
        "$SCRIPT_NAME" "$SYSLOG_FACILITY" "$USE_UTC" "$LOG_MAX_LINE_LENGTH" \
        "$LOG_MAX_JOURNAL_LENGTH"
}

# Parse a one-line config file "<key> = <value>", or the raw value when key is empty
parse_config_with() {
    config_key="$1"
    config_value="$2"
    if [ -n "$config_key" ]; then
        printf '%s = %s\n' "$config_key" "$config_value" > "$work_dir/check.conf"
    else
        printf '%s\n' "$config_value" > "$work_dir/check.conf"
    fi
    _parse_config_file "$work_dir/check.conf"
}

# Run one check on one value. stdout and stderr go to files in work_dir.
run_check() {
    check_name="$1"
    value="$2"
    case "$check_name" in
        string) _validate_string "$value" 64 "value" "false" "true" ;;
        string_no_cntrl) _validate_string "$value" 4096 "value" "true" "false" ;;
        config_file_path) _validate_config_file_path "$value" "log_file" 1 ;;
        config_journal_tag) _validate_config_journal_tag "$value" "tag" 1 ;;
        journal_tag) _validate_journal_tag "$value" ;;
        config_format) _validate_config_format "$value" 1 ;;
        log_level_value) _get_log_level_value "$value" 1 ;;
        truncate_limit) _truncate_log_message "$truncate_sample" "$value" ;;
        sanitize_script_name) _sanitize_script_name "$value" ;;
        init_max_line_length)
            init_logger --quiet --no-init-message --max-line-length "$value"
            ;;
        parse_line) parse_config_with "" "$value" ;;
        parse_format) parse_config_with "format" "$value" ;;
        parse_log_file) parse_config_with "log_file" "$value" ;;
        parse_tag) parse_config_with "tag" "$value" ;;
        parse_level) parse_config_with "level" "$value" ;;
        parse_max_line_length) parse_config_with "max_line_length" "$value" ;;
        parse_script_name) parse_config_with "script_name" "$value" ;;
        parse_facility) parse_config_with "facility" "$value" ;;
        parse_utc) parse_config_with "utc" "$value" ;;
        *)
            printf 'Unknown check: %s\n' "$check_name" >&2
            return 99
            ;;
    esac
}

rows_dir="$work_dir/rows"
mkdir -p "$rows_dir"
: > "$work_dir/index"
while IFS= read -r check_name; do
    [ -n "$check_name" ] && mkdir -p "$rows_dir/$check_name"
done <<CHECKS
$selected_checks
CHECKS

# Run every check on every input. Each result (stdout and stderr together, then the
# settings) goes to its own file, and all files are checksummed at the end, so a
# check costs no extra processes.
while IFS="$tab" read -r input_id encoded_input || [ -n "$input_id" ]; do
    case "$input_id" in
        ''|'#'*) continue ;;
    esac
    # The encoded input only contains alphanumerics and octal escapes, so it is safe
    # to use as a printf format. The trailing x keeps trailing newlines, which
    # command substitution would otherwise remove.
    # shellcheck disable=SC2059
    decoded_input=$(printf "${encoded_input}x")
    decoded_input="${decoded_input%x}"

    while IFS= read -r check_name; do
        [ -n "$check_name" ] || continue
        row_file="$rows_dir/$check_name/$input_id"
        if [ "${VALIDATOR_DRIVER_ISOLATE:-}" = "1" ]; then
            # A subshell per check, so a check that exits the shell is recorded as a
            # crash instead of stopping the driver. Needed for the bash code on main.
            rm -f "$work_dir/status"
            (
                reset_settings
                run_check "$check_name" "$decoded_input" >"$row_file" 2>&1 </dev/null
                check_status=$?
                print_settings >> "$row_file"
                printf '%s\n' "$check_status" > "$work_dir/status"
            )
            if [ -f "$work_dir/status" ]; then
                read -r check_status < "$work_dir/status"
            else
                check_status="crash"
            fi
        else
            reset_settings
            run_check "$check_name" "$decoded_input" >"$row_file" 2>&1 </dev/null
            check_status=$?
            print_settings >> "$row_file"
        fi
        printf '%s\t%s\t%s\n' "$check_name" "$input_id" "$check_status" >> "$work_dir/index"
    done <<CHECKS
$selected_checks
CHECKS
done < "$corpus_file"

# Lines starting with the script path are the shell's own diagnostics (for example
# bash's "line 769: [[: 08: value too great for base"). They depend on the shell and
# on line numbers, not on the validator, so they are removed before checksumming.
while IFS= read -r check_name; do
    [ -n "$check_name" ] || continue
    grep -l "^$logging_script:" "$rows_dir/$check_name"/* 2>/dev/null \
        | while IFS= read -r noisy_file; do
            grep -v "^$logging_script:" "$noisy_file" > "$work_dir/filtered"
            mv "$work_dir/filtered" "$noisy_file"
        done
    cksum "$rows_dir/$check_name"/*
done <<CHECKS > "$work_dir/checksums"
$selected_checks
CHECKS

# Join the index with the checksums: <check> <id> <status> <checksum>
# A crashed check has no meaningful output, so its checksum is "-".
awk -v rows_dir="$rows_dir/" '
    NR == FNR {
        path = $3
        sub(rows_dir, "", path)
        checksum[path] = $1
        next
    }
    {
        key = $1 "/" $2
        if ($3 == "crash") {
            printf "%s\t%s\tcrash\t-\n", $1, $2
        } else {
            printf "%s\t%s\t%s\t%s\n", $1, $2, $3, checksum[key]
        }
    }' "$work_dir/checksums" FS='\t' "$work_dir/index"
