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

# Test: parse_args with --user option
test_parse_args_user() {
    start_test "parse_args correctly handles --user option"

    # Create a test wrapper that sources install.sh functions
    local test_script="$TEST_DIR/test_parse_args_user.sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Source install.sh but prevent main from running
INSTALL_SH_TEST_MODE=true
source "${PROJECT_ROOT}/install.sh"

# Override main to do nothing
main() { :; }

# Test parse_args
INSTALL_MODE=""
parse_args --user

echo "INSTALL_MODE=${INSTALL_MODE}"
EOF

    local output
    output=$(bash "$test_script" 2>&1)

    assert_contains "$output" "INSTALL_MODE=user" "Should set INSTALL_MODE to user" || return

    pass_test
}

# Test: parse_args with --system option
test_parse_args_system() {
    start_test "parse_args correctly handles --system option"

    local test_script="$TEST_DIR/test_parse_args_system.sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
INSTALL_SH_TEST_MODE=true
source "${PROJECT_ROOT}/install.sh"
main() { :; }

INSTALL_MODE=""
parse_args --system
echo "INSTALL_MODE=${INSTALL_MODE}"
EOF

    local output
    output=$(bash "$test_script" 2>&1)

    assert_contains "$output" "INSTALL_MODE=system" || return

    pass_test
}

# Test: parse_args with --prefix option
test_parse_args_prefix() {
    start_test "parse_args correctly handles --prefix option"

    local test_script="$TEST_DIR/test_parse_args_prefix.sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
INSTALL_SH_TEST_MODE=true
source "${PROJECT_ROOT}/install.sh"
main() { :; }

INSTALL_MODE=""
PREFIX=""
parse_args --prefix /custom/path
echo "INSTALL_MODE=${INSTALL_MODE}"
echo "PREFIX=${PREFIX}"
EOF

    local output
    output=$(bash "$test_script" 2>&1)

    assert_contains "$output" "INSTALL_MODE=custom" || return
    assert_contains "$output" "PREFIX=/custom/path" || return

    pass_test
}

# Test: parse_args with --prefix but no path argument
test_parse_args_prefix_missing_path() {
    start_test "parse_args fails when --prefix has no path argument"

    local test_script="$TEST_DIR/test_parse_args_prefix_missing.sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
INSTALL_SH_TEST_MODE=true
source "${PROJECT_ROOT}/install.sh"
main() { :; }

parse_args --prefix
EOF

    local output exit_code
    output=$(bash "$test_script" 2>&1) || exit_code=$?

    if [[ ${exit_code:-0} -eq 0 ]]; then
        fail_test "Should have failed with missing --prefix argument"
        return
    fi

    assert_contains "$output" "prefix requires a non-empty path argument" || return

    pass_test
}

# Test: parse_args with --prefix followed by another option
test_parse_args_prefix_with_option() {
    start_test "parse_args fails when --prefix is followed by an option"

    local test_script="$TEST_DIR/test_parse_args_prefix_option.sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
INSTALL_SH_TEST_MODE=true
source "${PROJECT_ROOT}/install.sh"
main() { :; }

parse_args --prefix --user
EOF

    local output exit_code
    output=$(bash "$test_script" 2>&1) || exit_code=$?

    if [[ ${exit_code:-0} -eq 0 ]]; then
        fail_test "Should have failed when --prefix followed by option"
        return
    fi

    assert_contains "$output" "prefix requires a path argument, not an option" || return

    pass_test
}

# Test: parse_args with --auto-rc option
test_parse_args_auto_rc() {
    start_test "parse_args correctly handles --auto-rc option"

    local test_script="$TEST_DIR/test_parse_args_auto_rc.sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
INSTALL_SH_TEST_MODE=true
source "${PROJECT_ROOT}/install.sh"
main() { :; }

AUTO_RC=false
parse_args --auto-rc
echo "AUTO_RC=${AUTO_RC}"
EOF

    local output
    output=$(bash "$test_script" 2>&1)

    assert_contains "$output" "AUTO_RC=true" || return

    pass_test
}

# Test: parse_args with --no-backup option
test_parse_args_no_backup() {
    start_test "parse_args correctly handles --no-backup option"

    local test_script="$TEST_DIR/test_parse_args_no_backup.sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
INSTALL_SH_TEST_MODE=true
source "${PROJECT_ROOT}/install.sh"
main() { :; }

BACKUP=true
parse_args --no-backup
echo "BACKUP=${BACKUP}"
EOF

    local output
    output=$(bash "$test_script" 2>&1)

    assert_contains "$output" "BACKUP=false" || return

    pass_test
}

