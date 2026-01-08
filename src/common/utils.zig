//  utils.zig, small utilities and helpers
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

pub fn basename(path: []const u8) []const u8 {
    return std.fs.path.basename(path);
}

pub fn dirname(path: []const u8) ?[]const u8 {
    const len = path.len;
    if (len == 0) return "."; // empty string → "."

    // strip trailing slashes
    var end: usize = len;
    while (end > 0 and path[end - 1] == '/') : (end -= 1) {}

    if (end == 0) return "/"; // path was all slashes

    // find last slash before 'end'
    var i: isize = @as(isize, @intCast(end)) - 1;
    while (i >= 0) : (i -= 1) {
        if (path[@as(usize, @intCast(i))] == '/') break;
    }

    if (i < 0) return "."; // no slash found → current dir

    // skip any trailing slashes in the result
    var dir_end: usize = @as(usize, @intCast(i));
    while (dir_end > 0 and path[dir_end - 1] == '/') : (dir_end -= 1) {}

    if (dir_end == 0) return "/"; // root

    return path[0..dir_end];
}
