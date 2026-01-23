#!/usr/bin/env bash
#
# test_install.sh - Tests for install.sh functionality
#
# Tests:
# - Argument parsing
# - Path determination for different install modes
# - Error handling scenarios
# - Helper functions

# Source the install script functions without executing main
# We'll need to create a testable version

# Helper function to run install.sh test script
run_install_test_script() {
    local script_content="$1"
    local test_script="$TEST_DIR/test_script_$$.sh"
    
    cat > "$test_script" << EOF
#!/usr/bin/env bash
set -euo pipefail
INSTALL_SH_TEST_MODE=true
source "\${PROJECT_ROOT}/install.sh"
main() { :; }

$script_content
EOF
    
    bash "$test_script" 2>&1
}

# Helper function to assert command failed
assert_command_failed() {
    local exit_code="$1"
    local message="$2"
    
    if [[ ${exit_code:-0} -eq 0 ]]; then
        fail_test "$message"
        return 1
    fi
    return 0
}

# Test: parse_args with --user option
test_parse_args_user() {
    start_test "parse_args correctly handles --user option"

    local output
    output=$(run_install_test_script '
INSTALL_MODE=""
parse_args --user
echo "INSTALL_MODE=${INSTALL_MODE}"
')

    assert_contains "$output" "INSTALL_MODE=user" "Should set INSTALL_MODE to user" || return

    pass_test
}

# Test: parse_args with --system option
test_parse_args_system() {
    start_test "parse_args correctly handles --system option"

    local output
    output=$(run_install_test_script '
INSTALL_MODE=""
parse_args --system
echo "INSTALL_MODE=${INSTALL_MODE}"
')

    assert_contains "$output" "INSTALL_MODE=system" || return

    pass_test
}

# Test: parse_args with --prefix option
test_parse_args_prefix() {
    start_test "parse_args correctly handles --prefix option"

    local output
    output=$(run_install_test_script '
INSTALL_MODE=""
PREFIX=""
parse_args --prefix /custom/path
echo "INSTALL_MODE=${INSTALL_MODE}"
echo "PREFIX=${PREFIX}"
')

    assert_contains "$output" "INSTALL_MODE=custom" || return
    assert_contains "$output" "PREFIX=/custom/path" || return

    pass_test
}

# Test: parse_args with --prefix but no path argument
test_parse_args_prefix_missing_path() {
    start_test "parse_args fails when --prefix has no path argument"

    local output exit_code=0
    output=$(run_install_test_script 'parse_args --prefix') || exit_code=$?

    assert_command_failed "$exit_code" "Should have failed with missing --prefix argument" || return
    assert_contains "$output" "prefix requires a non-empty path argument" || return

    pass_test
}

# Test: parse_args with --prefix followed by another option
test_parse_args_prefix_with_option() {
    start_test "parse_args fails when --prefix is followed by an option"

    local output exit_code=0
    output=$(run_install_test_script 'parse_args --prefix --user') || exit_code=$?

    assert_command_failed "$exit_code" "Should have failed when --prefix followed by option" || return
    assert_contains "$output" "prefix requires a path argument, not an option" || return

    pass_test
}

# Test: parse_args with --auto-rc option
test_parse_args_auto_rc() {
    start_test "parse_args correctly handles --auto-rc option"

    local output
    output=$(run_install_test_script '
AUTO_RC=false
parse_args --auto-rc
echo "AUTO_RC=${AUTO_RC}"
')

    assert_contains "$output" "AUTO_RC=true" || return

    pass_test
}

# Test: parse_args with --no-backup option
test_parse_args_no_backup() {
    start_test "parse_args correctly handles --no-backup option"

    local output
    output=$(run_install_test_script '
BACKUP=true
parse_args --no-backup
echo "BACKUP=${BACKUP}"
')

    assert_contains "$output" "BACKUP=false" || return

    pass_test
}

# Test: parse_args with --help option
test_parse_args_help() {
    start_test "parse_args exits successfully with --help option"

    local output exit_code=0
    output=$(run_install_test_script 'parse_args --help') || exit_code=$?

    # --help should exit with 0
    if [[ $exit_code -ne 0 ]]; then
        fail_test "Should exit with 0 for --help (exit code: $exit_code)"
        return
    fi

    assert_contains "$output" "Usage:" || return
    assert_contains "$output" "Options:" || return

    pass_test
}

# Test: parse_args with unknown option
test_parse_args_unknown_option() {
    start_test "parse_args fails with unknown option"

    local output exit_code=0
    output=$(run_install_test_script 'parse_args --unknown-option') || exit_code=$?

    assert_command_failed "$exit_code" "Should have failed with unknown option" || return
    assert_contains "$output" "Unknown option" || return
    assert_contains "$output" "--unknown-option" || return

    pass_test
}

# Test: determine_install_paths for user mode
test_determine_install_paths_user() {
    start_test "determine_install_paths sets correct paths for user mode"

    local output
    output=$(run_install_test_script '
INSTALL_MODE="user"
determine_install_paths
echo "INSTALL_PREFIX=${INSTALL_PREFIX}"
echo "INSTALL_DIR=${INSTALL_DIR}"
echo "DOC_DIR=${DOC_DIR}"
')

    assert_contains "$output" "INSTALL_PREFIX=${HOME}/.local" || return
    assert_contains "$output" "INSTALL_DIR=${HOME}/.local/lib/bash-logger" || return
    assert_contains "$output" "DOC_DIR=${HOME}/.local/share/doc/bash-logger" || return

    pass_test
}

# Test: determine_install_paths for system mode
test_determine_install_paths_system() {
    start_test "determine_install_paths sets correct paths for system mode"

    local output
    output=$(run_install_test_script '
INSTALL_MODE="system"
determine_install_paths
echo "INSTALL_PREFIX=${INSTALL_PREFIX}"
echo "INSTALL_DIR=${INSTALL_DIR}"
echo "DOC_DIR=${DOC_DIR}"
')

    assert_contains "$output" "INSTALL_PREFIX=/usr/local" || return
    assert_contains "$output" "INSTALL_DIR=/usr/local/lib/bash-logger" || return
    assert_contains "$output" "DOC_DIR=/usr/local/share/doc/bash-logger" || return

    pass_test
}

# Test: determine_install_paths for custom mode
test_determine_install_paths_custom() {
    start_test "determine_install_paths sets correct paths for custom mode"

    local output
    output=$(run_install_test_script '
INSTALL_MODE="custom"
PREFIX="/custom/prefix"
determine_install_paths
echo "INSTALL_PREFIX=${INSTALL_PREFIX}"
echo "INSTALL_DIR=${INSTALL_DIR}"
echo "DOC_DIR=${DOC_DIR}"
')

    assert_contains "$output" "INSTALL_PREFIX=/custom/prefix" || return
    assert_contains "$output" "INSTALL_DIR=/custom/prefix/lib/bash-logger" || return
    assert_contains "$output" "DOC_DIR=/custom/prefix/share/doc/bash-logger" || return

    pass_test
}

# Test: check_root fails when system mode without root
test_check_root_system_no_root() {
    start_test "check_root fails when system mode without root privileges"

    # Skip if running as root
    if [[ $EUID -eq 0 ]]; then
        skip_test "running as root"
        return
    fi

    local output exit_code=0
    output=$(run_install_test_script '
INSTALL_MODE="system"
check_root
') || exit_code=$?

    assert_command_failed "$exit_code" "Should have failed without root privileges" || return
    assert_contains "$output" "System-wide installation requires root privileges" || return

    pass_test
}

# Test: check_root passes for user mode
test_check_root_user_mode() {
    start_test "check_root passes for user mode"

    local output
    output=$(run_install_test_script '
INSTALL_MODE="user"
check_root
echo "SUCCESS"
')

    assert_contains "$output" "SUCCESS" || return

    pass_test
}

# Test: check_install_prefix_writable with writable directory
test_check_install_prefix_writable_success() {
    start_test "check_install_prefix_writable succeeds with writable directory"

    local output
    output=$(run_install_test_script '
INSTALL_PREFIX="${TEST_TMP_DIR}/writable"
mkdir -p "$INSTALL_PREFIX"
check_install_prefix_writable
echo "SUCCESS"
')

    assert_contains "$output" "SUCCESS" || return

    pass_test
}

# Test: check_install_prefix_writable with non-writable directory
test_check_install_prefix_writable_failure() {
    start_test "check_install_prefix_writable fails with non-writable directory"

    # Skip if running as root (root can write anywhere)
    if [[ $EUID -eq 0 ]]; then
        skip_test "running as root"
        return
    fi

    local output exit_code=0
    output=$(run_install_test_script '
# Try to use a non-writable system directory
INSTALL_PREFIX="/root/test-install"
check_install_prefix_writable
') || exit_code=$?

    assert_command_failed "$exit_code" "Should have failed with non-writable directory" || return
    assert_contains "$output" "No write permission" || return

    pass_test
}

# Test: check_install_prefix_writable with non-existent prefix
test_check_install_prefix_writable_nonexistent() {
    start_test "check_install_prefix_writable handles non-existent prefix"

    local output
    output=$(run_install_test_script '
INSTALL_PREFIX="${TEST_TMP_DIR}/new/path/that/does/not/exist"
check_install_prefix_writable
echo "SUCCESS"
')

    assert_contains "$output" "SUCCESS" || return

    pass_test
}

# Test: info function outputs correctly
test_info_function() {
    start_test "info function outputs with correct format"

    local output
    output=$(run_install_test_script 'info "Test message"')

    assert_contains "$output" "Test message" || return
    # Should contain the arrow prefix
    assert_contains "$output" "==>" || return

    pass_test
}

# Test: error function outputs correctly and exits
test_error_function() {
    start_test "error function outputs with correct format and exits"

    local output exit_code=0
    output=$(run_install_test_script 'error "Test error message"') || exit_code=$?

    assert_command_failed "$exit_code" "error function should exit with non-zero code" || return
    assert_contains "$output" "Error:" || return
    assert_contains "$output" "Test error message" || return

    pass_test
}

# Test: success function outputs correctly
test_success_function() {
    start_test "success function outputs with correct format"

    local output
    output=$(run_install_test_script 'success "Test success message"')

    assert_contains "$output" "Test success message" || return
    assert_contains "$output" "==>" || return

    pass_test
}

# Test: warn function outputs correctly
test_warn_function() {
    start_test "warn function outputs with correct format"

    local output
    output=$(run_install_test_script 'warn "Test warning message"')

    assert_contains "$output" "Warning:" || return
    assert_contains "$output" "Test warning message" || return

    pass_test
}

# Test: Multiple argument combinations
test_parse_args_multiple_options() {
    start_test "parse_args handles multiple options correctly"

    local output
    output=$(run_install_test_script '
INSTALL_MODE=""
PREFIX=""
AUTO_RC=false
BACKUP=true

parse_args --prefix /test/path --auto-rc --no-backup

echo "INSTALL_MODE=${INSTALL_MODE}"
echo "PREFIX=${PREFIX}"
echo "AUTO_RC=${AUTO_RC}"
echo "BACKUP=${BACKUP}"
')

    assert_contains "$output" "INSTALL_MODE=custom" || return
    assert_contains "$output" "PREFIX=/test/path" || return
    assert_contains "$output" "AUTO_RC=true" || return
    assert_contains "$output" "BACKUP=false" || return

    pass_test
}

# Test: parse_args with --skip-verify option
test_parse_args_skip_verify() {
    start_test "parse_args correctly handles --skip-verify option"

    local output
    output=$(run_install_test_script '
SKIP_VERIFY=false
parse_args --skip-verify
echo "SKIP_VERIFY=${SKIP_VERIFY}"
')

    assert_contains "$output" "SKIP_VERIFY=true" || return

    pass_test
}

# Test: detect_checksum_tool finds sha256sum or shasum
test_detect_checksum_tool() {
    start_test "detect_checksum_tool detects available checksum tool"

    local output
    output=$(run_install_test_script '
detect_checksum_tool
echo "CHECKSUM_CMD=${CHECKSUM_CMD}"
')

    # Should find either sha256sum or shasum on most systems
    if [[ "$output" == *"CHECKSUM_CMD=sha256sum"* ]] || [[ "$output" == *"CHECKSUM_CMD=shasum -a 256"* ]]; then
        pass_test
    else
        # If neither is found, that's also valid behavior - just verify the variable is set (possibly empty)
        if [[ "$output" == *"CHECKSUM_CMD="* ]]; then
            pass_test
        else
            fail_test "detect_checksum_tool should set CHECKSUM_CMD variable"
        fi
    fi
}

# Test: verify_file_checksum with valid checksum
test_verify_file_checksum_valid() {
    start_test "verify_file_checksum succeeds with valid checksum"

    local output exit_code=0
    output=$(run_install_test_script '
# Create a test file
TEST_FILE_DIR="${TEST_TMP_DIR}/checksum_test"
mkdir -p "$TEST_FILE_DIR"
echo "test content" > "${TEST_FILE_DIR}/logging.sh"

# Generate correct checksum
detect_checksum_tool
if [[ -z "$CHECKSUM_CMD" ]]; then
    echo "SKIP: No checksum tool available"
    exit 0
fi

if [[ "$CHECKSUM_CMD" == "sha256sum" ]]; then
    sha256sum "${TEST_FILE_DIR}/logging.sh" > "${TEST_FILE_DIR}/logging.sh.sha256"
else
    shasum -a 256 "${TEST_FILE_DIR}/logging.sh" > "${TEST_FILE_DIR}/logging.sh.sha256"
fi

# Verify
if verify_file_checksum "$TEST_FILE_DIR"; then
    echo "VERIFICATION_PASSED"
else
    echo "VERIFICATION_FAILED"
fi
') || exit_code=$?

    # Skip if no checksum tool
    if [[ "$output" == *"SKIP:"* ]]; then
        skip_test "no checksum tool available"
        return
    fi

    assert_contains "$output" "VERIFICATION_PASSED" || return

    pass_test
}

# Test: verify_file_checksum with invalid checksum
test_verify_file_checksum_invalid() {
    start_test "verify_file_checksum fails with invalid checksum"

    local output exit_code=0
    output=$(run_install_test_script '
# Create a test file
TEST_FILE_DIR="${TEST_TMP_DIR}/checksum_test_invalid"
mkdir -p "$TEST_FILE_DIR"
echo "test content" > "${TEST_FILE_DIR}/logging.sh"

# Create incorrect checksum file
echo "0000000000000000000000000000000000000000000000000000000000000000  logging.sh" > "${TEST_FILE_DIR}/logging.sh.sha256"

detect_checksum_tool
if [[ -z "$CHECKSUM_CMD" ]]; then
    echo "SKIP: No checksum tool available"
    exit 0
fi

# Verify should fail
if verify_file_checksum "$TEST_FILE_DIR"; then
    echo "VERIFICATION_PASSED"
else
    echo "VERIFICATION_FAILED"
fi
') || exit_code=$?

    # Skip if no checksum tool
    if [[ "$output" == *"SKIP:"* ]]; then
        skip_test "no checksum tool available"
        return
    fi

    assert_contains "$output" "VERIFICATION_FAILED" || return

    pass_test
}

# Test: verify_file_checksum with missing checksum file
test_verify_file_checksum_missing_file() {
    start_test "verify_file_checksum fails with missing checksum file"

    local output exit_code=0
    output=$(run_install_test_script '
# Create a test file but no checksum file
TEST_FILE_DIR="${TEST_TMP_DIR}/checksum_test_missing"
mkdir -p "$TEST_FILE_DIR"
echo "test content" > "${TEST_FILE_DIR}/logging.sh"

detect_checksum_tool
if [[ -z "$CHECKSUM_CMD" ]]; then
    echo "SKIP: No checksum tool available"
    exit 0
fi

# Verify should fail (no checksum file)
if verify_file_checksum "$TEST_FILE_DIR"; then
    echo "VERIFICATION_PASSED"
else
    echo "VERIFICATION_FAILED"
fi
') || exit_code=$?

    # Skip if no checksum tool
    if [[ "$output" == *"SKIP:"* ]]; then
        skip_test "no checksum tool available"
        return
    fi

    assert_contains "$output" "VERIFICATION_FAILED" || return

    pass_test
}

# Test: verify_release with --skip-verify skips verification
test_verify_release_skip_verify() {
    start_test "verify_release skips verification when --skip-verify is set"

    local output
    output=$(run_install_test_script '
SKIP_VERIFY=true
TEST_FILE_DIR="${TEST_TMP_DIR}/skip_verify_test"
mkdir -p "$TEST_FILE_DIR"
echo "test content" > "${TEST_FILE_DIR}/logging.sh"

if verify_release "v1.0.0" "$TEST_FILE_DIR"; then
    echo "VERIFY_RETURNED_SUCCESS"
else
    echo "VERIFY_RETURNED_FAILURE"
fi
')

    assert_contains "$output" "Skipping checksum verification" || return
    assert_contains "$output" "VERIFY_RETURNED_SUCCESS" || return

    pass_test
}

# Test: verify_release with valid checksum passes
test_verify_release_valid_checksum() {
    start_test "verify_release succeeds with valid checksum"

    local output exit_code=0
    output=$(run_install_test_script '
SKIP_VERIFY=false
TEST_FILE_DIR="${TEST_TMP_DIR}/verify_release_valid"
mkdir -p "$TEST_FILE_DIR"
echo "test content for verification" > "${TEST_FILE_DIR}/logging.sh"

detect_checksum_tool
if [[ -z "$CHECKSUM_CMD" ]]; then
    echo "SKIP: No checksum tool available"
    exit 0
fi

# Generate correct checksum file
if [[ "$CHECKSUM_CMD" == "sha256sum" ]]; then
    sha256sum "${TEST_FILE_DIR}/logging.sh" > "${TEST_FILE_DIR}/logging.sh.sha256"
else
    shasum -a 256 "${TEST_FILE_DIR}/logging.sh" > "${TEST_FILE_DIR}/logging.sh.sha256"
fi

# Mock download_checksum to not actually download (file already exists)
download_checksum() { return 0; }

if verify_release "v1.0.0" "$TEST_FILE_DIR"; then
    echo "VERIFY_RETURNED_SUCCESS"
else
    echo "VERIFY_RETURNED_FAILURE"
fi
') || exit_code=$?

    # Skip if no checksum tool
    if [[ "$output" == *"SKIP:"* ]]; then
        skip_test "no checksum tool available"
        return
    fi

    assert_contains "$output" "Checksum verification passed" || return
    assert_contains "$output" "VERIFY_RETURNED_SUCCESS" || return

    pass_test
}

# Test: verify_release with invalid checksum fails
test_verify_release_invalid_checksum() {
    start_test "verify_release fails with invalid checksum"

    local output exit_code=0
    output=$(run_install_test_script '
SKIP_VERIFY=false
TEST_FILE_DIR="${TEST_TMP_DIR}/verify_release_invalid"
mkdir -p "$TEST_FILE_DIR"
echo "test content for verification" > "${TEST_FILE_DIR}/logging.sh"

detect_checksum_tool
if [[ -z "$CHECKSUM_CMD" ]]; then
    echo "SKIP: No checksum tool available"
    exit 0
fi

# Create incorrect checksum file
echo "0000000000000000000000000000000000000000000000000000000000000000  logging.sh" > "${TEST_FILE_DIR}/logging.sh.sha256"

# Mock download_checksum to not actually download (file already exists)
download_checksum() { return 0; }

if verify_release "v1.0.0" "$TEST_FILE_DIR"; then
    echo "VERIFY_RETURNED_SUCCESS"
else
    echo "VERIFY_RETURNED_FAILURE"
fi
') || exit_code=$?

    # Skip if no checksum tool
    if [[ "$output" == *"SKIP:"* ]]; then
        skip_test "no checksum tool available"
        return
    fi

    # The error function calls exit 1, so we expect failure
    assert_contains "$output" "Checksum verification FAILED" || return

    pass_test
}

# Test: Multiple argument combinations including --skip-verify
test_parse_args_multiple_with_skip_verify() {
    start_test "parse_args handles multiple options including --skip-verify"

    local output
    output=$(run_install_test_script '
INSTALL_MODE=""
PREFIX=""
AUTO_RC=false
BACKUP=true
SKIP_VERIFY=false

parse_args --prefix /test/path --auto-rc --skip-verify

echo "INSTALL_MODE=${INSTALL_MODE}"
echo "PREFIX=${PREFIX}"
echo "AUTO_RC=${AUTO_RC}"
echo "SKIP_VERIFY=${SKIP_VERIFY}"
')

    assert_contains "$output" "INSTALL_MODE=custom" || return
    assert_contains "$output" "PREFIX=/test/path" || return
    assert_contains "$output" "AUTO_RC=true" || return
    assert_contains "$output" "SKIP_VERIFY=true" || return

    pass_test
}

# Test: validate_prefix expands tilde to home directory
test_validate_prefix_tilde_expansion() {
    start_test "validate_prefix expands ~ to home directory"

    local output
    output=$(run_install_test_script '
result=$(validate_prefix "~/test/path")
echo "RESULT=${result}"
')

    assert_contains "$output" "RESULT=${HOME}/test/path" || return

    pass_test
}

# Test: validate_prefix converts relative to absolute path
test_validate_prefix_relative_path() {
    start_test "validate_prefix converts relative path to absolute"

    local output
    output=$(run_install_test_script '
result=$(validate_prefix "relative/path")
echo "RESULT=${result}"
')

    # Should start with / (absolute path)
    if [[ "$output" == *"RESULT=/"* ]]; then
        pass_test
    else
        fail_test "validate_prefix should convert relative path to absolute"
    fi
}

# Test: validate_prefix removes trailing slashes
test_validate_prefix_trailing_slashes() {
    start_test "validate_prefix removes trailing slashes"

    local output
    output=$(run_install_test_script '
result=$(validate_prefix "/test/path///")
echo "RESULT=${result}"
')

    assert_contains "$output" "RESULT=/test/path" || return
    # Make sure trailing slashes are removed
    if [[ "$output" == *"RESULT=/test/path/"* ]]; then
        fail_test "Should remove trailing slashes"
        return
    fi

    pass_test
}

# Test: validate_prefix rejects path with newlines
test_validate_prefix_rejects_newlines() {
    start_test "validate_prefix rejects path containing newlines"

    local output exit_code=0
    output=$(run_install_test_script '
validate_prefix "/test/path
with/newline"
') || exit_code=$?

    assert_command_failed "$exit_code" "Should reject path with newlines" || return
    assert_contains "$output" "invalid newline" || return

    pass_test
}

# Test: validate_prefix rejects whitespace-only path
test_validate_prefix_rejects_whitespace() {
    start_test "validate_prefix rejects whitespace-only path"

    local output exit_code=0
    output=$(run_install_test_script '
validate_prefix "   "
') || exit_code=$?

    assert_command_failed "$exit_code" "Should reject whitespace-only path" || return
    assert_contains "$output" "empty or whitespace" || return

    pass_test
}

# Test: validate_prefix rejects excessively long paths
test_validate_prefix_rejects_long_path() {
    start_test "validate_prefix rejects excessively long paths"

    local output exit_code=0
    output=$(run_install_test_script '
# Create a path longer than 4096 characters
long_path="/$(printf "a%.0s" {1..4100})"
validate_prefix "$long_path"
') || exit_code=$?

    assert_command_failed "$exit_code" "Should reject path longer than 4096 chars" || return
    assert_contains "$output" "too long" || return

    pass_test
}

# Test: validate_prefix warns about tmp directory
test_validate_prefix_warns_tmp() {
    start_test "validate_prefix warns about temporary directory installation"

    local output
    # Capture both stdout and stderr (2>&1) to see the warning
    output=$(run_install_test_script '
result=$(validate_prefix "/tmp/test-install" 2>&1)
echo "WARNING_OUTPUT=${result}"
result2=$(validate_prefix "/tmp/test-install" 2>/dev/null)
echo "RESULT=${result2}"
')

    assert_contains "$output" "Warning:" || return
    assert_contains "$output" "temporary directory" || return
    assert_contains "$output" "RESULT=/tmp/test-install" || return

    pass_test
}

# Test: validate_prefix handles absolute path correctly
test_validate_prefix_absolute_path() {
    start_test "validate_prefix preserves valid absolute path"

    local output
    output=$(run_install_test_script '
result=$(validate_prefix "/usr/local/custom")
echo "RESULT=${result}"
')

    assert_contains "$output" "RESULT=/usr/local/custom" || return

    pass_test
}

# Run all tests
test_parse_args_user
test_parse_args_system
test_parse_args_prefix
test_parse_args_prefix_missing_path
test_parse_args_prefix_with_option
test_parse_args_auto_rc
test_parse_args_no_backup
test_parse_args_help
test_parse_args_unknown_option
test_determine_install_paths_user
test_determine_install_paths_system
test_determine_install_paths_custom
test_check_root_system_no_root
test_check_root_user_mode
test_check_install_prefix_writable_success
test_check_install_prefix_writable_failure
test_check_install_prefix_writable_nonexistent
test_info_function
test_error_function
test_success_function
test_warn_function
test_parse_args_multiple_options
test_parse_args_skip_verify
test_detect_checksum_tool
test_verify_file_checksum_valid
test_verify_file_checksum_invalid
test_verify_file_checksum_missing_file
test_verify_release_skip_verify
test_verify_release_valid_checksum
test_verify_release_invalid_checksum
test_parse_args_multiple_with_skip_verify
test_validate_prefix_tilde_expansion
test_validate_prefix_relative_path
test_validate_prefix_trailing_slashes
test_validate_prefix_rejects_newlines
test_validate_prefix_rejects_whitespace
test_validate_prefix_rejects_long_path
test_validate_prefix_warns_tmp
test_validate_prefix_absolute_path
