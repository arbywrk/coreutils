//  echo.zig, display a line of text
//  Copyright (C) 2026 Bogdan Rareș-Andrei
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
const std = @import("std");
const cli = @import("cli/mod.zig");
const config = @import("common/config.zig");

const StopOutput = error{StopOutput};

const CliOptions = cli.defineOptions(&.{
    cli.standard.helpOption(null, "Display help and exit"),
    cli.standard.versionOption(null, "Display version and exit"),
    .{ .name = "no_newline", .short = 'n', .help = "Do not output a trailing newline" },
    .{ .name = "escape", .short = 'e', .help = "Enable interpretation of backslash escapes" },
    .{ .name = "no_escape", .short = 'E', .help = "Disable interpretation of backslash escapes (default)" },
});

const Help = cli.Help{
    .usage = "Usage: {s} [options] [string...]\n",
    .after_options =
    \\If -e is in effect, the following sequences are recognized:
    \\
    \\  \               backslash
    \\  \a              alert (BEL)
    \\  \b              backspace
    \\  \c              produce no further output
    \\  \e              escape
    \\  \f              form feed
    \\  \n              new line
    \\  \r              carriage return
    \\  \t              horizontal tab
    \\  \v              vertical tab
    \\  \0NNN           byte with octal value NNN (1 to 3 digits)
    \\  \xHH            byte with hexadecimal value HH (1 to 2 digits)
    ,
};

pub fn main() !u8 {
    // Configure flags
    var omit_newline: bool = false;
    var escape: bool = false;

    // Configure arguments
    var ctx: CliOptions = undefined;
    try ctx.init();
    const program_name = ctx.args.programName();

    // Configure stdio
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    var stderr_writer = std.fs.File.stderr().writer(&.{});
    const stderr = &stderr_writer.interface;

    // Parese for position independed options
    var argsIter = try ctx.args.iterator();
    while (argsIter.nextOption() catch |err| {
        try cli.printError(stderr, program_name, err);
        return config.EXIT_FAILURE;
    }) |opt| {
        if (try cli.handleStandardOption(
            &ctx,
            opt,
            stdout,
            program_name,
            Help,
            ctx.entriesSlice(),
            .{ .help = CliOptions.Option.help, .version = CliOptions.Option.version },
        )) |exit_code| {
            return exit_code;
        }

        switch (ctx.optionOf(opt)) {
            CliOptions.Option.no_newline => omit_newline = true,
            CliOptions.Option.escape,
            CliOptions.Option.no_escape,
            CliOptions.Option.help,
            CliOptions.Option.version,
            => {},
        }
    }

    // reset argsIterator
    argsIter = try ctx.args.iterator();

    // print operands and parse escape sequence options
    var print_space: bool = false;
    while (argsIter.next() catch |err| {
        try cli.printError(stderr, program_name, err);
        return config.EXIT_FAILURE;
    }) |arg| {
        switch (arg) {
            .option => |opt| {
                // As opposed to other implementations
                // of echo. This one parses options
                // and operands at the same time
                // so that it allows switching between
                // enabled and disabled escape sequences
                switch (ctx.optionOf(opt)) {
                    CliOptions.Option.escape => escape = true,
                    CliOptions.Option.no_escape => escape = false,
                    else => {},
                }
            },

            .operand => |opr| {
                // Don't print space before the first operand
                if (print_space) try stdout.writeByte(' ');
                print_space = true;

                if (escape) {
                    writeEscaped(stdout, opr) catch |err| switch (err) {
                        error.StopOutput => {
                            try stdout.flush();
                            return config.EXIT_SUCCESS; // No more printing (\c exit)
                        },
                        else => return err,
                    };
                } else {
                    try stdout.writeAll(opr);
                }
            },
        }
    }

    if (!omit_newline)
        try stdout.writeByte('\n');

    return config.EXIT_SUCCESS;
}

