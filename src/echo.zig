//  echo.zig, display a line of text
//  Copyright (C) 2025 Bogdan Rareș-Andrei
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
const version = @import("common/version.zig");
const utils = @import("common/utils.zig");
const args = @import("common/args.zig");
const config = @import("common/config.zig");

const StopOutput = error{StopOutput};

pub fn main() !u8 {
    var options = [_]args.Option{
        .{ .def = .{ .long = "help", .help = "Display help and exit" } },
        .{ .def = .{ .long = "version", .help = "Display version and exit" } },
        .{ .def = .{ .short = 'n', .help = "Do not output a trailing newline" } },
        .{ .def = .{ .short = 'e', .help = "Enable interpretation of backslash escapes" } },
        .{ .def = .{ .short = 'E', .help = "Disable interpretation of backslash escapes (default)" } },
    };

    // Configure flags
    var omit_newline: bool = false;
    var escape: bool = false;

    // Configure arguments
    const arguments = try args.Args.init(&options);
    const program_name = arguments.programName();

    // Configure stdio
    var stdout_writer = std.fs.File.stdout().writer(&.{});
    const stdout = &stdout_writer.interface;
    var stderr_writer = std.fs.File.stderr().writer(&.{});
    const stderr = &stderr_writer.interface;

    // Parese for position independed options
    var argsIter = try arguments.iterator();
    while (argsIter.nextOption() catch |err| {
        try args.printError(stderr, program_name, err);
        return config.EXIT_FAILURE;
    }) |opt| {
        if (opt.isLong("version")) {
            try version.printVersion(stdout, program_name);
            return config.EXIT_SUCCESS;
        }

        if (opt.isLong("help")) {
            try printHelp(stdout, program_name, &options);
            return config.EXIT_SUCCESS;
        }

        if (opt.isShort('n')) {
            omit_newline = true;
        }
    }

    // reset argsIterator
    argsIter = try arguments.iterator();

    // print operands and parse escape sequence options
    var print_space: bool = false;
    while (argsIter.next() catch |err| {
        try args.printError(stderr, program_name, err);
        return config.EXIT_FAILURE;
    }) |arg| {
        switch (arg) {
            .option => |opt| {
                if (opt.isShort('e')) {
                    escape = true;
                } else if (opt.isShort('E')) {
                    escape = false;
                }
            },

            .operand => |opr| {
                // Don't print space before the first operand
                if (print_space) try stdout.writeByte(' ');
                print_space = true;

                if (escape) {
                    writeEscaped(stdout, opr) catch |err| switch (err) {
                        error.StopOutput => return config.EXIT_SUCCESS, // No more printing (\c exit)
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

fn writeEscaped(w: *std.Io.Writer, s: []const u8) !void {
    var i: usize = 0;
    while (i < s.len) {
        const c = s[i];
        if (c != '\\') {
            try w.writeByte(c);
            i += 1;
            continue;
        }
        if (i + 1 >= s.len) break;

        const next = s[i + 1];
        i += 2;

        // next is a runtime u8
        switch (next) {
            'a' => try w.writeByte(0x07),
            'b' => try w.writeByte(0x08),
            'c' => return StopOutput.StopOutput,
            'e' => try w.writeByte(0x1B), // TODO: fix \e
            'f' => try w.writeByte(0x0C),
            'n' => try w.writeByte(0x0A),
            'r' => try w.writeByte(0x0D), // TODO: fix \r
            't' => try w.writeByte(0x09),
            'v' => try w.writeByte(0x0B),
            '\\' => try w.writeByte('\\'),

            'x' => {
                const res = try parseHexByte(s, i);
                const b = res[0];
                i = res[1];
                try w.writeByte(b);
            },

            '0'...'7' => {
                const res = parseOctal(s, next, i);
                const b = res[0];
                i = res[1];
                try w.writeByte(b);
            },

            else => {
                try w.writeByte('\\');
                try w.writeByte(next);
            },
        }
    }
}

/// Parses up to two hexadecimal digits from `s`, starting at index `idx`.
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
/// - `s`: Input byte slice containing ASCII characters
/// - `idx`: Starting index in `s`
///
/// Returns:
/// - A tuple `{ value, next_index }` where:
///   - `value` is the parsed hexadecimal value as `u8`
///   - `next_index` is the index immediately after the last consumed character
///
/// Errors:
/// - Propagates any error returned by `std.fmt.charToDigit`
fn parseHexByte(s: []const u8, idx: usize) !std.meta.Tuple(&.{ u8, usize }) {
    var i: usize = idx;
    var val: u8 = 0;
    var count: usize = 0;

    while (i < s.len and count < 2) {
        const c = s[i];
        if (!std.ascii.isHex(c)) break;

        const b16_digit = try std.fmt.charToDigit(c, 16);
        val = val * 16 + b16_digit;
        i += 1;
        count += 1;
    }

    return .{ @as(u8, val), @as(usize, i) };
}

test "parseHexByte parses two hex digits" {
    const input = "1f";
    const result = try parseHexByte(input, 0);

    try std.testing.expectEqual(@as(u8, 0x1f), result[0]);
    try std.testing.expectEqual(@as(usize, 2), result[1]);
}

test "parseHexByte parses one hex digit" {
    const input = "a";
    const result = try parseHexByte(input, 0);

    try std.testing.expectEqual(@as(u8, 0x0a), result[0]);
    try std.testing.expectEqual(@as(usize, 1), result[1]);
}

test "parseHexByte stops after two digits even if more are present" {
    const input = "abcd";
    const result = try parseHexByte(input, 0);

    try std.testing.expectEqual(@as(u8, 0xab), result[0]);
    try std.testing.expectEqual(@as(usize, 2), result[1]);
}

test "parseHexByte stops at non-hex character" {
    const input = "1g3";
    const result = try parseHexByte(input, 0);

    try std.testing.expectEqual(@as(u8, 0x01), result[0]);
    try std.testing.expectEqual(@as(usize, 1), result[1]);
}

test "parseHexByte returns zero when first character is not hex" {
    const input = "xyz";
    const result = try parseHexByte(input, 0);

    try std.testing.expectEqual(@as(u8, 0x00), result[0]);
    try std.testing.expectEqual(@as(usize, 0), result[1]);
}

test "parseHexByte works with offset index" {
    const input = "00ff";
    const result = try parseHexByte(input, 2);

    try std.testing.expectEqual(@as(u8, 0xff), result[0]);
    try std.testing.expectEqual(@as(usize, 4), result[1]);
}

test "parseHexByte handles end-of-slice safely" {
    const input = "f";
    const result = try parseHexByte(input, 0);

    try std.testing.expectEqual(@as(u8, 0x0f), result[0]);
    try std.testing.expectEqual(@as(usize, 1), result[1]);
}

test "parseHexByte starting at end of slice" {
    const input = "ff";
    const result = try parseHexByte(input, 2);

    try std.testing.expectEqual(@as(u8, 0x00), result[0]);
    try std.testing.expectEqual(@as(usize, 2), result[1]);
}

fn parseOctal(s: []const u8, first: u8, idx: usize) std.meta.Tuple(&.{ u8, usize }) {
    // TODO: needs fixing
    var i: usize = idx;
    var val: u8 = first - '0';
    var count: usize = 1;

    while (i < s.len and count < 3) {
        const c = s[i];

        if (c < '0' or c > '7') break;

        val = val * 8 + (c - '0');

        i += 1;

        count += 1;
    }

    return .{ @as(u8, val), @as(usize, i) };
}

fn printHelp(
    writer: anytype,
    program_name: []const u8,
    options: []const args.Option,
) !void {
    try writer.print(
        \\Usage: {s} [options] [string...]
        \\
        \\Options:
        \\
    , .{program_name});

    try args.printHelp(writer, options);

    try writer.print(
        \\
        \\If -e is in effect, the following sequences are recognized:
        \\
        \\  \\              backslash
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
        \\
    , .{});
}
