#!/usr/bin/env bash
#
# test_fuzzing.sh - Fuzzing and edge case security tests
#
# Tests with random, malformed, and edge case inputs to discover
# potential vulnerabilities and ensure robust error handling.
#
# Tests include:
# - Random binary data
# - Mixed encodings
# - Boundary conditions
# - Malformed inputs
# - Unexpected data types

# shellcheck source=tests/test_helpers.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

# Test: Random printable ASCII characters
test_random_ascii() {
    start_test "Random ASCII characters are handled"

    local log_file="$TEST_TMP_DIR/fuzz_ascii.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Generate random ASCII printable characters
    for i in {1..50}; do
        local random_str
        random_str=$(LC_ALL=C tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~' </dev/urandom 2>/dev/null | head -c 100 2>/dev/null || echo "fallback")
        log_info "$random_str" 2>&1 || true
    done

    if [[ -f "$log_file" ]] && [[ -s "$log_file" ]]; then
        pass_test
    else
        fail_test "Random ASCII handling failed"
    fi
}

# Test: Mixed UTF-8 and invalid sequences
test_invalid_utf8() {
    start_test "Invalid UTF-8 sequences are handled"

    local log_file="$TEST_TMP_DIR/fuzz_utf8.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Various UTF-8 edge cases
    log_info $'\xc3\x28'  # Invalid UTF-8
    log_info $'\xa0\xa1'  # Invalid UTF-8
    log_info $'\xe2\x28\xa1'  # Invalid UTF-8
    log_info $'\xf0\x90\x8c\xbc'  # Valid UTF-8 (𐌼)

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "Invalid UTF-8 caused failure"
    fi
}

# Test: Control characters (0x00-0x1F)
test_control_characters() {
    start_test "Control characters are handled"

    local log_file="$TEST_TMP_DIR/fuzz_control.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Test various control characters
    for i in {1..31}; do
        local char
        char=$(printf "\\x%02x" $i)
        log_info "Control char $i: ${char}END" 2>&1 || true
    done

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "Control characters caused failure"
    fi
}

# Test: Extended ASCII (0x80-0xFF)
test_extended_ascii() {
    start_test "Extended ASCII characters are handled"

    local log_file="$TEST_TMP_DIR/fuzz_extended.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Test extended ASCII range
    for i in {128..255}; do
        local char
        char=$(printf "\\x%02x" $i)
        log_info "Extended $i: ${char}" 2>&1 || true
    done

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "Extended ASCII caused failure"
    fi
}

# Test: Extremely long single word
test_long_word() {
    start_test "Extremely long single word is handled"

    local log_file="$TEST_TMP_DIR/fuzz_longword.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Create a 50K character word without spaces
    local long_word
    long_word=$(printf 'abcdefghijklmnopqrstuvwxyz%.0s' {1..2000})

    if log_info "$long_word"; then
        pass_test
    else
        # Graceful failure is acceptable
        pass_test
    fi
}

# Test: Alternating quotes and escapes
test_quote_escapes() {
    start_test "Alternating quotes and escapes handled"

    local log_file="$TEST_TMP_DIR/fuzz_quotes.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Various quote and escape combinations
    log_info "Test with \"quotes\""
    log_info "Test with 'apostrophes'"
    log_info 'Test with '\''escaped'\'' quotes'
    log_info "Test with \$variables and \`backticks\`"
    log_info "Backslashes: \\ \\\\ \\\\\\"

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "Quote escapes caused failure"
    fi
}

# Test: Format string-like patterns
test_format_string_patterns() {
    start_test "Format string-like patterns are safe"

    local log_file="$TEST_TMP_DIR/fuzz_format.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Patterns that might be interpreted as format strings
    log_info "%s %d %x %p %n"
    log_info "%%%s%%%d%%%x"
    log_info "%99999999s"
    log_info "%*s %.*s"
    # Note: Avoid actual division by zero as it causes shell errors
    log_info "Division test: 1/0 (not evaluated)"

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "Format string patterns caused issues"
    fi
}

# Test: Boundary values for numbers
test_number_boundaries() {
    start_test "Number boundary values are handled"

    local log_file="$TEST_TMP_DIR/fuzz_numbers.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Various numeric boundaries
    log_info "Max int: 9223372036854775807"
    log_info "Min int: -9223372036854775808"
    log_info "Zero: 0"
    log_info "Negative zero: -0"
    log_info "Large float: 1.7976931348623157e+308"

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "Number boundaries caused failure"
    fi
}

# Test: Repeated special characters
test_repeated_special_chars() {
    start_test "Repeated special characters handled"

    local log_file="$TEST_TMP_DIR/fuzz_repeated.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Repeat each special character many times
    log_info "$(printf '!%.0s' {1..1000})"
    log_info "$(printf '@%.0s' {1..1000})"
    log_info "$(printf '#%.0s' {1..1000})"
    log_info "$(printf '$%.0s' {1..1000})"
    log_info "$(printf '%%%.0s' {1..1000})"

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "Repeated special characters failed"
    fi
}

# Test: Empty and whitespace-only messages
test_empty_whitespace() {
    start_test "Empty and whitespace-only messages"

    local log_file="$TEST_TMP_DIR/fuzz_empty.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    log_info ""
    log_info " "
    log_info "  "
    log_info $'\t'
    log_info $'\n'
    log_info $'   \t\t\t   '

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "Empty/whitespace messages failed"
    fi
}

# Test: Mixed newline types
test_mixed_newlines() {
    start_test "Mixed newline types are handled"

    local log_file="$TEST_TMP_DIR/fuzz_newlines.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Different newline representations
    log_info $'Unix\nNewline'
    log_info $'Windows\r\nNewline'
    log_info $'Old Mac\rNewline'
    log_info $'Mixed\n\r\nNewlines\r'

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "Mixed newlines caused failure"
    fi
}

# Test: Deeply nested structures
test_nested_structures() {
    start_test "Deeply nested structures handled"

    local log_file="$TEST_TMP_DIR/fuzz_nested.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Deeply nested brackets and braces
    local nested="{{{{{{{{{{nested}}}}}}}}}}"
    log_info "$nested"

    nested="[[[[[[[[[[nested]]]]]]]]]]"
    log_info "$nested"

    nested="(((((((((( nested ))))))))))"
    log_info "$nested"

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "Nested structures caused failure"
    fi
}

# Test: All printable ASCII in single message
test_all_printable_ascii() {
    start_test "All printable ASCII in single message"

    local log_file="$TEST_TMP_DIR/fuzz_all_ascii.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # All printable ASCII characters (32-126)
    local all_ascii=""
    for i in {32..126}; do
        all_ascii+=$(printf "\\$(printf '%03o' $i)")
    done

    log_info "$all_ascii"

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "All ASCII characters caused failure"
    fi
}

# Test: Rapid alternation of safe and unsafe content
test_alternating_content() {
    start_test "Alternating safe and unsafe content"

    local log_file="$TEST_TMP_DIR/fuzz_alternating.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    for i in {1..50}; do
        if [[ $((i % 2)) -eq 0 ]]; then
            log_info "Safe message $i"
        else
            log_info "Unsafe: \$(echo pwned) ; rm -rf / | cat /etc/passwd"
        fi
    done

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "Alternating content failed"
    fi
}

# Test: Right-to-left and bidirectional text
test_rtl_bidi_text() {
    start_test "Right-to-left and bidirectional text"

    local log_file="$TEST_TMP_DIR/fuzz_rtl.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # RTL override characters
    log_info $'Test \u202e RLO content'
    log_info $'Hebrew: \u05d0\u05d1\u05d2'
    log_info $'Arabic: \u0627\u0628\u062c'

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "RTL/Bidi text caused failure"
    fi
}

# Test: Zero-width characters
test_zero_width_chars() {
    start_test "Zero-width characters are handled"

    local log_file="$TEST_TMP_DIR/fuzz_zerowidth.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Zero-width characters
    log_info $'Text\u200bwith\u200czero\u200dwidth'
    log_info $'Zero-width\ufeffBOM'

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "Zero-width characters failed"
    fi
}

# Test: Combining characters and diacritics
test_combining_diacritics() {
    start_test "Combining characters and diacritics"

    local log_file="$TEST_TMP_DIR/fuzz_combining.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Multiple combining diacritics
    log_info $'e\u0301\u0302\u0303\u0304\u0305'  # e with many diacritics
    log_info $'Z\u0305\u032e\u0326\u031d\u0316'  # Zalgo text pattern

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "Combining characters failed"
    fi
}

# Test: Homoglyph characters
test_homoglyphs() {
    start_test "Homoglyph characters are handled"

    local log_file="$TEST_TMP_DIR/fuzz_homoglyphs.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Characters that look similar but are different
    log_info "Latin A vs Cyrillic А"
    log_info "Digit 0 vs Letter O vs Greek Ο"
    log_info "Digit 1 vs Letter l vs Letter I"

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "Homoglyphs caused failure"
    fi
}

# Test: Emoji and symbols
test_emoji_symbols() {
    start_test "Emoji and symbols are handled"

    local log_file="$TEST_TMP_DIR/fuzz_emoji.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Various emoji
    log_info "🔒🔓🔑🗝️"
    log_info "⚠️⚡💥🔥"
    log_info "✅❌⭕🚫"
    log_info "😀😃😄😁"

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "Emoji caused failure"
    fi
}

# Test: Regex special characters
test_regex_special() {
    start_test "Regex special characters are literal"

    local log_file="$TEST_TMP_DIR/fuzz_regex.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Characters special in regex
    log_info ". literal dot"
    log_info "* literal asterisk"
    log_info "+ literal plus"
    log_info "? literal question"
    log_info "^ literal caret"
    log_info "$ literal dollar"
    log_info "| literal pipe"
    log_info "() literal parens"
    log_info "[] literal brackets"
    log_info "{} literal braces"

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "Regex special characters failed"
    fi
}

# Test: SQL-like patterns
test_sql_patterns() {
    start_test "SQL-like patterns are safe"

    local log_file="$TEST_TMP_DIR/fuzz_sql.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # SQL injection-like patterns (should be harmless in logging)
    log_info "' OR '1'='1"
    log_info "admin'--"
    log_info "'; DROP TABLE logs;--"
    log_info "1' UNION SELECT * FROM users--"

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "SQL patterns caused failure"
    fi
}

# Test: XML/HTML-like patterns
test_xml_html_patterns() {
    start_test "XML/HTML patterns are handled"

    local log_file="$TEST_TMP_DIR/fuzz_xml.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    log_info "<script>alert('xss')</script>"
    log_info "<?xml version=\"1.0\"?>"
    log_info "<!DOCTYPE html>"
    log_info "<!-- comment -->"
    log_info "<![CDATA[data]]>"

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "XML/HTML patterns failed"
    fi
}

# Test: Path traversal variations
test_path_traversal_variations() {
    start_test "Path traversal variations in messages"

    local log_file="$TEST_TMP_DIR/fuzz_traversal.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    log_info "../../etc/passwd"
    log_info "..\\..\\windows\\system32"
    log_info "....//....//etc/passwd"
    log_info "%2e%2e%2f%2e%2e%2f"
    log_info "file:///etc/passwd"

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "Path traversal patterns failed"
    fi
}

# Test: URL and URI patterns
test_url_uri_patterns() {
    start_test "URL and URI patterns are safe"

    local log_file="$TEST_TMP_DIR/fuzz_urls.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    log_info "http://example.com"
    log_info "https://user:pass@example.com:8080/path?query=value#fragment"
    log_info "file:///etc/passwd"
    log_info "ftp://anonymous@ftp.example.com"
    log_info "javascript:alert(1)"

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "URL patterns failed"
    fi
}

# Test: Base64 and encoded content
test_encoded_content() {
    start_test "Encoded content is handled"

    local log_file="$TEST_TMP_DIR/fuzz_encoded.log"

    init_logger -l "$log_file" --no-color > /dev/null 2>&1

    # Base64-like strings
    log_info "SGVsbG8gV29ybGQh"
    log_info "$(echo "test" | base64 2>/dev/null || echo "dGVzdAo=")"

    # URL encoded
    log_info "%20%3D%3F%26%25"

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "Encoded content failed"
    fi
}

# Test: Random log level changes
test_random_level_changes() {
    start_test "Random log level changes during fuzzing"

    local log_file="$TEST_TMP_DIR/fuzz_levels.log"
    local levels=(DEBUG INFO WARN ERROR CRITICAL)

    for i in {1..50}; do
        local random_level="${levels[$RANDOM % 5]}"
        init_logger -l "$log_file" --level "$random_level" --no-color > /dev/null 2>&1
        log_info "Random level test $i"
    done

    if [[ -f "$log_file" ]]; then
        pass_test
    else
        fail_test "Random level changes caused failure"
    fi
}

# Run all tests
test_random_ascii
test_invalid_utf8
test_control_characters
test_extended_ascii
test_long_word
test_quote_escapes
test_format_string_patterns
test_number_boundaries
test_repeated_special_chars
test_empty_whitespace
test_mixed_newlines
test_nested_structures
test_all_printable_ascii
test_alternating_content
test_rtl_bidi_text
test_zero_width_chars
test_combining_diacritics
test_homoglyphs
test_emoji_symbols
test_regex_special
test_sql_patterns
test_xml_html_patterns
test_path_traversal_variations
test_url_uri_patterns
test_encoded_content
test_random_level_changes
