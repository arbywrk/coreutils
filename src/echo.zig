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

const StopOutput = error{StopOutput};

pub fn main() !void {
    var stdout_writer: std.fs.File.Writer = std.fs.File.stdout().writer(&.{});
    const stdout: *std.Io.Writer = &stdout_writer.interface;

    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    const program_name = utils.basename(args[0]);

    // parse meta-flags
    for (args[1..]) |arg| {
        if (!std.mem.startsWith(u8, arg, "-")) {
            continue;
        }

        if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--version")) {
            try version.printVersion(stdout, program_name);
            return;
        } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            const usage =
                \\Usage: {s} [options] [string...]
                \\
                \\Options:
                \\  -h, --help      Print this help and exit
                \\  -v, --version   Print version and exit
                \\  -n              Do not output a trailing newline
                \\  -e              Enable interpretation of backslash escapes
                \\  -E              Disable interpretation of backslash escapes (default)
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
            ;
            _ = try stdout.print(usage, .{program_name});
            return;
        }
    }

    var add_newline = true;
    var escape = false;

    var i: usize = 1;

    // parse flags
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') {
        const a = args[i];
        if (std.mem.eql(u8, a, "-n")) {
            add_newline = false;
        } else if (std.mem.eql(u8, a, "-e")) {
            escape = true;
        } else if (std.mem.eql(u8, a, "-E")) {
            escape = false;
        } else break;
        i += 1;
    }

    // print arguments
    var first = true;
    while (i < args.len) {
        if (!first) try stdout.writeByte(' ');
        first = false;

        if (escape) {
            writeEscaped(stdout, args[i]) catch |err| switch (err) {
                error.StopOutput => return, // No more printing (\c exit)
                else => return err,
            };
        } else {
            try stdout.writeAll(args[i]);
        }

        i += 1;
    }

    if (add_newline)
        try stdout.writeByte('\n');

    try stdout.flush();
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
            'e' => try w.writeByte(0x1B),
            'f' => try w.writeByte(0x0C),
            'n' => try w.writeByte(0x0A),
            'r' => try w.writeByte(0x0D),
            't' => try w.writeByte(0x09),
            'v' => try w.writeByte(0x0B),
            '\\' => try w.writeByte('\\'),

            'x' => {
                const res = try parseHex(s, i);
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

fn parseHex(s: []const u8, idx: usize) !std.meta.Tuple(&.{ u8, usize }) {
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

test "parseHex basic hex cases" {
    const input = "x41 rest";
    // index 1 → char at index 1 = '4'
    const res = try parseHex(input, 1);
    try std.testing.expectEqual(@as(u8, 0x41), res[0]);
    try std.testing.expectEqual(@as(usize, 3), res[1]);
}

test "parseHex single hex digit" {
    const input = "xA hello";
    const res = try parseHex(input, 1);
    try std.testing.expectEqual(@as(u8, 0x0A), res[0]);
    try std.testing.expectEqual(@as(usize, 2), res[1]);
}

test "parseHex no hex digits" {
    const input = "xG0";
    const res = try parseHex(input, 1);
    // No valid digits → value = 0, index stays same
    try std.testing.expectEqual(@as(u8, 0), res[0]);
    try std.testing.expectEqual(@as(usize, 1), res[1]);
}

test "parseHex stops at non-hex character" {
    const input = "4Z";
    const res = try parseHex(input, 0);
    try std.testing.expectEqual(@as(u8, 4), res[0]); // '4' = 0x04
    try std.testing.expectEqual(@as(usize, 1), res[1]);
}

fn parseOctal(s: []const u8, first: u8, idx: usize) std.meta.Tuple(&.{ u8, usize }) {
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

test "parseOctal simple octal" {
    const input = "123rest";
    const res = parseOctal(input, input[0], 1);
    try std.testing.expectEqual(@as(u8, 0o123), res[0]); // octal 123 = decimal 83
    try std.testing.expectEqual(@as(usize, 3), res[1]);
}

test "parseOctal stops at non-octal" {
    const input = "78";
    const res = parseOctal(input, input[0], 1);
    try std.testing.expectEqual(@as(u8, 7), res[0]);
    try std.testing.expectEqual(@as(usize, 1), res[1]); // '8' is invalid octal
}

test "parseOctal max 3 digits" {
    const input = "1234";
    const res = parseOctal(input, input[0], 1);
    try std.testing.expectEqual(@as(u8, 0o123), res[0]); // 83
    try std.testing.expectEqual(@as(usize, 3), res[1]); // stops after 3 digits
}

test "parseOctal single digit" {
    const input = "1abc";
    const res = parseOctal(input, input[0], 1);
    try std.testing.expectEqual(@as(u8, 1), res[0]);
    try std.testing.expectEqual(@as(usize, 1), res[1]);
}
