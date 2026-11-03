#!/usr/bin/env bash
#
# test_bash32_compat_check.sh - Tests for scripts/check-bash32-compat.sh
#
# Tests:
# - Each bash 4+ construct is reported
# - Bash 3.2 compatible code passes
# - Comment-only lines and exempted lines are ignored
# - Constructs that only look like bash 4+ syntax are not reported
# - The shipped logging.sh passes the check

CHECK_SCRIPT="$PROJECT_ROOT/scripts/check-bash32-compat.sh"

# Write one line of shell to $TEST_DIR/sample.sh, run the check on it, and set
# check_status and check_output.
run_check_on_line() {
    local sample_line="$1"
    local sample_file="$TEST_DIR/sample.sh"

    printf '%s\n' "$sample_line" > "$sample_file"
    check_output=$("$CHECK_SCRIPT" "$sample_file" 2>&1)
    check_status=$?
}

# Assert that the check rejects a line and names the offending file.
assert_line_rejected() {
    local sample_line="$1"

    run_check_on_line "$sample_line"
    assert_equals "1" "$check_status" "Should reject: $sample_line" || return
    assert_contains "$check_output" "sample.sh:1:" "Should name the line for: $sample_line" || return
}

# Assert that the check accepts a line.
assert_line_accepted() {
    local sample_line="$1"

    run_check_on_line "$sample_line"
    assert_equals "0" "$check_status" "Should accept: $sample_line ($check_output)" || return
}

test_compat_check_rejects_case_modification() {
    start_test "Bash 3.2 check: rejects case-modification expansions"

    assert_line_rejected 'x="${name,,}"' || return
    assert_line_rejected 'x="${name^^}"' || return
    assert_line_rejected 'x="${name,}"' || return
    assert_line_rejected 'x="${name^}"' || return
    assert_line_rejected 'x="${1,,}"' || return
    assert_line_rejected 'x="${names[0],,}"' || return

    pass_test
}

test_compat_check_rejects_arrays_and_namerefs() {
    start_test "Bash 3.2 check: rejects associative arrays and namerefs"

    assert_line_rejected 'declare -A table' || return
    assert_line_rejected 'local -A table' || return
    assert_line_rejected 'declare -n ref=target' || return
    assert_line_rejected 'local -n ref=target' || return
    assert_line_rejected 'mapfile -t lines < input' || return
    assert_line_rejected 'readarray -t lines < input' || return
    assert_line_rejected 'last="${items[-1]}"' || return

    pass_test
}

test_compat_check_rejects_operators_and_redirections() {
    start_test "Bash 3.2 check: rejects bash 4+ operators and redirections"

    assert_line_rejected 'if [[ -v name ]]; then :; fi' || return
    assert_line_rejected 'if [[ ! -v name ]]; then :; fi' || return
    assert_line_rejected 'cmd &>> out.log' || return
    assert_line_rejected 'cmd |& tee out.log' || return
    assert_line_rejected 'x="${name@Q}"' || return
    assert_line_rejected 'exec {log_fd}>out.log' || return

    pass_test
}

test_compat_check_rejects_builtins_and_variables() {
    start_test "Bash 3.2 check: rejects bash 4+ builtins and variables"

    assert_line_rejected 'coproc worker { cat; }' || return
    assert_line_rejected "printf '%(%Y)T' -1" || return
    assert_line_rejected 'now=$EPOCHSECONDS' || return
    assert_line_rejected 'now=${EPOCHREALTIME}' || return

    pass_test
}

test_compat_check_accepts_compatible_code() {
    start_test "Bash 3.2 check: accepts bash 3.2 compatible code"

    assert_line_accepted 'x=$(printf "%s" "$name" | tr "[:upper:]" "[:lower:]")' || return
    assert_line_accepted 'if [[ -n "${name:-}" && "$name" == "a" ]]; then :; fi' || return
    assert_line_accepted 'declare -a items=(a b c)' || return
    assert_line_accepted 'last="${items[${#items[@]}-1]}"' || return
    assert_line_accepted 'cmd >> out.log 2>&1' || return
    assert_line_accepted 'cmd1 || cmd2 && cmd3' || return
    assert_line_accepted "pattern='(rm|dd)|&& *rm'" || return
    assert_line_accepted 'x="${name:-a,b}"' || return
    assert_line_accepted 'x="${prefix}>"' || return
    assert_line_accepted 'x="${name//,/ }"' || return

    pass_test
}

test_compat_check_ignores_comments_and_marked_lines() {
    start_test "Bash 3.2 check: ignores comment lines and exempted lines"

    assert_line_accepted '# Replacement for ${name,,} and declare -A' || return
    assert_line_accepted '    # mapfile is not used here' || return
    assert_line_accepted 'x="${name,,}"  # bash32-compat: ignore' || return

    pass_test
}

test_compat_check_reports_every_violation() {
    start_test "Bash 3.2 check: reports every violation, not only the first"

    printf '%s\n' 'x="${a,,}"' 'declare -A table' 'mapfile -t l < f' > "$TEST_DIR/sample.sh"
    check_output=$("$CHECK_SCRIPT" "$TEST_DIR/sample.sh" 2>&1)
    check_status=$?

    assert_equals "1" "$check_status" || return
    assert_contains "$check_output" "sample.sh:1:" || return
    assert_contains "$check_output" "sample.sh:2:" || return
    assert_contains "$check_output" "sample.sh:3:" || return

    pass_test
}

test_compat_check_missing_file_is_usage_error() {
    start_test "Bash 3.2 check: a missing file is a usage error"

    check_output=$("$CHECK_SCRIPT" "$TEST_DIR/does-not-exist.sh" 2>&1)
    check_status=$?

    assert_equals "2" "$check_status" || return
    assert_contains "$check_output" "file not found" || return

    pass_test
}

test_compat_check_logging_sh_passes() {
    start_test "Bash 3.2 check: logging.sh uses no bash 4+ syntax"

    check_output=$("$CHECK_SCRIPT" 2>&1)
    check_status=$?

    assert_equals "0" "$check_status" "logging.sh failed the check: $check_output" || return

    pass_test
}

# Run all tests
test_compat_check_rejects_case_modification
test_compat_check_rejects_arrays_and_namerefs
test_compat_check_rejects_operators_and_redirections
test_compat_check_rejects_builtins_and_variables
test_compat_check_accepts_compatible_code
test_compat_check_ignores_comments_and_marked_lines
test_compat_check_reports_every_violation
test_compat_check_missing_file_is_usage_error
test_compat_check_logging_sh_passes

# Cleanup after running all tests
cleanup_test_suite
