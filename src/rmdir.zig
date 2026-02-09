//  rmdir.zig, utility for deleting empty directories
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
const fs = std.fs;

const utils = @import("common/utils.zig");
const cli = @import("cli/mod.zig");
const config = @import("common/config.zig");
const validators = @import("common/validators.zig");

// Canonical option definitions for this util.
const CliOptions = cli.defineOptions(&.{
    .{
        .name = "parents",
        .short = 'p',
        .long = "parents",
        .help = "remove DIRECTORY and its ancestors; e.g., 'rmdir -p a/b/c' removes a/b/c, a/b, and a",
    },
    .{
        .name = "verbose",
        .short = 'v',
        .long = "verbose",
        .help = "output a diagnostic for every directory processed",
    },
    .{
        .name = "ignore_fail_on_non_empty",
        .long = "ignore-fail-on-non-empty",
        .help = "ignore each failure that is solely because a directory is non-empty",
    },
    cli.standard.defaultHelp,
    cli.standard.defaultVersion,
});

const Help = cli.Help{
    .usage = "Usage: {s} [OPTION]... DIRECTORY...\n",
    .description = "Remove the DIRECTORY(ies), if they are empty.",
};

pub fn main() !u8 {
    var stdout_writer = fs.File.stdout().writer(&.{});
    var stderr_writer = fs.File.stderr().writer(&.{});
    const stdout = &stdout_writer.interface;
    const stderr = &stderr_writer.interface;

    var ctx: CliOptions = undefined;
    try ctx.init();
    const program_name = ctx.args.programName();
    var iter = try ctx.args.iterator();

    // Configuration flags
    var remove_parents = false;
    var verbose = false;
    var ignore_non_empty = false;

    // Process all options
    while (iter.nextOption() catch |err| {
        try cli.printError(stderr, program_name, err);
        return config.EXIT_FAILURE;
    }) |opt| {
        if (try cli.handleStandardOption(
            &ctx,
            opt,
            stdout,
            program_name,
            Help,
            ctx.entriesSlice(),
            .{ .help = CliOptions.Option.help, .version = CliOptions.Option.version },
        )) |exit_code| return exit_code;

        switch (ctx.optionOf(opt)) {
            CliOptions.Option.ignore_fail_on_non_empty => ignore_non_empty = true,
            CliOptions.Option.parents => remove_parents = true,
            CliOptions.Option.verbose => verbose = true,
            CliOptions.Option.help,
            CliOptions.Option.version,
            => unreachable,
        }
    }

    // Process operands (directory paths)
    var had_operand = false;
    var exit_status: u8 = config.EXIT_SUCCESS;

    // Re-init iterator before scanning operands.
    iter = try ctx.args.iterator();

    while (iter.nextOperand()) |dir_path| {
        had_operand = true;

        validators.validateDirPath(dir_path) catch |err| {
            const message = switch (err) {
                error.EmptyPath,
                error.DotPath,
                error.DotDotPath,
                error.TrailingSlash,
                => "Invalid argument",
            };
            try stderr.print(
                "{s}: failed to remove '{s}': {s}\n",
                .{ program_name, dir_path, message },
            );
            exit_status = config.EXIT_FAILURE;
            continue;
        };

        // Attempt removal
        if (!try removeDirectory(stdout, stderr, program_name, dir_path, .{
            .parents = remove_parents,
            .verbose = verbose,
            .ignore_non_empty = ignore_non_empty,
        })) {
            exit_status = config.EXIT_FAILURE;
        }
    }

    if (!had_operand) {
        try stderr.print(
            "{s}: missing operand\nTry '{s} --help' for more information.\n",
            .{ program_name, program_name },
        );
        return config.EXIT_FAILURE;
    }

    return exit_status;
}

const RemoveOptions = struct {
    parents: bool,
    verbose: bool,
    ignore_non_empty: bool,
};

/// Removes directory and optionally its parents. Returns true on success.
fn removeDirectory(
    stdout: anytype,
    stderr: anytype,
    program_name: []const u8,
    path: []const u8,
    opts: RemoveOptions,
) !bool {
    var current = path;
    var overall_success = true;

    while (true) {
        fs.cwd().deleteDir(current) catch |err| {
            const is_not_empty = (err == error.DirNotEmpty);

            // Handle DirNotEmpty specially due to --ignore-fail-on-non-empty
            if (is_not_empty and opts.ignore_non_empty) {
                // Silently ignore
                break;
            }

            // Print appropriate error message
            if (is_not_empty) {
                try stderr.print(
                    "{s}: failed to remove '{s}': Directory not empty\n",
                    .{ program_name, current },
                );
            } else {
                try printRemovalError(stderr, program_name, current, err);
            }

            overall_success = false;
            break;
        };

        // Successfully removed
        if (opts.verbose) {
            try stdout.print("{s}: removing directory, '{s}'\n", .{ program_name, current });
        }

        // Stop if not removing parents
        if (!opts.parents) break;

        // Get parent directory
        const parent = utils.dirname(current) orelse break;

        // Stop at root or current directory
        if (parent.len == 0 or
            std.mem.eql(u8, parent, ".") or
            std.mem.eql(u8, parent, "/") or
            std.mem.eql(u8, parent, current))
        {
            break;
        }

        current = parent;
    }

    return overall_success;
}

/// Prints error message for directory removal failure.
fn printRemovalError(
    stderr: anytype,
    program_name: []const u8,
    path: []const u8,
    err: anyerror,
) !void {
    const message = switch (err) {
        error.FileNotFound => "No such file or directory",
        error.NotDir => "Not a directory",
        error.AccessDenied => "Permission denied",
        error.FileBusy => "Device or resource busy",
        error.InvalidUtf8 => "Invalid UTF-8",
        error.SymLinkLoop => "Too many levels of symbolic links",
        error.NameTooLong => "File name too long",
        error.SystemResources => "Insufficient kernel memory",
        error.ReadOnlyFileSystem => "Read-only file system",
        else => @errorName(err),
    };

    try stderr.print(
        "{s}: failed to remove '{s}': {s}\n",
        .{ program_name, path, message },
    );
}

// fn printHelp(
//     writer: anytype,
//     program: []const u8,
//     options: []const args.Option,
// ) !void {
//     try writer.print(
//         \\Usage: {s} [OPTION]... DIRECTORY...
//         \\Remove the DIRECTORY(ies), if they are empty.
//         \\
//         \\Options:
//         \\
//     , .{program});
//
//     try args.printHelp(writer, options);
// }
