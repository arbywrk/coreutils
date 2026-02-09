# Contributing

Thanks for considering a contribution. This project aims to keep each utility focused on its core logic while sharing a consistent, zero-cost CLI layer. The guidelines below help keep changes predictable and easy to review.

**Getting Started**
1. Ensure Zig is installed (this repo currently targets Zig 0.15.x).
2. Build the project with `zig build`.

**Development Workflow**
1. Make a focused change in a feature branch.
2. Keep user-facing output consistent with other utilities.
3. Run `zig build` before opening a PR.

**Adding A New Utility**
1. Use the helper: `zig run tools/new_util.zig -- <name>`.
2. The tool creates `src/<name>.zig` with a ready-to-edit CLI skeleton and guidance comments.

**CLI Guidelines**
1. Use the `cli` module (`src/cli/`) for options, help text, and error reporting.
2. Use `cli.standard.defaultHelp` and `cli.standard.defaultVersion` unless a command intentionally differs.
3. Use `cli.handleStandardOption` to handle `--help` and `--version` early in parsing.
4. Use `ArgsIterator.nextOption()` for option-first parsing, or `next()` if you need to interleave options and operands.

**Validators**
1. Put shared validation logic in `src/common/validators.zig`.
2. Validators return `error` values; utilities decide how to render user-facing messages.

**Style Notes**
1. Keep functions small and explicit.
2. Avoid unnecessary allocations in hot paths.
3. Prefer simple, readable control flow over clever abstractions.
