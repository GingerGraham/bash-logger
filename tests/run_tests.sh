#!/usr/bin/env bash
#
# run_tests.sh - Test runner for bash-logger module
#
# This script runs all test suites and reports results.
# Usage: ./run_tests.sh [options] [test_suite...]
#
# Options:
#   --junit          Generate JUnit XML report for CI/SonarQube integration
#   --output-dir DIR Directory for reports (default: ../test-reports)
#
# Examples:
#   ./run_tests.sh                    # Run all tests
#   ./run_tests.sh test_log_levels    # Run specific test suite
#   ./run_tests.sh --junit            # Run all tests with JUnit XML output
#   ./run_tests.sh test_log_levels test_format  # Run multiple specific suites

# Note: We don't use set -e here because tests may return non-zero on purpose
set -uo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# JUnit XML output options
JUNIT_OUTPUT=false
OUTPUT_DIR="$PROJECT_ROOT/test-reports"

# Fail-fast: stop after the first suite that has failures
FAIL_FAST=false

# Parallel execution options
# Auto-detect available cores as a baseline
system_cores=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "1")
# Use reasonable caps to avoid excessive resource contention
max_jobs=8

# Check environment variable first, then fall back to auto-detect
if [[ -n "${TEST_PARALLEL_JOBS:-}" ]]; then
    # Validate TEST_PARALLEL_JOBS is a positive integer
    if [[ "$TEST_PARALLEL_JOBS" =~ ^[0-9]+$ ]] && [[ $TEST_PARALLEL_JOBS -gt 0 ]]; then
        PARALLEL_JOBS="$TEST_PARALLEL_JOBS"
        # Warn if user value exceeds system capabilities
        if [[ $PARALLEL_JOBS -gt $system_cores ]]; then
            echo "Warning: TEST_PARALLEL_JOBS=$PARALLEL_JOBS exceeds system cores ($system_cores); note: parallel jobs will be limited to max_jobs=$max_jobs to avoid contention" >&2
        fi
    else
        echo "Warning: Invalid TEST_PARALLEL_JOBS='$TEST_PARALLEL_JOBS', falling back to auto-detect" >&2
        PARALLEL_JOBS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "1")
    fi
else
    PARALLEL_JOBS="$system_cores"
fi

# Cap at 8 to avoid excessive resource contention
if [[ $PARALLEL_JOBS -gt $max_jobs ]]; then
    PARALLEL_JOBS=$max_jobs
fi
RESULTS_DIR=""   # Temporary directory for isolated suite results

# Arrays to store test results for JUnit XML
declare -a SUITE_NAMES
declare -a SUITE_TESTS_COUNT
declare -a SUITE_FAILURES_COUNT
declare -a SUITE_TIMES
declare -a SUITE_TESTCASES
declare -a SUITE_ERRORS

# Colors for output
if [[ -t 1 ]]; then
    COLOR_GREEN="\033[0;32m"
    COLOR_RED="\033[0;31m"
    COLOR_YELLOW="\033[0;33m"
    COLOR_BLUE="\033[0;34m"
    COLOR_RESET="\033[0m"
else
    COLOR_GREEN=""
    COLOR_RED=""
    COLOR_YELLOW=""
    COLOR_BLUE=""
    COLOR_RESET=""
fi

# Test statistics
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Store failed test details
declare -a FAILED_TEST_DETAILS

# Export variables for test suites
export PROJECT_ROOT
export SCRIPT_DIR

# Print banner
print_banner() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Bash Logger Test Suite"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Escape runner-generated paths and errors without the testcase pipe delimiter.
runner_xml_escape() {
    printf '%s' "$1" \
        | LC_ALL=C tr -d '\000-\010\013\014\016-\037' \
        | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' \
            -e "s/'/\&apos;/g" -e 's/"/\&quot;/g'
}

