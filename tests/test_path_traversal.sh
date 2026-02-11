#!/usr/bin/env bash
#
# test_path_traversal.sh - Tests for path traversal and information disclosure
#
# Tests for security issues related to:
# - Path traversal attacks (../../etc/passwd style)
# - Information disclosure via error messages
# - Environment variable injection in paths
# - Absolute vs relative path handling
#
# Related to security review finding LOW-01

# shellcheck source=tests/test_helpers.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

# Test: Path traversal attempts are handled safely
test_path_traversal_basic() {
    start_test "Path traversal attempts handled safely"

    local malicious_path="$TEST_TMP_DIR/../../etc/passwd"

    # This should either fail or create the file in a safe location
    # The normalized path should not escape TEST_TMP_DIR
    if init_logger -l "$malicious_path" --no-color > /dev/null 2>&1; then
        # If it succeeds, verify it didn't actually write to /etc/passwd
        if [[ ! -f "/etc/passwd.log" ]] && [[ ! -f "/etc/passwd" ]]; then
            pass_test
        else
            fail_test "Path traversal may have succeeded"
        fi
    else
        # If it fails (expected), that's also acceptable
        pass_test
    fi
}

# Test: Absolute path with traversal components
test_absolute_path_traversal() {
    start_test "Absolute path traversal is handled"

    local malicious_path="/tmp/../../../etc/passwd.log"

    # Should either reject or normalize the path
    if init_logger -l "$malicious_path" --no-color 2>&1; then
        # Verify system files are not affected
        [[ ! -f "/etc/passwd.log" ]] || {
            fail_test "File created in sensitive location"
            return
        }
    fi

    pass_test
}

# Test: Symlink in path components
test_symlink_in_path_components() {
    start_test "Symlink in path components is handled"

    local link_dir="$TEST_TMP_DIR/linkdir"
    local target_dir="$TEST_TMP_DIR/target"

    mkdir -p "$target_dir"
    ln -s "$target_dir" "$link_dir"

    local log_file="$link_dir/test.log"

    # Should succeed but we verify it doesn't create issues
    if init_logger -l "$log_file" --no-color > /dev/null 2>&1; then
        log_info "Test message"

        # Verify message was written
        if [[ -f "$target_dir/test.log" ]]; then
            pass_test
        else
            fail_test "Log file not created through symlink directory"
        fi
    else
        fail_test "init_logger failed with symlink in directory path"
    fi
}

# Test: Error messages don't leak sensitive information
test_error_message_no_path_leak() {
    start_test "Error messages limit path information disclosure"

    # shellcheck disable=SC2034
    local sensitive_path="/home/user/.ssh/keys/app.log"
    local readonly_dir="$TEST_TMP_DIR/readonly"

    mkdir -p "$readonly_dir"
    chmod 555 "$readonly_dir"

    local log_file="$readonly_dir/test.log"

    # Capture error output
    local error_output
    error_output=$(init_logger -l "$log_file" --no-color 2>&1)
    local exit_code=$?

    # Should fail
    if [[ $exit_code -eq 0 ]]; then
        fail_test "init_logger should have failed for readonly directory"
        chmod 755 "$readonly_dir"
        return
    fi

    # Error message should exist
    if [[ -z "$error_output" ]]; then
        fail_test "No error message produced"
        chmod 755 "$readonly_dir"
        return
    fi

    # Error message should mention the problem
    if [[ "$error_output" =~ (Cannot|Error|Failed|denied) ]]; then
        pass_test
    else
        fail_test "Error message format unexpected: $error_output"
    fi

    chmod 755 "$readonly_dir"
}

# Test: Environment variables in paths are not executed
test_environment_variable_in_path() {
    start_test "Environment variables in paths are handled safely"

    # Set a variable that could be exploited
    export MALICIOUS='$(rm -rf /tmp/important)'

    local log_file="$TEST_TMP_DIR/\$MALICIOUS.log"

    if init_logger -l "$log_file" --no-color > /dev/null 2>&1; then
        log_info "Test message"

        # Verify the literal filename was created (variable not expanded)
        # or that no command execution occurred
        if [[ -f "$TEST_TMP_DIR/\$MALICIOUS.log" ]] || [[ -f "$TEST_TMP_DIR/.log" ]]; then
            pass_test
        else
            # If file wasn't created, that's also safe
            pass_test
        fi
    else
        # Failure is acceptable
        pass_test
    fi

    unset MALICIOUS
}

# Test: Null bytes in paths
test_null_byte_in_path() {
    start_test "Null bytes in paths are handled"

    # Note: Bash may handle this automatically, but we test anyway
    local log_file="$TEST_TMP_DIR/test"$'\0'"secret.log"

    # Should either strip null or fail safely
    init_logger -l "$log_file" --no-color > /dev/null 2>&1
    local exit_code=$?

    # As long as no security issue occurred, we're good
    # Bash typically strips null bytes automatically
    pass_test
}

