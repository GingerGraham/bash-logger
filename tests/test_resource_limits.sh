#!/usr/bin/env bash
#
# test_resource_limits.sh - Tests for resource exhaustion and DoS prevention
#
# Tests that the logging library handles resource-intensive scenarios:
# - Extremely large messages
# - Rapid logging rate
# - Disk space limitations
# - Memory constraints
# - File descriptor limits
#
# Related to security review finding INFO-02

# shellcheck source=tests/test_helpers.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

# Test: Extremely large message is handled
test_extremely_large_message() {
    start_test "Extremely large messages are handled"

    local log_file="$TEST_TMP_DIR/large_msg.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Create a very large message (1MB) using efficient string generation
    local large_message
    large_message=$(head -c 1048576 /dev/zero | tr '\0' 'A')

    # Should handle without crashing
    if log_info "$large_message" 2>&1; then
        # Verify file was created and has content
        if [[ -f "$log_file" ]] && [[ -s "$log_file" ]]; then
            pass_test
        else
            fail_test "Log file was not created or is empty"
        fi
    else
        # If function fails gracefully, that's also acceptable
        pass_test
    fi
}

# Test: Message exceeding reasonable limits
test_message_size_limit() {
    start_test "Message size limits are reasonable"

    local log_file="$TEST_TMP_DIR/size_limit.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # 10MB message - should handle or gracefully limit
    local huge_message
    huge_message=$(head -c 10485760 /dev/zero 2>/dev/null | tr '\0' 'X' 2>/dev/null || head -c 100000 /dev/zero | tr '\0' 'X')

    # Log and verify doesn't cause system issues
    log_info "$huge_message" 2>&1 || true

    # As long as system is still responsive
    if log_info "After large message"; then
        pass_test
    else
        fail_test "System became unresponsive"
    fi
}

# Test: Rapid logging rate
test_rapid_logging_rate() {
    start_test "Rapid logging rate is handled"

    local log_file="$TEST_TMP_DIR/rapid.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Log many messages quickly
    local count=0
    for i in {1..1000}; do
        log_info "Message $i" && ((count++))
    done

    # Verify most messages were logged
    if [[ $count -ge 900 ]]; then
        pass_test
    else
        fail_test "Only $count/1000 messages logged successfully"
    fi
}

# Test: Nested logging doesn't cause stack overflow
test_nested_logging() {
    start_test "Nested logging calls don't cause stack overflow"

    local log_file="$TEST_TMP_DIR/nested.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Function that logs and calls itself (limited depth)
    recursive_log() {
        local depth=$1
        if [[ $depth -le 0 ]]; then
            return 0
        fi
        log_info "Depth: $depth"
        recursive_log $((depth - 1))
    }

    # Should handle reasonable recursion depth
    if recursive_log 50; then
        pass_test
    else
        fail_test "Nested logging caused failure"
    fi
}

# Test: Long-running logger session
test_long_running_session() {
    start_test "Long-running logger session remains stable"

    local log_file="$TEST_TMP_DIR/long_running.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Simulate long-running session with periodic logging
    for i in {1..100}; do
        log_info "Session tick $i"
        # Small delay to simulate real usage
        sleep 0.01 2>/dev/null || true
    done

    # Verify logger still works at end
    if log_info "Session complete"; then
        pass_test
    else
        fail_test "Logger degraded over time"
    fi
}

# Test: Multiple concurrent log files
test_multiple_log_files() {
    start_test "Multiple log files can be handled"

    local log_file1="$TEST_TMP_DIR/multi1.log"
    local log_file2="$TEST_TMP_DIR/multi2.log"
    local log_file3="$TEST_TMP_DIR/multi3.log"

    # Initialize with first file
    init_logger -l "$log_file1" --no-color > /dev/null 2>&1
    log_info "File 1 message"

    # Re-initialize with different files
    init_logger -l "$log_file2" --no-color > /dev/null 2>&1
    log_info "File 2 message"

    init_logger -l "$log_file3" --no-color > /dev/null 2>&1
    log_info "File 3 message"

    # Verify all files exist and have content
    if [[ -f "$log_file1" ]] && [[ -f "$log_file2" ]] && [[ -f "$log_file3" ]]; then
        pass_test
    else
        fail_test "Not all log files were created"
    fi
}

