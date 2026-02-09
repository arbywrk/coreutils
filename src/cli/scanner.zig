//  cli/scanner.zig, tokenization of argv into short options, long options, and operands.
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
//  shared by the scanner, iterator, and higher-level helpers.
//
const std = @import("std");
const types = @import("types.zig");

const Token = union(enum) {
    short: struct { char: u8, value: ?[]const u8 },
    long: struct { name: []const u8, value: ?[]const u8 },
    operand: []const u8,
};

pub const Scanner = struct {
    args: std.process.ArgIterator,
    past_delimiter: bool = false,
    short_cluster: ?[]const u8 = null,
    options: []types.OptionEntry,

    pub fn init(options: []types.OptionEntry) !Scanner {
        var it = std.process.args();
        if (!it.skip()) return error.NoProgramName;
        return .{ .args = it, .options = options };
    }

    pub fn next(self: *Scanner) ?Token {
        // Process remaining characters from short option cluster (-abc).
        if (self.short_cluster) |cluster| {
            const char = cluster[0];
            const rest = cluster[1..];

            // If this option takes an argument, consume rest of cluster as the value.
            if (findShort(self.options, char)) |opt| {
                if (opt.spec.arg == .required or opt.spec.arg == .optional) {
                    self.short_cluster = null;
                    return .{ .short = .{
                        .char = char,
                        .value = if (rest.len > 0) rest else null,
                    } };
                }
            }

            // Option takes no argument; continue processing cluster.
            self.short_cluster = if (rest.len > 0) rest else null;
            return .{ .short = .{ .char = char, .value = null } };
        }

        const arg = self.args.next() orelse return null;

        if (self.past_delimiter) return .{ .operand = arg };

        if (std.mem.eql(u8, arg, "--")) {
            self.past_delimiter = true;
            return self.next();
        }

        if (std.mem.eql(u8, arg, "-")) return .{ .operand = arg };

        // Long option: --name or --name=value
        if (std.mem.startsWith(u8, arg, "--")) {
            const body = arg[2..];
            const eq = std.mem.indexOfScalar(u8, body, '=');
            return .{ .long = .{
                .name = body[0..(eq orelse body.len)],
                .value = if (eq) |i| body[i + 1 ..] else null,
            } };
        }

        // Short option(s): -v or -abc
        if (arg.len >= 2 and arg[0] == '-') {
            self.short_cluster = arg[1..];
            return self.next();
        }

        return .{ .operand = arg };
    }

    /// Peek at the next operand without consuming it.
    /// Used to implement optional arguments.
    pub fn peekOperand(self: *Scanner) ?[]const u8 {
        const saved_short = self.short_cluster;
        const tok = self.next();
        self.short_cluster = saved_short;

        return if (tok) |t| switch (t) {
            .operand => |op| op,
            else => null,
        } else null;
    }
};

pub fn findShort(options: []const types.OptionEntry, char: u8) ?*const types.OptionEntry {
    for (options) |*o| if (o.spec.short == char) return o;
    return null;
}

pub fn findShortMut(options: []types.OptionEntry, char: u8) ?*types.OptionEntry {
    for (options) |*o| if (o.spec.short == char) return o;
    return null;
}

pub fn findLong(options: []const types.OptionEntry, name: []const u8) ?*const types.OptionEntry {
    for (options) |*o| {
        if (o.spec.long) |l| {
            if (std.mem.eql(u8, l, name)) return o;
        }
    }
    return null;
}

pub fn findLongMut(options: []types.OptionEntry, name: []const u8) ?*types.OptionEntry {
    for (options) |*o| {
        if (o.spec.long) |l| {
            if (std.mem.eql(u8, l, name)) return o;
        }
    }
    return null;
}

pub const TokenType = Token;
