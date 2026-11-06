#!/usr/bin/env bash
#
# test_shell_compat.sh - Differential tests across shells (Issue #143)
#
# Each scenario in tests/compat/scenarios/ is a short POSIX sh script that sources
# logging.sh with "." and exercises one area of behaviour. This suite runs every
# scenario under bash to get the reference result, then under each other shell in
# TEST_SHELLS, and compares:
#   * stdout
#   * stderr
#   * the content of $SCENARIO_DIR/test.log, when the scenario writes it
#   * the exit status
# Timestamps are masked before the comparison.
#
# Environment:
#   TEST_SHELLS          Space-separated list of shell commands. A command can include
#                        flags; separate commands with commas when they contain spaces,
#                        e.g. "bash,bash --posix,zsh,dash,busybox sh".
#                        Default: bash
#   TEST_REQUIRE_SHELLS  Shells that must be installed (see require_shell); a missing
#                        shell then fails instead of skipping.
#
# A scenario can set its locale with a header line, for example:
#   # compat-locale: C.UTF-8
# Scenarios without the header run with LC_ALL=C.
#
# Known failures are listed in tests/compat/known_failures.txt, one per line, as
#   <shell command>|<scenario file name>
# A listed pair that differs from bash is reported as skipped. A listed pair that now
# matches bash fails, so the list is kept current.

COMPAT_DIR="$PROJECT_ROOT/tests/compat"
COMPAT_SCENARIO_DIR="$COMPAT_DIR/scenarios"
COMPAT_KNOWN_FAILURES="$COMPAT_DIR/known_failures.txt"
COMPAT_TIMEOUT_SECONDS=60

# Print the locale a scenario asks for, or C.
compat_scenario_locale() {
    local scenario_file="$1"
    local locale_line
    locale_line=$(grep -m 1 '^# compat-locale:' "$scenario_file" 2>/dev/null)
    if [[ -n "$locale_line" ]]; then
        printf '%s\n' "${locale_line#\# compat-locale: }"
    else
        printf 'C\n'
    fi
}

# Return 0 if the named locale is installed.
compat_locale_available() {
    local wanted="$1"
    local normalized_wanted
    normalized_wanted=$(printf '%s' "$wanted" | tr '[:upper:]' '[:lower:]' | tr -d '-')
    if [[ "$normalized_wanted" == "c" || "$normalized_wanted" == "posix" ]]; then
        return 0
    fi
    locale -a 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -d '-' \
        | grep -qx "$normalized_wanted"
}

# Replace timestamps with a fixed marker.
compat_mask() {
    sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/<TIMESTAMP>/g'
}

# Run one scenario under one shell command and store the masked results.
# Arguments: shell command, scenario file, result directory
# The scenario always runs in the same working directory, so file paths in
# messages are identical across shells.
compat_run_scenario() {
    local shell_command="$1"
    local scenario_file="$2"
    local result_dir="$3"
    local work_dir="$TEST_TMP_DIR/compat-work"
    local scenario_locale
    scenario_locale=$(compat_scenario_locale "$scenario_file")

    rm -rf "$work_dir"
    mkdir -p "$work_dir" "$result_dir"

    # The environment is rebuilt from scratch so settings exported by the test runner
    # (or the developer's shell) cannot change the result.
    # shellcheck disable=SC2086  # word splitting of shell_command is intended
    (
        cd "$work_dir" || exit 1
        run_with_timeout "$COMPAT_TIMEOUT_SECONDS" \
            env -i PATH="$PATH" HOME="$work_dir" LC_ALL="$scenario_locale" \
                LOGGER_ROOT="$PROJECT_ROOT" SCENARIO_DIR="$work_dir" \
                $shell_command "$scenario_file" \
                >"$result_dir/stdout.raw" 2>"$result_dir/stderr.raw" </dev/null
    )
    printf '%s\n' "$?" > "$result_dir/status"

    compat_mask < "$result_dir/stdout.raw" > "$result_dir/stdout"
    compat_mask < "$result_dir/stderr.raw" > "$result_dir/stderr"
    if [[ -f "$work_dir/test.log" ]]; then
        compat_mask < "$work_dir/test.log" > "$result_dir/log"
    else
        printf '<no log file>\n' > "$result_dir/log"
    fi
    rm -f "$result_dir/stdout.raw" "$result_dir/stderr.raw"
}