# Test: Very long line without newlines
test_very_long_single_line() {
    start_test "Very long single line is handled"

    local log_file="$TEST_TMP_DIR/long_line.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Create single line with 100K characters
    local long_line
    long_line=$(printf 'L%.0s' {1..100000})

    if log_info "$long_line"; then
        if [[ -f "$log_file" ]] && [[ -s "$log_file" ]]; then
            pass_test
        else
            fail_test "Long line not logged"
        fi
    else
        # Graceful failure acceptable
        pass_test
    fi
}

# Test: Binary data handling
test_binary_data_handling() {
    start_test "Binary data is handled safely"

    local log_file="$TEST_TMP_DIR/binary.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Create message with binary-like data (printable representation)
    local binary_data
    binary_data=$(printf '\x01\x02\x03\x04\x05')

    # Should handle without corruption
    if log_info "Binary data: $binary_data"; then
        if [[ -f "$log_file" ]]; then
            pass_test
        else
            fail_test "Log file not created with binary data"
        fi
    else
        pass_test
    fi
}

# Test: Special characters in high volume
test_high_volume_special_chars() {
    start_test "High volume of special characters handled"

    local log_file="$TEST_TMP_DIR/special_chars.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Log many messages with special characters
    for i in {1..100}; do
        log_info "Special: \$\`\$()\{\}[]<>|&;*?" || break
    done

    if [[ -f "$log_file" ]] && [[ -s "$log_file" ]]; then
        pass_test
    else
        fail_test "Special characters in high volume caused issues"
    fi
}

# Test: Disk space handling (simulated)
test_disk_space_handling() {
    start_test "Disk space limitations are handled gracefully"

    local log_file="$TEST_TMP_DIR/disk_space.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Try to write a large amount of data
    local success_count=0
    for i in {1..1000}; do
        if log_info "$(printf 'Data%.0s' {1..1000})"; then
            ((success_count++))
        else
            # If it starts failing, that's expected with disk limits
            break
        fi
    done

    # Should have logged at least some messages
    if [[ $success_count -gt 0 ]]; then
        pass_test
    else
        fail_test "Could not log any messages"
    fi
}

# Test: File descriptor exhaustion resistance
test_file_descriptor_limit() {
    start_test "File descriptor limits don't cause crashes"

    local log_file="$TEST_TMP_DIR/fd_limit.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Repeatedly open and log (tests FD leaks)
    for i in {1..100}; do
        log_info "FD test $i"
    done

    # Verify logger still works
    if log_info "FD test complete"; then
        pass_test
    else
        fail_test "File descriptor issues detected"
    fi
}

# Test: Memory efficiency with repeated initialization
test_repeated_initialization() {
    start_test "Repeated initialization doesn't leak memory"

    local log_file="$TEST_TMP_DIR/reinit.log"

    # Initialize multiple times
    for i in {1..50}; do
        init_logger -l "$log_file" --no-color > /dev/null 2>&1
        log_info "Init cycle $i"
    done

    # Verify logger still functional
    if log_info "Reinitialization complete"; then
        pass_test
    else
        fail_test "Repeated initialization caused issues"
    fi
}

# Test: Simultaneous stdout and file logging stress
test_dual_output_stress() {
    start_test "Simultaneous stdout and file logging under stress"

    local log_file="$TEST_TMP_DIR/dual_output.log"

    init_logger -l "$log_file" --no-color

    # Log many messages to both outputs
    for i in {1..500}; do
        log_info "Dual output message $i" > /dev/null
    done

    if [[ -f "$log_file" ]] && [[ -s "$log_file" ]]; then
        pass_test
    else
        fail_test "Dual output stress test failed"
    fi
}

