const std = @import("std");

var orig_termios: std.os.termios = undefined;

pub fn init_terminal() !void {
    orig_termios = try std.os.tcgetattr(std.os.STDIN_FILENO);
    var tios: std.os.termios = orig_termios;
    // tios.lflag &= ~(std.os.system.ECHO | std.os.system.ICANON);
    tios.lflag.ECHO = false;
    tios.lflag.ICANON = false;
    tios.cc[@intFromEnum(std.os.system.V.MIN)] = 0;
    tios.cc[@intFromEnum(std.os.system.V.TIME)] = 0;
    try std.os.tcsetattr(std.os.STDIN_FILENO, std.os.system.TCSA.FLUSH, tios);
}

pub fn reset_terminal() void {
    std.os.tcsetattr(std.os.STDIN_FILENO, std.os.system.TCSA.FLUSH, orig_termios) catch {
        std.debug.print("Daaaaamn", .{});
    };
}