# Return 0 if a shell/scenario pair is listed as a known failure.
compat_is_known_failure() {
    local shell_command="$1"
    local scenario_name="$2"
    [[ -f "$COMPAT_KNOWN_FAILURES" ]] || return 1
    grep -v '^#' "$COMPAT_KNOWN_FAILURES" | grep -qxF "${shell_command}|${scenario_name}"
}

# Print a short diff of the first result that differs, for the test log.
compat_show_difference() {
    local reference_dir="$1"
    local candidate_dir="$2"
    local part
    for part in status stdout stderr log; do
        if ! cmp -s "$reference_dir/$part" "$candidate_dir/$part"; then
            echo "    --- bash $part / +++ candidate $part (first 40 lines)"
            diff -u "$reference_dir/$part" "$candidate_dir/$part" \
                | sed -n '3,42p' | sed 's/^/    /'
        fi
    done
}

# Return 0 if two result directories are identical.
compat_results_match() {
    local reference_dir="$1"
    local candidate_dir="$2"
    local part
    for part in status stdout stderr log; do
        cmp -s "$reference_dir/$part" "$candidate_dir/$part" || return 1
    done
    return 0
}

# Directory name for a shell command's results, e.g. "busybox sh" -> busybox_sh
compat_result_name() {
    printf '%s' "$1" | tr -c 'a-zA-Z0-9' '_'
}

# Test: one scenario under one shell gives the same results as bash
test_compat_scenario_in_shell() {
    local shell_command="$1"
    local scenario_file="$2"
    local scenario_name
    scenario_name=$(basename "$scenario_file")

    start_test "compat [$shell_command] $scenario_name matches bash"

    local shell_name="${shell_command%% *}"
    require_shell "$shell_name" || return 0

    local scenario_locale
    scenario_locale=$(compat_scenario_locale "$scenario_file")
    if ! compat_locale_available "$scenario_locale"; then
        skip_test "locale $scenario_locale is not installed"
        return 0
    fi

    local results_root="$TEST_TMP_DIR/compat-results/${scenario_name%.sh}"
    local reference_dir="$results_root/bash"
    if [[ ! -f "$reference_dir/status" ]]; then
        compat_run_scenario "bash" "$scenario_file" "$reference_dir"
    fi

    # The bash run is the reference; it only has to finish
    if [[ "$shell_command" == "bash" ]]; then
        local reference_status
        reference_status=$(cat "$reference_dir/status")
        if [[ "$reference_status" -ge 124 ]]; then
            fail_test "bash run did not finish (status $reference_status)"
            return 0
        fi
        pass_test
        return 0
    fi

    local candidate_dir
    candidate_dir="$results_root/$(compat_result_name "$shell_command")"
    compat_run_scenario "$shell_command" "$scenario_file" "$candidate_dir"

    if compat_results_match "$reference_dir" "$candidate_dir"; then
        if compat_is_known_failure "$shell_command" "$scenario_name"; then
            fail_test "Listed in known_failures.txt but now matches bash; remove the entry"
            return 0
        fi
        pass_test
        return 0
    fi

    if compat_is_known_failure "$shell_command" "$scenario_name"; then
        skip_test "known failure (tests/compat/known_failures.txt)"
        return 0
    fi

    fail_test "Results differ from bash (diff below)"
    compat_show_difference "$reference_dir" "$candidate_dir"
    return 0
}

# Test: every known-failure entry names a scenario that exists
test_compat_known_failures_are_valid() {
    start_test "compat known_failures.txt only lists existing scenarios"

    local entry
    local scenario_name
    while IFS= read -r entry || [[ -n "$entry" ]]; do
        case "$entry" in
            ''|'#'*) continue ;;
        esac
        scenario_name="${entry##*|}"
        assert_file_exists "$COMPAT_SCENARIO_DIR/$scenario_name" \
            "known_failures.txt entry '$entry' names a missing scenario" || return
    done < "$COMPAT_KNOWN_FAILURES"

    pass_test
}

# Run all tests
test_compat_known_failures_are_valid

compat_shells=$(test_shell_list)
for compat_scenario_file in "$COMPAT_SCENARIO_DIR"/*.sh; do
    while IFS= read -r compat_shell_command; do
        test_compat_scenario_in_shell "$compat_shell_command" "$compat_scenario_file"
    done <<< "$compat_shells"
done