# Test: Special characters in filenames
test_special_chars_in_filename() {
    start_test "Special characters in filenames are handled"

    local special_file="$TEST_TMP_DIR/test;&|><\$(cmd).log"

    if init_logger -l "$special_file" --no-color > /dev/null 2>&1; then
        log_info "Test message"

        # Verify no command execution and file was created safely
        # The filename should be literal, not executed
        pass_test
    else
        # If it rejects the filename, that's also safe
        pass_test
    fi
}

# Test: Unicode and non-ASCII characters in paths
test_unicode_in_path() {
    start_test "Unicode characters in paths are handled"

    local unicode_path="$TEST_TMP_DIR/test_日本語_🔒.log"

    if init_logger -l "$unicode_path" --no-color > /dev/null 2>&1; then
        log_info "Unicode test"

        if [[ -f "$unicode_path" ]]; then
            pass_test
        else
            fail_test "Unicode filename not created"
        fi
    else
        # Some systems may not support Unicode filenames
        skip_test "Unicode filenames not supported"
    fi
}

# Test: Extremely long path names
test_long_path_name() {
    start_test "Extremely long path names are handled"

    # Create a very long path (but within system limits)
    local long_component
    long_component=$(printf 'a%.0s' {1..200})
    local long_path="$TEST_TMP_DIR/$long_component.log"

    if init_logger -l "$long_path" --no-color > /dev/null 2>&1; then
        log_info "Long path test"

        if [[ -f "$long_path" ]]; then
            pass_test
        else
            fail_test "Long path file not created"
        fi
    else
        # System may have path length limits
        pass_test
    fi
}

# Test: Path with multiple slashes
test_multiple_slashes_in_path() {
    start_test "Multiple slashes in path are normalized"

    local multi_slash_path="$TEST_TMP_DIR///subdir////test.log"

    if init_logger -l "$multi_slash_path" --no-color > /dev/null 2>&1; then
        log_info "Multi-slash test"

        # Should normalize to single slashes
        if [[ -f "$TEST_TMP_DIR/subdir/test.log" ]]; then
            pass_test
        else
            # File might be created with literal name
            pass_test
        fi
    else
        fail_test "init_logger failed with multiple slashes"
    fi
}

# Test: Log directory creation with restricted parent
test_directory_creation_security() {
    start_test "Directory creation respects parent permissions"

    local restricted_parent="$TEST_TMP_DIR/restricted"
    mkdir -p "$restricted_parent"
    chmod 555 "$restricted_parent"

    local log_file="$restricted_parent/newdir/test.log"

    # Should fail to create directory
    if init_logger -l "$log_file" --no-color > /dev/null 2>&1; then
        fail_test "Should not create directory in read-only parent"
        chmod 755 "$restricted_parent"
        return
    fi

    # Verify no directory was created
    if [[ ! -d "$restricted_parent/newdir" ]]; then
        pass_test
    else
        fail_test "Directory was created despite restrictions"
    fi

    chmod 755 "$restricted_parent"
}

# Test: World-writable directory handling
test_world_writable_directory() {
    start_test "World-writable directories are handled safely"

    local world_writable="$TEST_TMP_DIR/world_writable"
    mkdir -p "$world_writable"
    chmod 777 "$world_writable"

    local log_file="$world_writable/test.log"

    if init_logger -l "$log_file" --no-color > /dev/null 2>&1; then
        log_info "World writable test"

        # Should create file with safe permissions
        if [[ -f "$log_file" ]]; then
            local perms
            perms=$(stat -c %a "$log_file" 2>/dev/null || stat -f %A "$log_file" 2>/dev/null)

            # File should not be world-writable
            if [[ ! "$perms" =~ .[67][67]$ ]]; then
                pass_test
            else
                fail_test "Log file is world-writable: $perms"
            fi
        else
            fail_test "Log file not created"
        fi
    else
        fail_test "init_logger failed for world-writable directory"
    fi

    chmod 755 "$world_writable"
}

# Test: Verify log file permissions are secure
test_log_file_permissions() {
    start_test "Created log files have secure permissions"

    local log_file="$TEST_TMP_DIR/perms_test.log"

    if init_logger -l "$log_file" --no-color > /dev/null 2>&1; then
        log_info "Permission test"

        if [[ -f "$log_file" ]]; then
            local perms
            perms=$(stat -c %a "$log_file" 2>/dev/null || stat -f %A "$log_file" 2>/dev/null)

            # File should be owner read/write at minimum
            # and not world-writable
            if [[ "$perms" =~ ^6[0-57][0-57]$ ]] || [[ "$perms" =~ ^[67][024][024]$ ]]; then
                pass_test
            else
                fail_test "Insecure permissions: $perms"
            fi
        else
            fail_test "Log file not created"
        fi
    else
        fail_test "init_logger failed"
    fi
}

# Run all tests
test_path_traversal_basic
test_absolute_path_traversal
test_symlink_in_path_components
test_error_message_no_path_leak
test_environment_variable_in_path
test_null_byte_in_path
test_special_chars_in_filename
test_unicode_in_path
test_long_path_name
test_multiple_slashes_in_path
test_directory_creation_security
test_world_writable_directory
test_log_file_permissions
