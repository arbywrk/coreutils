//  rmdir.zig, utility for deleting empty directories
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
const proc = std.process;
const fs = std.fs;

const utils = @import("common/utils.zig");
const version = @import("common/version.zig");
const arguments = @import("common/args.zig");
const Args = arguments.Args;

pub fn main() !u8 {
    var stdout_writer = fs.File.stdout().writer(&.{});
    var stderr_writer = fs.File.stderr().writer(&.{});
    const stdout = &stdout_writer.interface;
    const stderr = &stderr_writer.interface;

    const specs = [_]arguments.OptionSpec{
        .{
            .short = 'p',
            .long = "parents",
            .help = "remove DIRECTORY and its ancestors; e.g., 'rmdir -p a/b/c' is similar to 'rmdir a/b/c a/b a'",
            // TODO: create a struct for the help message containing the help msg format and argumetns if needed
        },
        .{
            .short = 'v',
            .long = "verbose",
            .help = "output a diagnostic for every directory processed",
        },
        .{
            .long = "ignore-fail-on-non-empty",
            .help = "ignore each failure that is solely because a directory is non-empty",
        },
        .{
            .long = "help",
            .help = "display this help and exit",
        },
        .{
            .long = "version",
            .help = "output version information and exit",
        },
    };

    var remove_parents = false;
    var verbose = false;
    var ignore_non_empty = false;

    var args = try Args.init(&specs);
    const program_name = args.programName();
    var argsIt = try args.iterator();

    // Process options.
    argsIt.setMode(.options_only);
    while (argsIt.next() catch |err| {
        switch (err) {
            error.UnknownOption => {
                try stderr.print(
                    "{s}: invalid option\nTry '{s} --help' for more information.\n",
                    .{ program_name, program_name },
                );
            },
            error.MissingOptionArgument => {
                try stderr.print(
                    "{s}: option requires an argument\nTry '{s} --help' for more information.\n",
                    .{ program_name, program_name },
                );
            },
            error.UnexpectedArgument => {
                try stderr.print(
                    "{s}: option does not take an argument\nTry '{s} --help' for more information.\n",
                    .{ program_name, program_name },
                );
            },
        }
        return 1;
    }) |arg| {
        if (arg.option.spec.long) |l| {
            if (std.mem.eql(u8, l, "help")) {
                try printHelp(stdout, program_name, &specs);
                return 0;
            }
            if (std.mem.eql(u8, l, "version")) {
                try version.printVersion(stdout, program_name);
                return 0;
            }
            if (std.mem.eql(u8, l, "ignore-fail-on-non-empty")) {
                ignore_non_empty = true;
                continue;
            }
        }

        // Handle short options
        if (arg.option.spec.short) |c| {
            switch (c) {
                'p' => remove_parents = true,
                'v' => verbose = true,
                else => {},
            }
        }
    }

    // Process operands.
    var had_operand = false;
    var exit_status: u8 = 0;

    argsIt.reset();
    argsIt.setMode(.operands_only);
    while (argsIt.next() catch |err| {
        switch (err) {
            error.UnknownOption => {
                // TODO: handle error
                return 1;
            },
            error.UnexpectedArgument => {
                // TODO: handle error
                return 1;
            },
            error.MissingOptionArgument => {
                // TODO: handle error
                return 1;
            },
        }
    }) |arg| {
        had_operand = true;
        const path = arg.operand;

        // Safety (shouldn't happen)
        if (path.len == 0) continue;

        // Validate path: reject "." and ".."
        if (std.mem.eql(u8, path, ".") or std.mem.eql(u8, path, "..")) {
            try stderr.print(
                "{s}: failed to remove '{s}': Invalid Argument\n", // TODO: create custom error
                .{ program_name, path },
            );
            exit_status = 1;
            continue;
        }

        // Validate path: reject paths ending with "/" (POSIX behavior)
        if (path[path.len - 1] == '/') {
            try stderr.print(
                "{s}: failed to remove '{s}': Invalid argument\n",
                .{ program_name, path },
            );
            exit_status = 1;
            continue;
        }

        if (!try removeOne(
            stderr,
            program_name,
            path,
            remove_parents,
            verbose,
            ignore_non_empty,
        )) {
            exit_status = 1;
        }
    }

    if (!had_operand) {
        try stderr.print(
            "{s}: missing operand\nTry '{s} --help' for more information.\n",
            .{ program_name, program_name },
        );
        return 1;
    }

    return exit_status;
}