/// Writes a string to `writer`, interpreting backslash escape sequences.
///
/// The function processes the input string `str` character by character, writing
/// literal characters directly to the writer and interpreting escape sequences
/// when a backslash is encountered.
///
/// Supported escape sequences:
/// - `\a`: Alert/bell (0x07)
/// - `\b`: Backspace (0x08)
/// - `\c`: Stop output (returns `StopOutput` error)
/// - `\e`: Escape (0x1B)
/// - `\f`: Form feed (0x0C)
/// - `\n`: Newline (0x0A)
/// - `\r`: Carriage return (0x0D)
/// - `\t`: Horizontal tab (0x09)
/// - `\v`: Vertical tab (0x0B)
/// - `\\`: Literal backslash
/// - `\xHH`: Hexadecimal byte value (1-2 digits)
/// - `\0NNN`: Octal byte value (1-3 digits, leading zeros ignored)
///
/// Unrecognized escape sequences are written literally (both backslash and
/// following character).
///
/// Parameters:
/// - `writer`: Writer to output processed characters
/// - `str`: Input byte slice to process
///
/// Returns:
/// - `StopOutput.StopOutput` when `\c` escape is encountered
/// - Any error returned by the writer
fn writeEscaped(writer: anytype, str: []const u8) !void {
    var i: usize = 0;
    while (i < str.len) {
        const c = str[i];
        if (c != '\\') {
            try writer.writeByte(c);
            i += 1;
            continue;
        }
        if (i + 1 > str.len) break;

        // if the next position is the end of the slice
        // but there is a backslash at the end, we just print
        // the backslash
        const next = if (i + 1 < str.len) str[i + 1] else '\\';
        i += 2;

        // `next` is a runtime u8
        switch (next) {
            'a' => try writer.writeByte(0x07),
            'b' => try writer.writeByte(0x08),
            'c' => return StopOutput.StopOutput,
            'e' => try writer.writeByte(0x1B),
            'f' => try writer.writeByte(0x0C),
            'n' => try writer.writeByte(0x0A),
            'r' => try writer.writeByte(0x0D),
            't' => try writer.writeByte(0x09),
            'v' => try writer.writeByte(0x0B),
            '\\' => try writer.writeByte('\\'),

            'x' => {
                if (i >= str.len or !std.ascii.isHex(str[i])) {
                    // TODO: get rid of duplicat logic (line: 227)
                    // no hex digits after \x
                    try writer.writeByte('\\');
                    try writer.writeByte(next);
                } else {
                    const res = parseHexEscape(str, i);
                    const b = res[0];
                    i = res[1];
                    try writer.writeByte(b);
                }
            },

            '0' => {
                const res = parseOctalEscape(str, i);
                const b = res[0];
                i = res[1];
                try writer.writeByte(b);
            },

            else => {
                try writer.writeByte('\\');
                try writer.writeByte(next);
            },
        }
    }
}

test "writeEscaped: plain text" {
    var buf: [64]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const w = fbs.writer();

    try writeEscaped(&w, "hello");

    try std.testing.expectEqualStrings("hello", fbs.getWritten());
}

test "writeEscaped: hex escape" {
    var buf: [64]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);

    try writeEscaped(&fbs.writer(), "\\x41");

    try std.testing.expectEqualStrings("A", fbs.getWritten());
}

test "writeEscaped: octal escape" {
    var buf: [64]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);

    try writeEscaped(&fbs.writer(), "\\0101");

    try std.testing.expectEqualStrings("A", fbs.getWritten());
}

test "writeEscaped: unknown escape prints literally" {
    var buf: [64]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);

    try writeEscaped(&fbs.writer(), "\\q");

    try std.testing.expectEqualStrings("\\q", fbs.getWritten());
}

test "writeEscaped bugfix: trailing backslash" {
    var buf: [64]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);

    try writeEscaped(&fbs.writer(), "\\");

    try std.testing.expectEqualStrings("\\", fbs.getWritten());
}

test "writeEscaped: \\c stops output" {
    var buf: [64]u8 = undefined;
    var fbs = std.Io.fixedBufferStream(&buf);

    const err = writeEscaped(&fbs.writer(), "hi\\cbye");

    try std.testing.expectError(StopOutput.StopOutput, err);
    try std.testing.expectEqualStrings("hi", fbs.getWritten());
}

