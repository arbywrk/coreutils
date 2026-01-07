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
const errors = @import("common/errors.zig");
const Args = arguments.Args;

// TODO: Consider adding proper exit codes as constants for better maintainability
// const EXIT_SUCCESS: u8 = 0;
// const EXIT_FAILURE: u8 = 1;

pub fn main() !u8 {
    // TODO: These writer patterns are verbose. Consider a helper function or wrapper:
    // const io = try utils.getStdIO();
    // Then use io.stdout, io.stderr
    var stdout_writer = fs.File.stdout().writer(&.{});
    var stderr_writer = fs.File.stderr().writer(&.{});
    const stdout = &stdout_writer.interface;
    const stderr = &stderr_writer.interface;

    const specs = [_]arguments.OptionSpec{
        .{ .short = 'p', .long = "parents", .help = "remove DIRECTORY and its ancestors" },
        .{
            .short = 'v',
            .long = "verbose",
            .help = "output a diagnostic for every directory processed",
        },
        .{
            .long = "ignore-fail-on-non-empty",
            .help = "ignore each failure that is solely because a directory is non-empty",
        },
        // TODO: Consider adding .short = 'h' for --help (common convention)
        .{
            .long = "help",
            .help = "display this help and exit",
        },
        // TODO: Consider adding .short = 'V' for --version (common convention)
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
    // TODO: The error handling pattern is repetitive. Consider extracting to a helper function:
    // handleOptionError(stderr, program_name, err)
    while (argsIt.nextOption() catch |err| {
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
    }) |opt| {
        // TODO: This pattern could be simplified with a helper. Consider:
        // if (opt.isLong("help")) { ... }
        // if (opt.isShort('p')) { ... }
        if (opt.spec.long) |l| {
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
        if (opt.spec.short) |c| {
            switch (c) {
                'p' => remove_parents = true,
                'v' => verbose = true,
                // TODO: The else branch is unnecessary if all short options are handled above.
                // If a short option exists in specs but isn't handled here, that's a bug.
                // Consider adding a compile-time assertion or at least an unreachable.
                else => {},
            }
        }
    }

    // Process operands.
    var had_operand = false;
    var exit_status: u8 = 0;

    // TODO: CRITICAL BUG - Calling reset() here is inefficient and potentially problematic.
    // The argsIt already consumed all options, so calling reset() forces re-parsing
    // the entire argument list from the OS. This is especially bad because:
    // 1. It's unnecessary - the iterator should already be positioned after options
    // 2. It doubles the system calls to read args
    // 3. If there's any issue with reset() (known bug in your args.zig), this fails
    //
    // SOLUTION: Don't reset. The iterator should naturally move to operands after
    // nextOption() returns null. Remove the reset() call entirely.
    try argsIt.reset();

    while (argsIt.nextOperand()) |dir_path| {
        had_operand = true;

        // Safety (shouldn't happen)
        if (dir_path.len == 0) continue;

        // Reject "." and "..".
        // TODO: This check has inconsistent capitalization in error message
        // "Invalid Argument" vs "Invalid argument" below
        if (std.mem.eql(u8, dir_path, ".") or std.mem.eql(u8, dir_path, "..")) {
            try stderr.print(
                "{s}: failed to remove '{s}': Invalid Argument\n",
                .{ program_name, dir_path },
            );
            exit_status = 1;
            continue;
        }

        // Reject paths ending with "/"
        // TODO: POSIX specifies this behavior, but should this also check for multiple
        // trailing slashes? "path///" should also be rejected.
        // Consider: std.mem.endsWith(u8, dir_path, "/")
        if (dir_path[dir_path.len - 1] == '/') {
            try stderr.print(
                "{s}: failed to remove '{s}': Invalid argument\n",
                .{ program_name, dir_path },
            );
            exit_status = 1;
            continue;
        }

        // TODO: Consider validating paths earlier:
        // - Empty path components (path//path)
        // - Null bytes in path
        // - Excessively long paths before attempting removal

        if (!try removeOne(
            stderr,
            program_name,
            dir_path,
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
// TODO: Function signature could be cleaner with a config struct:
// const RemoveConfig = struct { parents: bool, verbose: bool, ignore_non_empty: bool };
// This reduces parameter count and makes call sites clearer.
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
                // TODO: POSIX compliance - verbose output should go to stdout, not stderr
                // GNU rmdir sends verbose messages to stdout
                try stderr.print("{s}: removing directory, '{s}'\n", .{ program_name, current });
            }
        } else |err| {
            // Handle specific error cases
            // TODO: This error handling pattern is clever but has issues:
            // 1. The err_is_dir_not_empty logic is convoluted
            // 2. Setting success=false before checking ignore_non_empty then setting it back to true is confusing
            // 3. Consider extracting error printing to a separate function
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
                // TODO: Add more specific errors:
                // - error.PathAlreadyExists (shouldn't happen for deleteDir but be defensive)
                // - error.IsDir (if path is actually a file, though NotDir should cover this)
                // - error.NoDevice
                // - error.NoSpaceLeft
                else => blk: {
                    // Generic error handling for unexpected errors
                    try stderr.print(
                        "{s}: failed to remove '{s}': {s}\n",
                        .{ program_name, current, @errorName(err) },
                    );
                    break :blk false;
                },
            };

            // TODO: This logic is confusing. The success flag is set to false, then
            // potentially set back to true. Consider restructuring:
            //
            // if (err_is_dir_not_empty) {
            //     if (ignore_non_empty) {
            //         // Silently ignore
            //     } else {
            //         try stderr.print(...);
            //         success = false;
            //     }
            // } else {
            //     success = false; // Error was already printed above
            // }
            success = false;

            if (err_is_dir_not_empty and !ignore_non_empty) {
                try stderr.print(
                    "{s}: failed to remove '{s}': Directory not empty\n",
                    .{ program_name, current },
                );
            } else if (ignore_non_empty) {
                // ignore the fail of 'dir not empty'
                // TODO: This condition is wrong. It sets success=true for ANY error
                // if ignore_non_empty is set, not just DirNotEmpty errors.
                // Should be: else if (err_is_dir_not_empty and ignore_non_empty)
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
        // TODO: This check might not handle all edge cases:
        // - What about Windows paths? "C:\" vs "/"
        // - What about network paths? "//server/share"
        // - Empty string check is redundant if dirname() returns null for these cases
        // - Should also check for current == parent to prevent infinite loops
        if (parent.len == 0 or
            std.mem.eql(u8, parent, ".") or
            std.mem.eql(u8, parent, "/"))
        {
            break;
        }

        // TODO: Add infinite loop protection:
        // if (std.mem.eql(u8, current, parent)) break;

        current = parent;
    }

    return success;
}

fn printHelp(
    writer: anytype,
    program: []const u8,
    specs: []const arguments.OptionSpec,
) !void {
    // TODO: Help text is missing several standard sections:
    // - Author information
    // - Reporting bugs section
    // - Copyright notice
    // - SEE ALSO references
    // - Examples section
    //
    // Compare with: rmdir --help
    //
    // TODO: The help text doesn't explain the -p behavior clearly.
    // Should mention that 'rmdir -p a/b/c' is like 'rmdir a/b/c a/b a'
    try writer.print(
        \\Usage: {s} [OPTION]... DIRECTORY...
        \\
        \\Remove the DIRECTORY(ies), if they are empty.
        \\
        \\Options:
    , .{program});

    try arguments.printHelp(writer, specs);

    // TODO: Add footer with additional information:
    // - Exit status codes (0 = success, 1 = failure)
    // - POSIX compliance notes
    // - Behavior with symlinks (not followed)
    // - Difference from 'rm -d' or 'rm -r'
}

// TODO: Missing comprehensive tests. Should add:
// test "rejects dot and dotdot" { ... }
// test "rejects trailing slash" { ... }
// test "removes with parents flag" { ... }
// test "stops on first parent removal failure" { ... }
// test "verbose output format" { ... }
// test "ignore non-empty behavior" { ... }
// test "multiple directories in one invocation" { ... }
// test "option before and after operand" { ... }
// test "handles permission errors gracefully" { ... }

// TODO: Consider adding a dry-run mode (-n/--dry-run) for testing

// TODO: Memory safety - all paths are slices from argv, which is fine,
// but should document that paths must remain valid for the program lifetime

// TODO: Performance consideration - for large directory trees with -p,
// consider batching operations or providing progress indicators

// TODO: Race condition - between checking path and removing it, another process
// could create/modify the directory. This is acceptable (TOCTOU is unavoidable)
// but should be documented in the code.
