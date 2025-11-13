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
const posix = std.posix;

pub fn main() !void {
    const STDOUT = 1;
    var hostname_buffer: [posix.HOST_NAME_MAX]u8 = undefined;
    _ = try posix.gethostname(&hostname_buffer);
    const hostname_len = std.mem.indexOfScalar(u8, &hostname_buffer, 0) orelse posix.HOST_NAME_MAX;
    _ = try posix.write(STDOUT, hostname_buffer[0..hostname_len]);
    _ = try posix.write(STDOUT, "\n");
    return;
}
