//  true.zig, do nothing successfluly
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
const utils = @import("common/utils.zig");
const version = @import("common/version.zig");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    const program_name = utils.basename(args[0]);

    // parse meta-flags
    if (args.len > 1 and std.mem.startsWith(u8, args[1], "-")) {
        if (std.mem.eql(u8, args[1], "-v") or std.mem.eql(u8, args[1], "--version")) {
            var stdout_writer: std.fs.File.Writer = std.fs.File.stdout().writer(&.{});
            const stdout: *std.Io.Writer = &stdout_writer.interface;
            try version.printVersion(stdout, program_name);
            return;
        } else if (std.mem.eql(u8, args[1], "-h") or std.mem.eql(u8, args[1], "--help")) {
            var stdout_writer: std.fs.File.Writer = std.fs.File.stdout().writer(&.{});
            const stdout: *std.Io.Writer = &stdout_writer.interface;
            const usage =
                \\Usage: {s} [ignored command line arguments]
                \\       {s} OPTION
                \\
                \\Options:
                \\  -h, --help      Print this help and exit
                \\  -v, --version   Print version and exit
                \\
            ;
            try stdout.print(usage, .{ program_name, program_name });
            return;
        }
    }
    std.posix.exit(0);
}
