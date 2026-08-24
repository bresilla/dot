const std = @import("std");
// The version is passed in by build.zig rather than written here: this project keeps its version in
// its git tags, and a literal in the source is a copy nothing bumps.
const build_options = @import("build_options");

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var args = std.process.args();
    _ = args.skip();
    if (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            try printHelp(stdout);
            try stdout.flush();
            return;
        }
        if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-V")) {
            try stdout.print("{s}\n", .{build_options.version});
            try stdout.flush();
            return;
        }
        try stdout.print("unknown command: {s}\n", .{arg});
        try stdout.flush();
        std.process.exit(2);
    }

    try printHelp(stdout);
    try stdout.flush();
}

fn printHelp(writer: *std.Io.Writer) !void {
    try writer.print(
        \\{{PROJECT_NAME}}
        \\
        \\Usage:
        \\  {{kebab_name}} [--help] [--version]
        \\
    , .{});
}

test "the help text names the program" {
    var buffer: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try printHelp(&writer);
    try std.testing.expect(std.mem.indexOf(u8, writer.buffered(), "{{kebab_name}}") != null);
}
