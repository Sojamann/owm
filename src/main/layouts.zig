const std = @import("std");
const osx = @import("osx");

const win = osx.window;
const input = osx.input;

pub const Options = struct {
    ally: std.mem.Allocator,

    layout: union(enum) {
        /// maximizes the specified application on the currently focused screen
        maximize: []const u8,
        /// splits the currently focused screen into two and places
        /// the specified applications accordingly
        split: struct {
            left: []const u8,
            right: []const u8,
        },
    }
};

/// applies the through the Options specified layout
pub fn handle(
    context: *const anyopaque,
) input.HandlerError!void {
    const options: *const Options = @ptrCast(@alignCast(context));
    
    const windows = win.listApplications(options.ally) catch |err| {
        std.log.err("failed listing all windows due to: {}", .{err});
        return input.HandlerError.Failed;
    };
    defer {
        for (windows) |w| {
            options.ally.free(w.name);
        }
        options.ally.free(windows);
    }


    const screen_size = win.getActiveScreenSize() catch |err| {
        std.log.err(
            "failed getting active displays due to: {}",
            .{err},
        );
        return input.HandlerError.Failed;
    };

    switch (options.layout) {
        .maximize => |app_name| {
            const app_info = findApp(windows, app_name) orelse return;
            const app = try (getAppHandle("unable to maximize", app_info)) orelse return;
            defer app.deinit();

            app.move(
                screen_size.origin.x,
                screen_size.origin.y,
                screen_size.size.width,
                screen_size.size.height,
            ) catch |err| {
                std.log.err(
                    "failed maximizing '{s}' due to: {}",
                    .{app_name, err},
                );
                return;
            };

            app.focus() catch |err| {
                std.log.err(
                    "failed focusing application '{s}' due to: {}",
                    .{app_name, err},
                );
                return;
            };
        },
        .split => |apps| {
            const left_app_info = findApp(windows, apps.left) orelse return;
            const right_app_info = findApp(windows, apps.right) orelse return;

            const left_app = (try getAppHandle("unable to split", left_app_info)) orelse return;
            defer left_app.deinit();
            const right_app = (try getAppHandle("unable to split", right_app_info)) orelse return;
            defer right_app.deinit();

            left_app.focus() catch |err| std.log.err(
                "failed setting focus to app '{s}' due to: {}",
                .{apps.left, err},
            );

            left_app.move(
                screen_size.origin.x,
                screen_size.origin.y,
                screen_size.size.width / 2,
                screen_size.size.height,
            ) catch |err| {
                std.log.err(
                    "failed moving {s} left due to: {}",
                    .{apps.left, err},
                );
                return;
            };
            right_app.move(
                screen_size.origin.x + (screen_size.size.width/2),
                screen_size.origin.y + (screen_size.size.height/2),
                screen_size.size.width / 2,
                screen_size.size.height,
            ) catch |err| {
                std.log.err(
                    "failed moving {s} right due to: {}",
                    .{apps.left, err},
                );
                return;
            };
        }
    
    }
}

fn findApp(
    app_infos: []win.ListApplicationItem,
    name: []const u8,
) ?win.ListApplicationItem {
    for (app_infos) |w| {
        if (std.ascii.eqlIgnoreCase(w.name, name)) {
            return w;
        }
    }
    std.log.info(
        "could not find application '{s}'", 
        .{name},
    );
    return null;
}

/// uitlity function to obtain a Application instance that includes the
/// error handling and logging.
/// An error is returned if it is unexpected
/// An null value is returned if the applciation has no open windows.
fn getAppHandle(
    comptime context: []const u8,
    info: win.ListApplicationItem,
) !?win.Application {
    return win.Application.fromPid(info.pid) catch |err| switch (err) {
        error.NoWindow => {
            std.log.info(
                "{s} as app {s} (pid {}) has no open windows",
                .{context, info.name, info.pid},
            );
            return null;
        },
        else => {
            std.log.err(
                "{s} as no accessibility handle could be acquired for pid {} ({s}) due to: {}",
                .{context, info.pid, info.name, err},
            );
            return input.HandlerError.Failed;
        },
    };
}
