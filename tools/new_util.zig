//  tools/new_util.zig, helper for scaffolding a new coreutil
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
const std = @import("std");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var stdout_writer = std.fs.File.stdout().writer(&.{});
    const stdout = &stdout_writer.interface;

    var args_it = std.process.args();
    _ = args_it.next(); // skip argv[0]
    const name = args_it.next() orelse {
        try stdout.print("Usage: zig run tools/new_util.zig -- <name>\n", .{});
        return;
    };

    if (name.len == 0) {
        try stdout.print("Name cannot be empty.\n", .{});
        return;
    }
    if (!isValidName(name)) {
        try stdout.print("Invalid name. Use only [A-Za-z0-9_].\n", .{});
        return;
    }
    const desc_comment = "<Short Description>";
    const usage_suffix = "<Usage>";

    const template = try std.fmt.allocPrint(allocator,
        \\//  {s}.zig, {s}
        \\//  Copyright (C) 2026 <Your Name>
        \\//
        \\//  This program is free software: you can redistribute it and/or modify
        \\//  it under the terms of the GNU General Public License as published by
        \\//  the Free Software Foundation, either version 3 of the License, or
        \\//  (at your option) any later version.
        \\//
        \\//  This program is distributed in the hope that it will be useful,
        \\//  but WITHOUT ANY WARRANTY; without even the implied warranty of
        \\//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
        \\//  GNU General Public License for more details.
        \\//
        \\//  You should have received a copy of the GNU General Public License
        \\//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
        \\//
        \\const std = @import("std");
        \\const cli = @import("cli/mod.zig");
        \\const config = @import("common/config.zig");
        \\
        \\// Define all options once and use the generated enum for switching.
        \\const CliOptions = cli.defineOptions(&.{{
        \\    cli.standard.defaultHelp,
        \\    cli.standard.defaultVersion,
        \\    // Add your options here:
        \\    // .{{ .name = "verbose", .short = 'v', .long = "verbose", .help = "enable verbose output" }},
        \\}});
        \\
        \\const Help = cli.Help{{
        \\    .usage = "Usage: {{s}} {s}\\n",
        \\    .description = "{s}",
        \\    // .after_options = "Extra notes after the option list.\\n",
        \\}};
        \\
        \\pub fn main() !u8 {{
        \\    var stdout_writer = std.fs.File.stdout().writer(&.{{}});
        \\    var stderr_writer = std.fs.File.stderr().writer(&.{{}});
        \\    const stdout = &stdout_writer.interface;
        \\    const stderr = &stderr_writer.interface;
        \\
        \\    var ctx: CliOptions = undefined;
        \\    try ctx.init();
        \\    const program_name = ctx.args.programName();
        \\
        \\    // Parse options first (errors are reported consistently).
        \\    var iter = try ctx.args.iterator();
        \\    while (iter.nextOption() catch |err| {{
        \\        try cli.printError(stderr, program_name, err);
        \\        return config.EXIT_FAILURE;
        \\    }}) |opt| {{
        \\        if (try cli.handleStandardOption(
        \\            &ctx,
        \\            opt,
        \\            stdout,
        \\            program_name,
        \\            Help,
        \\            ctx.entriesSlice(),
        \\            .{{ .help = CliOptions.Option.help, .version = CliOptions.Option.version }},
        \\        )) |exit_code| return exit_code;
        \\
        \\        switch (ctx.optionOf(opt)) {{
        \\            // Handle your custom options here.
        \\            // CliOptions.Option.verbose => {{}},
        \\            CliOptions.Option.help,
        \\            CliOptions.Option.version,
        \\            => unreachable,
        \\        }}
        \\    }}
        \\
        \\    // Process operands (non-option arguments).
        \\    iter = try ctx.args.iterator();
        \\    while (iter.nextOperand()) |operand| {{
        \\        _ = operand;
        \\        // IMPLEMENT: core logic here
        \\    }}
        \\
        \\    // If you need to handle options and operands in order, use:
        \\    // while (try iter.next()) |arg| switch (arg) {{ .option => |o| {{...}}, .operand => |op| {{...}} }}
        \\
        \\    return config.EXIT_SUCCESS;
        \\}}
        \\
    , .{ name, desc_comment, usage_suffix, desc_comment });
    defer allocator.free(template);

    const path = try std.fmt.allocPrint(allocator, "src/{s}.zig", .{name});
    defer allocator.free(path);

    var file = std.fs.cwd().createFile(path, .{ .exclusive = true }) catch |err| {
        switch (err) {
            error.PathAlreadyExists => {
                try stdout.print("File already exists: {s}\n", .{path});
                return;
            },
            else => return err,
        }
    };
    defer file.close();

    try file.writeAll(template);
    try stdout.print("Created {s}\n", .{path});
}

fn isValidName(name: []const u8) bool {
    if (name.len == 0) return false;
    for (name) |c| {
        if ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or (c == '_')) {
            continue;
        }
        return false;
    }
    return true;
}
