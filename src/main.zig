const std = @import("std");

var task_frame: anyframe = undefined;

fn task() void {
    suspend {
        task_frame = @frame();
    }
    std.log.info("All your codebase are belong to us.", .{});
}

pub fn main() anyerror!void {
    _ = async task();
    std.log.info("All your codebase are belong to us.", .{});
    resume task_frame;
}
