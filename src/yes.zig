//  yes.zig, writes a message to the stdout until stopped
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
const cli = @import("cli/mod.zig");
const config = @import("common/config.zig");
const posix = std.posix;

const CliOptions = cli.defineOptions(&.{
    cli.standard.helpOption('h', "Display this help and exit"),
    cli.standard.versionOption('v', "Output version information and exit"),
});

const Help = cli.Help{
    .usage =
        \\Usage: {s} [string...]
        \\       {s} OPTION
    ,
};

pub fn main() !u8 {
    const allocator = std.heap.page_allocator;
    const STDOUT = 1;

    // Setup stderr with small buffer (only for errors)
    var stderr_buffer: [256]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
    const stderr = &stderr_writer.interface;
    var stdout_writer = std.fs.File.stdout().writer(&.{});
    const stdout = &stdout_writer.interface;

    var ctx: CliOptions = undefined;
    try ctx.init();
    const program_name = ctx.args.programName();

    var iter = try ctx.args.iterator();
    while (iter.nextOption() catch |err| {
        try cli.printError(stderr, program_name, err);
        try stderr.flush();
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
    }

    // Build the repeated line
    var line_buf: []u8 = undefined;
    var operand_count: usize = 0;
    var total_len: usize = 0;

    iter = try ctx.args.iterator();
    while (iter.nextOperand()) |arg| {
        operand_count += 1;
        total_len += arg.len;
    }

    if (operand_count == 0) {
        line_buf = try allocator.alloc(u8, 2);
        line_buf[0] = 'y';
        line_buf[1] = '\n';
    } else {
        total_len += operand_count - 1; // spaces
        total_len += 1; // newline

        line_buf = try allocator.alloc(u8, total_len);
        var pos: usize = 0;

        iter = try ctx.args.iterator();
        while (iter.nextOperand()) |arg| {
            @memcpy(line_buf[pos..][0..arg.len], arg);
            pos += arg.len;
            if (pos + 1 < total_len) {
                line_buf[pos] = ' ';
                pos += 1;
            }
        }
        line_buf[pos] = '\n';
    }

    // Precompute a large buffer to minimize syscalls (32 KB)
    const BLOCK_SIZE: usize = 32 * 1024;
    var block: [BLOCK_SIZE]u8 = undefined;
    var block_len: usize = 0;

    while (block_len + line_buf.len <= BLOCK_SIZE) : (block_len += line_buf.len) {
        @memcpy(block[block_len..][0..line_buf.len], line_buf);
    }

    // Write repeatedly
    const slice = block[0..block_len];
    while (true) {
        _ = try posix.write(STDOUT, slice);
    }

    return config.EXIT_SUCCESS;
}