# Generate SonarQube Generic Test Execution report
generate_junit_xml() {
    local output_file="$1"

    mkdir -p "$(dirname "$output_file")"

    {
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo '<testExecutions version="1">'

        local suite_idx=0
        for suite_name in "${SUITE_NAMES[@]+"${SUITE_NAMES[@]}"}"; do
            # Path relative to project root for the test file
            local test_file_path
            test_file_path=$(runner_xml_escape "tests/${suite_name}.sh")

            echo "  <file path=\"$test_file_path\">"

            # Output testcases for this suite
            IFS='|' read -ra testcases <<< "${SUITE_TESTCASES[$suite_idx]}"
            for testcase in "${testcases[@]}"; do
                if [[ -n "$testcase" ]]; then
                    echo "    $testcase"
                fi
            done

            if [[ -n "${SUITE_ERRORS[$suite_idx]}" ]]; then
                local escaped_name escaped_error
                escaped_name=$(runner_xml_escape "$suite_name: suite error")
                escaped_error=$(runner_xml_escape "${SUITE_ERRORS[$suite_idx]}")
                printf '    <testCase name="%s" duration="0"><error message="%s"/></testCase>\n' \
                    "$escaped_name" "$escaped_error"
            fi

            echo "  </file>"
            suite_idx=$((suite_idx + 1))
        done

        echo "</testExecutions>"
    } > "$output_file"

    echo ""
    echo -e "${COLOR_BLUE}Test execution report written to: $output_file${COLOR_RESET}"
}

# Snapshot completed test results even when a sourced suite exits or hits nounset.
# Called by the worker's EXIT trap; worker locals remain in scope in its subshell.
write_suite_results() {
    local suite_status="$1"
    set +e
    local suite_end_time suite_duration
    suite_end_time=$(date +%s.%N 2>/dev/null || date +%s)
    suite_duration=$(echo "$suite_end_time - $suite_start_time" | bc 2>/dev/null || echo "0")

    cleanup_test_suite

    if [[ "$suite_completed" == "true" && "$suite_status" -eq 0 && "$suite_tests" -gt 0 ]]; then
        if [[ "$suite_failed" -eq 0 ]]; then
            echo -e "${COLOR_GREEN}✓ $test_name: $suite_passed passed${COLOR_RESET}"
        else
            echo -e "${COLOR_RED}✗ $test_name: $suite_passed passed, $suite_failed failed${COLOR_RESET}"
        fi
    fi
    echo ""

    {
        echo "SUITE_TESTS=$suite_tests"
        echo "SUITE_PASSED=$suite_passed"
        echo "SUITE_FAILED=$suite_failed"
        echo "SUITE_SKIPPED=$suite_skipped"
        echo "SUITE_DURATION=$suite_duration"
        echo "SUITE_COMPLETED=$suite_completed"
        echo "SUITE_TESTCASES_START"
        echo "$CURRENT_SUITE_TESTCASES"
        echo "SUITE_TESTCASES_END"
        echo "FAILED_DETAILS_START"
        for _detail in "${FAILED_TEST_DETAILS[@]+"${FAILED_TEST_DETAILS[@]}"}"; do
            printf '%s\n' "$_detail"
        done
        echo "FAILED_DETAILS_END"
        echo "RESULTS_COMPLETE"
    } > "$results_file"
}

# Isolate both sequential and parallel suites, including shell options and exits.
run_test_suite() (
    local test_file="$1"
    local results_file="$2"
    local test_name
    test_name="$(basename "$test_file" .sh)"

    echo -e "${COLOR_BLUE}Running $test_name...${COLOR_RESET}"

    # shellcheck source=tests/test_helpers.sh disable=SC1091
    source "$SCRIPT_DIR/test_helpers.sh"
    FAILED_TEST_DETAILS=()
    CURRENT_SUITE_TESTCASES=""
    export JUNIT_OUTPUT

    local suite_completed=false
    local suite_start_time
    suite_start_time=$(date +%s.%N 2>/dev/null || date +%s)
    trap 'write_suite_results "$?"' EXIT

    # Do not put source or this worker in an if/||: that disables suite errexit.
    # shellcheck source=/dev/null
    source "$test_file"
    local suite_status=$?
    suite_completed=true
    exit "$suite_status"
)

