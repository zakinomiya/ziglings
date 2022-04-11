const std = @import("std");

pub const Command = struct {
    long_name: []const u8,
    commands: ?[]Command = null,

    pub fn deinit(self: Command, allocator: std.mem.Allocator) void {
        if (self.commands) |cmds| {
            for (cmds) |cmd| {
                cmd.deinit(allocator);
            }
            allocator.free(cmds);
        }
    }
};

pub const Parser = struct {
    iter: Iterator,
    root_command: *Command,
    cur_command: *Command,

    const Iterator = struct {
        args: [][:0]u8,
        i: u32 = 0,

        pub fn init(args: [][:0]u8) Iterator {
            return Iterator{ .args = args, .i = 0 };
        }

        // iterating over command line arguments
        pub fn next(self: *Iterator) ?[:0]u8 {
            if (self.i < self.args.len) {
                const a = self.args[self.i];
                self.i += 1;
                return a;
            }
            return null;
        }

        // read ahead
        pub fn skip(self: *Iterator) ?[:0]u8 {
            if (self.i < self.args.len) {
                return self.args[self.i];
            }
            return null;
        }
    };

    pub fn init(
        args: [][:0]u8,
        commands: []const Command,
        allocator: std.mem.Allocator,
    ) Parser {
        const cmds = allocator.alloc(Command, commands.len) catch unreachable;
        for (commands) |c, i| {
            cmds[i] = c;
        }

        const c = allocator.create(Command) catch unreachable;
        c.* = Command{ .long_name = "hello", .commands = cmds };
        var iter = Iterator.init(args);
        return Parser{
            .iter = iter,
            .root_command = c,
            .cur_command = c,
        };
    }

    pub fn deinit(self: Parser, allocator: std.mem.Allocator) void {
        self.root_command.deinit(allocator);
        allocator.destroy(self.root_command);
    }

    pub fn parse(self: *Parser) !void {
        std.debug.print("cur_command: {s}\n", .{self.cur_command.long_name});
        const a = self.iter.next();
        std.debug.print("a: {s}\n", .{a.?});
        std.debug.print("cur_command: {s}\n", .{self.cur_command.long_name});
        // @1 running the next line will print broken cur_command
        std.debug.print("cur_command: {s}\n", .{self.cur_command.long_name});
        // @2 running the next two lines will panic (running with @1 won't panic but will print broken cur_command)
        const b = self.iter.next();
        std.debug.print("b: {s}\n", .{b.?});
        // @3 running the next two lines with @1 and @2 will panic with very long text
        std.debug.print("cur_command: {s}\n", .{self.cur_command.long_name});
        std.debug.print("cur_command: {s}\n", .{self.cur_command.long_name});
    }
};

pub fn main() anyerror!void {
    const alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator).allocator();
    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);
    var parser = Parser.init(args);
    try parser.parse();
}

// mocking std.process.args
const TestArgs = struct {
    args: [][:0]u8,

    fn init(args: []const []const u8) !TestArgs {
        var arr = try std.testing.allocator.alloc([:0]u8, args.len);
        for (args) |arg, i| {
            arr[i] = try std.testing.allocator.dupeZ(u8, arg);
        }
        return TestArgs{ .args = arr };
    }

    fn deinit(self: TestArgs) void {
        for (self.args) |a| {
            std.testing.allocator.free(a);
        }
    }
};

test "test" {
    var args = try TestArgs.init(&[_][]const u8{ "test", "--verbose", "hello", "--user", "root", "foo" });
    defer std.testing.allocator.free(args.args);
    defer args.deinit();
    var parser = Parser.init(args.args, &[_]Command{ .{ .long_name = "test" }, .{ .long_name = "test2" } }, std.testing.allocator);
    defer parser.deinit(std.testing.allocator);

    try parser.parse();
}
