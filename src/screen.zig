const std = @import("std");

pub const WIDTH = 64;
pub const HEIGHT = 32;

const OPENING = [_]u8{ 0x1B, '[', '1', ';', '3', '2', 'm' };
const CLOSING = [_]u8{ 0x1B, '[', '0', 'm' };

const ON = "■";
const OFF = "·";

pub const Screen = struct {
    grid: [HEIGHT][WIDTH]u8 = undefined,

    pub fn draw(self: *Screen) void {
        for (0..HEIGHT) |_| {
            std.debug.print(&[3]u8{ 0x1B, '[', 'A' }, .{});
        }

        for (0..HEIGHT) |y| {
            for (0..WIDTH) |x| {
                if (self.grid[y][x] == 0) {
                    std.debug.print(OFF, .{});
                } else {
                    std.debug.print("{s}{s}{s}", .{ OPENING, ON, CLOSING });
                }
                std.debug.print(" ", .{});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn update(self: *Screen, x: u64, y: u64, v: u8) bool {
        const ov = self.grid[y][x];
        self.grid[y][x] ^= v;
        return ov == 1 and v == 1;
    }

    pub fn clear(self: *Screen) void {
        for (0..HEIGHT) |y| {
            for (0..WIDTH) |x| {
                self.grid[y][x] = 0;
            }
        }
    }
};

pub fn init() Screen {
    return Screen{};
}