# Test: parse_args with --help option
test_parse_args_help() {
    start_test "parse_args exits successfully with --help option"

    local test_script="$TEST_DIR/test_parse_args_help.sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
INSTALL_SH_TEST_MODE=true
source "${PROJECT_ROOT}/install.sh"
main() { :; }

parse_args --help
EOF

    local output exit_code=0
    output=$(bash "$test_script" 2>&1) || exit_code=$?

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

    local test_script="$TEST_DIR/test_parse_args_unknown.sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
INSTALL_SH_TEST_MODE=true
source "${PROJECT_ROOT}/install.sh"
main() { :; }

parse_args --unknown-option
EOF

    local output exit_code
    output=$(bash "$test_script" 2>&1) || exit_code=$?

    if [[ ${exit_code:-0} -eq 0 ]]; then
        fail_test "Should have failed with unknown option"
        return
    fi

    assert_contains "$output" "Unknown option" || return
    assert_contains "$output" "--unknown-option" || return

    pass_test
}

# Test: determine_install_paths for user mode
test_determine_install_paths_user() {
    start_test "determine_install_paths sets correct paths for user mode"

    local test_script="$TEST_DIR/test_paths_user.sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
INSTALL_SH_TEST_MODE=true
source "${PROJECT_ROOT}/install.sh"
main() { :; }

INSTALL_MODE="user"
determine_install_paths
echo "INSTALL_PREFIX=${INSTALL_PREFIX}"
echo "INSTALL_DIR=${INSTALL_DIR}"
echo "DOC_DIR=${DOC_DIR}"
EOF

    local output
    output=$(bash "$test_script" 2>&1)

    assert_contains "$output" "INSTALL_PREFIX=${HOME}/.local" || return
    assert_contains "$output" "INSTALL_DIR=${HOME}/.local/lib/bash-logger" || return
    assert_contains "$output" "DOC_DIR=${HOME}/.local/share/doc/bash-logger" || return

    pass_test
}

# Test: determine_install_paths for system mode
test_determine_install_paths_system() {
    start_test "determine_install_paths sets correct paths for system mode"

    local test_script="$TEST_DIR/test_paths_system.sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
INSTALL_SH_TEST_MODE=true
source "${PROJECT_ROOT}/install.sh"
main() { :; }

INSTALL_MODE="system"
determine_install_paths
echo "INSTALL_PREFIX=${INSTALL_PREFIX}"
echo "INSTALL_DIR=${INSTALL_DIR}"
echo "DOC_DIR=${DOC_DIR}"
EOF

    local output
    output=$(bash "$test_script" 2>&1)

    assert_contains "$output" "INSTALL_PREFIX=/usr/local" || return
    assert_contains "$output" "INSTALL_DIR=/usr/local/lib/bash-logger" || return
    assert_contains "$output" "DOC_DIR=/usr/local/share/doc/bash-logger" || return

    pass_test
}

# Test: determine_install_paths for custom mode
test_determine_install_paths_custom() {
    start_test "determine_install_paths sets correct paths for custom mode"

    local test_script="$TEST_DIR/test_paths_custom.sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
INSTALL_SH_TEST_MODE=true
source "${PROJECT_ROOT}/install.sh"
main() { :; }

INSTALL_MODE="custom"
PREFIX="/custom/prefix"
determine_install_paths
echo "INSTALL_PREFIX=${INSTALL_PREFIX}"
echo "INSTALL_DIR=${INSTALL_DIR}"
echo "DOC_DIR=${DOC_DIR}"
EOF

    local output
    output=$(bash "$test_script" 2>&1)

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

    local test_script="$TEST_DIR/test_check_root.sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
INSTALL_SH_TEST_MODE=true
source "${PROJECT_ROOT}/install.sh"
main() { :; }

INSTALL_MODE="system"
check_root
EOF

    local output exit_code
    output=$(bash "$test_script" 2>&1) || exit_code=$?

    if [[ ${exit_code:-0} -eq 0 ]]; then
        fail_test "Should have failed without root privileges"
        return
    fi

    assert_contains "$output" "System-wide installation requires root privileges" || return

    pass_test
}

# Test: check_root passes for user mode
test_check_root_user_mode() {
    start_test "check_root passes for user mode"

    local test_script="$TEST_DIR/test_check_root_user.sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
INSTALL_SH_TEST_MODE=true
source "${PROJECT_ROOT}/install.sh"
main() { :; }

INSTALL_MODE="user"
check_root
echo "SUCCESS"
EOF

    local output
    output=$(bash "$test_script" 2>&1)

    assert_contains "$output" "SUCCESS" || return

    pass_test
}

