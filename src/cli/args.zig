//  cli/args.zig, argument iterator built on top of Scanner.
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
const utils = @import("../common/utils.zig");

const types = @import("types.zig");
const scan = @import("scanner.zig");

pub const CliError = types.CliError;
pub const ArgMode = types.ArgMode;
pub const OptionSpec = types.OptionSpec;
pub const OptionEntry = types.OptionEntry;
pub const ParsedOption = types.ParsedOption;
pub const ParsedArg = types.ParsedArg;

pub const Scanner = scan.Scanner;

/// Iterates through command-line arguments, separating options from operands.
/// Options may appear anywhere before `--`.
pub const ArgsIterator = struct {
    scanner: Scanner,
    options: []OptionEntry,

    /// Returns next option, skipping operands. Returns null when no options remain.
    pub fn nextOption(self: *ArgsIterator) CliError!?ParsedOption {
        while (true) {
            const tok = self.scanner.next() orelse return null;

            switch (tok) {
                .operand => continue,
                .short => |s| {
                    const entry = scan.findShortMut(self.options, s.char) orelse
                        return error.UnknownOption;
                    return try self.consume(entry, s.value);
                },
                .long => |l| {
                    const entry = scan.findLongMut(self.options, l.name) orelse
                        return error.UnknownOption;
                    return try self.consume(entry, l.value);
                },
            }
        }
    }

    /// Returns next operand, skipping options and their arguments.
    /// Call this after nextOption() returns null.
    pub fn nextOperand(self: *ArgsIterator) ?[]const u8 {
        while (true) {
            const tok = self.scanner.next() orelse return null;

            switch (tok) {
                .operand => |op| return op,

                .short => |s| {
                    if (scan.findShort(self.options, s.char)) |entry| {
                        if (entry.spec.arg != .none and !entry.state.inline_arg) {
                            _ = self.scanner.next(); // skip the option-argument token
                        }
                    }
                },

                .long => |l| {
                    if (scan.findLong(self.options, l.name)) |entry| {
                        if (entry.spec.arg != .none and !entry.state.inline_arg) {
                            _ = self.scanner.next(); // skip the option-argument token
                        }
                    }
                },
            }
        }
    }

    /// Returns next argument in order, whether option or operand.
    pub fn next(self: *ArgsIterator) CliError!?ParsedArg {
        const tok = self.scanner.next() orelse return null;

        switch (tok) {
            .operand => |op| return .{ .operand = op },

            .short => |s| {
                const entry = scan.findShortMut(self.options, s.char) orelse
                    return error.UnknownOption;
                return .{ .option = try self.consume(entry, s.value) };
            },

            .long => |l| {
                const entry = scan.findLongMut(self.options, l.name) orelse
                    return error.UnknownOption;
                return .{ .option = try self.consume(entry, l.value) };
            },
        }
    }

    /// Handles option argument consumption based on ArgMode.
    ///
    /// Semantics of entry.state.inline_arg:
    /// - true  => argument came from the same token (inline_value != null)
    /// - false => argument came from the next argv token (or absent for optional)
    fn consume(self: *ArgsIterator, entry: *OptionEntry, inline_value: ?[]const u8) CliError!ParsedOption {
        switch (entry.spec.arg) {
            .none => {
                if (inline_value != null) return error.UnexpectedArgument;
                entry.state.inline_arg = true; // irrelevant, but keeps state consistent
                return .{ .spec = &entry.spec, .argument = null };
            },

            .required => {
                if (inline_value) |v| {
                    entry.state.inline_arg = true;
                    return .{ .spec = &entry.spec, .argument = v };
                }

                const next_arg = self.scanner.args.next() orelse
                    return error.MissingOptionArgument;

                entry.state.inline_arg = false;
                return .{ .spec = &entry.spec, .argument = next_arg };
            },

            .optional => {
                if (inline_value) |v| {
                    entry.state.inline_arg = true;
                    return .{ .spec = &entry.spec, .argument = v };
                }

                // Try consuming next argument if it doesn't look like an option.
                if (self.scanner.peekOperand()) |next_arg| {
                    if (!std.mem.startsWith(u8, next_arg, "-")) {
                        _ = self.scanner.args.next(); // consume it
                        entry.state.inline_arg = false;
                        return .{ .spec = &entry.spec, .argument = next_arg };
                    }
                }

                entry.state.inline_arg = true; // no extra token to skip
                return .{ .spec = &entry.spec, .argument = null };
            },
        }
    }
};

/// Main entry point for argument parsing. Initialize once per program.
pub const Args = struct {
    options: []OptionEntry,
    program_name: []const u8,

    /// Initializes argument parser. Extracts program name from argv[0].
    pub fn init(options: []OptionEntry) !Args {
        var it = std.process.args();
        const arg0 = it.next() orelse return error.NoProgramName;
        return .{
            .program_name = utils.basename(arg0),
            .options = options,
        };
    }

    pub fn programName(self: *const Args) []const u8 {
        return self.program_name;
    }

    /// Creates an iterator for processing arguments.
    /// Clears parse-state so multiple iterations behave consistently.
    pub fn iterator(self: *const Args) !ArgsIterator {
        for (self.options) |*o| o.state.inline_arg = false;

        return .{
            .scanner = try Scanner.init(self.options),
            .options = self.options,
        };
    }
};

// re-export help/error utilities
pub const printHelp = types.printHelp;
pub const printError = types.printError;
pub const errorMessage = types.errorMessage;
