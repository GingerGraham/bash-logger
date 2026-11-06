#!/usr/bin/env bash
#
# test_validator_equivalence.sh - Validators accept and reject the same inputs (Issue #143)
#
# The golden files in tests/compat/golden/ were generated once, with bash, from the
# logging.sh that still used bash regular expressions for its security checks
# (see tests/compat/generate_validator_golden.sh). This suite runs the same corpus
# through the current validators under every shell in TEST_SHELLS and requires an
# exact match: same exit status, and the same messages and resulting settings
# (compared by checksum). Where bash on main exited the shell ("crash" in the golden
# file), the only requirement is that the current code does not.
#
#   validators.tsv        corpus checked with LC_ALL=C
#   validators_utf8.tsv   valid UTF-8 corpus checked with a UTF-8 locale (Linux only)
#
# TEST_SHELLS and TEST_REQUIRE_SHELLS work as in test_shell_compat.sh.

EQUIVALENCE_DIR="$PROJECT_ROOT/tests/compat"
EQUIVALENCE_GOLDEN_DIR="$EQUIVALENCE_DIR/golden"
EQUIVALENCE_DRIVER="$EQUIVALENCE_DIR/validator_driver.sh"

# Print the name of an installed UTF-8 locale, or nothing.
# The UTF-8 golden file records glibc's character classes, so it is only checked on Linux.
equivalence_utf8_locale() {
    [[ "$(uname -s)" == "Linux" ]] || return 0
    local candidate
    for candidate in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8; do
        if locale -a 2>/dev/null | grep -qx "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
}

# Print the check names used in a golden file, space separated
equivalence_checks_in() {
    grep -v '^#' "$1" | cut -f1 | awk '!seen[$0]++' | tr '\n' ' '
}

# Print one line for each result that does not match the golden file.
# A golden "crash" (bash on main exited the shell) must not crash now; any other
# result is accepted for it, because exiting the caller's shell was a bug.
# Every other golden row must match the status and checksum exactly, and a result
# that has no golden row is reported too.
equivalence_compare() {
    local expected_file="$1"
    local actual_file="$2"
    awk -F '\t' '
        NR == FNR { expected[$1 "\t" $2] = $3 " " $4; order[++count] = $1 "\t" $2; next }
        {
            actual[$1 "\t" $2] = $3 " " $4
            if (!(($1 "\t" $2) in expected)) {
                printf "%s: not in the golden file, got %s %s\n", $1 "\t" $2, $3, $4
            }
        }
        END {
            for (i = 1; i <= count; i++) {
                key = order[i]
                if (!(key in actual)) {
                    printf "%s: expected %s, got nothing\n", key, expected[key]
                } else if (expected[key] == "crash -") {
                    if (actual[key] == "crash -") {
                        printf "%s: still crashes\n", key
                    }
                } else if (expected[key] != actual[key]) {
                    printf "%s: expected %s, got %s\n", key, expected[key], actual[key]
                }
            }
        }' "$expected_file" "$actual_file" | tr '\t' ' '
}

# Test: one shell matches one golden file
test_validator_equivalence_in_shell() {
    local shell_command="$1"
    local golden_name="$2"
    local corpus_name="$3"
    local locale_name="$4"

    start_test "validators [$shell_command] match $golden_name"

    local shell_name="${shell_command%% *}"
    require_shell "$shell_name" || return 0

    if [[ -z "$locale_name" ]]; then
        skip_test "no UTF-8 locale installed, or not Linux"
        return 0
    fi

    local golden_file="$EQUIVALENCE_GOLDEN_DIR/$golden_name"
    local corpus_file="$EQUIVALENCE_GOLDEN_DIR/$corpus_name"
    local actual_file="$TEST_DIR/actual.tsv"
    local expected_file="$TEST_DIR/expected.tsv"
    local checks
    checks=$(equivalence_checks_in "$golden_file")

    grep -v '^#' "$golden_file" > "$expected_file"
    # shellcheck disable=SC2086  # word splitting of shell_command and checks is intended
    env -i PATH="$PATH" HOME="$TEST_DIR" TMPDIR="$TEST_DIR" LC_ALL="$locale_name" \
        $shell_command "$EQUIVALENCE_DRIVER" "$PROJECT_ROOT/logging.sh" "$corpus_file" $checks \
        > "$actual_file" 2> "$TEST_DIR/driver.stderr" </dev/null

    local mismatch_file="$TEST_DIR/mismatches"
    equivalence_compare "$expected_file" "$actual_file" > "$mismatch_file"

    if [[ -s "$mismatch_file" ]]; then
        local difference_count
        difference_count=$(wc -l < "$mismatch_file" | tr -d ' ')
        fail_test "$difference_count results differ from $golden_name (first lines below)"
        echo "    <check> <corpus id>: expected <status> <checksum>, got <status> <checksum>"
        echo "    Corpus ids are the first column of $corpus_name"
        head -20 "$mismatch_file" | sed 's/^/    /'
        if [[ -s "$TEST_DIR/driver.stderr" ]]; then
            echo "    driver stderr:"
            head -5 "$TEST_DIR/driver.stderr" | sed 's/^/    /'
        fi
        return 0
    fi

    pass_test
}

# Test: the golden files exist and are not empty
test_validator_golden_files_present() {
    start_test "validator golden files and corpora are present"

    local golden_file
    for golden_file in validators.tsv validators_utf8.tsv \
                       validator_corpus.txt validator_corpus_utf8.txt; do
        assert_file_not_empty "$EQUIVALENCE_GOLDEN_DIR/$golden_file" || return
    done

    pass_test
}

# Run all tests
test_validator_golden_files_present

equivalence_locale=$(equivalence_utf8_locale)
while IFS= read -r equivalence_shell; do
    test_validator_equivalence_in_shell "$equivalence_shell" \
        validators.tsv validator_corpus.txt C
    test_validator_equivalence_in_shell "$equivalence_shell" \
        validators_utf8.tsv validator_corpus_utf8.txt "$equivalence_locale"
done <<< "$(test_shell_list)"