/// Remove a directory, optionally with its parent directories.
/// Returns true on success, false on failure.
fn removeOne(
    stderr: anytype,
    program_name: []const u8,
    path: []const u8,
    parents: bool,
    verbose: bool,
    ignore_non_empty: bool,
) !bool {
    var success = true;
    var current = path;

    while (true) {
        // Attempt to remove the directory
        if (fs.cwd().deleteDir(current)) {
            if (verbose) {
                try stderr.print("{s}: removing directory, '{s}'\n", .{ program_name, current });
            }
        } else |err| {
            // Handle specific error cases
            const err_is_dir_not_empty = switch (err) {
                // Check if the error is 'dir not empty' so that the logic can be handled
                // underneath, taking into account the ignore-fail-on-non-empty option.
                error.DirNotEmpty => true,

                // The other errors are handled on the spot
                error.FileNotFound => blk: {
                    try stderr.print(
                        "{s}: failed to remove '{s}': No such file or directory\n",
                        .{ program_name, current },
                    );
                    break :blk false;
                },
                error.NotDir => blk: {
                    try stderr.print(
                        "{s}: failed to remove '{s}': Not a directory\n",
                        .{ program_name, current },
                    );
                    break :blk false;
                },
                error.AccessDenied => blk: {
                    try stderr.print(
                        "{s}: failed to remove '{s}': Permission denied\n",
                        .{ program_name, current },
                    );
                    break :blk false;
                },
                error.FileBusy => blk: {
                    try stderr.print(
                        "{s}: failed to remove '{s}': Device or resource busy\n",
                        .{ program_name, current },
                    );
                    break :blk false;
                },
                error.InvalidUtf8 => blk: {
                    try stderr.print(
                        "{s}: failed to remove '{s}': Invalid UTF-8\n",
                        .{ program_name, current },
                    );
                    break :blk false;
                },
                error.SymLinkLoop => blk: {
                    try stderr.print(
                        "{s}: failed to remove '{s}': Too many levels of symbolic links\n",
                        .{ program_name, current },
                    );
                    break :blk false;
                },
                error.NameTooLong => blk: {
                    try stderr.print(
                        "{s}: failed to remove '{s}': File name too long\n",
                        .{ program_name, current },
                    );
                    break :blk false;
                },
                error.SystemResources => blk: {
                    try stderr.print(
                        "{s}: failed to remove '{s}': Insufficient kernel memory\n",
                        .{ program_name, current },
                    );
                    break :blk false;
                },
                error.ReadOnlyFileSystem => blk: {
                    try stderr.print(
                        "{s}: failed to remove '{s}': Read-only file system\n",
                        .{ program_name, current },
                    );
                    break :blk false;
                },
                else => blk: {
                    // Generic error handling for unexpected errors
                    try stderr.print(
                        "{s}: failed to remove '{s}': {s}\n",
                        .{ program_name, current, @errorName(err) },
                    );
                    break :blk false;
                },
            };

            success = false;

            if (err_is_dir_not_empty and !ignore_non_empty) {
                try stderr.print(
                    "{s}: failed to remove '{s}': Directory not empty\n",
                    .{ program_name, current },
                );
            } else if (ignore_non_empty) {
                // ignore the fail of 'dir not empty'
                success = true;
            }

            // If removal fails, don't continue with parents.
            break;
        }

        // If -p not specified, stop after removing the target directory.
        if (!parents) break;

        // Get parent directory.
        const parent = utils.dirname(current) orelse break;

        // Stop if it reached the root or current directory.
        if (parent.len == 0 or
            std.mem.eql(u8, parent, ".") or
            std.mem.eql(u8, parent, "/"))
        {
            break;
        }

        current = parent;
    }

    return success;
}

fn printHelp(
    writer: anytype,
    program: []const u8,
    specs: []const arguments.OptionSpec,
) !void {
    try writer.print(
        \\Usage: {s} [OPTION]... DIRECTORY...
        \\
        \\Remove the DIRECTORY(ies), if they are empty.
        \\
        \\Options:
    , .{program});

    try arguments.printHelp(writer, specs);
}
