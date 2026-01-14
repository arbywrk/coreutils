#!/usr/bin/env bats

load ../../helpers

setup() {
    ECHO_BIN="${ECHO_BIN:-./zig-out/bin/echo}"
    
    if [[ ! -x "$ECHO_BIN" ]]; then
        skip "Echo binary not found at $ECHO_BIN"
    fi
    
    ACTUAL_OUTPUT=$(mktemp)
}

teardown() {
    rm -f "$ACTUAL_OUTPUT"
}

@test "echo: basic simple string" {
    run "$ECHO_BIN" "Hello, World!"
    assert_output_exact "Hello, World!
"
}

@test "echo: basic multiple arguments" {
    run "$ECHO_BIN" "one" "two" "three"
    assert_output_exact "one two three
"
}

@test "echo: basic empty no args" {
    run "$ECHO_BIN"
    assert_output_exact "
"
}

@test "echo: basic single argument with spaces" {
    run "$ECHO_BIN" "hello world"
    assert_output_exact "hello world
"
}

@test "echo: basic flag n no trailing newline" {
    run "$ECHO_BIN" -n "test"
    assert_output_exact "test"
}

@test "echo: basic flag n with multiple args" {
    run "$ECHO_BIN" -n "one" "two" "three"
    assert_output_exact "one two three"
}

@test "echo: escape newline" {
    run "$ECHO_BIN" -e "Line1\\nLine2"
    assert_output_exact "Line1
Line2
"
}

@test "echo: escape tab" {
    run "$ECHO_BIN" -e "Tab\\there"
    assert_output_exact "Tab	here
"
}

@test "echo: escape backslash" {
    run "$ECHO_BIN" -e "\\\\\\\\"
    assert_output_exact "\\\\
"
}

@test "echo: escape alert bell" {
    run "$ECHO_BIN" -e "\\a"
    assert_output_exact $'\a\n'
}

@test "echo: escape backspace" {
    run "$ECHO_BIN" -e "AB\\bC"
    assert_output_exact $'AB\bC\n'
}

@test "echo: escape carriage return" {
    run "$ECHO_BIN" -e "Carriage return\\rOVERWRITE"
    assert_output_exact $'Carriage return\rOVERWRITE\n'
}

@test "echo: escape vertical tab" {
    run "$ECHO_BIN" -e "Vertical\\vtab"
    assert_output_exact $'Vertical\vtab\n'
}

@test "echo: escape form feed" {
    run "$ECHO_BIN" -e "Form\\ffeed"
    assert_output_exact $'Form\ffeed\n'
}

@test "echo: escape escape character" {
    run "$ECHO_BIN" -e "Escape\\esequence"
    assert_output_exact $'Escape\x1bsequence\n'
}

@test "echo: escape stop output backslash c" {
    run "$ECHO_BIN" -e "Stop\\chere"
    assert_output_exact "Stop"
}

@test "echo: escape stop output with flag n" {
    run "$ECHO_BIN" -e -n "Stop\\c"
    assert_output_exact "Stop"
}

@test "echo: escape multiple escapes in one string" {
    run "$ECHO_BIN" -e "Line1\\nTab\\there\\nEnd"
    assert_output_exact "Line1
Tab	here
End
"
}

@test "echo: octal single digit 07 equals bell" {
    run "$ECHO_BIN" -e "\\07"
    assert_output_exact $'\007\n'
}

@test "echo: octal two digits 077 equals question mark" {
    run "$ECHO_BIN" -e "\\077"
    assert_output_exact $'?\n'
}

@test "echo: octal three digits 0101 equals A" {
    run "$ECHO_BIN" -e "\\0101"
    assert_output_exact "A
"
}

@test "echo: octal mixed lengths" {
    run "$ECHO_BIN" -e "\\07\\077\\0777"
    assert_output_exact $'\007?\xff\n'
}

@test "echo: octal spell Hello" {
    run "$ECHO_BIN" -e "\\0110\\0145\\0154\\0154\\0157"
    assert_output_exact "Hello
"
}

@test "echo: octal null byte" {
    run "$ECHO_BIN" -e "\\0"
    assert_output_exact $'\000\n'
}

