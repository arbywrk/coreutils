//  args.zig, abstractions for argument handleing
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
const utils = @import("utils.zig");

pub const OptionError = error{
    UnknownOption,
    MissingOptionArgument,
    UnexpectedArgument,
    NoProgramName,
};

/// Describes a command-line option with parse state.
pub const Option = struct {
    /// Immutable option definition.
    def: OptionDef = .{},
    /// Mutable parse state.
    state: OptionParseState = .{},
};

/// Describes a command-line option accepted by the program.
pub const OptionDef = struct {
    /// Single character flag (e.g., 'v' for -v).
    short: ?u8 = null,
    /// Multi-character name (e.g., "verbose" for --verbose).
    long: ?[]const u8 = null,
    /// Whether this option accepts an argument.
    arg: ArgMode = .none,
    /// Description shown in help output.
    help: []const u8 = "",
};

/// Tracks whether an option's argument was seen during parsing.
pub const OptionParseState = struct {
    /// Set to true when option argument is consumed.
    arg_seen: bool = false,
};

/// Specifies how an option handles arguments.
pub const ArgMode = enum {
    /// Option takes no argument (flag only).
    none,
    /// Option requires an argument.
    required,
    /// Option accepts an optional argument (only via --opt=arg syntax).
    optional,
};

/// A successfully parsed option with its argument if any.
pub const ParsedOption = struct {
    def: *const OptionDef,
    argument: ?[]const u8,

    pub fn isLong(self: *const ParsedOption, name: []const u8) bool {
        return if (self.def.long) |l| std.mem.eql(u8, l, name) else false;
    }

    pub fn isShort(self: *const ParsedOption, char: u8) bool {
        return if (self.def.short) |s| s == char else false;
    }
};

/// Either an option or an operand (non-option argument).
pub const ParsedArg = union(enum) {
    option: ParsedOption,
    operand: []const u8,
};

const Token = union(enum) {
    short: struct { char: u8, value: ?[]const u8 },
    long: struct { name: []const u8, value: ?[]const u8 },
    operand: []const u8,
};

/// Tokenizes argv into short options, long options, and operands.
/// Options can appear anywhere, -- stops option parsing.
const Scanner = struct {
    args: std.process.ArgIterator,
    past_delimiter: bool = false,
    short_cluster: ?[]const u8 = null,
    options: []Option,

    fn init(options: []Option) !Scanner {
        var it = std.process.args();
        if (!it.skip()) return error.NoProgramName;
        return .{ .args = it, .options = options };
    }

    fn next(self: *Scanner) ?Token {
        // Process remaining characters from short option cluster (-abc).
        if (self.short_cluster) |cluster| {
            // ex: -abcfarg (where -a -b -c -f arg, are options)
            // will be parsed as -a -b -c -f arg

            const char = cluster[0];
            const rest = cluster[1..];

            // If this option takes an argument, consume rest of cluster as the value.
            if (findShort(self.options, char)) |option| {
                if (option.def.arg == .required or option.def.arg == .optional) {
                    self.short_cluster = null;
                    return .{ .short = .{
                        .char = char,
                        .value = if (rest.len > 0) rest else null,
                    } };
                }
            }

            // Option takes no argument; continue processing cluster.
            self.short_cluster = if (rest.len > 0) rest else null;
            return .{ .short = .{ .char = char, .value = null } };
        }

        const arg = self.args.next() orelse return null;

        // After -- delimiter, everything is an operand.
        if (self.past_delimiter) return .{ .operand = arg };

        // -- stops option parsing; subsequent arguments are operands.
        if (std.mem.eql(u8, arg, "--")) {
            self.past_delimiter = true;
            return self.next();
        }

        // Single - is an operand.
        if (std.mem.eql(u8, arg, "-")) return .{ .operand = arg };

        // Long option: --name or --name=value
        if (std.mem.startsWith(u8, arg, "--")) {
            const body = arg[2..];
            const eq = std.mem.indexOfScalar(u8, body, '=');
            return .{ .long = .{
                .name = body[0..(eq orelse body.len)],
                .value = if (eq) |i| body[i + 1 ..] else null,
            } };
        }

        // Short option(s): -v or -abc
        if (arg.len >= 2 and arg[0] == '-') {
            self.short_cluster = arg[1..];
            return self.next();
        }

        return .{ .operand = arg };
    }

    /// Peek at the next argument without consuming it.
    /// Used to implement --option arg syntax for optional arguments.
    fn peek(self: *Scanner) ?[]const u8 {
        // Save current position.
        const saved_short = self.short_cluster;

        // Try to get next token.
        const tok = self.next();

        // Restore position.
        self.short_cluster = saved_short;

        return if (tok) |t| switch (t) {
            .operand => |op| op,
            else => null,
        } else null;
    }
};

