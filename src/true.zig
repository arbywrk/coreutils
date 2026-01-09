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
const version = @import("common/version.zig");
const args = @import("common/args.zig");
const config = @import("common/config.zig");

pub fn main() !u8 {
    var options = [_]args.Option{
        .{ .def = .{ .long = "help", .help = "display this help and exit" } },
        .{ .def = .{ .long = "version", .help = "output version information and exit" } },
    };

    const arguments = try args.Args.init(&options);
    const program_name = arguments.programName();
    var iter = try arguments.iterator();

    // Check for --help or --version (all other arguments ignored)
    while (try iter.nextOption()) |opt| {
        if (opt.isLong("help")) {
            var stdout_writer = std.fs.File.stdout().writer(&.{});
            const stdout = &stdout_writer.interface;
            try stdout.print(
                \\Usage: {s} [ignored command line arguments]
                \\   or: {s} OPTION
                \\Exit with a status code indicating success.
                \\
                \\Options:
                \\
            , .{ program_name, program_name });
            try args.printHelp(stdout, &options);
            return config.EXIT_SUCCESS;
        }

        if (opt.isLong("version")) {
            var stdout_writer = std.fs.File.stdout().writer(&.{});
            const stdout = &stdout_writer.interface;
            try version.printVersion(stdout, program_name);
            return config.EXIT_SUCCESS;
        }
    }

    return config.EXIT_SUCCESS;
}