# Test: check_install_prefix_writable with writable directory
test_check_install_prefix_writable_success() {
    start_test "check_install_prefix_writable succeeds with writable directory"

    local test_script="$TEST_DIR/test_writable_success.sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
INSTALL_SH_TEST_MODE=true
source "${PROJECT_ROOT}/install.sh"
main() { :; }

INSTALL_PREFIX="${TEST_TMP_DIR}/writable"
mkdir -p "$INSTALL_PREFIX"
check_install_prefix_writable
echo "SUCCESS"
EOF

    local output
    output=$(bash "$test_script" 2>&1)

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

    local test_script="$TEST_DIR/test_writable_failure.sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
INSTALL_SH_TEST_MODE=true
source "${PROJECT_ROOT}/install.sh"
main() { :; }

# Try to use a non-writable system directory
INSTALL_PREFIX="/root/test-install"
check_install_prefix_writable
EOF

    local output exit_code
    output=$(bash "$test_script" 2>&1) || exit_code=$?

    if [[ ${exit_code:-0} -eq 0 ]]; then
        fail_test "Should have failed with non-writable directory"
        return
    fi

    assert_contains "$output" "No write permission" || return

    pass_test
}

# Test: check_install_prefix_writable with non-existent prefix
test_check_install_prefix_writable_nonexistent() {
    start_test "check_install_prefix_writable handles non-existent prefix"

    local test_script="$TEST_DIR/test_writable_nonexistent.sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
INSTALL_SH_TEST_MODE=true
source "${PROJECT_ROOT}/install.sh"
main() { :; }

INSTALL_PREFIX="${TEST_TMP_DIR}/new/path/that/does/not/exist"
check_install_prefix_writable
echo "SUCCESS"
EOF

    local output
    output=$(bash "$test_script" 2>&1)

    assert_contains "$output" "SUCCESS" || return

    pass_test
}

# Test: info function outputs correctly
test_info_function() {
    start_test "info function outputs with correct format"

    local test_script="$TEST_DIR/test_info.sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
INSTALL_SH_TEST_MODE=true
source "${PROJECT_ROOT}/install.sh"
main() { :; }

info "Test message"
EOF

    local output
    output=$(bash "$test_script" 2>&1)

    assert_contains "$output" "Test message" || return
    # Should contain the arrow prefix
    assert_contains "$output" "==>" || return

    pass_test
}

# Test: error function outputs correctly and exits
test_error_function() {
    start_test "error function outputs with correct format and exits"

    local test_script="$TEST_DIR/test_error.sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
INSTALL_SH_TEST_MODE=true
source "${PROJECT_ROOT}/install.sh"
main() { :; }

error "Test error message"
EOF

    local output exit_code
    output=$(bash "$test_script" 2>&1) || exit_code=$?

    if [[ ${exit_code:-0} -eq 0 ]]; then
        fail_test "error function should exit with non-zero code"
        return
    fi

    assert_contains "$output" "Error:" || return
    assert_contains "$output" "Test error message" || return

    pass_test
}

# Test: success function outputs correctly
test_success_function() {
    start_test "success function outputs with correct format"

    local test_script="$TEST_DIR/test_success.sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
INSTALL_SH_TEST_MODE=true
source "${PROJECT_ROOT}/install.sh"
main() { :; }

success "Test success message"
EOF

    local output
    output=$(bash "$test_script" 2>&1)

    assert_contains "$output" "Test success message" || return
    assert_contains "$output" "==>" || return

    pass_test
}

# Test: warn function outputs correctly
test_warn_function() {
    start_test "warn function outputs with correct format"

    local test_script="$TEST_DIR/test_warn.sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
INSTALL_SH_TEST_MODE=true
source "${PROJECT_ROOT}/install.sh"
main() { :; }

warn "Test warning message"
EOF

    local output
    output=$(bash "$test_script" 2>&1)

    assert_contains "$output" "Warning:" || return
    assert_contains "$output" "Test warning message" || return

    pass_test
}

# Test: Multiple argument combinations
test_parse_args_multiple_options() {
    start_test "parse_args handles multiple options correctly"

    local test_script="$TEST_DIR/test_multiple_args.sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
INSTALL_SH_TEST_MODE=true
source "${PROJECT_ROOT}/install.sh"
main() { :; }

INSTALL_MODE=""
PREFIX=""
AUTO_RC=false
BACKUP=true

parse_args --prefix /test/path --auto-rc --no-backup

echo "INSTALL_MODE=${INSTALL_MODE}"
echo "PREFIX=${PREFIX}"
echo "AUTO_RC=${AUTO_RC}"
echo "BACKUP=${BACKUP}"
EOF

    local output
    output=$(bash "$test_script" 2>&1)

    assert_contains "$output" "INSTALL_MODE=custom" || return
    assert_contains "$output" "PREFIX=/test/path" || return
    assert_contains "$output" "AUTO_RC=true" || return
    assert_contains "$output" "BACKUP=false" || return

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
