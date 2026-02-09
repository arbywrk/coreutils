//  cli/mod.zig
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
pub const types = @import("types.zig");
pub const args = @import("args.zig");
pub const define = @import("define_options.zig");
pub const standard = @import("standard.zig");
pub const ui = @import("ui.zig");

// Common convenience re-exports (optional)
pub const CliError = types.CliError;
pub const printError = types.printError;
pub const printHelp = types.printHelp;
pub const ArgMode = types.ArgMode;
pub const OptionSpec = types.OptionSpec;
pub const OptionEntry = types.OptionEntry;
pub const ParsedOption = types.ParsedOption;
pub const ParsedArg = types.ParsedArg;

pub const Args = args.Args;
pub const ArgsIterator = args.ArgsIterator;

pub const defineOptions = define.defineOptions;
pub const OptionSpecDecl = define.OptionSpecDecl;

pub const Help = ui.Help;
pub const printCommandHelp = ui.printCommandHelp;
pub const handleStandardOption = ui.handleStandardOption;
