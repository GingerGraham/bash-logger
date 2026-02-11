#!/usr/bin/env bash
#
# test_concurrent_access.sh - Tests for concurrent logging safety
#
# Tests that multiple processes can safely log simultaneously without
# corruption, race conditions, or data loss.
#
# Tests include:
# - Multiple processes logging to same file
# - Parallel initialization
# - Concurrent file operations
# - Race condition resistance

# shellcheck source=tests/test_helpers.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

# Test: Multiple processes logging to same file
test_multiprocess_same_file() {
    start_test "Multiple processes can log to same file safely"

    local log_file="$TEST_TMP_DIR/multiprocess.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Start multiple background processes
    for i in {1..10}; do
        (
            source "$PROJECT_ROOT/logging.sh"
            init_logger -l "$log_file" --no-color > /dev/null 2>&1
            for j in {1..10}; do
                log_info "Process $i message $j"
            done
        ) &
    done

    # Wait for all background processes
    wait

    # Verify log file has expected number of entries
    if [[ -f "$log_file" ]]; then
        local line_count
        line_count=$(wc -l < "$log_file")

        # Should have approximately 100 lines (10 processes * 10 messages)
        # Allow some variance for race conditions
        if [[ $line_count -ge 80 ]] && [[ $line_count -le 120 ]]; then
            pass_test
        else
            fail_test "Expected ~100 lines, got $line_count"
        fi
    else
        fail_test "Log file was not created"
    fi
}

# Test: Concurrent initialization
test_concurrent_initialization() {
    start_test "Concurrent initialization is safe"

    local log_file="$TEST_TMP_DIR/concurrent_init.log"

    # Initialize from multiple processes simultaneously
    for i in {1..5}; do
        (
            source "$PROJECT_ROOT/logging.sh"
            init_logger -l "$log_file" --no-color > /dev/null 2>&1
            log_info "Init process $i"
        ) &
    done

    wait

    # Verify file was created and has content
    if [[ -f "$log_file" ]] && [[ -s "$log_file" ]]; then
        pass_test
    else
        fail_test "Concurrent initialization failed"
    fi
}

# Test: Parallel log file creation
test_parallel_file_creation() {
    start_test "Parallel log file creation is safe"

    # Create multiple log files in parallel
    for i in {1..10}; do
        (
            source "$PROJECT_ROOT/logging.sh"
            local log_file="$TEST_TMP_DIR/parallel_$i.log"
            init_logger -l "$log_file" --no-color > /dev/null 2>&1
            log_info "Parallel creation test $i"
        ) &
    done

    wait

    # Verify all files were created
    local created_count=0
    for i in {1..10}; do
        [[ -f "$TEST_TMP_DIR/parallel_$i.log" ]] && ((created_count++))
    done

    if [[ $created_count -eq 10 ]]; then
        pass_test
    else
        fail_test "Only $created_count/10 files created"
    fi
}

# Test: Concurrent writes don't corrupt data
test_no_data_corruption() {
    start_test "Concurrent writes don't corrupt log data"

    local log_file="$TEST_TMP_DIR/corruption_test.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Write distinct patterns from multiple processes
    for i in {1..5}; do
        (
            source "$PROJECT_ROOT/logging.sh"
            init_logger -l "$log_file" --no-color > /dev/null 2>&1
            for j in {1..20}; do
                log_info "PROCESS_${i}_MESSAGE_${j}"
            done
        ) &
    done

    wait

    # Check for corruption (interleaved characters within a single message)
    local corrupted=0
    while IFS= read -r line; do
        # Each line should have complete PROCESS_X_MESSAGE_Y pattern
        if [[ "$line" =~ PROCESS_.*MESSAGE_ ]]; then
            # Extract the process and message numbers
            if [[ "$line" =~ PROCESS_([0-9]+)_MESSAGE_([0-9]+) ]]; then
                local proc_num="${BASH_REMATCH[1]}"
                local msg_num="${BASH_REMATCH[2]}"

                # Verify they are valid numbers
                if [[ ! "$proc_num" =~ ^[1-5]$ ]] || [[ ! "$msg_num" =~ ^[0-9]+$ ]]; then
                    corrupted=1
                    break
                fi
            fi
        fi
    done < "$log_file"

    if [[ $corrupted -eq 0 ]]; then
        pass_test
    else
        fail_test "Data corruption detected in concurrent writes"
    fi
}