test "writeEscaped bugfix: \\x with no hex afterwards" {
    var buf: [64]u8 = undefined;
    var fbs = std.Io.fixedBufferStream(&buf);

    try writeEscaped(&fbs.writer(), "\\x something else");
    try std.testing.expectEqualStrings("\\x something else", fbs.getWritten());
}

test "writeEscaped bugfix: \\x at the end" {
    var buf: [64]u8 = undefined;
    var fbs = std.Io.fixedBufferStream(&buf);

    try writeEscaped(&fbs.writer(), "\\x");
    try std.testing.expectEqualStrings("\\x", fbs.getWritten());
}

/// Parses up to two hexadecimal digits from `str`, starting at index `idx`.
///
/// The function reads consecutive ASCII hexadecimal characters (`0-9`, `a-f`,
/// `A-F`) beginning at `idx`, stopping when:
/// - A non-hex character is encountered
/// - Two hex digits have been consumed
/// - The end of the slice is reached
///
/// The parsed value is accumulated as a base-16 number.
///
/// Parameters:
/// - `str`: Input byte slice containing ASCII characters
/// - `idx`: Starting index in `str`
///
/// Returns:
/// - A tuple `{ value, next_index }` where:
///   - `value` is the parsed hexadecimal value as `u8`
///   - `next_index` is the index immediately after the last consumed character
fn parseHexEscape(str: []const u8, idx: usize) std.meta.Tuple(&.{ u8, usize }) {
    var i: usize = idx;
    var val: u8 = 0;
    var count: usize = 0;

    while (i < str.len and count < 2) {
        const c = str[i];

        const b16_digit = std.fmt.charToDigit(c, 16) catch |err| {
            switch (err) {
                // using switch to make sure that the if the
                // zig api changes for `charToDigit` it will
                // be a compile error
                error.InvalidCharacter => {
                    break; // stop at the first non hex digit
                },
            }
        };
        val = val * 16 + b16_digit;
        i += 1;
        count += 1;
    }

    return .{ @as(u8, val), @as(usize, i) };
}

test "parseHexEscape: parses two hex digits" {
    const input = "1f";
    const result = parseHexEscape(input, 0);

    try std.testing.expectEqual(@as(u8, 0x1f), result[0]);
    try std.testing.expectEqual(@as(usize, 2), result[1]);
}

test "parseHexEscape: parses one hex digit" {
    const input = "a";
    const result = parseHexEscape(input, 0);

    try std.testing.expectEqual(@as(u8, 0x0a), result[0]);
    try std.testing.expectEqual(@as(usize, 1), result[1]);
}

test "parseHexEscape: stops after two digits even if more are present" {
    const input = "abcd";
    const result = parseHexEscape(input, 0);

    try std.testing.expectEqual(@as(u8, 0xab), result[0]);
    try std.testing.expectEqual(@as(usize, 2), result[1]);
}

test "parseHexEscape: stops at non-hex character" {
    const input = "1g3";
    const result = parseHexEscape(input, 0);

    try std.testing.expectEqual(@as(u8, 0x01), result[0]);
    try std.testing.expectEqual(@as(usize, 1), result[1]);
}

test "parseHexEscape: returns zero when first character is not hex" {
    const input = "xyz";
    const result = parseHexEscape(input, 0);

    try std.testing.expectEqual(@as(u8, 0x00), result[0]);
    try std.testing.expectEqual(@as(usize, 0), result[1]);
}

test "parseHexEscape: works with offset index" {
    const input = "00ff";
    const result = parseHexEscape(input, 2);

    try std.testing.expectEqual(@as(u8, 0xff), result[0]);
    try std.testing.expectEqual(@as(usize, 4), result[1]);
}

test "parseHexEscape: handles end-of-slice safely" {
    const input = "f";
    const result = parseHexEscape(input, 0);

    try std.testing.expectEqual(@as(u8, 0x0f), result[0]);
    try std.testing.expectEqual(@as(usize, 1), result[1]);
}

