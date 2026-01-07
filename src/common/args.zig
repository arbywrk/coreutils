const std = @import("std");

const utils = @import("utils.zig");
const OptionError = @import("errors.zig").OptionError;

/// Specification for a command-line option.
pub const OptionSpec = struct {
    /// Short form (e.g., 'v' for -v). Can be null if only long form exists.
    short: ?u8 = null,
    /// Long form (e.g., "verbose" for --verbose). Can be null if only short form exists.
    long: ?[]const u8 = null,
    /// Whether this option takes a parameter.
    parm_type: OptionParameterType = .none,
    /// Help text describing this option.
    help: []const u8 = "",
};

/// Defines whether an option takes a parameter.
pub const OptionParameterType = enum {
    /// Option takes no parameter (e.g., -v, --verbose)
    none,
    /// Option requires a parameter (e.g., -o file, --output=file)
    required,
    /// Option accepts an optional parameter (e.g., --color[=always])
    optional,
};

/// Result of parsing a single option.
pub const ParsedOption = struct {
    /// The specification that matched this option.
    spec: *const OptionSpec,
    /// The parameter value if the option accepts one, null otherwise.
    value: ?[]const u8,

    pub fn isLong(self: *const @This(), option_name: []const u8) bool {
        const long_option = self.spec.long orelse return false;

        return std.mem.eql(u8, long_option, option_name);
    }

    pub fn isShort(self: *const @This(), option_name: u8) bool {
        const short_option = self.spec.short orelse return false;

        return short_option == option_name;
    }
};

// Result of parsing an argument
pub const ParsedArg = union(enum) {
    option: ParsedOption,
    operand: []const u8,
};

const ArgToken = union(enum) {
    short: struct { name: u8, inline_value: ?[]const u8 },
    long: struct { name: []const u8, inline_value: ?[]const u8 },
    operand: []const u8,
};

pub const ArgsIterator = struct {
    scanner: ArgScanner,
    specs: []const OptionSpec,

    /// Get the next option, skipping over operands.
    pub fn nextOption(self: *@This()) OptionError!?ParsedOption {
        while (true) {
            const tok = self.scanner.nextToken() orelse return null;

            switch (tok) {
                .operand => {
                    // ignore operands
                    continue;
                },

                .short => |s| {
                    const spec = findShort(self.specs, s.name) orelse
                        return error.UnknownOption;

                    const val = try consumeValue(&self.scanner, s.inline_value, spec.parm_type);
                    return .{ .spec = spec, .value = val };
                },

                .long => |l| {
                    const spec = findLong(self.specs, l.name) orelse
                        return error.UnknownOption;

                    const val = try consumeValue(&self.scanner, l.inline_value, spec.parm_type);
                    return .{ .spec = spec, .value = val };
                },
            }
        }
    }

    /// Get the next operand, skipping over options.
    /// TODO: This skips options but doesn't consume their arguments, which could lead to
    /// operands being consumed as option values. Need to track option consumption state.
    pub fn nextOperand(self: *@This()) ?[]const u8 {
        while (true) {
            const tok = self.scanner.nextToken() orelse return null;

            switch (tok) {
                .operand => |op| {
                    return op;
                },
                .short, .long => {
                    // TODO: This is a bug! If an option requires an argument, we need to skip
                    // the next token too. Currently, if you call nextOperand() without first
                    // processing options, you might get option arguments as operands.
                    // Example: "prog -o file.txt input.txt" - "file.txt" might be returned as operand.
                    continue;
                },
            }
        }
    }

    /// Get the next argument (option or operand) in order.
    pub fn next(self: *ArgsIterator) OptionError!?ParsedArg {
        while (true) {
            const tok = self.scanner.nextToken() orelse return null;

            switch (tok) {
                .operand => |op| {
                    return .{ .operand = op };
                },

                .short => |s| {
                    const spec = findShort(self.specs, s.name) orelse
                        return error.UnknownOption;

                    const val = try consumeValue(&self.scanner, s.inline_value, spec.parm_type);
                    return .{ .option = .{ .spec = spec, .value = val } };
                },

                .long => |l| {
                    const spec = findLong(self.specs, l.name) orelse
                        return error.UnknownOption;

                    const val = try consumeValue(&self.scanner, l.inline_value, spec.parm_type);
                    return .{ .option = .{ .spec = spec, .value = val } };
                },
            }
        }
    }
};

fn findShort(specs: []const OptionSpec, c: u8) ?*const OptionSpec {
    for (specs) |*s| if (s.short == c) return s;
    return null;
}

fn findLong(specs: []const OptionSpec, name: []const u8) ?*const OptionSpec {
    for (specs) |*s| if (s.long != null and std.mem.eql(u8, s.long.?, name)) return s;
    return null;
}

