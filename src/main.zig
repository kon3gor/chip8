const std = @import("std");
const term = @import("term.zig");
const input = @import("input.zig");
const chip8 = @import("chip8.zig");

const MAX_GAME_SIZE = 4096 - 512;

fn load_game(gf: []const u8, buf: []u8) !usize {
    const file = try std.fs.cwd().openFile(gf, .{});
    defer file.close();
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var lbuff: [MAX_GAME_SIZE]u8 = undefined;
    const n = try in_stream.readAll(&lbuff);
    @memcpy(buf, &lbuff);
    return n;
}

fn run() !void {
    var buf: [MAX_GAME_SIZE]u8 = undefined;
    const n = try load_game("roms/piper.ch8", &buf);
    var cpu = chip8.init_chip8(&buf, n);
    try cpu.loop();
}

pub fn main() !void {
    try term.init_terminal();
    run() catch |err| {
        term.reset_terminal();
        std.debug.print("{}", .{err});
        std.os.exit(1);
    };

    term.reset_terminal();
}