@test "echo: octal max value 0377 equals 0xFF" {
    run "$ECHO_BIN" -e "\\0377"
    assert_output_exact $'\xff\n'
}

@test "echo: octal followed by non octal digit" {
    run "$ECHO_BIN" -e "\\0778"
    assert_output_exact $'?8\n'
}

@test "echo: octal multiple sequences" {
    run "$ECHO_BIN" -e "\\0101\\0102\\0103"
    assert_output_exact "ABC
"
}

@test "echo: hex single digit x7 equals bell" {
    run "$ECHO_BIN" -e "\\x7"
    assert_output_exact $'\x07\n'
}

@test "echo: hex two digits x77 equals w" {
    run "$ECHO_BIN" -e "\\x77"
    assert_output_exact "w
"
}

@test "echo: hex uppercase hex digits" {
    run "$ECHO_BIN" -e "\\x4A"
    assert_output_exact "J
"
}

@test "echo: hex lowercase hex digits" {
    run "$ECHO_BIN" -e "\\x4a"
    assert_output_exact "J
"
}

@test "echo: hex mixed case" {
    run "$ECHO_BIN" -e "\\x4A\\x4b"
    assert_output_exact "JK
"
}

@test "echo: hex spell Hello" {
    run "$ECHO_BIN" -e "\\x48\\x65\\x6c\\x6c\\x6f"
    assert_output_exact "Hello
"
}

@test "echo: hex max value xff" {
    run "$ECHO_BIN" -e "\\xff"
    assert_output_exact $'\xff\n'
}

@test "echo: hex followed by non hex char" {
    run "$ECHO_BIN" -e "\\x41g"
    assert_output_exact "Ag
"
}

@test "echo: hex mixed hex lengths" {
    run "$ECHO_BIN" -e "\\x7\\x77"
    assert_output_exact $'\x07w\n'
}

@test "echo: hex incomplete x" {
    run "$ECHO_BIN" -e "\\x"
    assert_output_exact "
"
}

@test "echo: hex with valid hex after" {
    run "$ECHO_BIN" -e "\\xabc"
    assert_output_exact $'\xabc\n'
}

@test "echo: edge trailing backslash" {
    run "$ECHO_BIN" -e "test\\\\"
    assert_output_exact "test\\
"
}

@test "echo: edge invalid escape sequence" {
    run "$ECHO_BIN" -e "\\z"
    assert_output_exact "\\z
"
}

@test "echo: edge empty string with flag e" {
    run "$ECHO_BIN" -e ""
    assert_output_exact "
"
}

@test "echo: edge just a backslash" {
    run "$ECHO_BIN" -e "\\\\"
    assert_output_exact "\\
"
}

@test "echo: edge backslash at end of string" {
    run "$ECHO_BIN" -e "test\\"
    assert_output_exact "test
"
}

@test "echo: edge multiple backslashes" {
    run "$ECHO_BIN" -e "\\\\\\\\\\\\"
    assert_output_exact "\\\\\\
"
}

@test "echo: edge escape in middle of word" {
    run "$ECHO_BIN" -e "ab\\ncd"
    assert_output_exact "ab
cd
"
}

@test "echo: flags n and e together" {
    run "$ECHO_BIN" -n -e "test\\ttab"
    assert_output_exact "test	tab"
}

@test "echo: flags e and n together reversed" {
    run "$ECHO_BIN" -e -n "test\\ttab"
    assert_output_exact "test	tab"
}

@test "echo: flags E explicitly disables escapes" {
    run "$ECHO_BIN" -E "No\\nescapes"
    assert_output_exact "No\\nescapes
"
}

@test "echo: flags e then E" {
    run "$ECHO_BIN" -e "Escaped\\n" -E "Not escaped\\n"
    assert_output_exact "Escaped
 Not escaped\\n
"
}

@test "echo: flags E then e" {
    run "$ECHO_BIN" -E "Not escaped\\n" -e "Escaped\\n"
    assert_output_exact "Not escaped\\n Escaped
"
}

@test "echo: flags multiple e flags" {
    run "$ECHO_BIN" -e -e "test\\n"
    assert_output_exact "test
"
}

@test "echo: flags n with empty string" {
    run "$ECHO_BIN" -n ""
    assert_output_exact ""
}

