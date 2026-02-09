//  cli/standard.zig, common option declarations shared across utilities.
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
const define = @import("define_options.zig");

pub const OptionSpecDecl = define.OptionSpecDecl;

pub fn helpOption(comptime short: ?u8, comptime help: []const u8) OptionSpecDecl {
    return .{
        .name = "help",
        .short = short,
        .long = "help",
        .help = help,
    };
}

pub fn versionOption(comptime short: ?u8, comptime help: []const u8) OptionSpecDecl {
    return .{
        .name = "version",
        .short = short,
        .long = "version",
        .help = help,
    };
}

pub const defaultHelp = helpOption(null, "display this help and exit");
pub const defaultVersion = versionOption(null, "output version information and exit");