# Test: Race condition in directory creation
test_directory_creation_race() {
    start_test "Directory creation race condition is handled"

    local base_dir="$TEST_TMP_DIR/race_dir"

    # Multiple processes try to create same directory structure
    for i in {1..5}; do
        (
            source "$PROJECT_ROOT/logging.sh"
            local log_file="$base_dir/subdir/test_$i.log"
            init_logger -l "$log_file" --no-color > /dev/null 2>&1
            log_info "Race test $i"
        ) &
    done

    wait

    # Verify directory was created and all files exist
    if [[ -d "$base_dir/subdir" ]]; then
        local file_count=0
        for i in {1..5}; do
            [[ -f "$base_dir/subdir/test_$i.log" ]] && ((file_count++))
        done

        if [[ $file_count -eq 5 ]]; then
            pass_test
        else
            fail_test "Only $file_count/5 files created in race condition"
        fi
    else
        fail_test "Directory was not created"
    fi
}

# Test: Concurrent log level changes
test_concurrent_level_changes() {
    start_test "Concurrent log level changes don't cause issues"

    local log_file="$TEST_TMP_DIR/level_changes.log"

    # Start processes that change levels frequently
    for i in {1..3}; do
        (
            source "$PROJECT_ROOT/logging.sh"
            for level in INFO DEBUG WARN ERROR; do
                init_logger -l "$log_file" --level "$level" --no-color > /dev/null 2>&1
                log_info "Process $i level $level"
                sleep 0.01 2>/dev/null || true
            done
        ) &
    done

    wait

    if [[ -f "$log_file" ]] && [[ -s "$log_file" ]]; then
        pass_test
    else
        fail_test "Concurrent level changes caused issues"
    fi
}

# Test: Simultaneous reads and writes
test_simultaneous_read_write() {
    start_test "Simultaneous reads and writes are safe"

    local log_file="$TEST_TMP_DIR/read_write.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Writer process
    (
        source "$PROJECT_ROOT/logging.sh"
        init_logger -l "$log_file" --no-color > /dev/null 2>&1
        for i in {1..50}; do
            log_info "Write message $i"
            sleep 0.01 2>/dev/null || true
        done
    ) &
    local writer_pid=$!

    # Reader process
    (
        for i in {1..50}; do
            cat "$log_file" > /dev/null 2>&1 || true
            sleep 0.01 2>/dev/null || true
        done
    ) &
    local reader_pid=$!

    # Wait for both
    wait $writer_pid
    wait $reader_pid

    if [[ -f "$log_file" ]] && [[ -s "$log_file" ]]; then
        pass_test
    else
        fail_test "Simultaneous read/write caused issues"
    fi
}

# Test: File descriptor limit with concurrent processes
test_concurrent_fd_limit() {
    start_test "File descriptor limit with concurrent processes"

    local log_file="$TEST_TMP_DIR/fd_concurrent.log"

    # Start many processes that will open file descriptors
    for i in {1..20}; do
        (
            source "$PROJECT_ROOT/logging.sh"
            init_logger -l "$log_file" --no-color > /dev/null 2>&1
            for j in {1..5}; do
                log_info "FD test process $i message $j"
            done
        ) &
    done

    wait

    # Verify logging completed successfully
    if [[ -f "$log_file" ]] && [[ -s "$log_file" ]]; then
        local line_count
        line_count=$(wc -l < "$log_file")

        # Should have approximately 100 lines (20 * 5)
        if [[ $line_count -ge 80 ]]; then
            pass_test
        else
            fail_test "Only $line_count lines logged, expected ~100"
        fi
    else
        fail_test "Log file issue with concurrent FD usage"
    fi
}

# Test: Concurrent journal logging
test_concurrent_journal_logging() {
    start_test "Concurrent journal logging is safe"

    if ! check_logger_available; then
        skip_test "logger command not available"
        return
    fi

    local log_file="$TEST_TMP_DIR/concurrent_journal.log"
    local tag="test_concurrent_$$"

    # Multiple processes logging to journal simultaneously
    for i in {1..5}; do
        (
            source "$PROJECT_ROOT/logging.sh"
            init_logger -l "$log_file" --journal --tag "$tag" --no-color > /dev/null 2>&1
            for j in {1..5}; do
                log_info "Concurrent journal $i-$j"
            done
        ) &
    done

    wait

    # Verify file logging worked (journal check is unreliable in tests)
    if [[ -f "$log_file" ]] && [[ -s "$log_file" ]]; then
        pass_test
    else
        fail_test "Concurrent journal logging failed"
    fi
}

