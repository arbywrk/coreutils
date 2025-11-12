const std = @import("std");
const write = std.os.linux.write;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const STDOUT_FD = 1;

    // Setup stderr with small buffer (only for errors)
    var stderr_buffer: [256]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
    const stderr = &stderr_writer.interface;

    // Get command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Handle meta-options
    for (args[1..]) |arg| {
        if (std.mem.startsWith(u8, arg, "-")) {
            if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--version")) {
                const ver_mes = "{s}: 1.0.0\n";
                const ver_str = try std.fmt.allocPrint(allocator, ver_mes, .{args[0]});
                defer allocator.free(ver_str);
                _ = write(STDOUT_FD, ver_str.ptr, ver_str.len);
                return;
            } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                const usage =
                    \\Usage: yes [string...]
                    \\       yes <option>
                    \\
                    \\Options:
                    \\  -h, --help      Display this help and exit
                    \\  -v, --version   Output version information and exit
                    \\
                ;
                _ = write(STDOUT_FD, usage.ptr, usage.len);
                return;
            } else {
                try stderr.print("{s}: Invalid option: {s}\nTry '{s} --help' for more information.\n", .{ args[0], arg, args[0] });
                try stderr.flush();
                return;
            }
        }
    }

    // Build the repeated line
    var line_buf: []u8 = undefined;
    if (args.len > 1) {
        // Join all args with spaces + newline
        var total_len: usize = 0;
        for (args[1..]) |arg| total_len += arg.len;
        total_len += args.len - 2; // spaces
        total_len += 1; // newline

        line_buf = try allocator.alloc(u8, total_len);
        var pos: usize = 0;
        for (args[1..], 0..) |arg, i| {
            @memcpy(line_buf[pos..][0..arg.len], arg);
            pos += arg.len;
            if (i < args.len - 2) {
                line_buf[pos] = ' ';
                pos += 1;
            }
        }
        line_buf[pos] = '\n';
    } else {
        // Default
        line_buf = try allocator.alloc(u8, 2);
        line_buf[0] = 'y';
        line_buf[1] = '\n';
    }

    // Precompute a large buffer to minimize syscalls (32 KB)
    const BLOCK_SIZE: usize = 32 * 1024;
    var block: [BLOCK_SIZE]u8 = undefined;
    var block_len: usize = 0;

    while (block_len + line_buf.len <= BLOCK_SIZE) : (block_len += line_buf.len) {
        @memcpy(block[block_len..][0..line_buf.len], line_buf);
    }

    // Write repeatedly
    const slice = block[0..block_len];
    while (true) {
        _ = write(STDOUT_FD, slice.ptr, block_len);
    }
}
