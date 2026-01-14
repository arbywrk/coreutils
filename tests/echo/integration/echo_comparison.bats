#!/usr/bin/env bats

setup() {
    # Path to arbys-coreutils echo binary
    ECHO_BIN="${ECHO_BIN:-./zig-out/bin/echo}"
    
    # Path to GNU echo (fallback to system echo)
    GNU_ECHO="/usr/bin/echo"
    
    # Verify binaries exist
    if [[ ! -x "$ECHO_BIN" ]]; then
        skip "Echo binary not found at $ECHO_BIN"
    fi
    
    if [[ ! -x "$GNU_ECHO" ]]; then
        GNU_ECHO="echo"
    fi
    
    # Create temp files for comparison
    EXPECTED_OUTPUT=$(mktemp)
    ACTUAL_OUTPUT=$(mktemp)
}

teardown() {
    # Clean up temp files
    rm -f "$EXPECTED_OUTPUT" "$ACTUAL_OUTPUT"
}

# Helper function to compare with GNU echo
assert_matches_gnu() {
    local -a args=("$@")
    
    # Run GNU echo
    "$GNU_ECHO" "${args[@]}" > "$EXPECTED_OUTPUT" 2>&1 || true
    
    # Run your echo
    "$ECHO_BIN" "${args[@]}" > "$ACTUAL_OUTPUT" 2>&1 || true
    
    # Compare binary output
    local expected_hex actual_hex
    expected_hex=$(od -An -tx1 < "$EXPECTED_OUTPUT" | tr -d ' \n')
    actual_hex=$(od -An -tx1 < "$ACTUAL_OUTPUT" | tr -d ' \n')
    
    if [[ "$expected_hex" != "$actual_hex" ]]; then
        echo "Expected (hex): $expected_hex"
        echo "Actual (hex):   $actual_hex"
        echo "Expected (vis): $(cat -v "$EXPECTED_OUTPUT")"
        echo "Actual (vis):   $(cat -v "$ACTUAL_OUTPUT")"
        return 1
    fi
}

# Helper to test exact output
assert_output_hex() {
    local expected="$1"
    local expected_hex actual_hex
    
    expected_hex=$(printf "%s" "$expected" | od -An -tx1 | tr -d ' \n')
    actual_hex=$(od -An -tx1 < "$ACTUAL_OUTPUT" | tr -d ' \n')
    
    if [[ "$expected_hex" != "$actual_hex" ]]; then
        echo "Expected (hex): $expected_hex"
        echo "Actual (hex):   $actual_hex"
        echo "Expected (vis): $(printf "%s" "$expected" | cat -v)"
        echo "Actual (vis):   $(cat -v "$ACTUAL_OUTPUT")"
        return 1
    fi
}

@test "basic: simple string" {
    assert_matches_gnu "Hello, World!"
}

@test "basic: multiple arguments" {
    assert_matches_gnu "one" "two" "three"
}

@test "basic: empty (no args)" {
    assert_matches_gnu
}

@test "basic: single argument with spaces" {
    assert_matches_gnu "hello world"
}

@test "basic: -n flag (no trailing newline)" {
    assert_matches_gnu -n "test"
}

@test "basic: -n with multiple args" {
    assert_matches_gnu -n "one" "two" "three"
}

@test "escape: newline" {
    assert_matches_gnu -e "Line1\\nLine2"
}

@test "escape: tab" {
    assert_matches_gnu -e "Tab\\there"
}

@test "escape: backslash" {
    assert_matches_gnu -e "\\\\\\\\"
}

@test "escape: alert (bell)" {
    assert_matches_gnu -e "\\a"
}

@test "escape: backspace" {
    assert_matches_gnu -e "AB\\bC"
}

@test "escape: carriage return" {
    assert_matches_gnu -e "Carriage return\\rOVERWRITE"
}

@test "escape: vertical tab" {
    assert_matches_gnu -e "Vertical\\vtab"
}

@test "escape: form feed" {
    assert_matches_gnu -e "Form\\ffeed"
}

@test "escape: escape character" {
    assert_matches_gnu -e "Escape\\esequence"
}

@test "escape: stop output (\\c)" {
    assert_matches_gnu -e "Stop\\chere"
}

@test "escape: stop output with -n" {
    assert_matches_gnu -e -n "Stop\\c"
}

@test "escape: multiple escapes in one string" {
    assert_matches_gnu -e "Line1\\nTab\\there\\nEnd"
}

@test "octal: single digit (\\07 = bell)" {
    assert_matches_gnu -e "\\07"
}

@test "octal: two digits (\\077 = ?)" {
    assert_matches_gnu -e "\\077"
}

@test "octal: three digits (\\0101 = A)" {
    assert_matches_gnu -e "\\0101"
}

@test "octal: mixed lengths" {
    assert_matches_gnu -e "\\07\\077\\0777"
}

@test "octal: spell Hello" {
    assert_matches_gnu -e "\\0110\\0145\\0154\\0154\\0157"
}

@test "octal: null byte" {
    assert_matches_gnu -e "\\0"
}

@test "octal: max value (\\0377 = 0xFF)" {
    assert_matches_gnu -e "\\0377"
}

