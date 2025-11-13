//   -n     do not output the trailing newline
//
//   -e     enable interpretation of backslash escapes
//
//   -E     disable interpretation of backslash escapes (default)
//
//   --help display this help and exit
//
//   --version
//          output version information and exit
//
//   If -e is in effect, the following sequences are recognized:
//
//   \\     backslash
//
//   \a     alert (BEL)
//
//   \b     backspace
//
//   \c     produce no further output
//
//   \e     escape
//
//   \f     form feed
//
//   \n     new line
//
//   \r     carriage return
//
//   \t     horizontal tab
//
//   \v     vertical tab
//
//   \0NNN  byte with octal value NNN (1 to 3 digits)
//
//   \xHH   byte with hexadecimal value HH (1 to 2 digits)
const std = @import("std");
const posix = std.posix;

pub fn main() !void {
    const STDOUT = 1;
    const allocator = std.heap.page_allocator;

    const all_args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, all_args);

    const args = all_args[1..];

    // disabled by the -n flag
    const add_new_line: bool = true;

    // handle falgs
    for (args) |arg| {
        if (std.mem.startsWith(u8, arg, "-")) {
            // TODO: handle flags
            return;
        }
    }

    if (args.len == 0) {
        // default print nothing
        if (add_new_line) {
            _ = try posix.write(STDOUT, "\n");
        }
        return;
    } else {
        var total_len: usize = 0;
        for (args) |arg| total_len += arg.len;
        total_len += args.len - 1; // spaces

        if (add_new_line) {
            total_len += 1;
        }

        var line_buffer: []u8 = undefined;
        line_buffer = try allocator.alloc(u8, total_len);
        defer allocator.free(line_buffer);

        var pos: usize = 0;
        for (args, 0..) |arg, i| {
            // if (std.mem.startsWith(u8, arg, "-")) continue;
            @memcpy(line_buffer[pos..][0..arg.len], arg);
            pos += arg.len;
            if (i < args.len - 1) {
                line_buffer[pos] = ' ';
                pos += 1;
            }
        }
        if (add_new_line) {
            line_buffer[pos] = '\n';
        }

        _ = try posix.write(STDOUT, line_buffer);
        return;
    }
}