# Account for one dispatched suite using its identity and collected exit status.
aggregate_suite_result() {
    local test_file="$1" result_file="$2" suite_status="$3"
    local test_name
    test_name="$(basename "$test_file" .sh)"
    local suite_tests=0 suite_passed=0 suite_failed=0 suite_skipped=0 suite_duration=0
    local suite_completed=false results_complete=false
    local in_testcases=false in_failed_details=false
    local testcases_content="" suite_error="" output_tail=""
    local suite_failed_details=()

    if [[ -f "$result_file" ]]; then
        while IFS= read -r line; do
            if [[ "$line" == "SUITE_TESTCASES_START" ]]; then
                in_testcases=true
                continue
            elif [[ "$line" == "SUITE_TESTCASES_END" ]]; then
                in_testcases=false
                continue
            elif [[ "$line" == "FAILED_DETAILS_START" ]]; then
                in_failed_details=true
                continue
            elif [[ "$line" == "FAILED_DETAILS_END" ]]; then
                in_failed_details=false
                continue
            fi

            if [[ "$in_testcases" == "true" ]]; then
                testcases_content+="$line"
            elif [[ "$in_failed_details" == "true" ]]; then
                [[ -n "$line" ]] && suite_failed_details+=("$line")
            else
                case "$line" in
                    SUITE_TESTS=*) suite_tests="${line#SUITE_TESTS=}" ;;
                    SUITE_PASSED=*) suite_passed="${line#SUITE_PASSED=}" ;;
                    SUITE_FAILED=*) suite_failed="${line#SUITE_FAILED=}" ;;
                    SUITE_SKIPPED=*) suite_skipped="${line#SUITE_SKIPPED=}" ;;
                    SUITE_DURATION=*) suite_duration="${line#SUITE_DURATION=}" ;;
                    SUITE_COMPLETED=*) suite_completed="${line#SUITE_COMPLETED=}" ;;
                    RESULTS_COMPLETE) results_complete=true ;;
                esac
            fi
        done < "$result_file"
    fi

    # An interrupted write is not a reliable snapshot; do not report partial
    # passes or XML as if the complete set of results had been received.
    if [[ "$results_complete" != "true" ]]; then
        suite_tests=0 suite_passed=0 suite_failed=0 suite_skipped=0 suite_duration=0
        testcases_content=""
    else
        for detail in "${suite_failed_details[@]+"${suite_failed_details[@]}"}"; do
            FAILED_TEST_DETAILS+=("$detail")
        done
    fi

    if [[ "$results_complete" != "true" ]]; then
        suite_error="$test_name: suite exited with status $suite_status before reporting results"
    elif [[ "$suite_completed" != "true" ]]; then
        suite_error="$test_name: suite exited with status $suite_status before completing"
    elif [[ "$suite_status" -ne 0 ]]; then
        suite_error="$test_name: suite exited with status $suite_status"
    elif [[ "$suite_tests" -eq 0 ]]; then
        suite_error="$test_name: reported 0 tests (exit status $suite_status)"
    fi

    local output_file="${result_file}.output"
    if [[ -n "$suite_error" ]]; then
        FAILED_TEST_DETAILS+=("$suite_error")
        # Keep completed results, and represent an interrupted test (or the suite
        # itself) as one synthetic error rather than silently losing the suite.
        suite_failed=$((suite_failed + 1))
        suite_tests=$((suite_passed + suite_failed + suite_skipped))
        printf '%s\n' "$suite_error"
        if [[ -f "$output_file" ]]; then
            output_tail=$(tail -n 20 "$output_file")
            printf 'Last 20 lines of %s output:\n%s\n\n' "$test_name" "$output_tail"
            suite_error+=$'\n'"$output_tail"
        fi
    elif [[ -f "$output_file" ]]; then
        cat "$output_file"
    fi

    TOTAL_TESTS=$((TOTAL_TESTS + suite_tests))
    PASSED_TESTS=$((PASSED_TESTS + suite_passed))
    FAILED_TESTS=$((FAILED_TESTS + suite_failed))
    SKIPPED_TESTS=$((SKIPPED_TESTS + suite_skipped))

    if [[ "$JUNIT_OUTPUT" == "true" ]]; then
        SUITE_NAMES+=("$test_name")
        SUITE_TESTS_COUNT+=("$suite_tests")
        SUITE_FAILURES_COUNT+=("$suite_failed")
        SUITE_TIMES+=("$suite_duration")
        SUITE_TESTCASES+=("$testcases_content")
        SUITE_ERRORS+=("$suite_error")
    fi
}

# Job control for parallel execution
wait_for_job_slot() {
    local max_jobs="$1"
    while (( $(jobs -r | wc -l) >= max_jobs )); do
        sleep 0.1
    done
}

