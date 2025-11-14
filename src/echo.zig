//  echo.zig, write a line of text to stdout
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
const posix = std.posix;

const VERSION = "1.0.0";

pub fn main() !void {
    const STDOUT = 1;
    // const STDERR = 2;

    const allocator = std.heap.page_allocator;

    const all_args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, all_args);

    const program_name = all_args[0];
    const args = all_args[1..];

    // handle meta-flags
    if (args.len > 0) {
        const arg = args[0];
        if (std.mem.startsWith(u8, arg, "-")) {
            if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                const usage_foramt =
                    \\Usage: {s} [options...] [string...]
                    \\       {s} <option>
                    \\
                    \\Options:
                    \\  -h, --help        Display this help and exit (must be first)
                    \\  -v, --version     Output version information and exit (must be first)
                    \\
                    \\  -n, --no-newline  Do not output the trailing newline
                    \\
                ;
                const usage_str = try std.fmt.allocPrint(allocator, usage_foramt, .{ program_name, program_name });
                defer allocator.free(usage_str);
                _ = try posix.write(STDOUT, usage_str);
                return;
            }

            if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--version")) {
                const version_format = "{s}: {s}\n";
                const version_str = try std.fmt.allocPrint(allocator, version_format, .{ program_name, VERSION });
                defer allocator.free(version_str);
                _ = try posix.write(STDOUT, version_str);
                return;
            }
        }
    }

    // enabled by -e, disabled by -E
    const handle_escape_seq = false;
    _ = handle_escape_seq; // disable not-used warning

    // disabled by the -n flag
    var add_new_line: bool = true;

    var nr_of_flags: u8 = 0;

    // handle option flags
    for (args) |arg| {
        if (std.mem.startsWith(u8, arg, "-")) {
            if (std.mem.eql(u8, arg, "-n") or std.mem.eql(u8, arg, "--no-newline")) {
                add_new_line = false;
                nr_of_flags += 1;
                continue;
            }

            // unknown flags are ignored and interpreted as a string
            break;
        } else {
            // no more flags should be passed after the first non flag argument
            break;
        }
    }

    const args_with_no_flags = args[nr_of_flags..];

    if (args_with_no_flags.len == 0) {
        // default print nothing
        if (add_new_line) {
            _ = try posix.write(STDOUT, "\n");
        }
        return;
    } else {
        var total_len: usize = 0;
        for (args_with_no_flags) |arg| total_len += arg.len;
        total_len += args_with_no_flags.len - 1; // spaces

        if (add_new_line) {
            total_len += 1;
        }

        var line_buffer: []u8 = undefined;
        line_buffer = try allocator.alloc(u8, total_len);
        defer allocator.free(line_buffer);

        var pos: usize = 0;
        for (args_with_no_flags, 0..) |arg, i| {
            @memcpy(line_buffer[pos..][0..arg.len], arg);
            pos += arg.len;
            if (i < args_with_no_flags.len - 1) {
                line_buffer[pos] = ' ';
                pos += 1;
            }
        }
        if (add_new_line) {
            line_buffer[pos] = '\n';
        }

        _ = try posix.write(STDOUT, line_buffer);
        return;
    }
}
