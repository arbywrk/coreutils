//  cli/define_options.zig, higher-level abstraction for defining options.
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
const cli = @import("args.zig");

pub const OptionSpec = cli.OptionSpec;

/// Declarative spec used by defineOptions().
pub const OptionSpecDecl = struct {
    /// Canonical option name. Must be a valid Zig identifier (use underscores).
    name: []const u8,
    short: ?u8 = null,
    long: ?[]const u8 = null,
    arg: cli.ArgMode = .none,
    help: []const u8 = "",
};

/// defineOptions() builds a specialized `Cli` type for a command.
/// The returned type owns its runtime option entries and provides canonical option switching.
pub fn defineOptions(comptime decls: []const OptionSpecDecl) type {
    comptime {
        if (decls.len == 0) @compileError("defineOptions: empty option list");
    }

    // Canonical enum for switching.
    const OptionEnum = comptime blk: {
        var ef: [decls.len]std.builtin.Type.EnumField = undefined;

        for (decls, 0..) |d, i| {
            const ztmp = d.name ++ "\x00";
            const zname: [:0]const u8 = ztmp[0 .. ztmp.len - 1 :0];
            ef[i] = .{ .name = zname, .value = i };
        }

        break :blk @Type(.{
            .@"enum" = .{
                .tag_type = u16,
                .fields = &ef,
                .decls = &.{},
                .is_exhaustive = true,
            },
        });
    };

    // Comptime specs table for metadata access (by enum index).
    const specs_table = comptime blk: {
        var arr: [decls.len]OptionSpec = undefined;
        for (decls, 0..) |d, i| {
            arr[i] = .{
                .short = d.short,
                .long = d.long,
                .arg = d.arg,
                .help = d.help,
            };
        }
        break :blk arr;
    };

    return struct {
        pub const Option = OptionEnum;
        pub const specs: [decls.len]OptionSpec = specs_table;

        /// Runtime option entries (spec + parse state) used by the low-level iterator.
        entries: [decls.len]cli.OptionEntry = undefined,

        /// Low-level parser instance.
        args: cli.Args = undefined,

        /// Initialize in-place to avoid self-referential slice issues.
        pub fn init(self: *@This()) !void {
            inline for (decls, 0..) |d, i| {
                self.entries[i] = .{
                    .spec = .{
                        .short = d.short,
                        .long = d.long,
                        .arg = d.arg,
                        .help = d.help,
                    },
                    .state = .{},
                };
            }

            self.args = try cli.Args.init(self.entries[0..]);
        }

        /// Map a parsed option to its canonical enum value.
        pub fn optionOf(self: *const @This(), opt: cli.ParsedOption) Option {
            // opt.spec points into self.entries[i].spec
            inline for (decls, 0..) |_, i| {
                if (opt.spec == &self.entries[i].spec) return @enumFromInt(i);
            }
            unreachable;
        }

        /// Access the OptionSpec for a canonical option.
        pub fn specOf(_: *const @This(), which: Option) *const OptionSpec {
            return &specs[@intFromEnum(which)];
        }

        /// Access the runtime option entries slice.
        pub fn entriesSlice(self: *const @This()) []const cli.OptionEntry {
            return self.entries[0..];
        }

        pub fn printHelp(self: *const @This(), w: anytype) !void {
            try cli.printHelp(w, self.entries[0..]);
        }
    };
}
