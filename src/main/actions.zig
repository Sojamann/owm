const std = @import("std");
const osx = @import("osx");

const win = osx.window;
const input = osx.input;


/// describes what should happen with a window
pub const Action = enum {
    left,
    right,
    up,
    down,
    maximize,
    leftMonitor,
    rightMonitor,
};


/// the context for the handle function
pub const Options = struct {
    action: Action,
};

/// performs an Action wrapped in a Option on the currently focused window
pub fn handle(context: *const anyopaque) input.HandlerError!void {
    const options: *const Options = @ptrCast(@alignCast(context));

    const app = win.Application.getFocused() catch |err| {
        std.log.debug(
            "failed getting focused application due to: {}",
            .{err},
        );
        return input.HandlerError.Failed;
    };
    defer app.deinit();

    const active_screen_size = win.getActiveScreenSize() catch |err| {
        std.log.err(
            "failed getting active displays due to: {}",
            .{err},
        );
        return input.HandlerError.Failed;
    };

    switch (options.action) {
        .left => app.move(
            active_screen_size.origin.x,
            active_screen_size.origin.y,
            active_screen_size.size.width/2,
            active_screen_size.size.height,
        ) catch |err| {
            std.log.err(
                "failed moving window left due to: {}",
                .{err}
            );
        },
        .right => app.move(
            active_screen_size.origin.x + (active_screen_size.size.width/2),
            active_screen_size.origin.y + (active_screen_size.size.height),
            active_screen_size.size.width/2,
            active_screen_size.size.height,
        ) catch |err| {
            std.log.err(
                "failed moving window right due to: {}",
                .{err}
            );
        },
        .up => app.move(
            active_screen_size.origin.x,
            active_screen_size.origin.y,
            active_screen_size.size.width,
            active_screen_size.size.height/2,
        ) catch |err| {
            std.log.err(
                "failed moving window up due to: {}",
                .{err}
            );
        },
        .down => app.move(
            active_screen_size.origin.x,
            active_screen_size.origin.y + (active_screen_size.size.height/2),
            active_screen_size.size.width,
            active_screen_size.size.height/2,
        ) catch |err| {
            std.log.err(
                "failed moving window down due to: {}",
                .{err}
            );
        },
        .maximize => app.move(
            active_screen_size.origin.x,
            active_screen_size.origin.y,
            active_screen_size.size.width,
            active_screen_size.size.height,
        ) catch |err| {
            std.log.err(
                "failed maximizing window due to: {}",
                .{err}
            );
        },
        .leftMonitor, .rightMonitor => {
            var screen_bounds_buff: [16]win.Bounds = undefined;
            const screens = win.getScreens(&screen_bounds_buff) catch |err| {
                std.log.err(
                    "failed getting display bounds due to: {}", 
                    .{err},
                );
                return input.HandlerError.Failed;
            };

            // find the position of the current screen in the bounds slice
            const curr_index: i64 = blk: {
                for (screens, 0..) |screen, i| {
                    if (
                        active_screen_size.origin.x == screen.origin.x
                        and active_screen_size.origin.y == screen.origin.y
                        and active_screen_size.size.width == screen.size.width
                        and active_screen_size.size.height == screen.size.height
                    ) {
                        break :blk @intCast(i);
                    }
                }
                break :blk 0;
            };

            const next_index = if (options.action == .leftMonitor)
                curr_index - 1
            else
                curr_index + 1;

            const total_screens: i64 = @intCast(screens.len);
            const next_screen = screens[@intCast(@mod(next_index, total_screens))];
            
            // TODO: preserve layout
            app.move(
                next_screen.origin.x,
                next_screen.origin.y,
                next_screen.size.width,
                next_screen.size.height,
            ) catch |err| {
                std.log.err(
                    "failed moving window to right monitor due to: {}",
                    .{err}
                );
                return;
            };

            // bring the mouse to the new monitor since it should be focused
            // now. AND by doing so the next time getScreen is called, the
            // right screen is pulled.
            input.moveMouse(
                next_screen.origin.x + (next_screen.size.width/2),
                next_screen.origin.y + (next_screen.size.height/2),
            );
        },
    }
}
