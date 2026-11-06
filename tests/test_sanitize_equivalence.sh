#!/usr/bin/env bash
#
# test_sanitize_equivalence.sh - Messages are logged as before the conversion (Issue #143)
#
# tests/compat/golden/sanitize.tsv was generated once, with bash and LC_ALL=C, from
# logging.sh at 2.7.0 (e53fcda), before the POSIX conversion (see
# tests/compat/generate_sanitize_golden.sh). This suite logs the same corpus under every
# shell in TEST_SHELLS and requires the same log output, compared by checksum, in three
# modes: default sanitizing, unsafe newlines and unsafe ANSI codes.
#
# 3.0 removes more than 2.7.0 did. The rows that changed on purpose, with the reason for
# each, are in tests/compat/golden/sanitize_3.0.tsv (see
# tests/compat/generate_sanitize_changes.sh), which replaces those rows of sanitize.tsv.
#
# TEST_SHELLS and TEST_REQUIRE_SHELLS work as in test_shell_compat.sh.

SANITIZE_GOLDEN_DIR="$PROJECT_ROOT/tests/compat/golden"
SANITIZE_DRIVER="$PROJECT_ROOT/tests/compat/sanitize_driver.sh"

# Print sanitize.tsv with the rows in sanitize_3.0.tsv replaced by their 3.0 results
write_expected_sanitize_results() {
    awk -F'\t' '
        FNR == 1 { file_number++ }
        /^#/ { next }
        file_number == 1 { changed[$1 "\t" $2] = $3; next }
        {
            key = $1 "\t" $2
            if (key in changed) { $3 = changed[key] }
            printf "%s\t%s\t%s\n", $1, $2, $3
        }
    ' "$SANITIZE_GOLDEN_DIR/sanitize_3.0.tsv" "$SANITIZE_GOLDEN_DIR/sanitize.tsv"
}

# Test: one shell matches the golden file
test_sanitize_equivalence_in_shell() {
    local shell_command="$1"

    start_test "sanitizing [$shell_command] matches sanitize.tsv"

    require_shell "${shell_command%% *}" || return 0

    local expected_file="$TEST_DIR/expected.tsv"
    local actual_file="$TEST_DIR/actual.tsv"
    write_expected_sanitize_results > "$expected_file"

    # shellcheck disable=SC2086  # word splitting of shell_command is intended
    env -i PATH="$PATH" HOME="$TEST_DIR" TMPDIR="$TEST_DIR" LC_ALL=C \
        $shell_command "$SANITIZE_DRIVER" "$PROJECT_ROOT/logging.sh" \
        "$SANITIZE_GOLDEN_DIR/sanitize_corpus.txt" \
        > "$actual_file" 2> "$TEST_DIR/driver.stderr" </dev/null

    if ! cmp -s "$expected_file" "$actual_file"; then
        local difference_count
        difference_count=$(diff "$expected_file" "$actual_file" | grep -c '^>')
        fail_test "$difference_count results differ from sanitize.tsv (first lines below)"
        echo "    <mode> <corpus id> <checksum>; ids are lines in sanitize_corpus.txt"
        diff "$expected_file" "$actual_file" | grep '^[<>]' | head -20 | sed 's/^/    /'
        if [[ -s "$TEST_DIR/driver.stderr" ]]; then
            echo "    driver stderr:"
            head -5 "$TEST_DIR/driver.stderr" | sed 's/^/    /'
        fi
        return 0
    fi

    pass_test
}

# Test: the golden file and corpus exist and cover every message in all three modes
test_sanitize_golden_files_present() {
    start_test "sanitizing golden file covers every corpus message in three modes"

    local corpus_file="$SANITIZE_GOLDEN_DIR/sanitize_corpus.txt"
    local golden_file="$SANITIZE_GOLDEN_DIR/sanitize.tsv"
    assert_file_not_empty "$corpus_file" || return
    assert_file_not_empty "$golden_file" || return

    local message_count
    local result_count
    message_count=$(grep -vc '^#' "$corpus_file")
    result_count=$(grep -vc '^#' "$golden_file")
    assert_equals "$((message_count * 3))" "$result_count" "rows in sanitize.tsv" || return

    pass_test
}

# Test: every row in sanitize_3.0.tsv is a real change with a listed reason
test_sanitize_changes_are_explained() {
    start_test "every 3.0 sanitizing change differs from 2.7.0 and has a reason"

    local changes_file="$SANITIZE_GOLDEN_DIR/sanitize_3.0.tsv"
    assert_file_not_empty "$changes_file" || return

    local problems
    problems=$(awk -F'\t' '
        FNR == 1 { file_number++ }
        /^#/ { next }
        file_number == 1 { baseline[$1 "\t" $2] = $3; next }
        {
            key = $1 "\t" $2
            if (!(key in baseline)) { print "not in sanitize.tsv: " key; next }
            if (baseline[key] == $3) { print "same as 2.7.0: " key }
            if ($4 !~ /^(esc|utf8|c1)(,(esc|utf8|c1))*$/) { print "no valid reason: " key }
        }
    ' "$SANITIZE_GOLDEN_DIR/sanitize.tsv" "$changes_file")
    assert_equals "" "$problems" || return

    pass_test
}

# Run all tests
test_sanitize_golden_files_present
test_sanitize_changes_are_explained

while IFS= read -r sanitize_shell; do
    test_sanitize_equivalence_in_shell "$sanitize_shell"
done <<< "$(test_shell_list)"