/// TODO: This function has a subtle bug - when kind is .required and inline_val is null,
/// it consumes the next argument without checking if it's an option or operand.
/// This means "prog -o --help" would consume "--help" as the value for -o.
/// Should validate that the consumed argument is not an option.
fn consumeValue(
    scanner: *ArgScanner,
    inline_val: ?[]const u8,
    kind: OptionParameterType,
) OptionError!?[]const u8 {
    return switch (kind) {
        .none => blk: {
            // TODO: Should check if inline_val is provided and return error.UnexpectedArgument
            // Currently silently ignores: "prog --verbose=something" would not error
            if (inline_val != null) return error.UnexpectedArgument;
            break :blk null;
        },
        .required => inline_val orelse scanner.args.next() orelse error.MissingOptionArgument,
        .optional => inline_val,
    };
}

/// Base scanner that tokenizes command-line arguments.
const ArgScanner = struct {
    args: std.process.ArgIterator,
    after_delim: bool = false,
    short_group: ?[]const u8 = null,

    pub fn init() !ArgScanner {
        var it = std.process.args();
        if (!it.skip()) return error.NoProgramName;
        return .{ .args = it };
    }

    pub fn reset(self: *ArgScanner) !void {
        self.args = std.process.args();
        if (!self.args.skip()) return error.NoProgramName;
        self.after_delim = false;
        self.short_group = null;
    }

    /// TODO: The short option clustering logic has a subtle issue.
    /// When returning a short option with inline_value, it includes ALL remaining characters.
    /// This breaks the expected behavior: "-ofile" should return 'o' with value "file",
    /// but "-abc" should return 'a', then 'b', then 'c' separately.
    /// The current logic always returns inline_value for any short option in a group.
    pub fn nextToken(self: *ArgScanner) ?ArgToken {
        if (self.short_group) |g| {
            defer self.short_group = if (g.len > 1) g[1..] else null;

            // TODO: This is wrong for clustering. Should only set inline_value if this is
            // the last char in the group. Otherwise "-abc" would try to parse "bc" as a value.
            // Correct behavior: only the LAST option in a cluster can have an inline value.
            return .{
                .short = .{
                    .name = g[0],
                    .inline_value = if (g.len > 1) g[1..] else null,
                },
            };
        }

        const raw = self.args.next() orelse return null;

        if (!self.after_delim and std.mem.eql(u8, raw, "--")) {
            self.after_delim = true;
            return self.nextToken();
        }

        // TODO: Should handle single dash "-" as operand (commonly used for stdin/stdout)
        if (!self.after_delim and raw.len >= 2 and raw[0] == '-') {
            if (raw[1] == '-') {
                const eq = std.mem.indexOfScalar(u8, raw, '=');
                return .{
                    .long = .{
                        .name = raw[2..(eq orelse raw.len)],
                        .inline_value = if (eq) |i| raw[i + 1 ..] else null,
                    },
                };
            }

            self.short_group = raw[1..];
            return self.nextToken();
        }

        return .{ .operand = raw };
    }
};

/// Struct for working with arguments
pub const Args = struct {
    scanner: ArgScanner,
    specs: []const OptionSpec,
    program_name: []const u8,

    /// TODO: This stores program_name but scanner also processes argv[0].
    /// The scanner.init() already skips the first arg, so there's duplication.
    /// Consider either: 1) Pass program_name to init, or 2) Add a method to get it from scanner
    pub fn init(
        specs: []const OptionSpec,
    ) !Args {
        var args = std.process.args();
        const arg0 = args.next() orelse {
            // there will always be at least 1 arg
            // but just in case...
            return error.NoProgramName;
        };
        return .{
            .program_name = utils.basename(arg0),
            .scanner = try ArgScanner.init(),
            .specs = specs,
        };
    }

    pub fn programName(self: *@This()) []const u8 {
        return self.program_name;
    }

    /// TODO: This creates a fresh scanner each time, which means creating a new process.args()
    /// iterator. This works but is inefficient if you need multiple passes over args.
    /// Consider: should iterator() return a value or pointer? Currently returns by value.
    pub fn iteratorInit(self: *const Args) !ArgsIterator {
        // TODO: self.scanner is not used here - we create a new one. Should we clone self.scanner instead?
        return .{
            .scanner = try ArgScanner.init(),
            .specs = self.specs,
        };
    }
};

/// Print help text for all option specifications.
/// TODO: Add formatting options - indent level, max width for wrapping, etc.
/// TODO: Support for option groups/categories in help output
pub fn printHelp(
    writer: anytype,
    specs: []const OptionSpec,
) !void {
    for (specs) |s| {
        try writer.print("  ", .{});
        if (s.short) |c| {
            try writer.print("-{c}", .{c});
            if (s.long != null) try writer.print(", ", .{});
        }
        if (s.long) |l| {
            try writer.print("--{s}", .{l});
        }
        if (s.parm_type == .required) try writer.print(" <arg>", .{});
        if (s.parm_type == .optional) try writer.print(" [arg]", .{});
        try writer.print("\n      {s}\n", .{s.help});
    }
}

// TODO: Add comprehensive tests, especially for:
// - Short option clustering edge cases (-abc vs -ofile)
// - Mixed option and operand ordering
// - Multiple iterator instances and reset() behavior
// - Error cases (unknown options, missing arguments, unexpected arguments)
// - Special cases: single dash "-", double dash "--", empty args
// - POSIX compliance: can options appear after operands?
