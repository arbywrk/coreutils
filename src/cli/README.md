# CLI Module

This directory provides a small, zero-allocation CLI layer for the utilities in `src/`. The goal is to keep each utility focused on its core behavior while sharing consistent option parsing, help output, and error formatting.

**Key Concepts**
1. Options are declared once and mapped to a compile-time enum.
2. Parsing is allocation-free and works directly on `argv`.
3. Help and version handling are standardized, but each utility controls its own help text.

**Module Map**
1. `types.zig`  
Defines core types: `OptionSpec`, `OptionEntry`, `ArgMode`, `ParsedOption`, and error helpers like `printError` and `printHelp`.
2. `scanner.zig`  
Tokenizes `argv` into short options, long options, and operands. Supports short clusters and `--` delimiter.
3. `args.zig`  
Provides `Args` and `ArgsIterator`. This is the primary parsing API.
4. `define_options.zig`  
Builds a per-command CLI type with a canonical `Option` enum and runtime option entries.
5. `standard.zig`  
Helpers for shared options like `--help` and `--version`.
6. `ui.zig`  
User-facing helpers for help output and standard option handling.
7. `mod.zig`  
Convenience re-exports for the rest of the CLI API.

**Typical Usage**
```zig
const cli = @import("cli/mod.zig");
const config = @import("common/config.zig");

const CliOptions = cli.defineOptions(&.{
    cli.standard.defaultHelp,
    cli.standard.defaultVersion,
    .{ .name = "verbose", .short = 'v', .long = "verbose", .help = "enable verbose output" },
});

const Help = cli.Help{
    .usage = "Usage: {s} [OPTION]... [ARG]...\n",
    .description = "Example utility using the shared CLI layer.",
};

pub fn main() !u8 {
    var stdout_writer = std.fs.File.stdout().writer(&.{});
    var stderr_writer = std.fs.File.stderr().writer(&.{});
    const stdout = &stdout_writer.interface;
    const stderr = &stderr_writer.interface;

    var ctx: CliOptions = undefined;
    try ctx.init();
    const program_name = ctx.args.programName();

    var iter = try ctx.args.iterator();
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
            CliOptions.Option.verbose => {},
            CliOptions.Option.help,
            CliOptions.Option.version,
            => unreachable,
        }
    }

    iter = try ctx.args.iterator();
    while (iter.nextOperand()) |operand| {
        _ = operand;
        // Handle operands here.
    }

    return config.EXIT_SUCCESS;
}
```

**ArgMode Semantics**
1. `.none` means the option does not take an argument.
2. `.required` consumes an argument from the same token (`--opt=val` or `-oval`) or the next token.
3. `.optional` accepts an inline value, or consumes the next token only if it does not look like an option.

**Help Text**
1. Provide `Help.usage` with `{s}` where the program name should be substituted.
2. Provide `Help.description` for short user-facing summaries.
3. Use `Help.after_options` to append extra notes or syntax details after the options list.

