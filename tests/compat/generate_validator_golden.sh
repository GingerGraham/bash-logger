#!/usr/bin/env bash
#
# generate_validator_golden.sh - Build the validator corpus and golden results (Issue #143)
#
# Usage: tests/compat/generate_validator_golden.sh <logging.sh>
#
# Writes:
#   tests/compat/golden/validator_corpus.txt       inputs checked with LC_ALL=C
#   tests/compat/golden/validators.tsv             bash results for those inputs
#   tests/compat/golden/validator_corpus_utf8.txt  valid UTF-8 inputs
#   tests/compat/golden/validators_utf8.tsv        bash results with a UTF-8 locale
#
# The golden files record how the validators behaved BEFORE the POSIX conversion.
# Generate them only from a logging.sh that still uses the bash regular expressions
# (e53fcda or earlier). Never regenerate them from the converted code: the
# point of the files is to prove that the conversion accepts and rejects exactly the
# same inputs.
#
# Inputs whose bash result comes from 64-bit integer wraparound are left out on
# purpose (for example a 20-digit max_line_length that wraps to a small number).
# Bash accepting those is a bug, not behaviour to preserve.

set -euo pipefail

if [[ $# -ne 1 || ! -f "$1" ]]; then
    echo "Usage: $0 <logging.sh>" >&2
    exit 1
fi

logging_script="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
compat_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
golden_dir="$compat_dir/golden"
mkdir -p "$golden_dir"

# Encode a value as a printf format: alphanumerics stay, every other byte is \ooo
encode_value() {
    local value="$1"
    local encoded=""
    local octal
    for octal in $(printf '%s' "$value" | LC_ALL=C od -An -v -to1); do
        case "$octal" in
            06[0-9]|07[0-1]|10[1-7]|11[0-7]|12[0-7]|13[0-2]|14[1-7]|15[0-7]|16[0-7]|17[0-2])
                # 0-9 (060-071), A-Z (101-132), a-z (141-172)
                encoded="${encoded}$(printf "\\${octal}")"
                ;;
            *)
                encoded="${encoded}\\${octal}"
                ;;
        esac
    done
    printf '%s' "$encoded"
}

# Print a string made of a character repeated a number of times
repeat_text() {
    local text="$1"
    local count="$2"
    local result=""
    local index=0
    while [[ $index -lt $count ]]; do
        result="${result}${text}"
        index=$((index + 1))
    done
    printf '%s' "$result"
}

c_inputs=()

# Every single byte 1-255, alone and between two letters
for code in $(seq 1 255); do
    byte=$(printf "\\$(printf '%03o' "$code")")
    if [[ $code -eq 10 ]]; then
        byte=$'\n'
    fi
    c_inputs+=("$byte" "a${byte}b")
done

# Empty and whitespace
c_inputs+=("" " " "  " $'\t' "a b" " leading" "trailing ")

# Shell metacharacters and command injection attempts
c_inputs+=(
    '$(id)' '`id`' '${HOME}' '$HOME' 'a;b' 'a|b' 'a&b' 'a&&b' 'a||b' 'a<b' 'a>b'
    '(a)' '{a}' '[a]' 'a\b' 'a]b' 'a[b' "a'b" 'a"b' 'a!b' 'a*b' 'a?b' 'a~b' 'a#b'
    'my-app' 'my_app.v2' 'my app' 'app:1' 'app/1' 'app=1' 'app%1' 'app@host'
)

# Path validation: absolute, relative, traversal and suspicious patterns
c_inputs+=(
    '/var/log/app.log' 'relative/path.log' './app.log' '../app.log' '/'
    '/tmp/../../etc/passwd' '/var/log/../../etc/shadow' '/tmp/a b/c.log'
    '/tmp/$(whoami).log' '/tmp/`whoami`.log' '/tmp/$HOME.log' '/tmp/${x}.log'
    '/tmp/x;rm -rf /' '/tmp/x; rm -rf /' '/tmp/x;   rm' '/tmp/x;dd' '/tmp/x;  dd if=/dev/zero'
    $'/tmp/x;\trm' '/tmp/x;rmdir' '/tmp/x; ls' '/tmp/x;;rm'
    '/tmp/x|sh' '/tmp/x| sh' '/tmp/x|   sh -c' '/tmp/x||sh' '/tmp/x|bash' '/tmp/x | grep'
    '/tmp/x&&rm' '/tmp/x&& rm' '/tmp/x&&  dd' '/tmp/x&&ls' '/tmp/x& rm' '/tmp/x & & rm'
    '/tmp/x&&&rm' '/tmp/rm;' '/tmp/;' '/tmp/x$(' '/tmp/x$' '/tmp/x$ (y)'
)

