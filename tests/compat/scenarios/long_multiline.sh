# shellcheck shell=sh
# Line control characters (LF, CR, tab) in messages of every size, including either side
# of the lengths where the sanitizer switches to tr (2,048 and 16,384 characters).
# Truncation is off except in the last case, so it cannot hide a difference.
. "$LOGGER_ROOT/logging.sh"

# Print text of a length: 63 characters then a separator, repeated, cut to the length.
# Arguments: length, separator (printf format, default \n)
make_text() {
    awk -v length_wanted="$1" -v separator="${2:-\\n}" 'BEGIN {
        gsub(/\\n/, "\n", separator); gsub(/\\r/, "\r", separator); gsub(/\\t/, "\t", separator)
        text = ""
        line = 0
        while (length(text) < length_wanted) {
            for (j = 0; j < 63; j++) text = text sprintf("%c", 97 + (line + j) % 26)
            text = text separator
            line++
        }
        printf "%s", substr(text, 1, length_wanted)
    }'
}

nl='
'
cr=$(printf '\r')
tab=$(printf '\t')

init_logger --quiet --no-color --log "$SCENARIO_DIR/test.log" --format "%l|%m|" \
    --max-line-length 0

# Each control character, CRLF, and runs of each
log_info "lf${nl}cr${cr}tab${tab}crlf${cr}${nl}end"
log_info "runs${nl}${nl}${nl}and${cr}${cr}${cr}and${tab}${tab}${tab}and${cr}${nl}${cr}${nl}end"

# Only control characters, and leading and trailing newlines
log_info "${nl}${nl}${nl}"
log_info "${cr}${tab}${cr}${tab}"
log_info "${nl}${nl}leading newlines"
log_info "trailing newlines${nl}${nl}"
log_info "${tab}${nl}both ends${nl}${tab}"

# Content that looks like format tokens, replacement syntax, globs or echo options
log_info "%m %d & \\& * ? [a] \\ \\n${nl}-n"
log_info "-n${nl}-e"
log_info "$(printf '*%s*' "${nl}")"

# Either side of the tr limits, with a newline, CR or tab every 64 characters
for size in 2047 2048 2049 16383 16384 16385; do
    log_info "$(make_text "$size")"
    log_info "$(make_text "$size" '\r')"
    log_info "$(make_text "$size" '\t')"
done

# Long, with no control characters at all, either side of the limits
for size in 2049 16385; do
    log_info "$(make_text "$size" ' ')"
done

# Long, with every kind of control character, and a 64 KB message
log_info "$(make_text 20000 '\r\n')"
log_info "$(make_text 65536)"

# The default truncation limit still applies after the long-message path
LOG_MAX_LINE_LENGTH=4096
log_info "$(make_text 20000)"
