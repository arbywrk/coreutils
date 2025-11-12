const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Allow an optional CLI parameter: `zig build utilname=<name>`
    const util_opt = b.option([]const u8, "utilname", "Build only a single utility");

    // Read directory contents of src/
    const src_dir = std.fs.cwd().openDir("src", .{ .iterate = true }) catch {
        std.debug.print("src directory missing\n", .{});
        return;
    };
    var it = src_dir.iterate();

    // Keep track of all executables
    var all_utils: std.ArrayList(*std.Build.Step) = .empty;
    defer all_utils.deinit(b.allocator);

    while (it.next() catch null) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".zig"))
            continue;

        const name = entry.name[0 .. entry.name.len - 4]; // strip .zig

        // If utilname was given, skip others
        if (util_opt) |utilname| {
            if (!std.mem.eql(u8, utilname, name))
                continue;
        }

        const exe = b.addExecutable(.{
            .name = name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(std.fmt.allocPrint(b.allocator, "src/{s}", .{entry.name}) catch unreachable),
                .optimize = optimize,
                .target = target,
            }),
        });

        b.installArtifact(exe);
        try all_utils.append(b.allocator, &exe.step);
    }

    // If building all, add a top-level step
    const all_step = b.step("all", "Build all utilities");
    for (all_utils.items) |step| all_step.dependOn(step);

    // Default step = all
    b.default_step.dependOn(all_step);
}
