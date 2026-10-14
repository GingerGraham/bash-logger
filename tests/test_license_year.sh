#!/usr/bin/env bash
#
# test_license_year.sh - Tests for scripts/update-license-year.sh
#
# Tests:
# - A single-year notice becomes a range in a later year
# - An existing range has its end year extended
# - A notice that already covers the year is left untouched
# - Repeated runs do not change the result
# - Everything except the copyright line is preserved byte-for-byte
# - Invalid input fails without modifying the file

UPDATE_LICENSE_SCRIPT="$PROJECT_ROOT/scripts/update-license-year.sh"

# Write a minimal license file to $TEST_DIR/LICENSE and print its path.
# Arguments: the copyright line to use.
# The file deliberately has no trailing newline, like the real LICENSE file.
create_license_file() {
    local copyright_line="$1"
    local license_file="$TEST_DIR/LICENSE"

    printf '%s\n\nPermission is hereby granted, free of charge.\n\nThe above copyright notice shall be included.' \
        "$copyright_line" > "$license_file"

    echo "$license_file"
}

test_license_year_single_year_becomes_range() {
    start_test "License year: single year becomes a range in a later year"

    local license_file
    license_file=$(create_license_file "Copyright © 2026 Graham Watts")

    "$UPDATE_LICENSE_SCRIPT" "$license_file" 2027 > /dev/null || { fail_test "script failed"; return; }

    assert_file_contains "$license_file" "Copyright © 2026-2027 Graham Watts" || return

    pass_test
}

test_license_year_range_end_year_is_extended() {
    start_test "License year: existing range has its end year extended"

    local license_file
    license_file=$(create_license_file "Copyright © 2026-2027 Graham Watts")

    "$UPDATE_LICENSE_SCRIPT" "$license_file" 2029 > /dev/null || { fail_test "script failed"; return; }

    assert_file_contains "$license_file" "Copyright © 2026-2029 Graham Watts" || return
    assert_file_not_contains "$license_file" "2027" || return

    pass_test
}

test_license_year_current_single_year_is_unchanged() {
    start_test "License year: single year matching the current year is unchanged"

    local license_file
    license_file=$(create_license_file "Copyright © 2026 Graham Watts")
    local before
    before=$(cat "$license_file")

    "$UPDATE_LICENSE_SCRIPT" "$license_file" 2026 > /dev/null || { fail_test "script failed"; return; }

    assert_equals "$before" "$(cat "$license_file")" "File changed when it was already current" || return

    pass_test
}

test_license_year_current_range_is_unchanged() {
    start_test "License year: range already ending in the current year is unchanged"

    local license_file
    license_file=$(create_license_file "Copyright © 2026-2028 Graham Watts")
    local before
    before=$(cat "$license_file")

    "$UPDATE_LICENSE_SCRIPT" "$license_file" 2028 > /dev/null || { fail_test "script failed"; return; }

    assert_equals "$before" "$(cat "$license_file")" "File changed when it was already current" || return

    pass_test
}

test_license_year_repeated_runs_are_idempotent() {
    start_test "License year: running twice in the same year gives the same result"

    local license_file
    license_file=$(create_license_file "Copyright © 2026 Graham Watts")

    "$UPDATE_LICENSE_SCRIPT" "$license_file" 2027 > /dev/null || { fail_test "first run failed"; return; }
    local after_first_run
    after_first_run=$(cat "$license_file")

    "$UPDATE_LICENSE_SCRIPT" "$license_file" 2027 > /dev/null || { fail_test "second run failed"; return; }

    assert_equals "$after_first_run" "$(cat "$license_file")" "Second run changed the file" || return
    assert_file_not_contains "$license_file" "2027-2027" || return

    pass_test
}

