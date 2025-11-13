const std = @import("std");
const posix = std.posix;

pub fn main() !void {
    const STDOUT = 1;
    var hostname_buffer: [posix.HOST_NAME_MAX]u8 = undefined;
    _ = try posix.gethostname(&hostname_buffer);
    const hostname_len = std.mem.indexOfScalar(u8, &hostname_buffer, 0) orelse posix.HOST_NAME_MAX;
    _ = try posix.write(STDOUT, hostname_buffer[0..hostname_len]);
    _ = try posix.write(STDOUT, "\n");
    return;
}
