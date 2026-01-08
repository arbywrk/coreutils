//  hostname.zig, write the hostname to stdout
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
const config = @import("common/config.zig");
const arguments = @import("common/args.zig");
const posix = std.posix;

pub fn main() !u8 {
    var stdout_writer = std.fs.File.stdout().writer(&.{});
    // var stderr_writer = std.fs.File.stderr().writer(&.{});
    const stdout = &stdout_writer.interface;
    // const stderr = &stderr_writer.interface;

    // const specs = [_]arguments.OptionSpec{
    //     .{ .short = 'a', .long = "aliases", .help = "alias names" },
    //     .{ .short = 'd', .long = "domain", .help = "DNS domain name" },
    //     .{ .short = 'f', .long = "fqdn", .help = "DNS host name of FQDN" },
    //     .{ .short = 'f', .long = "long", .help = "DNS host name of FQDN" },
    //     .{ .short = 'F', .long = "file", .arg = .required, .help = "set host name or NIS domain name from FILE" },
    //     .{ .short = 'i', .long = "ip-addresses", .help = "addresses for the host name" },
    //     .{ .short = 's', .long = "short", .help = "short host name" },
    //     .{ .short = 'y', .long = "yp", .help = "NIS/YP domain name" },
    //     .{ .short = 'y', .long = "nis", .help = "NIS/YP domain name" },
    //     .{ .long = "help", .help = "display this help and exit" },
    //     .{ .long = "version", .help = "output version information and exit" },
    // };

    var hostname_buffer: [posix.HOST_NAME_MAX]u8 = undefined;
    _ = try posix.gethostname(&hostname_buffer);
    const hostname_len = std.mem.indexOfScalar(u8, &hostname_buffer, 0) orelse posix.HOST_NAME_MAX;
    try stdout.print("{s}\n", .{hostname_buffer[0..hostname_len]});
    return config.EXIT_SUCCESS;
}
