const std = @import("std");

const usage =
    \\Usage: yes [string...]
    \\       yes <option>
    \\
    \\Options:
    \\  -h, --help      Display this help and exit
    \\  -v, --version   Output version information and exit
    \\
;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Setup stderr with small buffer (only for errors)
    var stderr_buffer: [256]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
    const stderr = &stderr_writer.interface;

    // Setup stdout with larger buffer for performance
    var stdout_buffer: [8192]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    // Get command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Handle meta-options
    for (args[1..]) |arg| {
        if (std.mem.startsWith(u8, arg, "-")) {
            if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--version")) {
                try stdout.print("{s}: 1.0.0\n", .{args[0]});
                try stdout.flush();
                return;
            } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                try stdout.writeAll(usage);
                try stdout.flush();
                return;
            } else {
                try stderr.print("{s}: Invalid option: {s}\nTry '{s} --help' for more information.\n", .{ args[0], arg, args[0] });
                try stderr.flush();
                return;
            }
        }
    }

    // Build output string - calculate size first
    var total_len: usize = 0;
    if (args.len > 1) {
        for (args[1..]) |arg| {
            total_len += arg.len;
        }
        total_len += args.len - 2; // spaces between args
        total_len += 1; // newline
    } else {
        total_len = 2; // "y\n"
    }

    // Allocate exact size needed
    const line = try allocator.alloc(u8, total_len);
    defer allocator.free(line);

    // Fill the buffer
    var pos: usize = 0;
    if (args.len > 1) {
        for (args[1..], 0..) |arg, i| {
            @memcpy(line[pos..][0..arg.len], arg);
            pos += arg.len;
            if (i < args.len - 2) {
                line[pos] = ' ';
                pos += 1;
            }
        }
        line[pos] = '\n';
    } else {
        line[0] = 'y';
        line[1] = '\n';
    }

    // Write repeatedly
    var count: usize = 0;
    while (true) : (count += 1) {
        try stdout.writeAll(line);
        // Flush periodically for better performance
        if (count % 100 == 0) {
            try stdout.flush();
        }
    }
}
