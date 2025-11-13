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

pub fn main() !void {
    const STDOUT = 1;

    posix.write(STDOUT, "WARNING: This 'echo' implementation is incomplete!\n");

    const allocator = std.heap.page_allocator;

    const all_args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, all_args);

    const args = all_args[1..];

    // disabled by the -n flag
    const add_new_line: bool = true;

    // handle falgs
    for (args) |arg| {
        if (std.mem.startsWith(u8, arg, "-")) {
            // TODO: handle flags
            return;
        }
    }

    if (args.len == 0) {
        // default print nothing
        if (add_new_line) {
            _ = try posix.write(STDOUT, "\n");
        }
        return;
    } else {
        var total_len: usize = 0;
        for (args) |arg| total_len += arg.len;
        total_len += args.len - 1; // spaces

        if (add_new_line) {
            total_len += 1;
        }

        var line_buffer: []u8 = undefined;
        line_buffer = try allocator.alloc(u8, total_len);
        defer allocator.free(line_buffer);

        var pos: usize = 0;
        for (args, 0..) |arg, i| {
            // if (std.mem.startsWith(u8, arg, "-")) continue;
            @memcpy(line_buffer[pos..][0..arg.len], arg);
            pos += arg.len;
            if (i < args.len - 1) {
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
