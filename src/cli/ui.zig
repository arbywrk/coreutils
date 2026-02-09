//  cli/ui.zig, user-facing CLI helpers
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
//
const types = @import("types.zig");
const config = @import("../common/config.zig");
const version = @import("../common/version.zig");

pub const Help = struct {
    usage: []const u8,
    /// Optional description shown after usage.
    description: []const u8 = "",
    /// Optional footer shown after options (e.g. extra syntax notes).
    after_options: []const u8 = "",
};

pub fn printCommandHelp(
    writer: anytype,
    program_name: []const u8,
    help: Help,
    options: []const types.OptionEntry,
) !void {
    try writeUsage(writer, program_name, help.usage);
    if (help.usage.len == 0 or help.usage[help.usage.len - 1] != '\n') {
        try writer.writeByte('\n');
    }

    if (help.description.len > 0) {
        try writer.print("{s}\n", .{help.description});
    }

    try writer.print("\nOptions:\n\n", .{});
    try types.printHelp(writer, options);

    if (help.after_options.len > 0) {
        if (help.after_options[help.after_options.len - 1] != '\n') {
            try writer.print("\n{s}\n", .{help.after_options});
        } else {
            try writer.print("\n{s}", .{help.after_options});
        }
    }
}

fn writeUsage(writer: anytype, program_name: []const u8, usage: []const u8) !void {
    var i: usize = 0;
    while (i < usage.len) {
        if (usage[i] == '{' and i + 2 < usage.len and usage[i + 1] == 's' and usage[i + 2] == '}') {
            try writer.writeAll(program_name);
            i += 3;
        } else {
            try writer.writeByte(usage[i]);
            i += 1;
        }
    }
}

pub fn handleStandardOption(
    ctx: anytype,
    opt: types.ParsedOption,
    stdout: anytype,
    program_name: []const u8,
    help: Help,
    options: []const types.OptionEntry,
    standard: anytype,
) !?u8 {
    const which = ctx.optionOf(opt);
    if (which == standard.help) {
        try printCommandHelp(stdout, program_name, help, options);
        return config.EXIT_SUCCESS;
    }
    if (which == standard.version) {
        try version.printVersion(stdout, program_name);
        return config.EXIT_SUCCESS;
    }
    return null;
}
