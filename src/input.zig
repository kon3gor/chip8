const std = @import("std");
const Reader = std.fs.File.Reader;
const c = @cImport({
    @cInclude("ApplicationServices/ApplicationServices.h");
    @cInclude("Carbon/Carbon.h");
});
const state = c.kCGEventSourceStateCombinedSessionState;

const KEYS = [_]u8{
    c.kVK_ANSI_X, // 0
    c.kVK_ANSI_1, // 1
    c.kVK_ANSI_2, // 2
    c.kVK_ANSI_3, // 3
    c.kVK_ANSI_Q, // 4
    c.kVK_ANSI_W, // 5
    c.kVK_ANSI_E, // 6
    c.kVK_ANSI_A, // 7
    c.kVK_ANSI_S, // 8
    c.kVK_ANSI_D, // 9
    c.kVK_ANSI_Z, // A
    c.kVK_ANSI_C, // B
    c.kVK_ANSI_4, // C
    c.kVK_ANSI_R, // D
    c.kVK_ANSI_F, // E
    c.kVK_ANSI_V, // F
};

pub const NO_KEY: u8 = 0xff;

pub const Keyboard = struct {
    inner: [16]bool = undefined,
    any_pressed: bool = false,

    pub fn init() Keyboard {
        var kb = Keyboard{};
        for (0..16) |i| {
            kb.inner[i] = false;
        }
        return kb;
    }

    pub fn start(self: *Keyboard) !void {
        const handle = try std.Thread.spawn(.{}, loop, .{self});
        handle.detach();
    }

    fn loop(self: *Keyboard) void {
        var any_pressed = false;
        while (true) {
            for (KEYS, 0..) |key, i| {
                const v = c.CGEventSourceKeyState(state, key);
                self.inner[i] = v;
                any_pressed = any_pressed or v;
            }
            self.any_pressed = any_pressed;
        }
    }

    pub fn is_key_pressed(self: *Keyboard, key: u8) bool {
        return self.inner[key];
    }

    pub fn get_pressed_key(self: *Keyboard) u8 {
        var i: u8 = 0;
        while (i < 16) {
            if (self.inner[i]) {
                return i;
            }
            i += 1;
        }
        return NO_KEY;
    }
};

pub fn convert_key(key: u8) u8 {
    return switch (key) {
        '1' => 0x1,
        '2' => 0x2,
        '3' => 0x3,
        '4' => 0xc,

        'q' => 0x4,
        'w' => 0x5,
        'e' => 0x6,
        'r' => 0xd,

        'a' => 0x7,
        's' => 0x8,
        'd' => 0x9,
        'f' => 0xe,

        'z' => 0xa,
        'x' => 0x0,
        'c' => 0xb,
        'v' => 0xf,

        else => 0xff,
    };
}