# Print final summary
print_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Test Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Total Tests:   $TOTAL_TESTS"
    echo -e "${COLOR_GREEN}Passed:        $PASSED_TESTS${COLOR_RESET}"

    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo -e "${COLOR_RED}Failed:        $FAILED_TESTS${COLOR_RESET}"
    else
        echo "Failed:        $FAILED_TESTS"
    fi

    if [[ $SKIPPED_TESTS -gt 0 ]]; then
        echo -e "${COLOR_YELLOW}Skipped:       $SKIPPED_TESTS${COLOR_RESET}"
    fi

    echo ""

    # Print failed test details if any
    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Failed Tests"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        for detail in "${FAILED_TEST_DETAILS[@]}"; do
            echo -e "${COLOR_RED}$detail${COLOR_RESET}"
        done
        echo ""
    fi

    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${COLOR_GREEN}All tests passed!${COLOR_RESET}"
        echo ""
        return 0
    else
        echo -e "${COLOR_RED}Some tests failed.${COLOR_RESET}"
        echo ""
        return 1
    fi
}

# Main execution
main() {
    # Parse command line options
    local test_args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --junit)
                JUNIT_OUTPUT=true
                shift
                ;;
            --output-dir)
                if [[ -z "${2:-}" ]]; then
                    echo "Error: --output-dir requires a directory argument" >&2
                    exit 1
                fi
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -j|--parallel)
                if [[ -z "${2:-}" ]]; then
                    echo "Error: -j/--parallel requires a number argument" >&2
                    exit 1
                fi
                PARALLEL_JOBS="$2"
                if ! [[ "$PARALLEL_JOBS" =~ ^[0-9]+$ ]] || [[ "$PARALLEL_JOBS" -lt 1 ]]; then
                    echo "Error: parallel jobs must be a positive integer" >&2
                    exit 1
                fi
                shift 2
                ;;
            --fail-fast|-x)
                FAIL_FAST=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [options] [test_suite...]"
                echo ""
                echo "Options:"
                echo "  --junit          Generate JUnit XML report for CI/SonarQube"
                echo "  --output-dir DIR Directory for reports (default: ../test-reports)"
                echo "  -j, --parallel N Run N test suites in parallel (auto-detect cores by default, max 8)"
                echo "  -x, --fail-fast  Stop after the first suite that contains a failure"
                echo "  --help, -h       Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0                    # Run all tests"
                echo "  $0 -j 4               # Run tests with 4 parallel jobs"
                echo "  $0 --fail-fast        # Stop at first failure (useful for debugging)"
                echo "  $0 --junit            # Run tests with JUnit XML output"
                echo "  $0 test_log_levels    # Run specific test suite"
                exit 0
                ;;
            *)
                test_args+=("$1")
                shift
                ;;
        esac
    done

    print_banner

    if [[ "$JUNIT_OUTPUT" == "true" ]]; then
        echo -e "${COLOR_BLUE}JUnit XML output enabled${COLOR_RESET}"
        # Warn if bc is not available (needed for accurate timing)
        if ! command -v bc >/dev/null 2>&1; then
            echo -e "${COLOR_YELLOW}Warning: 'bc' not found - test durations will show as 0${COLOR_RESET}"
        fi
        echo ""
    fi

    # Fail-fast requires sequential execution to guarantee stopping at the first failure
    if [[ "$FAIL_FAST" == "true" && "$PARALLEL_JOBS" -gt 1 ]]; then
        echo -e "${COLOR_YELLOW}Fail-fast mode: forcing sequential execution (overrides -j $PARALLEL_JOBS)${COLOR_RESET}"
        echo ""
        PARALLEL_JOBS=1
    fi

    if [[ "$PARALLEL_JOBS" -gt 1 ]]; then
        echo -e "${COLOR_BLUE}Running tests with $PARALLEL_JOBS parallel jobs${COLOR_RESET}"
        echo ""
    fi

    if [[ "$FAIL_FAST" == "true" ]]; then
        echo -e "${COLOR_YELLOW}Fail-fast enabled: will stop after the first suite with failures${COLOR_RESET}"
        echo ""
    fi

    # Check if logging.sh exists
    if [[ ! -f "$PROJECT_ROOT/logging.sh" ]]; then
        echo -e "${COLOR_RED}Error: logging.sh not found at $PROJECT_ROOT/logging.sh${COLOR_RESET}"
        exit 1
    fi

    # Determine which tests to run
    local test_files=()

    if [[ ${#test_args[@]} -eq 0 ]]; then
        # Discover all test files matching pattern, excluding the example template
        while IFS= read -r test_file; do
            test_files+=("$test_file")
        done < <(find "$SCRIPT_DIR" -maxdepth 1 -name "test_*.sh" -not -name "test_example.sh" -not -name "test_helpers.sh" -type f | sort)
    else
        # Run specified tests
        for test_name in "${test_args[@]}"; do
            # Remove .sh extension if provided
            test_name="${test_name%.sh}"

            # test_helpers.sh contains shared helper functions, not a runnable test suite
            if [[ "$test_name" == "test_helpers" ]]; then
                echo -e "${COLOR_YELLOW}Warning: Skipping helper file (not a test suite): $SCRIPT_DIR/test_helpers.sh${COLOR_RESET}"
                continue
            fi

            # Add .sh extension
            test_file="$SCRIPT_DIR/${test_name}.sh"

            if [[ ! -f "$test_file" ]]; then
                echo -e "${COLOR_YELLOW}Warning: Test file not found: $test_file${COLOR_RESET}"
                continue
            fi

            test_files+=("$test_file")
        done
    fi

    # Check if we have any valid test files
    if [[ ${#test_files[@]} -eq 0 ]]; then
        echo -e "${COLOR_RED}Error: No valid test files found${COLOR_RESET}"
        exit 1
    fi

    # Every dispatched suite gets a result path, PID and exit status in either mode.
    RESULTS_DIR="$(mktemp -d -t bash-logger-results.XXXXXX)" || return 1
    trap 'rm -rf "$RESULTS_DIR"' EXIT
    local suite_pids=() suite_statuses=()
    local suite_idx=0 result_file suite_status

    if [[ "$PARALLEL_JOBS" -gt 1 ]]; then
        local total_suites=${#test_files[@]}
        echo -e "${COLOR_BLUE}Dispatching $total_suites test suites...${COLOR_RESET}"
        echo ""

        for test_file in "${test_files[@]}"; do
            wait_for_job_slot "$PARALLEL_JOBS"
            local test_name
            test_name="$(basename "$test_file" .sh)"
            result_file="$RESULTS_DIR/result_${suite_idx}.txt"
            echo -e "${COLOR_BLUE}→${COLOR_RESET} Dispatching $test_name [$((suite_idx + 1))/$total_suites]"
            run_test_suite "$test_file" "$result_file" >"${result_file}.output" 2>&1 &
            suite_pids+=("$!")
            suite_idx=$((suite_idx + 1))
        done

        echo ""
        echo -e "${COLOR_BLUE}All test suites dispatched. Waiting for completion...${COLOR_RESET}"
        for suite_pid in "${suite_pids[@]}"; do
            wait "$suite_pid"
            suite_statuses+=("$?")
        done
        echo ""

        for ((suite_idx=0; suite_idx<${#test_files[@]}; suite_idx++)); do
            aggregate_suite_result "${test_files[$suite_idx]}" \
                "$RESULTS_DIR/result_${suite_idx}.txt" "${suite_statuses[$suite_idx]}"
        done
    else
        for test_file in "${test_files[@]}"; do
            result_file="$RESULTS_DIR/result_${suite_idx}.txt"
            # Launch and wait explicitly so errexit is preserved inside the suite.
            run_test_suite "$test_file" "$result_file" >"${result_file}.output" 2>&1 &
            suite_pids+=("$!")
            wait "${suite_pids[$suite_idx]}"
            suite_status=$?
            suite_statuses+=("$suite_status")
            aggregate_suite_result "$test_file" "$result_file" "$suite_status"
            suite_idx=$((suite_idx + 1))
            if [[ "$FAIL_FAST" == "true" && $FAILED_TESTS -gt 0 ]]; then
                echo -e "${COLOR_RED}Fail-fast: stopping after first failed suite${COLOR_RESET}"
                echo ""
                break
            fi
        done
    fi

    rm -rf "$RESULTS_DIR"
    trap - EXIT

    # Print summary
    print_summary
    local exit_status=$?

    # Generate JUnit XML if requested
    if [[ "$JUNIT_OUTPUT" == "true" ]]; then
        generate_junit_xml "$OUTPUT_DIR/junit.xml"
    fi

    return $exit_status
}

# Run main function
main "$@"