# Lengths around the limits used by the validators (64, 4096)
c_inputs+=(
    "$(repeat_text a 63)" "$(repeat_text a 64)" "$(repeat_text a 65)"
    "$(repeat_text a 4095)" "$(repeat_text a 4096)" "$(repeat_text a 4097)"
    "/$(repeat_text a 4094)" "/$(repeat_text a 4095)" "/$(repeat_text a 4096)"
    "$(repeat_text '[' 64)" "$(repeat_text '$' 65)"
)

# Numbers, including leading zeros (bash reads these as octal) and signs
c_inputs+=(
    0 1 7 8 9 10 13 14 15 20 64 100 4096 1048575 1048576 1048577 9999999 99999999
    00 01 07 010 017 08 09 0189 0777 04000000 04000001 03777777 0000000000001
    -1 +1 -0 ' 5' '5 ' '1e3' '0x10' '1.5' '5a' 'a5' '١'
    123456789012345678
)

# Log level names and facilities, in several cases
c_inputs+=(
    debug DEBUG Debug info INFO notice NOTICE warn WARN warning Warning error ERROR err
    critical CRITICAL crit alert ALERT emergency EMERGENCY emerg fatal FATAL init
    'INFO ' ' INFO' 'IN FO' notalevel
    kern user mail daemon auth syslog lpr news uucp cron authpriv ftp
    local0 local7 LOCAL3 Local5 local8 local daemon2
    true false yes no on off TRUE Yes ON maybe
)

# Format strings
c_inputs+=(
    '%d [%l] [%s] %m' '%m' '%%' '%' '%q' '%d%l%s%m%z' 'plain text' '%m %m'
    $'%m\t%l' $'%m\001' $'\033[31m%m'
)

# Config file lines: sections, comments, quotes, key/value syntax
c_inputs+=(
    '[logging]' '[section one]' '[]' '[a]b]' '[[a]]' '[a' 'a]' ' [logging] '
    '# comment' '; comment' '  # indented' '#' ';'
    'key' '=value' 'key=' 'key = value' ' key = value ' 'k==v' 'a=b=c' '==' '='
    '"quoted"' "'quoted'" '"' "'" '""' "''" '"a' "'a" 'a"' "a'" '"a'"'" "'a\"" '"a"b"'
    'level = DEBUG' 'format = "%m"' "format = '%m'"
)

# Valid UTF-8 inputs, checked with a UTF-8 locale. These cover what the C locale
# cannot: multi-byte characters around the length limits, and C1 control
# characters, which bash treats as [[:cntrl:]] in a UTF-8 locale.
utf8_inputs=(
    'é' 'café' 'naïve-tag' '日本語' 'emoji😀' 'Ωmega'
    "$(repeat_text é 63)" "$(repeat_text é 64)" "$(repeat_text é 65)"
    "$(repeat_text 日 64)" "$(repeat_text 日 65)"
    "$(repeat_text é 4096)" "$(repeat_text é 4097)"
    "/$(repeat_text é 4095)" "/$(repeat_text é 4096)"
    '/var/log/café.log' '/tmp/日本語.log'
    $'a\u0085b' $'a\u0080b' $'a\u009bb' $'a\u009fb' $'a b' $'\u0085'
    $'a b' $'a​b' $'a﻿b' $'a­b'
)

write_corpus() {
    local corpus_file="$1"
    shift
    local index=0
    local value
    {
        printf '# Validator corpus for test_validator_equivalence.sh (Issue #143)\n'
        printf '# Generated by tests/compat/generate_validator_golden.sh; do not edit by hand.\n'
        for value in "$@"; do
            index=$((index + 1))
            printf '%s\t%s\n' "$index" "$(encode_value "$value")"
        done
    } > "$corpus_file"
}

write_golden() {
    local corpus_file="$1"
    local golden_file="$2"
    local locale_name="$3"
    shift 3
    local source_commit
    source_commit=$(git -C "$(dirname "$logging_script")" log -1 --format=%h -- "$(basename "$logging_script")" 2>/dev/null || echo unknown)
    {
        printf '# Golden validator results (Issue #143). Do not regenerate from converted code.\n'
        printf '# logging.sh %s, %s, LC_ALL=%s\n' "$source_commit" "$(bash --version | head -1)" "$locale_name"
        LC_ALL="$locale_name" VALIDATOR_DRIVER_ISOLATE=1 bash "$compat_dir/validator_driver.sh" \
            "$logging_script" "$corpus_file" "$@"
    } > "$golden_file"
}

write_corpus "$golden_dir/validator_corpus.txt" "${c_inputs[@]}"
write_corpus "$golden_dir/validator_corpus_utf8.txt" "${utf8_inputs[@]}"

write_golden "$golden_dir/validator_corpus.txt" "$golden_dir/validators.tsv" C
write_golden "$golden_dir/validator_corpus_utf8.txt" "$golden_dir/validators_utf8.tsv" C.UTF-8 \
    string string_no_cntrl config_file_path config_journal_tag journal_tag \
    config_format

echo "Wrote golden files to $golden_dir"
