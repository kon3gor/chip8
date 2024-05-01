const std = @import("std");
const term = @import("term.zig");
const screen = @import("screen.zig");
const input = @import("input.zig");

const MEM_SIZE = 4096;
const STACK_SIZE = 16;
const FONT_START_ADDRESS = 0x0;
const REGISTERS_NUM = 16;
const PROGRAM_START_ADDR = 0x200;
const EXIT = 'p';
const TICK_HZ = 60;
const TICK_RATE = ((1 * std.time.ns_per_s) / TICK_HZ);
const BYTES_PER_CHAR = 5;

const font = [_]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};

const Chip8 = struct {
    memo: [MEM_SIZE]u8 = undefined, // 4kb of memory
    pc: u16 = PROGRAM_START_ADDR, // Program counter
    I: u16 = 0, // Index register
    delay_timer: u8 = 0,
    sound_timer: u8 = 0,
    V: [REGISTERS_NUM]u8 = undefined, // registers
    //todo: move this to the main memo
    stack: [STACK_SIZE]u16 = undefined, // 32 bytes stack
    stack_index: u8 = 0,
    screen: screen.Screen = screen.init(),
    rand: std.rand.Xoshiro256 = std.rand.DefaultPrng.init(42),

    keyboard: input.Keyboard = input.Keyboard.init(),
    current_key: u8 = input.NO_KEY,
    draw_flag: bool = true,

    pub fn loop(self: *Chip8) !void {
        var timer = try std.time.Timer.start();
        try self.keyboard.start();
        while (true) {
            self.fetch_and_decode();
            if (self.draw_flag) {
                self.screen.draw();
                self.draw_flag = false;
            }
            if (timer.read() >= TICK_RATE) {
                timer.reset();
                self.tick();
            }
        }
    }

    fn tick(self: *Chip8) void {
        if (self.sound_timer > 0) {
            self.sound_timer -= 1;
            if (self.sound_timer == 0) {
                // todo: BEEP
            }
        }

        if (self.delay_timer > 0) {
            self.delay_timer -= 1;
        }
    }

    fn fetch_and_decode(self: *Chip8) void {
        const hi = self.memo[self.pc];
        const lo = self.memo[self.pc + 1];

        self.pc += 2;

        if (self.pc >= MEM_SIZE) {
            return;
        }

        const opcode = @as(u16, hi) << 8 | lo;
        //std.debug.print("Current instruction: {x}\n", .{opcode & 0xF000});
        switch (opcode & 0xF000) {
            0x0000 => {
                self.zero_based_op(opcode);
            },
            0x1000 => {
                self.pc = opcode & 0x0FFF;
            },
            0x2000 => {
                self.stack[self.stack_index] = self.pc;
                self.stack_index += 1;
                self.pc = opcode & 0x0FFF;
            },
            0x3000 => {
                const i: u8 = @truncate((opcode & 0x0F00) >> 8);
                if (self.V[i] == lo) {
                    self.pc += 2;
                }
            },
            0x4000 => {
                const i: u8 = @truncate((opcode & 0x0F00) >> 8);
                if (self.V[i] != lo) {
                    self.pc += 2;
                }
            },
            0x5000 => {
                const i: u8 = @truncate((opcode & 0x0F00) >> 8);
                const j: u8 = @truncate((opcode & 0x00F0) >> 4);
                if (self.V[i] == self.V[j]) {
                    self.pc += 2;
                }
            },
            0x6000 => { // It's just 6XNN for now
                const v: u8 = lo;
                const i: u8 = @truncate((opcode & 0x0F00) >> 8);
                self.V[i] = v;
            },
            0x7000 => { // It's just 7XNN for now
                const i: u8 = @truncate((opcode & 0x0F00) >> 8);
                const v: u8 = @truncate(@as(u16, self.V[i]) + lo);
                self.V[i] = v;
            },
            0x8000 => {
                self.arithmetical_op(opcode);
            },
            0x9000 => {
                const i: u8 = @truncate((opcode & 0x0F00) >> 8);
                const j: u8 = @truncate((opcode & 0x00F0) >> 4);
                if (self.V[i] != self.V[j]) {
                    self.pc += 2;
                }
            },
            0xa000 => { // Set I register to NNN
                self.I = opcode & 0x0FFF;
            },
            0xb000 => {
                self.pc = (opcode & 0x0FFF) + self.V[0];
            },
            0xc000 => {
                const x = hi & 0x0F;
                self.V[x] = lo & self.rand.random().uintAtMost(u8, 0xFF);
            },
            0xd000 => {
                const x = (opcode & 0x0F00) >> 8;
                const y = (opcode & 0x00F0) >> 4;
                const n = opcode & 0x000F;
                //std.debug.print("Draw sprite at (V[{x}], V[{x}]) = ({x}, {x}) of height {d}\n", .{ x, y, self.V[x], self.V[y], n });
                self.draw(self.V[x], self.V[y], n);
                self.draw_flag = true;
            },
            0xe000 => {
                self.e_based_op(opcode);
            },
            0xf000 => {
                self.f_based_op(opcode);
            },
            else => {
                std.debug.print("Unknown instruction: {x}\n", .{opcode & 0xF000});
            },
        }
    }

    fn e_based_op(self: *Chip8, opcode: u16) void {
        const lo: u8 = @truncate(opcode & 0x00FF);
        const x: u8 = @truncate((opcode & 0x0F00) >> 8);
        switch (lo) {
            0x9e => {
                const v = self.V[x];
                if (self.keyboard.is_key_pressed(v)) {
                    self.pc += 2;
                }
            },
            0xa1 => {
                const v = self.V[x];
                if (!self.keyboard.is_key_pressed(v)) {
                    self.pc += 2;
                }
            },
            else => unreachable,
        }
    }

    fn f_based_op(self: *Chip8, opcode: u16) void {
        const lo = (opcode & 0x00FF);
        const x = (opcode & 0x0F00) >> 8;
        switch (lo) {
            0x29 => {
                const v = self.V[x];
                self.I = FONT_START_ADDRESS + BYTES_PER_CHAR * v;
            },
            0x33 => {
                const v = self.V[x];
                self.memo[self.I] = v / 100;
                self.memo[self.I + 1] = (v % 100) / 10;
                self.memo[self.I + 2] = v % 10;
            },
            0x55 => {
                for (0..x + 1) |i| {
                    self.memo[self.I + i] = self.V[i];
                }
                self.I = x + 1;
            },
            0x65 => {
                for (0..x + 1) |i| {
                    self.V[i] = self.memo[self.I + i];
                }
                self.I = x + 1;
            },
            0x1e => {
                self.I += self.V[x];
            },
            0x07 => {
                self.V[x] = self.delay_timer;
            },
            0x15 => {
                self.delay_timer = self.V[x];
            },
            0x18 => {
                self.sound_timer = self.V[x];
            },
            0x0a => {
                const v = self.keyboard.get_pressed_key();
                if (v == input.NO_KEY) {
                    self.pc -= 2;
                    return;
                }
                self.V[x] = v;
            },
            else => {
                //not yet implemented
            },
        }
    }

    fn zero_based_op(self: *Chip8, opcode: u16) void {
        switch (opcode) {
            0x00e0 => self.screen.clear(),
            0x00ee => {
                self.stack_index -= 1;
                const v = self.stack[self.stack_index];
                self.stack[self.stack_index] = 0;
                self.pc = v;
            },
            else => {
                // It's probably 0x0nnn, which is unsupported
            },
        }
    }

    fn arithmetical_op(self: *Chip8, opcode: u16) void {
        const x: u8 = @truncate((opcode & 0x0F00) >> 8);
        const y: u8 = @truncate((opcode & 0x00F0) >> 4);
        switch (opcode & 0x000F) {
            0x0 => {
                self.V[x] = self.V[y];
            },
            0x1 => {
                self.V[x] = self.V[x] | self.V[y];
                self.V[0xF] = 0;
            },
            0x2 => {
                self.V[x] = self.V[x] & self.V[y];
                self.V[0xF] = 0;
            },
            0x3 => {
                self.V[x] = self.V[x] ^ self.V[y];
                self.V[0xF] = 0;
            },
            0x4 => {
                const r: u16 = @as(u16, self.V[x]) + self.V[y];
                if (r > 0xFF) {
                    self.V[0xF] = 1;
                } else {
                    self.V[0xF] = 0;
                }
                self.V[x] = @truncate(r);
            },
            0x5 => {
                var r: u8 = 0;
                if (self.V[x] >= self.V[y]) {
                    r = self.V[x] - self.V[y];
                    self.V[0xF] = 1;
                } else {
                    r = self.V[x] + (0xFF - self.V[y] + 1);
                    self.V[0xF] = 0;
                }
                self.V[x] = r;
            },
            0x6 => {
                self.V[x] = self.V[y];
                const c = self.V[x] & 1;
                self.V[0xF] = c;

                self.V[x] = std.math.shr(u8, self.V[x], 1);
            },
            0x7 => {
                var r: u8 = 0;
                if (self.V[y] >= self.V[x]) {
                    r = self.V[y] - self.V[x];
                    self.V[0xF] = 1;
                } else {
                    r = self.V[y] + (0xFF - self.V[x] + 1);
                    self.V[0xF] = 0;
                }
                self.V[x] = r;
            },
            0xe => {
                self.V[x] = self.V[y];
                const c = self.V[x] & 0x80;
                self.V[0xF] = c;

                self.V[x] = std.math.shl(u8, self.V[x], 1);
            },
            else => {
                //todo: idk
            },
        }
    }

    fn draw(self: *Chip8, x: u8, y: u8, n: u16) void {
        self.V[0xF] = 0;
        for (0..n) |i| {
            const vbyte = self.memo[self.I + i];
            var j: u8 = 0;
            while (j < 8) {
                const vbit = (std.math.shr(u8, vbyte, j)) & 0x1;
                if (self.screen.update((x + 7 - j) % screen.WIDTH, (y + i) % screen.HEIGHT, vbit)) {
                    self.V[0xF] = 1;
                }
                j += 1;
            }
        }
    }

    fn read_current_key(self: *Chip8) u8 {
        const key = self.current_key;
        self.current_key = input.NO_KEY;
        return key;
    }
};

pub fn init_chip8(game: []u8, n: usize) Chip8 {
    var chip8 = Chip8{};
    for (0..n) |i| {
        chip8.memo[PROGRAM_START_ADDR + i] = game[i];
    }

    for (font, 0..) |sprite, i| {
        chip8.memo[FONT_START_ADDRESS + i] = sprite;
    }

    return chip8;
}
