const std = @import("std");
const utils = @import("utils.zig");

/// Defines whether an option takes a parameter.
pub const OptionParameterType = enum {
    /// Option takes no parameter (e.g., -v, --verbose)
    none,
    /// Option requires a parameter (e.g., -o file, --output=file)
    required,
    /// Option accepts an optional parameter (e.g., --color[=always])
    optional,
};

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

/// Result of parsing a single option.
pub const ParsedOption = struct {
    /// The specification that matched this option.
    spec: *const OptionSpec,
    /// The parameter value if the option accepts one, null otherwise.
    value: ?[]const u8,
};

pub const ParseItem = union(enum) {
    option: ParsedOption,
    operand: []const u8,
};

pub const OptionError = error{
    UnknownOption,
    MissingOptionArgument,
    UnexpectedArgument,
};

const ArgToken = union(enum) {
    short: struct { name: u8, inline_value: ?[]const u8 },
    long: struct { name: []const u8, inline_value: ?[]const u8 },
    operand: []const u8,
};

const IterMode = enum {
    options_only,
    operands_only,
    all,
};

pub const ParsedArg = union(enum) {
    option: struct {
        spec: *const OptionSpec,
        value: ?[]const u8,
    },
    operand: []const u8,
};

pub const ArgsIterator = struct {
    scanner: ArgScanner,
    specs: []const OptionSpec,
    mode: IterMode = .all,

    pub fn setMode(self: *ArgsIterator, mode: IterMode) void {
        self.mode = mode;
    }

    pub fn reset(self: *ArgsIterator) void {
        self.scanner.reset() catch {}; // TODO: handle error
    }

    // TODO: create 3 functions: nextOption, nextOperand and next instead of the enum setting
    pub fn next(self: *ArgsIterator) OptionError!?ParsedArg {
        while (true) {
            const tok = self.scanner.nextToken() orelse return null;

            switch (tok) {
                .operand => |op| {
                    if (self.mode == .options_only) continue;
                    return .{ .operand = op };
                },

                .short => |s| {
                    if (self.mode == .operands_only) continue;
                    const spec = findShort(self.specs, s.name) orelse return error.UnknownOption;

                    const val = try consumeValue(&self.scanner, s.inline_value, spec.parm_type);
                    return .{ .option = .{ .spec = spec, .value = val } };
                },

                .long => |l| {
                    if (self.mode == .operands_only) continue;
                    const spec = findLong(self.specs, l.name) orelse return error.UnknownOption;

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

fn consumeValue(
    scanner: *ArgScanner,
    inline_val: ?[]const u8,
    kind: OptionParameterType,
) OptionError!?[]const u8 {
    return switch (kind) {
        .none => null,
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

    pub fn nextToken(self: *ArgScanner) ?ArgToken {
        if (self.short_group) |g| {
            defer self.short_group = if (g.len > 1) g[1..] else null;
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

    pub fn init(
        specs: []const OptionSpec,
    ) !Args {
        var args = std.process.args();
        const arg0 = args.next() orelse {
            // there will always be at leas 1 arg
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

    pub fn iterator(self: *const Args) !ArgsIterator {
        return .{
            .scanner = try ArgScanner.init(),
            .specs = self.specs,
        };
    }
};

/// Print help text for all option specifications.
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
