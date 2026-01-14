const std = @import("std");
const osx = @import("osx");

const win = osx.window;
const input = osx.input;

const actions = @import("main/actions.zig");
const layouts = @import("main/layouts.zig");

const config = @import("main/config.zig");

// since we link with libc and the mac APIs are using it we will do so as well
const ally = std.heap.c_allocator;


fn handleSigInt(signal: c_int) callconv(.c) void {
    std.log.info("shutdowm requested with signal {}", .{signal});
    input.remap(input.Button.CapsLock, input.Button.CapsLock) catch {};
    std.log.info("restored capslock functionality", .{});
    std.process.exit(0);
}

pub fn main() !void {
    // ensures that the system trusts this process
    try osx.makeTrusted();

    // load the user config
    const parse_result = config.readConfig(ally) catch {
        std.log.err("Invalid config file", .{});
        std.process.exit(1);
    };
    defer parse_result.deinit();
    const cfg = parse_result.value;

    // store the input handlers which store the context and the callback to a user input
    var handlers: [256]input.Handler = undefined;
    var num_handlers: usize = 0;

    // store all callback contexts here so that the pointers are valid
    var store: [256]union{l: layouts.Options, a: actions.Options} = undefined;
    var store_count: usize = 0;

    // store wheather the capslock button is used in order to remap it later
    var remap_capslock = false;

    for (cfg.actions) |action| {
        store[store_count] = .{.a = .{.action = action.do}};
        defer store_count += 1;
        
        var keystate = input.KeyState.withButtons(action.when);
        // if capslock is set -> we will remap the key to F20 so here the button is switched
        if (keystate.isSet(input.Button.CapsLock)) {
            keystate.unset(input.Button.CapsLock);
            keystate.set(input.Button.F20);
            remap_capslock = true;
        }

        handlers[num_handlers] = .{
            .on = keystate,
            .do = actions.handle,
            .context = &store[store_count],
        };
        defer num_handlers += 1;
        std.log.debug(
            "registered action {} for combination {any}",
            .{action.do, action.when},
        );
    }


    for (cfg.layouts) |layout| {
        var keystate = input.KeyState.withButtons(layout.when);

        // if capslock is set -> we will remap the key to F20 so here the button is switched
        if (keystate.isSet(input.Button.CapsLock)) {
            keystate.unset(input.Button.CapsLock);
            keystate.set(input.Button.F20);
            remap_capslock = true;
        }

        const opt: layouts.Options = blk: switch (layout.do) {
            .maximize => |s| {
                std.log.debug(
                    "registered fullscreen layout using '{s}' for combination {any}",
                    .{s, layout.when},
                );
                break :blk .{
                    .ally = ally,
                    .layout = .{.maximize = s},
                };
            },
            .split => |split| {
                std.log.debug(
                    "registered split layout using '{s}|{s}' for combination {any}",
                    .{split.left, split.right, layout.when},
                );
                break :blk .{
                    .ally = ally,
                    .layout = .{
                        .split = .{ .left = split.left, .right = split.right }
                    }
                };
            }
        };

        store[store_count] = .{.l = opt};
        defer store_count += 1;

        handlers[num_handlers] = .{
            .on = keystate,
            .do = layouts.handle,
            .context = &store[store_count],
        };
        defer num_handlers += 1;
    }

    // Given that the user is using the CapsLock button for key combinations we need to remap
    // it to the F20 key and when the program exists, revert this change.
    if (remap_capslock) {
        std.log.warn("remapping CAPSLOCK as it is used in keyboard shortcuts", .{});
        try input.remap(input.Button.CapsLock, input.Button.F20);

        const action = std.posix.Sigaction{
            .handler = .{ .handler = handleSigInt },
            .mask = std.posix.sigemptyset(),
            .flags = 0,
        };
        std.posix.sigaction(std.posix.SIG.HUP, &action, null);
        std.posix.sigaction(std.posix.SIG.QUIT, &action, null);
        std.posix.sigaction(std.posix.SIG.INT, &action, null);
        std.posix.sigaction(std.posix.SIG.TERM, &action, null);
    }

    input.startListner(handlers[0..num_handlers]) catch |err| {
        if (remap_capslock) {
            input.remap(input.Button.CapsLock, input.Button.CapsLock) catch {};
        }
        std.log.err("stopping .... due to error: {}", .{err});
        std.process.exit(1);
    };
}
