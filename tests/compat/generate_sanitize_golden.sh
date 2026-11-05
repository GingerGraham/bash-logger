#!/usr/bin/env bash
#
# generate_sanitize_golden.sh - Build the sanitizing corpus and golden results (Issue #143)
#
# Usage: tests/compat/generate_sanitize_golden.sh <logging.sh>
#
# Writes:
#   tests/compat/golden/sanitize_corpus.txt   messages, encoded as in validator_corpus.txt
#   tests/compat/golden/sanitize.tsv          bash results for those messages
#
# The golden results record how messages were sanitized and formatted BEFORE the POSIX
# conversion. Generate them only from logging.sh at 2.7.0 (e53fcda), with bash and
# LC_ALL=C. Never regenerate them from the converted code.
#
# The corpus is generated with a fixed seed and committed, so it does not depend on the
# awk that later runs the tests. It leaves out two known, intended differences:
#   * messages that are only echo options (-n, -e, -E and combinations): bash on main
#     logged these as empty lines (see test_posix_echo_option_messages)
#   * messages longer than the truncation limit: the driver turns truncation off,
#     because dash and busybox truncate by bytes and never cut a UTF-8 character

set -euo pipefail

if [[ $# -ne 1 || ! -f "$1" ]]; then
    echo "Usage: $0 <logging.sh>" >&2
    exit 1
fi

logging_script="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
compat_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
golden_dir="$compat_dir/golden"
mkdir -p "$golden_dir"

# Encode stdin as a printf format: alphanumerics stay, every other byte is \ooo
encode_stdin() {
    LC_ALL=C od -An -v -to1 | awk '
        BEGIN {
            for (code = 48; code <= 57; code++) keep[sprintf("%03o", code)] = sprintf("%c", code)
            for (code = 65; code <= 90; code++) keep[sprintf("%03o", code)] = sprintf("%c", code)
            for (code = 97; code <= 122; code++) keep[sprintf("%03o", code)] = sprintf("%c", code)
        }
        {
            for (field = 1; field <= NF; field++) {
                if ($field in keep) { printf "%s", keep[$field] } else { printf "\\%s", $field }
            }
        }'
}

# Print text of a length: 63 characters then a separator, repeated, cut to the length
make_text() {
    awk -v length_wanted="$1" -v separator="$2" 'BEGIN {
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

esc=$'\033'
bel=$'\a'
nl=$'\n'
cr=$'\r'
tab=$'\t'

messages=(
    # Each line control character, CRLF, runs, and combinations
    "lf${nl}end" "cr${cr}end" "tab${tab}end" "crlf${cr}${nl}end"
    "runs${nl}${nl}${nl}${cr}${cr}${tab}${tab}end" "${cr}${nl}${cr}${nl}${cr}${nl}"
    # Only control characters, leading and trailing newlines
    "${nl}" "${nl}${nl}${nl}" "${cr}" "${tab}" "${cr}${tab}${nl}"
    "${nl}leading" "${nl}${nl}leading two" "trailing${nl}" "trailing two${nl}${nl}"
    "${tab}${nl}both${nl}${tab}" " spaces around "
    # Content that looks like format tokens, replacement syntax, globs or options
    "%m" "%d %l %s %z %m %%" "%" "&" '\&' "a & b" "*" "*.sh" "?" "[a-z]" '\' '\\' '\n'
    '\t \r \033 \c' '$HOME $(id) `id`' "-n text" "-e text" "--" "-" "-x" "text -n"
    # ANSI sequences of every kind the sanitizer removes, and ones it keeps
    "${esc}[31mred${esc}[0m" "${esc}[2J${esc}[H${esc}[?25l private" "${esc}]0;title${bel}after"
    "${esc}]8;;http://x${esc}\\link${esc}]8;;${esc}\\ done" "${esc}Pq#0;2${esc}\\ dcs"
    "${esc}^pm${esc}\\ ${esc}_apc${esc}\\ end" "lone ${esc}c and ${esc}(B" "${esc}${esc}[31m[0m"
    "${esc}" "${esc}[" "text${esc}" "${esc}[31m${nl}${esc}[0m"
    # UTF-8, alone and with control characters
    "café naïve 日本語 😀" "é${nl}é${cr}é${tab}é" "$(printf '\302\205 C1 next line')" "Ω${esc}[1mΩ"
)

# Either side of the lengths where the sanitizer switches to tr (2,048 and 16,384)
for size in 2047 2048 2049 16383 16384 16385; do
    messages+=("$(make_text "$size" "$nl")")
done
messages+=("$(make_text 2049 "$cr$nl")" "$(make_text 16385 "$tab")" "$(make_text 3000 " ")")

# Random messages from a fixed seed. Pieces are joined to lengths up to about 3,000.
while IFS= read -r random_message; do
    messages+=("$(printf '%b' "$random_message")")
done < <(awk 'BEGIN {
    srand(143)
    split("a|b|c|text|word|  |\\n|\\r|\\t|\\r\\n|\\n\\n|%m|%d|&|\\\\|*|?|-n|é|日本|\\0033[31m|\\0033[0m|\\0033]0;t\\0007|\\0033|=|$|`", piece, "|")
    pieces = 0
    for (key in piece) pieces++
    for (message = 0; message < 50; message++) {
        target = int(rand() * 3000) + 1
        if (message % 5 == 0) target = int(rand() * 40) + 1
        text = ""
        count = 0
        while (count < target) {
            chosen = piece[int(rand() * pieces) + 1]
            text = text chosen
            count += length(chosen)
        }
        print text
    }
}')

# Leave out messages that are only echo options (see the header)
corpus_file="$golden_dir/sanitize_corpus.txt"
{
    printf '# Sanitizing corpus for test_sanitize_equivalence.sh (Issue #143)\n'
    printf '# Generated by tests/compat/generate_sanitize_golden.sh; do not edit by hand.\n'
    index=0
    for message in "${messages[@]}"; do
        if [[ "$message" =~ ^-[neE]+$ ]]; then
            continue
        fi
        index=$((index + 1))
        printf '%s\t%s\n' "$index" "$(printf '%s' "$message" | encode_stdin)"
    done
} > "$corpus_file"

source_commit=$(git -C "$(dirname "$logging_script")" log -1 --format=%h -- "$(basename "$logging_script")" 2>/dev/null || echo unknown)
{
    printf '# Golden sanitizing results (Issue #143). Do not regenerate from converted code.\n'
    printf '# logging.sh %s, %s, LC_ALL=C\n' "$source_commit" "$(bash --version | head -1)"
    LC_ALL=C bash "$compat_dir/sanitize_driver.sh" "$logging_script" "$corpus_file"
} > "$golden_dir/sanitize.tsv"

echo "Wrote $index messages to $corpus_file and results to $golden_dir/sanitize.tsv"