/// Iterates through command-line arguments, separating options from operands.
/// Options may appear anywhere before --.
pub const ArgsIterator = struct {
    scanner: Scanner,
    options: []Option,

    /// Returns next option, skipping operands. Returns null when no options remain.
    /// Use this to process all options before handling operands.
    pub fn nextOption(self: *ArgsIterator) OptionError!?ParsedOption {
        while (true) {
            const tok = self.scanner.next() orelse return null;

            switch (tok) {
                .operand => continue,
                .short => |s| {
                    const option = findShortMut(self.options, s.char) orelse
                        return error.UnknownOption;
                    return try self.consume(option, s.value);
                },
                .long => |l| {
                    const option = findLongMut(self.options, l.name) orelse
                        return error.UnknownOption;
                    return try self.consume(option, l.value);
                },
            }
        }
    }

    /// Returns next operand, skipping options and their arguments.
    /// Call this after nextOption() returns null to process non-option arguments.
    pub fn nextOperand(self: *ArgsIterator) ?[]const u8 {
        while (true) {
            const tok = self.scanner.next() orelse return null;

            switch (tok) {
                .operand => |op| return op,
                // If there is no option with the given name
                // it treats it as an operand.
                // To avoid having invalid options treated as operands
                // first traverse using nextOption(),
                // which will return an error for invalid arguments.
                // It also uses the arg_seen field from option.state
                // (which is set by traversing the arguments with next() or nextOption())
                // to determine if the next argument is an
                // option-argument or not (if so it skips it)
                .short => |s| {
                    if (findShort(self.options, s.char)) |option| {
                        if (option.def.arg != .none and !option.state.arg_seen) {
                            _ = self.scanner.next(); // skip the option-argument
                        }
                    }
                },
                .long => |l| {
                    if (findLong(self.options, l.name)) |option| {
                        if (option.def.arg != .none and !option.state.arg_seen) {
                            _ = self.scanner.next(); // skip the option-argument
                        }
                    }
                },
            }
        }
    }

    /// Returns next argument in order, whether option or operand.
    /// Use this when processing arguments sequentially matters.
    pub fn next(self: *ArgsIterator) OptionError!?ParsedArg {
        const tok = self.scanner.next() orelse return null;

        switch (tok) {
            .operand => |op| return .{ .operand = op },
            .short => |s| {
                const option = findShortMut(self.options, s.char) orelse
                    return error.UnknownOption;
                return .{ .option = try self.consume(option, s.value) };
            },
            .long => |l| {
                const option = findLongMut(self.options, l.name) orelse
                    return error.UnknownOption;
                return .{ .option = try self.consume(option, l.value) };
            },
        }
    }

    /// Handles option argument consumption based on ArgMode.
    /// For optional arguments: tries --opt=val, then --opt val if next arg isn't an option.
    /// For required arguments: tries inline value, then next argument.
    fn consume(
        self: *ArgsIterator,
        option: *Option,
        inline_value: ?[]const u8,
    ) OptionError!ParsedOption {
        switch (option.def.arg) {
            .none => {
                if (inline_value != null) return error.UnexpectedArgument;
                return .{ .def = &option.def, .argument = null };
            },

            .required => {
                if (inline_value) |v| {
                    option.state.arg_seen = true;
                    return .{ .def = &option.def, .argument = v };
                }

                const next_arg = self.scanner.args.next() orelse
                    return error.MissingOptionArgument;

                option.state.arg_seen = false;
                return .{ .def = &option.def, .argument = next_arg };
            },

            .optional => {
                // Inline value (--opt=val) always works.
                if (inline_value) |v| {
                    option.state.arg_seen = true;
                    return .{ .def = &option.def, .argument = v };
                }

                // Try consuming next argument if it doesn't look like an option.
                // Supports both --opt val and --opt (no value).
                if (self.scanner.peek()) |next_arg| {
                    if (!std.mem.startsWith(u8, next_arg, "-")) {
                        _ = self.scanner.args.next(); // Consume it
                        option.state.arg_seen = false;
                        return .{ .def = &option.def, .argument = next_arg };
                    }
                }

                return .{ .def = &option.def, .argument = null };
            },
        }
    }
};

