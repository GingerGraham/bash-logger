#!/usr/bin/env bash
#
# generate_validator_changes.sh - Record the validator results that changed in 3.0
#
# Usage: tests/compat/generate_validator_changes.sh [logging.sh]
#
# Runs the validator corpus through the given logging.sh (default: the one in this
# repository) and writes every row whose result differs from the 2.7.0 record:
#
#   tests/compat/golden/validators_3.0.tsv        rows of validators.tsv (LC_ALL=C)
#   tests/compat/golden/validators_utf8_3.0.tsv   rows of validators_utf8.tsv, written only
#                                                 when a row changes
#
# Each row is "<check> <corpus id> <status> <checksum> <reason>". test_validator_equivalence.sh
# applies these rows on top of validators.tsv and validators_utf8.tsv, which stay the record
# of 2.7.0 and are never regenerated. A golden "crash" row is not a change: bash on 2.7.0
# exited the shell there, and the suite only requires that the current code does not.
#
# Every change needs a reason. Add one to reason_for_check below, with the issue that makes
# the change, before running this script for a new intended change. A changed check without
# a reason makes the script fail, so an unintended change cannot be recorded by accident.
#
# Run it with bash. It needs a UTF-8 locale for validators_utf8_3.0.tsv.

set -euo pipefail

compat_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
golden_dir="$compat_dir/golden"
driver="$compat_dir/validator_driver.sh"

logging_script="${1:-$compat_dir/../../logging.sh}"
if [[ ! -f "$logging_script" ]]; then
    echo "Usage: $0 [logging.sh]" >&2
    exit 1
fi
logging_script="$(cd "$(dirname "$logging_script")" && pwd)/$(basename "$logging_script")"

# Print the reason a check's result changed in 3.0, or nothing when none is recorded.
# Arguments: check name, golden file name, corpus id
# Corpus ids above 749 in validator_corpus.txt were added for #154 (see
# generate_validator_golden.sh), so a change there is the control character check, not the
# overlong tag fix, which changes four of the original inputs.
reason_for_check() {
    local control_reason="Rejects C1 controls, U+2028, U+2029 and bidirectional controls in every locale (#154)"
    case "$1" in
        string|config_file_path|config_journal_tag|journal_tag|parse_log_file)
            printf '%s' "$control_reason"
            ;;
        config_format|parse_format)
            printf '%s' "A config format with control characters is rejected, and the controls from #154 count as well (#164, #154)"
            ;;
        parse_tag)
            if [[ "$2" == "validators.tsv" && "$3" -le 749 ]]; then
                printf '%s' "Sanitizes an overlong invalid config tag after cutting it to 64 characters (#154)"
            else
                printf '%s' "$control_reason"
            fi
            ;;
        init_max_line_length)
            printf '%s' "A CLI line limit that is invalid octal or above 1048576 is rejected with the config file's warning, and the limit in effect stays (#150)"
            ;;
        parse_max_line_length)
            printf '%s' "The config warning for an invalid limit now names the limit in effect, not the default (#150)"
            ;;
        *) return 0 ;;
    esac
}

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

# Print the first installed UTF-8 locale name, or nothing
find_utf8_locale() {
    local candidate
    for candidate in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8; do
        if locale -a 2>/dev/null | grep -qx "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
}

# Write the changed rows of one golden file to an overlay file.
# Arguments: golden name, corpus name, locale, overlay name, remove an empty overlay (yes/no)
write_overlay() {
    local golden_name="$1"
    local corpus_name="$2"
    local locale_name="$3"
    local overlay_name="$4"
    local remove_when_empty="$5"
    local golden_file="$golden_dir/$golden_name"
    local checks
    checks=$(grep -v '^#' "$golden_file" | cut -f1 | awk '!seen[$0]++' | tr '\n' ' ')

    local actual_file="$work_dir/$golden_name.actual"
    # shellcheck disable=SC2086  # word splitting of the check names is intended
    env -i PATH="$PATH" HOME="$work_dir" TMPDIR="$work_dir" LC_ALL="$locale_name" \
        bash "$driver" "$logging_script" "$golden_dir/$corpus_name" $checks \
        > "$actual_file" 2> "$work_dir/driver.stderr" < /dev/null

    local rows_file="$work_dir/$overlay_name.rows"
    local changed_count=0
    : > "$rows_file"
    while IFS=$'\t' read -r check_name corpus_id status checksum; do
        local reason
        reason=$(reason_for_check "$check_name" "$golden_name" "$corpus_id")
        if [[ -z "$reason" ]]; then
            echo "Error: $golden_name $check_name $corpus_id changed, and no reason is" \
                "recorded for $check_name in reason_for_check" >&2
            exit 1
        fi
        printf '%s\t%s\t%s\t%s\t%s\n' \
            "$check_name" "$corpus_id" "$status" "$checksum" "$reason" >> "$rows_file"
        changed_count=$((changed_count + 1))
    done < <(awk -F '\t' '
        NR == FNR { if ($0 !~ /^#/) { expected[$1 "\t" $2] = $3 " " $4 } ; next }
        {
            key = $1 "\t" $2
            if (!(key in expected) || expected[key] == "crash -") { next }
            if (expected[key] != $3 " " $4) { print }
        }' "$golden_file" "$actual_file")

    local overlay_file="$golden_dir/$overlay_name"
    if [[ $changed_count -eq 0 && "$remove_when_empty" == "yes" ]]; then
        rm -f "$overlay_file"
        echo "No changed rows in $golden_name, so no $overlay_name" >&2
        return 0
    fi
    {
        printf '# Validator results that changed in 3.0, applied on top of %s.\n' "$golden_name"
        printf '# Generated by tests/compat/generate_validator_changes.sh; do not edit by hand.\n'
        printf '# Columns: check, corpus id, status, checksum, reason.\n'
        cat "$rows_file"
    } > "$overlay_file"
    echo "Wrote $overlay_file ($changed_count changed rows)" >&2
}

write_overlay validators.tsv validator_corpus.txt C validators_3.0.tsv no

utf8_locale=$(find_utf8_locale)
if [[ -n "$utf8_locale" ]]; then
    write_overlay validators_utf8.tsv validator_corpus_utf8.txt "$utf8_locale" \
        validators_utf8_3.0.tsv yes
else
    echo "Warning: no UTF-8 locale installed, so validators_utf8_3.0.tsv was not checked" >&2
fi
