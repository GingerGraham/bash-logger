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

# Arrays to store test results for JUnit XML
declare -a SUITE_NAMES
declare -a SUITE_TESTS_COUNT
declare -a SUITE_FAILURES_COUNT
declare -a SUITE_TIMES
declare -a SUITE_TESTCASES

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
            local test_file_path="tests/${suite_name}.sh"

            echo "  <file path=\"$test_file_path\">"

            # Output testcases for this suite
            IFS='|' read -ra testcases <<< "${SUITE_TESTCASES[$suite_idx]}"
            for testcase in "${testcases[@]}"; do
                if [[ -n "$testcase" ]]; then
                    echo "    $testcase"
                fi
            done

            echo "  </file>"
            suite_idx=$((suite_idx + 1))
        done

        echo "</testExecutions>"
    } > "$output_file"

    echo ""
    echo -e "${COLOR_BLUE}Test execution report written to: $output_file${COLOR_RESET}"
}

# Run a single test suite
run_test_suite() {
    local test_file="$1"
    local test_name
    test_name="$(basename "$test_file" .sh)"

    echo -e "${COLOR_BLUE}Running $test_name...${COLOR_RESET}"

    # Source the test helpers in current shell
    # shellcheck source=tests/test_helpers.sh
    source "$SCRIPT_DIR/test_helpers.sh"

    # Reset test counters for this suite
    suite_tests=0
    suite_passed=0
    suite_failed=0
    suite_skipped=0

    # Reset JUnit testcase collection for this suite
    CURRENT_SUITE_TESTCASES=""
    export JUNIT_OUTPUT CURRENT_SUITE_TESTCASES

    # Record start time for suite
    local suite_start_time
    suite_start_time=$(date +%s.%N 2>/dev/null || date +%s)

    # Source and run the test suite
    # shellcheck source=/dev/null
    source "$test_file"

    # Record end time and calculate duration
    local suite_end_time suite_duration
    suite_end_time=$(date +%s.%N 2>/dev/null || date +%s)
    suite_duration=$(echo "$suite_end_time - $suite_start_time" | bc 2>/dev/null || echo "0")

    # Clean up test suite temporary directory
    cleanup_test_suite

    # Update totals
    TOTAL_TESTS=$((TOTAL_TESTS + suite_tests))
    PASSED_TESTS=$((PASSED_TESTS + suite_passed))
    FAILED_TESTS=$((FAILED_TESTS + suite_failed))
    SKIPPED_TESTS=$((SKIPPED_TESTS + suite_skipped))

    # Store suite results for JUnit XML
    if [[ "$JUNIT_OUTPUT" == "true" ]]; then
        SUITE_NAMES+=("$test_name")
        SUITE_TESTS_COUNT+=("$suite_tests")
        SUITE_FAILURES_COUNT+=("$suite_failed")
        SUITE_TIMES+=("$suite_duration")
        SUITE_TESTCASES+=("$CURRENT_SUITE_TESTCASES")
    fi

    # Print suite summary
    if [[ $suite_failed -eq 0 ]]; then
        echo -e "${COLOR_GREEN}✓ $test_name: $suite_passed passed${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}✗ $test_name: $suite_passed passed, $suite_failed failed${COLOR_RESET}"
    fi
    echo ""
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
            --help|-h)
                echo "Usage: $0 [options] [test_suite...]"
                echo ""
                echo "Options:"
                echo "  --junit          Generate JUnit XML report for CI/SonarQube"
                echo "  --output-dir DIR Directory for reports (default: ../test-reports)"
                echo "  --help, -h       Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0                    # Run all tests"
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

    # Check if logging.sh exists
    if [[ ! -f "$PROJECT_ROOT/logging.sh" ]]; then
        echo -e "${COLOR_RED}Error: logging.sh not found at $PROJECT_ROOT/logging.sh${COLOR_RESET}"
        exit 1
    fi

    # Determine which tests to run
    local test_files=()

    if [[ ${#test_args[@]} -eq 0 ]]; then
        # Discover all test files matching pattern
        while IFS= read -r test_file; do
            test_files+=("$test_file")
        done < <(find "$SCRIPT_DIR" -maxdepth 1 -name "test_*.sh" -type f | sort)
    else
        # Run specified tests
        for test_name in "${test_args[@]}"; do
            # Remove .sh extension if provided
            test_name="${test_name%.sh}"
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

    # Run each test suite
    for test_file in "${test_files[@]}"; do
        if [[ -f "$test_file" ]]; then
            run_test_suite "$test_file"
        fi
    done

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
