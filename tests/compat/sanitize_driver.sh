# shellcheck shell=sh
# shellcheck disable=SC2034  # the LOG_UNSAFE_* settings set here are read by logging.sh
#
# sanitize_driver.sh - Log every message in a corpus and checksum the result (Issue #143)
#
# Usage: <shell> sanitize_driver.sh <logging.sh> <corpus file>
#
# Written in POSIX sh so the same driver runs in every shell under test. The corpus
# format is the one validator_driver.sh reads.
#
# Each message is logged with format "%m" and truncation off, in three modes:
#   default          newlines, CR, tab and ANSI sequences sanitized
#   allow_newlines   LOG_UNSAFE_ALLOW_NEWLINES=true
#   allow_ansi       LOG_UNSAFE_ALLOW_ANSI_CODES=true
# Output: one line per mode and message: <mode><TAB><id><TAB><cksum of the log file>

logging_script="$1"
corpus_file="$2"

# shellcheck source=../../logging.sh disable=SC1091
. "$logging_script"

work_dir="${TMPDIR:-/tmp}/sanitize-driver.$$"
mkdir -p "$work_dir/rows" || exit 1
trap 'rm -rf "$work_dir"' EXIT

tab=$(printf '\t')
init_logger --quiet --no-color --no-init-message --format "%m" --max-line-length 0 \
    --log "$work_dir/init.log" || exit 1
: > "$work_dir/index"

while IFS="$tab" read -r message_id encoded_message || [ -n "$message_id" ]; do
    case "$message_id" in
        ''|'#'*) continue ;;
    esac
    # Only alphanumerics and octal escapes, so safe as a printf format; the x keeps
    # trailing newlines that command substitution would remove
    # shellcheck disable=SC2059
    message=$(printf "${encoded_message}x")
    message="${message%x}"

    for mode in default allow_newlines allow_ansi; do
        LOG_UNSAFE_ALLOW_NEWLINES="false"
        LOG_UNSAFE_ALLOW_ANSI_CODES="false"
        case "$mode" in
            allow_newlines) LOG_UNSAFE_ALLOW_NEWLINES="true" ;;
            allow_ansi) LOG_UNSAFE_ALLOW_ANSI_CODES="true" ;;
        esac
        LOG_FILE="$work_dir/rows/$mode.$message_id"
        : > "$LOG_FILE"
        log_info "$message"
        printf '%s\t%s\n' "$mode" "$message_id" >> "$work_dir/index"
    done
done < "$corpus_file"

# Checksum all rows at once, then print them in corpus order
cd "$work_dir/rows" || exit 1
cksum -- * > "$work_dir/checksums"
awk '
    NR == FNR { checksum[$3] = $1; next }
    { printf "%s\t%s\t%s\n", $1, $2, checksum[$1 "." $2] }
' "$work_dir/checksums" FS='\t' "$work_dir/index"
