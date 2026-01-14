#!/usr/bin/env bash

assert_output_exact() {
    local expected="$1"
    
    if [[ "$output" != "$expected" ]]; then
        {
            echo "Output does not match expected"
            echo "Expected:"
            printf "%s" "$expected" | od -An -tx1c
            echo ""
            echo "Actual:"
            printf "%s" "$output" | od -An -tx1c
        } >&2
        return 1
    fi
}

assert_output_hex() {
    local expected="$1"
    local expected_hex actual_hex
    
    expected_hex=$(printf "%s" "$expected" | od -An -tx1 | tr -d ' \n')
    actual_hex=$(od -An -tx1 < "$ACTUAL_OUTPUT" | tr -d ' \n')
    
    if [[ "$expected_hex" != "$actual_hex" ]]; then
        {
            echo "Output hex does not match expected"
            echo "Expected (hex): $expected_hex"
            echo "Actual (hex):   $actual_hex"
            echo ""
            echo "Expected (visual):"
            printf "%s" "$expected" | cat -v
            echo ""
            echo "Actual (visual):"
            cat -v "$ACTUAL_OUTPUT"
        } >&2
        return 1
    fi
}
