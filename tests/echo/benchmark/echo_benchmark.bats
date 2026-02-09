#!/usr/bin/env bats

# Performance benchmark suite for echo implementation

setup() {
    # Path to your echo binary (adjust as needed)
    ARBYS_ECHO="${ARBYS_ECHO:-./zig-out/bin/echo}"
    GNU_ECHO="/usr/bin/echo"
    
    # Verify binaries exist
    [ -x "$ARBYS_ECHO" ] || skip "arbys-coreutils echo not found at $ARBYS_ECHO"
    [ -x "$GNU_ECHO" ] || skip "GNU echo not found at $GNU_ECHO"
    
    # Create temp directory for test files
    TEMP_DIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEMP_DIR"
}

# Helper function to benchmark a command
# Usage: benchmark <iterations> <command...>
benchmark() {
    local iterations=$1
    shift
    local start end elapsed
    
    start=$(date +%s%N)
    for ((i=0; i<iterations; i++)); do
        "$@" > /dev/null
    done
    end=$(date +%s%N)
    
    elapsed=$((end - start))
    echo "$elapsed"
}

# Helper to compare performance
# Usage: compare_performance <iterations> <description> <args...>
compare_performance() {
    local iterations=$1
    local description=$2
    shift 2
    
    echo "# Benchmarking: $description ($iterations iterations)" >&3
    
    local arbys_time gnu_time
    arbys_time=$(benchmark "$iterations" "$ARBYS_ECHO" "$@")
    gnu_time=$(benchmark "$iterations" "$GNU_ECHO" "$@")
    
    local arbys_ms=$((arbys_time / 1000000))
    local gnu_ms=$((gnu_time / 1000000))
    
    echo "#   arbys-coreutils: ${arbys_ms}ms" >&3
    echo "#   GNU coreutils:   ${gnu_ms}ms" >&3
    
    if [ "$arbys_time" -lt "$gnu_time" ]; then
        local speedup=$((gnu_time * 100 / arbys_time))
        echo "#   Result: arbys-coreutils is faster! (GNU is ${speedup}% of arbys time)" >&3
    else
        local slowdown=$((arbys_time * 100 / gnu_time))
        echo "#   Result: GNU is faster (arbys is ${slowdown}% of GNU time)" >&3
    fi
    echo "#" >&3
    
    # Always pass - we're just benchmarking
    true
}

@test "benchmark: simple string (10000 iterations)" {
    compare_performance 10000 "simple string" "hello world"
}

@test "benchmark: empty output (10000 iterations)" {
    compare_performance 10000 "empty output"
}

@test "benchmark: single character (10000 iterations)" {
    compare_performance 10000 "single character" "x"
}

@test "benchmark: multiple arguments (10000 iterations)" {
    compare_performance 10000 "multiple arguments" "one" "two" "three" "four" "five"
}

@test "benchmark: long string (5000 iterations)" {
    local long_string="Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris."
    compare_performance 5000 "long string (200+ chars)" "$long_string"
}

@test "benchmark: many short arguments (5000 iterations)" {
    compare_performance 5000 "many short arguments (20 args)" \
        a b c d e f g h i j k l m n o p q r s t
}

@test "benchmark: with -n flag (10000 iterations)" {
    compare_performance 10000 "with -n flag" -n "hello world"
}

@test "benchmark: escape sequences -e (5000 iterations)" {
    compare_performance 5000 "escape sequences" -e "hello\\tworld\\n"
}

@test "benchmark: multiple escape sequences (5000 iterations)" {
    compare_performance 5000 "multiple escapes" -e "\\n\\t\\r\\a\\b\\f\\v\\\\"
}

@test "benchmark: hex escapes (5000 iterations)" {
    compare_performance 5000 "hex escapes" -e "\\x48\\x65\\x6c\\x6c\\x6f"
}

@test "benchmark: octal escapes (5000 iterations)" {
    compare_performance 5000 "octal escapes" -e "\\101\\102\\103\\104\\105"
}

@test "benchmark: mixed escapes (5000 iterations)" {
    compare_performance 5000 "mixed escapes" -e "\\x41\\102\\tcombined\\n"
}

@test "benchmark: long string with escapes (2000 iterations)" {
    compare_performance 2000 "long string with escapes" -e \
        "Line 1\\nLine 2\\tTabbed\\nLine 3\\x20Space\\nLine 4\\101Letter"
}

@test "benchmark: alternating -e and -E flags (5000 iterations)" {
    compare_performance 5000 "alternating flags" -e "\\n" -E "\\n" -e "\\t"
}

@test "benchmark: worst case - many single-byte escapes (2000 iterations)" {
    compare_performance 2000 "many single-byte escapes" -e \
        "\\n\\n\\n\\n\\n\\t\\t\\t\\t\\t\\r\\r\\r\\r\\r"
}

