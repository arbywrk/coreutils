//  true.zig, do nothing successfully
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

const CliOptions = cli.defineOptions(&.{
    cli.standard.helpOption(null, "display this help and exit"),
    cli.standard.versionOption(null, "output version information and exit"),
});

const Help = cli.Help{
    .usage =
    \\Usage: {s} [ignored command line arguments]
    \\   or: {s} OPTION
    ,
    .description = "Exit with a status code indicating success.",
};

pub fn main() !u8 {
    var ctx: CliOptions = undefined;
    try ctx.init();
    const program_name = ctx.args.programName();
    var stdout_writer = std.fs.File.stdout().writer(&.{});
    var stderr_writer = std.fs.File.stderr().writer(&.{});
    const stdout = &stdout_writer.interface;
    const stderr = &stderr_writer.interface;
    var iter = try ctx.args.iterator();

    // Check for --help or --version (all other arguments ignored)
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
    }

    return config.EXIT_SUCCESS;
}