/// Main entry point for argument parsing. Initialize once per program.
pub const Args = struct {
    options: []Option,
    program_name: []const u8,

    /// Initializes argument parser. Extracts program name from argv[0].
    pub fn init(options: []Option) !Args {
        var args = std.process.args();
        const arg0 = args.next() orelse return error.NoProgramName;
        return .{
            .program_name = utils.basename(arg0),
            .options = options,
        };
    }

    /// Returns basename of argv[0].
    pub fn programName(self: *const Args) []const u8 {
        return self.program_name;
    }

    /// Creates an iterator for processing arguments.
    /// Note: Despite taking *const self, this returns an iterator that can
    /// modify option state. The options slice itself is shared, not copied.
    pub fn iterator(self: *const Args) !ArgsIterator {
        return .{
            .scanner = try Scanner.init(self.options),
            .options = self.options,
        };
    }
};

fn findShort(options: []const Option, char: u8) ?*const Option {
    for (options) |*o| if (o.def.short == char) return o;
    return null;
}

fn findShortMut(options: []Option, char: u8) ?*Option {
    for (options) |*o| if (o.def.short == char) return o;
    return null;
}

fn findLong(options: []const Option, name: []const u8) ?*const Option {
    for (options) |*o| {
        if (o.def.long) |l| {
            if (std.mem.eql(u8, l, name)) return o;
        }
    }
    return null;
}

fn findLongMut(options: []Option, name: []const u8) ?*Option {
    for (options) |*o| {
        if (o.def.long) |l| {
            if (std.mem.eql(u8, l, name)) return o;
        }
    }
    return null;
}

/// Returns human-readable description of an error.
pub fn getErrorMessage(err: OptionError) []const u8 {
    return switch (err) {
        error.UnknownOption => "invalid option",
        error.MissingOptionArgument => "option requires an argument",
        error.UnexpectedArgument => "option doesn't allow an argument",
        error.NoProgramName => "no program name in argv[0]",
    };
}

/// Prints error message to writer with program name and help suggestion.
pub fn printError(writer: anytype, program_name: []const u8, err: OptionError) !void {
    try writer.print(
        "{s}: {s}\nTry '{s} --help' for more information.\n",
        .{ program_name, getErrorMessage(err), program_name },
    );
}

/// Formats and prints help text for given option specifications.
/// Output format: "  -s, --long <arg>\n      description"
pub fn printHelp(writer: anytype, options: []const Option) !void {
    for (options) |o| {
        const def = o.def;
        try writer.print("  ", .{});

        if (def.short) |c| {
            try writer.print("-{c}", .{c});
            if (def.long != null) try writer.print(", ", .{});
        }

        if (def.long) |l| {
            try writer.print("--{s}", .{l});
        }

        switch (def.arg) {
            .required => try writer.print(" <arg>", .{}),
            .optional => try writer.print(" [arg]", .{}),
            .none => {},
        }

        try writer.print("\n      {s}\n", .{def.help});
    }
}