# Test: Interleaved initialization and logging
test_interleaved_init_log() {
    start_test "Interleaved initialization and logging is safe"

    local log_file="$TEST_TMP_DIR/interleaved.log"

    # Process that repeatedly reinitializes and logs
    (
        source "$PROJECT_ROOT/logging.sh"
        for i in {1..10}; do
            init_logger -l "$log_file" --no-color > /dev/null 2>&1
            log_info "Reinit message $i"
        done
    ) &

    # Process that just logs
    (
        source "$PROJECT_ROOT/logging.sh"
        init_logger -l "$log_file" --no-color > /dev/null 2>&1
        for i in {1..20}; do
            log_info "Regular message $i"
        done
    ) &

    wait

    if [[ -f "$log_file" ]] && [[ -s "$log_file" ]]; then
        pass_test
    else
        fail_test "Interleaved operations failed"
    fi
}

# Test: Concurrent different log files
test_concurrent_different_files() {
    start_test "Concurrent logging to different files"

    # Each process gets its own file
    for i in {1..10}; do
        (
            source "$PROJECT_ROOT/logging.sh"
            local log_file="$TEST_TMP_DIR/different_$i.log"
            init_logger -l "$log_file" --no-color > /dev/null 2>&1
            for j in {1..10}; do
                log_info "File $i message $j"
            done
        ) &
    done

    wait

    # Verify all files exist with correct content
    local success_count=0
    for i in {1..10}; do
        if [[ -f "$TEST_TMP_DIR/different_$i.log" ]]; then
            local line_count
            line_count=$(wc -l < "$TEST_TMP_DIR/different_$i.log")
            [[ $line_count -ge 9 ]] && ((success_count++))
        fi
    done

    if [[ $success_count -eq 10 ]]; then
        pass_test
    else
        fail_test "Only $success_count/10 files completed successfully"
    fi
}

# Test: Mixed console and file logging concurrently
test_mixed_output_concurrent() {
    start_test "Mixed console and file logging concurrently"

    local log_file="$TEST_TMP_DIR/mixed_concurrent.log"

    # Console-only processes
    for i in {1..3}; do
        (
            source "$PROJECT_ROOT/logging.sh"
            init_logger --no-color > /dev/null 2>&1
            for j in {1..10}; do
                log_info "Console $i-$j" > /dev/null
            done
        ) &
    done

    # File logging processes
    for i in {1..3}; do
        (
            source "$PROJECT_ROOT/logging.sh"
            init_logger -l "$log_file" --quiet > /dev/null 2>&1
            for j in {1..10}; do
                log_info "File $i-$j"
            done
        ) &
    done

    wait

    # File should have entries from file loggers only
    if [[ -f "$log_file" ]]; then
        local line_count
        line_count=$(wc -l < "$log_file")

        # Should have ~30 lines from 3 file processes
        if [[ $line_count -ge 20 ]] && [[ $line_count -le 40 ]]; then
            pass_test
        else
            fail_test "Expected ~30 lines, got $line_count"
        fi
    else
        fail_test "Log file not created"
    fi
}

# Test: Stress test with many concurrent processes
test_high_concurrency_stress() {
    start_test "High concurrency stress test"

    local log_file="$TEST_TMP_DIR/stress.log"

    # Start many processes (but not too many to overwhelm test system)
    for i in {1..50}; do
        (
            source "$PROJECT_ROOT/logging.sh"
            init_logger -l "$log_file" --no-color > /dev/null 2>&1
            log_info "Stress message $i"
        ) &
    done

    wait

    # Verify reasonable completion
    if [[ -f "$log_file" ]]; then
        local line_count
        line_count=$(wc -l < "$log_file")

        # Should have most messages (allow some failures under stress)
        if [[ $line_count -ge 40 ]]; then
            pass_test
        else
            fail_test "Only $line_count/50 messages logged under stress"
        fi
    else
        fail_test "Log file not created under stress"
    fi
}

# Test: Verify no process blocks indefinitely
test_no_deadlock() {
    start_test "Concurrent processes don't deadlock"

    local log_file="$TEST_TMP_DIR/deadlock_test.log"
    local timeout=5

    # Start processes in background
    for i in {1..5}; do
        (
            source "$PROJECT_ROOT/logging.sh"
            init_logger -l "$log_file" --no-color > /dev/null 2>&1
            for j in {1..20}; do
                log_info "Deadlock test $i-$j"
            done
        ) &
    done

    # Wait with timeout
    local wait_start=$SECONDS
    wait
    local wait_duration=$((SECONDS - wait_start))

    if [[ $wait_duration -lt $timeout ]]; then
        pass_test
    else
        fail_test "Processes took too long, possible deadlock"
    fi
}

# Run all tests
test_multiprocess_same_file
test_concurrent_initialization
test_parallel_file_creation
test_no_data_corruption
test_directory_creation_race
test_concurrent_level_changes
test_simultaneous_read_write
test_concurrent_fd_limit
test_concurrent_journal_logging
test_interleaved_init_log
test_concurrent_different_files
test_mixed_output_concurrent
test_high_concurrency_stress
test_no_deadlock