@test "stress test: very long output (100 iterations)" {
    # Generate a string that's ~4KB (larger than buffer)
    local huge_string=""
    for ((i=0; i<100; i++)); do
        huge_string="${huge_string}The quick brown fox jumps over the lazy dog. "
    done
    
    compare_performance 100 "very long output (~4.5KB)" "$huge_string"
}

@test "stress test: many arguments (1000 iterations)" {
    # Build array of 100 short arguments
    local args=()
    for ((i=0; i<100; i++)); do
        args+=("arg$i")
    done
    
    compare_performance 1000 "100 arguments" "${args[@]}"
}

@test "stress test: complex escape processing (1000 iterations)" {
    compare_performance 1000 "complex escapes" -e \
        "\\x48\\x65\\x6c\\x6c\\x6f\\t\\101\\102\\103\\n\\r\\v\\f\\a\\b"
}

@test "real world: typical shell usage (5000 iterations)" {
    compare_performance 5000 "typical: error message" \
        "Error: File not found"
}

@test "real world: formatted output (5000 iterations)" {
    compare_performance 5000 "typical: formatted" -e \
        "Name:\\tJohn Doe\\nAge:\\t30\\nCity:\\tNew York"
}

@test "real world: script progress (5000 iterations)" {
    compare_performance 5000 "typical: progress" -n "Processing... "
}

# Memory efficiency test (not a speed test, but useful)
@test "memory: verify no memory leaks (valgrind)" {
    if ! command -v valgrind >/dev/null 2>&1; then
        skip "valgrind not installed"
    fi
    
    # Only test arbys-coreutils implementation
    run valgrind --leak-check=full --error-exitcode=1 \
        "$ARBYS_ECHO" -e "hello\\nworld\\t\\x41\\101"
    
    [ "$status" -eq 0 ]
}

# Correctness verification (ensure performance optimizations don't break behavior)
@test "correctness: outputs match GNU (sample tests)" {
    local test_cases=(
        "hello world"
        "-n no newline"
        "-e hello\\nworld"
        "-e \\x41\\x42\\x43"
        "-e \\101\\102\\103"
    )
    
    for test_case in "${test_cases[@]}"; do
        local arbys_output gnu_output
        arbys_output=$($ARBYS_ECHO $test_case)
        gnu_output=$($GNU_ECHO $test_case)
        
        if [ "$arbys_output" != "$gnu_output" ]; then
            echo "# Mismatch for: $test_case" >&3
            echo "#   arbys-coreutils: '$arbys_output'" >&3
            echo "#   GNU coreutils:   '$gnu_output'" >&3
            return 1
        fi
    done
}

# Startup overhead test
@test "benchmark: startup overhead (10000 iterations)" {
    echo "# Testing startup overhead with minimal work" >&3
    compare_performance 10000 "startup overhead (empty)" ""
}

# Buffer efficiency test
@test "benchmark: output near buffer boundary (1000 iterations)" {
    # Create string that's just under 4KB
    local near_buffer=""
    for ((i=0; i<90; i++)); do
        near_buffer="${near_buffer}12345678901234567890123456789012345678901234567890"
    done
    
    compare_performance 1000 "near buffer size (~4.5KB)" "$near_buffer"
}

# Summary test that prints comparison table
@test "summary: performance comparison table" {
    echo "#" >&3
    echo "# ============================================" >&3
    echo "# PERFORMANCE SUMMARY" >&3
    echo "# ============================================" >&3
    echo "#" >&3
    
    local tests=(
        "1000:simple:hello world"
        "1000:escapes:-e hello\\\\nworld\\\\t"
        "1000:hex:-e \\\\x48\\\\x65\\\\x6c\\\\x6c\\\\x6f"
        "1000:octal:-e \\\\101\\\\102\\\\103"
        "1000:multiple:one two three four five"
    )
    
    printf "# %-20s | %12s | %12s | %s\n" "Test" "arbys (ms)" "GNU (ms)" "Ratio" >&3
    echo "# $(printf '%20s-+-%12s-+-%12s-+-%s' | tr ' ' '-')" >&3
    
    for test_spec in "${tests[@]}"; do
        IFS=: read -r iterations name args <<< "$test_spec"
        
        local arbys_time gnu_time
        arbys_time=$(benchmark "$iterations" $ARBYS_ECHO $args)
        gnu_time=$(benchmark "$iterations" $GNU_ECHO $args)
        
        local arbys_ms=$((arbys_time / 1000000))
        local gnu_ms=$((gnu_time / 1000000))
        
        # Calculate ratio correctly: if arbys is faster, show how much faster
        if [ "$arbys_time" -lt "$gnu_time" ]; then
            local ratio="$(awk "BEGIN {printf \"%.2fx faster\", $gnu_time / $arbys_time}")"
        else
            local ratio="$(awk "BEGIN {printf \"%.2fx slower\", $arbys_time / $gnu_time}")"
        fi
        
        printf "# %-20s | %12d | %12d | %s\n" \
            "$name" "$arbys_ms" "$gnu_ms" "$ratio" >&3
    done
    
    echo "#" >&3
    true
}