test "parseHexEscape: starting at end of slice" {
    const input = "ff";
    const result = parseHexEscape(input, 2);

    try std.testing.expectEqual(@as(u8, 0x00), result[0]);
    try std.testing.expectEqual(@as(usize, 2), result[1]);
}

/// Parses up to three octal digits from `str`, starting at index `idx`.
///
/// The function reads consecutive ASCII octal characters (`0-7`)
/// beginning at index `idx`, and stopping when:
/// - A non-octal character is encountered
/// - Three octal digits have been consumed
/// - The end of the slice is reached
///
/// The parsed value is accumulated as a base-8 number.
///
/// Parameters:
/// - `str`: Input byte slice containing ASCII characters
/// - `idx`: Starting index in `str`
///
/// Returns:
/// - A tuple `{ value, next_index }` where:
///   - `value` is the parsed octal value as `u8`
///   - `next_index` is the index immediately after the last consumed character
fn parseOctalEscape(str: []const u8, idx: usize) std.meta.Tuple(&.{ u8, usize }) {
    var i: usize = idx;
    var val: u16 = 0;
    var count: usize = 0;

    while (i < str.len and count < 3) {
        const c = str[i];

        if (c < '0' or c > '7') break;

        val = val * 8 + (c - '0');

        i += 1;

        count += 1;
    }

    return .{ @as(u8, @truncate(val)), @as(usize, i) };
}

test "parseOctalEscape: parses three octal digits" {
    const input = "341";
    const result = parseOctalEscape(input, 0);

    try std.testing.expectEqual(@as(u8, 0o341), result[0]);
    try std.testing.expectEqual(@as(usize, 3), result[1]);
}

test "parseOctalEscape: parses two octal digits" {
    const input = "71";
    const result = parseOctalEscape(input, 0);

    try std.testing.expectEqual(@as(u8, 0o071), result[0]);
    try std.testing.expectEqual(@as(usize, 2), result[1]);
}

test "parseOctalEscape: parses one octal digit" {
    const input = "5";
    const result = parseOctalEscape(input, 0);

    try std.testing.expectEqual(@as(u8, 0o005), result[0]);
    try std.testing.expectEqual(@as(usize, 1), result[1]);
}

test "parseOctalEscape: stops after three digits even if more are present" {
    const input = "3654321";
    const result = parseOctalEscape(input, 0);

    try std.testing.expectEqual(@as(u8, 0o365), result[0]);
    try std.testing.expectEqual(@as(usize, 3), result[1]);
}

test "parseOctalEscape: stops at non-octal character" {
    const input = "183";
    const result = parseOctalEscape(input, 0);

    try std.testing.expectEqual(@as(u8, 0o001), result[0]);
    try std.testing.expectEqual(@as(usize, 1), result[1]);
}

test "parseOctalEscape: returns zero when first character is not octal" {
    const input = "xyz";
    const result = parseOctalEscape(input, 0);

    try std.testing.expectEqual(@as(u8, 0o000), result[0]);
    try std.testing.expectEqual(@as(usize, 0), result[1]);
}

test "parseOctalEscape: works with offset index" {
    const input = "1177";
    const result = parseOctalEscape(input, 2);

    try std.testing.expectEqual(@as(u8, 0o077), result[0]);
    try std.testing.expectEqual(@as(usize, 4), result[1]);
}

test "parseOctalEscape: handles end-of-slice safely" {
    const input = "7";
    const result = parseOctalEscape(input, 0);

    try std.testing.expectEqual(@as(u8, 0o007), result[0]);
    try std.testing.expectEqual(@as(usize, 1), result[1]);
}

test "parseOctalEscape: starting at end of slice" {
    const input = "77";
    const result = parseOctalEscape(input, 2);

    try std.testing.expectEqual(@as(u8, 0o000), result[0]);
    try std.testing.expectEqual(@as(usize, 2), result[1]);
}

test "parseOctalEscape bugfix: silently enforce max value at 255" {
    const input = "777";
    const result = parseOctalEscape(input, 0);

    try std.testing.expectEqual(@as(u8, 0o377), result[0]);
    try std.testing.expectEqual(@as(usize, 3), result[1]);
}
