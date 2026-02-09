//  cli/types.zig, core CLI types
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

pub const CliError = error{
    UnknownOption,
    MissingOptionArgument,
    UnexpectedArgument,
    NoProgramName,
};

/// How an option consumes an argument.
pub const ArgMode = enum {
    /// Option takes no argument (flag only).
    none,
    /// Option requires an argument.
    required,
    /// Option accepts an optional argument (only via --opt=arg syntax; and optionally via --opt arg
    /// if next token is not an option-like string).
    optional,
};

/// Immutable option specification.
pub const OptionSpec = struct {
    /// Single character option (e.g. 'v' for -v).
    short: ?u8 = null,
    /// Long option name (e.g. "verbose" for --verbose).
    long: ?[]const u8 = null,
    /// Whether this option consumes an argument.
    arg: ArgMode = .none,
    /// Help text shown in --help output.
    help: []const u8 = "",
};

/// Parse-state for one option spec.
///
/// Note: this does not mean “option was seen”. It is used only so the iterator can
/// correctly skip option arguments while scanning operands.
///
/// Semantics:
/// - inline_arg = true  => the option argument (if any) was supplied inline in the same argv token
///                         (e.g. -oFILE, --opt=VAL). No extra argv token should be skipped.
/// - inline_arg = false => the option argument (if any) is expected to be the next argv token and
///                         should be skipped by nextOperand() when it encounters the option.
pub const OptionParseState = struct {
    inline_arg: bool = false,
};

/// Runtime entry: immutable spec + mutable parse state.
/// This is what the scanner/iterator searches.
pub const OptionEntry = struct {
    spec: OptionSpec = .{},
    state: OptionParseState = .{},
};

/// A successfully parsed option with its argument (if any).
pub const ParsedOption = struct {
    spec: *const OptionSpec,
    argument: ?[]const u8,

    pub fn isLong(self: *const ParsedOption, name: []const u8) bool {
        return if (self.spec.long) |l| std.mem.eql(u8, l, name) else false;
    }

    pub fn isShort(self: *const ParsedOption, ch: u8) bool {
        return if (self.spec.short) |s| s == ch else false;
    }
};

/// Either an option or an operand (non-option argument).
pub const ParsedArg = union(enum) {
    option: ParsedOption,
    operand: []const u8,
};

/// Returns a human-readable description of a CLI error.
pub fn errorMessage(err: CliError) []const u8 {
    return switch (err) {
        error.UnknownOption => "invalid option",
        error.MissingOptionArgument => "option requires an argument",
        error.UnexpectedArgument => "option doesn't allow an argument",
        error.NoProgramName => "no program name in argv[0]",
    };
}

/// Prints an error message with a standard “Try --help” footer.
pub fn printError(writer: anytype, program_name: []const u8, err: CliError) !void {
    try writer.print(
        "{s}: {s}\nTry '{s} --help' for more information.\n",
        .{ program_name, errorMessage(err), program_name },
    );
}

/// Prints help text for the provided option entries.
///
/// Format:
///   -s, --long <arg>
///       description
pub fn printHelp(writer: anytype, options: []const OptionEntry) !void {
    for (options) |o| {
        const spec = o.spec;
        try writer.print("  ", .{});

        if (spec.short) |c| {
            try writer.print("-{c}", .{c});
            if (spec.long != null) try writer.print(", ", .{});
        }

        if (spec.long) |l| {
            try writer.print("--{s}", .{l});
        }

        switch (spec.arg) {
            .required => try writer.print(" <arg>", .{}),
            .optional => try writer.print(" [arg]", .{}),
            .none => {},
        }

        try writer.print("\n      {s}\n", .{spec.help});
    }
}
