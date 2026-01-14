const std = @import("std");

/// exports handing of mac types such as CF*
pub const types = @import("osx/types.zig");

/// exports keyboard management functions
pub const input = @import("osx/input.zig");

/// exports window management functions
pub const window = @import("osx/window.zig");

const C = @import("osx/c.zig").C;
/// tries to get the system to trust this process if it does not already
pub fn makeTrusted() !void {
    const keys: [1]C.CFStringRef = .{C.kAXTrustedCheckOptionPrompt};
    const values: [1]C.CFBooleanRef = .{ C.kCFBooleanTrue };
 
    const opts = C.CFDictionaryCreate(
        C.kCFAllocatorDefault,
        @constCast(@ptrCast(&keys)),
        @constCast(@ptrCast(&values)),
        keys.len,
        &C.kCFTypeDictionaryKeyCallBacks,
        &C.kCFTypeDictionaryValueCallBacks,
    ).?;
    defer C.CFRelease(opts);

    if (1 == C.AXIsProcessTrustedWithOptions(opts)) {
        std.log.debug("the system already trusts this process", .{});
        return;
    }
    var iter = std.process.args();
    const prog_name = types.newCFString(iter.next().?);
    defer C.CFRelease(prog_name);

    types.checkAXError(C.AXMakeProcessTrusted(prog_name)) catch |err| {
        std.log.err("failed gaining trust due to: {}", .{err});
        return err;
    };
}