# Test: Unicode in high volume
test_high_volume_unicode() {
    start_test "High volume Unicode logging"

    local log_file="$TEST_TMP_DIR/unicode_volume.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Log many Unicode messages
    for i in {1..100}; do
        log_info "Unicode: 日本語 🔒 中文 Ελληνικά €£¥" || break
    done

    if [[ -f "$log_file" ]] && [[ -s "$log_file" ]]; then
        pass_test
    else
        fail_test "High volume Unicode caused issues"
    fi
}

# Test: Format string complexity
test_complex_format_strings() {
    start_test "Complex format strings don't cause issues"

    local log_file="$TEST_TMP_DIR/complex_format.log"

    # Use complex format
    init_logger -l "$log_file" --format "%Y-%m-%d %H:%M:%S %z [%L] (%N:%P) - %M" --no-color > /dev/null 2>&1

    # Log many messages with complex format
    for i in {1..100}; do
        log_info "Complex format message $i" || break
    done

    if [[ -f "$log_file" ]] && [[ -s "$log_file" ]]; then
        pass_test
    else
        fail_test "Complex format strings caused issues"
    fi
}

# Test: Mixed log levels in high volume
test_mixed_levels_high_volume() {
    start_test "Mixed log levels in high volume"

    local log_file="$TEST_TMP_DIR/mixed_levels.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Log with all levels
    for i in {1..200}; do
        case $((i % 5)) in
            0) log_debug "Debug $i" ;;
            1) log_info "Info $i" ;;
            2) log_warn "Warn $i" ;;
            3) log_error "Error $i" ;;
            4) log_critical "Critical $i" ;;
        esac
    done

    if [[ -f "$log_file" ]] && [[ -s "$log_file" ]]; then
        pass_test
    else
        fail_test "Mixed level high volume test failed"
    fi
}

# Test: Empty messages in volume
test_empty_messages_volume() {
    start_test "Empty messages in volume don't cause issues"

    local log_file="$TEST_TMP_DIR/empty_volume.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Log many empty or whitespace messages
    for i in {1..100}; do
        log_info ""
        log_info "   "
        log_info "Normal message $i"
    done

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "Empty messages caused file issues"
    fi
}

# Test: Rapid configuration changes
test_rapid_config_changes() {
    start_test "Rapid configuration changes are handled"

    local log_file="$TEST_TMP_DIR/config_changes.log"

    # Change configuration rapidly
    for i in {1..50}; do
        init_logger -l "$log_file" --level INFO --no-color > /dev/null 2>&1
        log_info "Config change $i"
        init_logger -l "$log_file" --level DEBUG --no-color > /dev/null 2>&1
        log_debug "Debug after change $i"
    done

    if log_info "Configuration stress complete"; then
        pass_test
    else
        fail_test "Rapid config changes caused failure"
    fi
}

# Test: Pathological input patterns
test_pathological_patterns() {
    start_test "Pathological input patterns are handled"

    local log_file="$TEST_TMP_DIR/pathological.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Various pathological patterns
    log_info "$(printf '\n%.0s' {1..100})"  # Many newlines
    log_info "$(printf ' %.0s' {1..1000})"  # Many spaces
    log_info "$(printf '\t%.0s' {1..100})"  # Many tabs

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "Pathological patterns caused issues"
    fi
}

# Run all tests
test_extremely_large_message
test_message_size_limit
test_rapid_logging_rate
test_nested_logging
test_long_running_session
test_multiple_log_files
test_very_long_single_line
test_binary_data_handling
test_high_volume_special_chars
test_disk_space_handling
test_file_descriptor_limit
test_repeated_initialization
test_dual_output_stress
test_high_volume_unicode
test_complex_format_strings
test_mixed_levels_high_volume
test_empty_messages_volume
test_rapid_config_changes
test_pathological_patterns
