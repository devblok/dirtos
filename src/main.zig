const std = @import("std");

var task_frame: @Frame(task) = undefined;

fn task() void {
    suspend {
        task_frame = @frame();
    }
    std.log.info("All your codebase are belong to us.", .{});
}

pub fn main() anyerror!void {
    std.log.info("All your codebase are belong to us.", .{});
}