test_license_year_successive_years_keep_first_year() {
    start_test "License year: successive years keep the original first year"

    local license_file
    license_file=$(create_license_file "Copyright © 2026 Graham Watts")

    "$UPDATE_LICENSE_SCRIPT" "$license_file" 2027 > /dev/null || { fail_test "2027 run failed"; return; }
    "$UPDATE_LICENSE_SCRIPT" "$license_file" 2028 > /dev/null || { fail_test "2028 run failed"; return; }

    assert_file_contains "$license_file" "Copyright © 2026-2028 Graham Watts" || return

    pass_test
}

test_license_year_rest_of_file_is_preserved() {
    start_test "License year: only the copyright line changes"

    local license_file
    license_file=$(create_license_file "Copyright © 2026 Graham Watts")

    "$UPDATE_LICENSE_SCRIPT" "$license_file" 2027 > /dev/null || { fail_test "script failed"; return; }

    # Compare everything after the first line, including the missing trailing newline.
    local expected_body
    expected_body=$(printf '\nPermission is hereby granted, free of charge.\n\nThe above copyright notice shall be included.x')
    local actual_body
    actual_body=$(tail -n +2 "$license_file"; printf x)

    assert_equals "$expected_body" "$actual_body" "Text outside the copyright line was modified" || return

    pass_test
}

test_license_year_only_first_copyright_line_changes() {
    start_test "License year: a later line mentioning copyright is left alone"

    local license_file="$TEST_DIR/LICENSE"
    printf 'Copyright © 2026 Graham Watts\nCopyright © 2020 Someone Else\n' > "$license_file"

    "$UPDATE_LICENSE_SCRIPT" "$license_file" 2027 > /dev/null || { fail_test "script failed"; return; }

    assert_file_contains "$license_file" "Copyright © 2026-2027 Graham Watts" || return
    assert_file_contains "$license_file" "Copyright © 2020 Someone Else" || return

    pass_test
}

test_license_year_missing_copyright_line_fails() {
    start_test "License year: file without a copyright line fails"

    local license_file="$TEST_DIR/LICENSE"
    printf 'Permission is hereby granted.\n' > "$license_file"

    assert_failure "'$UPDATE_LICENSE_SCRIPT' '$license_file' 2027" || return

    pass_test
}

test_license_year_missing_file_fails() {
    start_test "License year: missing license file fails"

    assert_failure "'$UPDATE_LICENSE_SCRIPT' '$TEST_DIR/does-not-exist' 2027" || return

    pass_test
}

test_license_year_invalid_year_fails_without_changes() {
    start_test "License year: invalid year argument fails and leaves the file alone"

    local license_file
    license_file=$(create_license_file "Copyright © 2026 Graham Watts")
    local before
    before=$(cat "$license_file")

    assert_failure "'$UPDATE_LICENSE_SCRIPT' '$license_file' 27" || return
    assert_failure "'$UPDATE_LICENSE_SCRIPT' '$license_file' next-year" || return
    assert_equals "$before" "$(cat "$license_file")" "File changed despite invalid year" || return

    pass_test
}

test_license_year_start_year_in_future_fails() {
    start_test "License year: notice starting after the target year fails"

    local license_file
    license_file=$(create_license_file "Copyright © 2030 Graham Watts")
    local before
    before=$(cat "$license_file")

    assert_failure "'$UPDATE_LICENSE_SCRIPT' '$license_file' 2027" || return
    assert_equals "$before" "$(cat "$license_file")" "File changed despite start year in the future" || return

    pass_test
}

test_license_year_single_year_becomes_range
test_license_year_range_end_year_is_extended
test_license_year_current_single_year_is_unchanged
test_license_year_current_range_is_unchanged
test_license_year_repeated_runs_are_idempotent
test_license_year_successive_years_keep_first_year
test_license_year_rest_of_file_is_preserved
test_license_year_only_first_copyright_line_changes
test_license_year_missing_copyright_line_fails
test_license_year_missing_file_fails
test_license_year_invalid_year_fails_without_changes
test_license_year_start_year_in_future_fails