@test "octal: followed by non-octal digit" {
    assert_matches_gnu -e "\\0778"
}

@test "octal: multiple sequences" {
    assert_matches_gnu -e "\\0101\\0102\\0103"
}

@test "hex: single digit (\\x7 = bell)" {
    assert_matches_gnu -e "\\x7"
}

@test "hex: two digits (\\x77 = w)" {
    assert_matches_gnu -e "\\x77"
}

@test "hex: uppercase hex digits" {
    assert_matches_gnu -e "\\x4A"
}

@test "hex: lowercase hex digits" {
    assert_matches_gnu -e "\\x4a"
}

@test "hex: mixed case" {
    assert_matches_gnu -e "\\x4A\\x4b"
}

@test "hex: spell Hello" {
    assert_matches_gnu -e "\\x48\\x65\\x6c\\x6c\\x6f"
}

@test "hex: max value (\\xff)" {
    assert_matches_gnu -e "\\xff"
}

@test "hex: followed by non-hex char" {
    assert_matches_gnu -e "\\x41g"
}

@test "hex: mixed hex lengths" {
    assert_matches_gnu -e "\\x7\\x77"
}

@test "hex: incomplete (\\x)" {
    assert_matches_gnu -e "\\x"
}

@test "hex: with valid hex after" {
    assert_matches_gnu -e "\\xabc"
}

@test "edge: trailing backslash" {
    assert_matches_gnu -e "test\\\\"
}

@test "edge: invalid escape sequence" {
    assert_matches_gnu -e "\\z"
}

@test "edge: empty string with -e" {
    assert_matches_gnu -e ""
}

@test "edge: just a backslash" {
    assert_matches_gnu -e "\\\\"
}

@test "edge: backslash at end of string" {
    assert_matches_gnu -e "test\\"
}

@test "edge: multiple backslashes" {
    assert_matches_gnu -e "\\\\\\\\\\\\"
}

@test "edge: escape in middle of word" {
    assert_matches_gnu -e "ab\\ncd"
}

@test "flags: -n and -e together" {
    assert_matches_gnu -n -e "test\\ttab"
}

@test "flags: -e and -n together (reversed)" {
    assert_matches_gnu -e -n "test\\ttab"
}

@test "flags: -E explicitly disables escapes" {
    assert_matches_gnu -E "No\\nescapes"
}

@test "flags: multiple -e flags" {
    assert_matches_gnu -e -e "test\\n"
}

@test "flags: -n with empty string" {
    assert_matches_gnu -n ""
}

@test "multi: two arguments" {
    assert_matches_gnu "first" "second"
}

@test "multi: three arguments with -e" {
    assert_matches_gnu -e "First\\n" "Second\\n" "Third"
}

@test "multi: empty arguments" {
    assert_matches_gnu "" "test" ""
}

@test "multi: many arguments" {
    assert_matches_gnu "a" "b" "c" "d" "e" "f" "g" "h"
}

@test "real: ANSI color codes" {
    assert_matches_gnu -e "\\x1b[31mRed\\x1b[0m"
}

@test "real: progress bar" {
    assert_matches_gnu -e "Progress: [=====     ] 50%\\r"
}

@test "real: multiple lines with tabs" {
    assert_matches_gnu -e "Name:\\tJohn\\nAge:\\t30\\nCity:\\tNYC"
}

@test "real: bell followed by text" {
    assert_matches_gnu -e "\\aAlert! Something happened"
}

@test "real: backspace editing" {
    assert_matches_gnu -e "Hello Worlld\\b\\bd!"
}

@test "stress: long string" {
    local long_str=""
    for i in {1..100}; do
        long_str+="test "
    done
    assert_matches_gnu "$long_str"
}

@test "stress: many escape sequences" {
    assert_matches_gnu -e "\\n\\t\\n\\t\\n\\t\\n\\t\\n\\t"
}

@test "stress: long octal sequence" {
    assert_matches_gnu -e "\\0101\\0102\\0103\\0104\\0105\\0106\\0107\\0110\\0111\\0112"
}

@test "stress: long hex sequence" {
    assert_matches_gnu -e "\\x41\\x42\\x43\\x44\\x45\\x46\\x47\\x48\\x49\\x4a"
}

@test "meta: --help shows usage" {
    run "$ECHO_BIN" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "meta: --version shows version" {
    run "$ECHO_BIN" --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "echo" ]]
}

@test "bugfix: escape should not consume space" {
    "$ECHO_BIN" -e "Escape\\e sequence" > "$ACTUAL_OUTPUT"
    # Should contain the space after ESC character
    [[ $(wc -c < "$ACTUAL_OUTPUT") -eq 17 ]]  # "Escape" + ESC + " sequence" + newline
}

@test "bugfix: hex parsing \\x7\\x77" {
    assert_matches_gnu -e "\\x7\\x77"
}

@test "bugfix: octal parsing \\07\\077\\0777" {
    assert_matches_gnu -e "\\07\\077\\0777"
}

@test "bugfix: -e -E flag interaction" {
    "$ECHO_BIN" -e "Escaped\\n" -E "Not escaped\\n" > "$ACTUAL_OUTPUT"
    # First should be escaped, second should be literal
    assert_output_hex $'Escaped\n Not escaped\\n\n'
}