@test "echo: multi two arguments" {
    run "$ECHO_BIN" "first" "second"
    assert_output_exact "first second
"
}

@test "echo: multi three arguments with flag e" {
    run "$ECHO_BIN" -e "First\\n" "Second\\n" "Third"
    assert_output_exact "First
 Second
 Third
"
}

@test "echo: multi mixed escaped and plain" {
    run "$ECHO_BIN" -e "test\\n" "plain" -e "more\\t"
    assert_output_exact "test
 plain more	
"
}

@test "echo: multi empty arguments" {
    run "$ECHO_BIN" "" "test" ""
    assert_output_exact " test 
"
}

@test "echo: multi many arguments" {
    run "$ECHO_BIN" "a" "b" "c" "d" "e" "f" "g" "h"
    assert_output_exact "a b c d e f g h
"
}

@test "echo: real ANSI color codes" {
    run "$ECHO_BIN" -e "\\x1b[31mRed\\x1b[0m"
    assert_output_exact $'\x1b[31mRed\x1b[0m\n'
}

@test "echo: real progress bar" {
    run "$ECHO_BIN" -e "Progress: [=====     ] 50%\\r"
    assert_output_exact $'Progress: [=====     ] 50%\r\n'
}

@test "echo: real multiple lines with tabs" {
    run "$ECHO_BIN" -e "Name:\\tJohn\\nAge:\\t30\\nCity:\\tNYC"
    assert_output_exact "Name:	John
Age:	30
City:	NYC
"
}

@test "echo: real bell followed by text" {
    run "$ECHO_BIN" -e "\\aAlert! Something happened"
    assert_output_exact $'\aAlert! Something happened\n'
}

@test "echo: real backspace editing" {
    run "$ECHO_BIN" -e "Hello Worlld\\b\\bd!"
    assert_output_exact $'Hello Worlld\b\bd!\n'
}

@test "echo: stress long string" {
    local long_str=""
    for i in {1..100}; do
        long_str+="test "
    done
    local expected="${long_str}
"
    run "$ECHO_BIN" "$long_str"
    assert_output_exact "$expected"
}

@test "echo: stress many escape sequences" {
    run "$ECHO_BIN" -e "\\n\\t\\n\\t\\n\\t\\n\\t\\n\\t"
    assert_output_exact "
	
	
	
	
	
"
}

@test "echo: stress long octal sequence" {
    run "$ECHO_BIN" -e "\\0101\\0102\\0103\\0104\\0105\\0106\\0107\\0110\\0111\\0112"
    assert_output_exact "ABCDEFGHIJ
"
}

@test "echo: stress long hex sequence" {
    run "$ECHO_BIN" -e "\\x41\\x42\\x43\\x44\\x45\\x46\\x47\\x48\\x49\\x4a"
    assert_output_exact "ABCDEFGHIJ
"
}

@test "echo: meta help shows usage" {
    run "$ECHO_BIN" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "echo: meta version shows version" {
    run "$ECHO_BIN" --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "echo" ]]
}

@test "echo: bugfix carriage return should work" {
    "$ECHO_BIN" -e "Carriage return\\rOVERWRITE" > "$ACTUAL_OUTPUT"
    assert_output_hex $'Carriage return\rOVERWRITE\n'
}

@test "echo: bugfix escape should not consume space" {
    "$ECHO_BIN" -e "Escape\\e sequence" > "$ACTUAL_OUTPUT"
    [[ $(wc -c < "$ACTUAL_OUTPUT") -eq 18 ]]
}

@test "echo: bugfix hex parsing x7 x77" {
    run "$ECHO_BIN" -e "\\x7\\x77"
    assert_output_exact $'\x07w\n'
}

@test "echo: bugfix octal parsing 07 077 0777" {
    run "$ECHO_BIN" -e "\\07\\077\\0777"
    assert_output_exact $'\007?\xff\n'
}

@test "echo: bugfix flag e E interaction" {
    "$ECHO_BIN" -e "Escaped\\n" -E "Not escaped\\n" > "$ACTUAL_OUTPUT"
    assert_output_hex $'Escaped\n Not escaped\\n\n'
}
