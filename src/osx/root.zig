const std = @import("std");

const axui = @import("./c.zig").C;
const osx = @import("types.zig");


pub fn newCFString(value: [:0]const u8) axui.CFStringRef {
    return axui.CFStringCreateWithCString(
        axui.CFAllocatorGetDefault(),
        value,
        axui.kCFStringEncodingUTF8,
    );
}

// TODO: do for axui.AXValueRef
const CFType = enum {
    string,
    int,
    float,
    index,
    char,
    boolean,
};

pub const CFValue = union(CFType) {
    /// this value must be freed by the caller
    string: []u8,
    int: i64,
    float: f64,
    index: usize,
    char: u8,
    boolean: bool,

    pub fn from(ally: std.mem.Allocator, raw: axui.CFTypeRef) !CFValue {
        // NOTE: we cannot switch on this value here since the value to compare
        // it to is not compiletime known optained through e.g. axui.CFGetTypeID
        const type_id = axui.CFGetTypeID(raw);

        if (type_id == axui.CFStringGetTypeID()) {
            const key_string: axui.CFStringRef = @ptrCast(raw);
            const key_len = axui.CFStringGetLength(key_string);

            // hold enough mem for the 0-terminator
            const value: []u8 = try ally.alloc(u8, @intCast(key_len + 1));
            errdefer ally.free(value);
            std.debug.assert(1 == axui.CFStringGetCString(
                key_string,
                value.ptr,
                @intCast(value.len),
                axui.kCFStringEncodingUTF8,
            ));
            return .{ .string = value[0 .. value.len - 1] };
        } else if (type_id == axui.CFBooleanGetTypeID()) {
            const bool_ref: axui.CFBooleanRef = @ptrCast(raw);
            return .{ .boolean = 1 == axui.CFBooleanGetValue(bool_ref) };
        } else if (type_id == axui.CFNumberGetTypeID()) {
            const num_raw: axui.CFNumberRef = @ptrCast(raw);
            const num_type = axui.CFNumberGetType(num_raw);
            return switch (num_type) {
                axui.kCFNumberNSIntegerType, // platform dependent integer
                axui.kCFNumberShortType,
                axui.kCFNumberIntType,
                axui.kCFNumberLongType,
                axui.kCFNumberLongLongType,
                axui.kCFNumberSInt8Type,
                axui.kCFNumberSInt16Type,
                axui.kCFNumberSInt32Type,
                axui.kCFNumberSInt64Type,
                => {
                    var value: i64 = 0;
                    std.debug.assert(1 == axui.CFNumberGetValue(num_raw, num_type, &value));
                    return .{ .int = value };
                },
                axui.kCFNumberFloat32Type,
                axui.kCFNumberFloat64Type,
                axui.kCFNumberFloatType,
                axui.kCFNumberDoubleType,
                axui.kCFNumberCGFloatType, // a float from the CG (Core Graphics library)
                // same as CFNumberCGFloatType
                => {
                    var value: f64 = 0;
                    std.debug.assert(1 == axui.CFNumberGetValue(num_raw, num_type, &value));
                    return .{ .float = value };
                },
                axui.kCFNumberCharType => {
                    var value: u8 = 0;
                    std.debug.assert(1 == axui.CFNumberGetValue(num_raw, num_type, &value));
                    return .{ .char = value };
                },
                axui.kCFNumberCFIndexType => {
                    var value: usize = 0;
                    std.debug.assert(1 == axui.CFNumberGetValue(num_raw, num_type, &value));
                    return .{ .index = value };
                },
                else => unreachable,
            };
        }

        return error.UnknownType;
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        switch (self) {
            .string => |str| {
                try writer.print("{s}", .{str});
            },
            .char => |char| {
                try writer.print("{c}", .{char});
            },
            .float,
            => |value| {
                try writer.print("{d}", .{value});
            },
            .index => |value| {
                try writer.print("{d}", .{value});
            },
            .int => |value| {
                try writer.print("{d}", .{value});
            },
            .boolean => |value| {
                try writer.print("{}", .{value});
            },
        }
    }
};

pub fn makeTrusted() !void {
    var iter = std.process.args();
    if (0 == axui.AXIsProcessTrustedWithOptions(null)) {
        std.debug.print("we are not trusted -> gain it\n", .{});
        osx.checkAXError(axui.AXMakeProcessTrusted(newCFString(iter.next().?))) catch |err| {
            std.debug.print("failed gaining trust ue to: {}\n", .{err});
            std.process.exit(1);
        };
    }
}

pub const Window = struct {
    pid: u32,
};

pub fn listWindows(ally: std.mem.Allocator) !void {
    const windows = axui.CGWindowListCopyWindowInfo(
        axui.kCGWindowListOptionAll,
        axui.kCGNullWindowID,
    );
    defer axui.CFRelease(windows);

    const window_count: usize = @intCast(axui.CFArrayGetCount(windows));

    for (0..window_count) |window_number| {
        const window: axui.CFDictionaryRef = @ptrCast(axui.CFArrayGetValueAtIndex(
            windows,
            @intCast(window_number),
        ));
        const attribute_count: usize = @intCast(axui.CFDictionaryGetCount(@ptrCast(window)));

        const keys = try ally.alloc(axui.CFTypeRef, attribute_count);
        defer ally.free(keys);

        const values = try ally.alloc(axui.CFTypeRef, attribute_count);
        defer ally.free(values);

        axui.CFDictionaryGetKeysAndValues(
            @ptrCast(window),
            keys.ptr,
            values.ptr,
        );

        for (0..attribute_count) |i| {
            const keyValue = CFValue.from(ally, keys[i]) catch {
                std.debug.print("encounted unkown key type\n", .{});
                continue;
            };
            const valueValue = CFValue.from(ally, values[i]) catch {
                std.debug.print("encounted unkown value type for key: {f}\n", .{keyValue});
                continue;
            };
            std.debug.print("{f}: {f}\n", .{ keyValue, valueValue });
            switch (keyValue) {
                .string => |str| {
                    defer ally.free(str);
                },
                else => {},
            }
            switch (valueValue) {
                .string => |str| {
                    defer ally.free(str);
                },
                else => {},
            }
        }
    }
}

pub fn findWindow(ally: std.mem.Allocator, name: []const u8) !?Window {
    const win_infos = axui.CGWindowListCopyWindowInfo(
        axui.kCGWindowListExcludeDesktopElements, // return only user windows
        axui.kCGNullWindowID,
    );
    //defer axui.CFRelease(win_infos);

    const ownerNameAttribute = newCFString("kCGWindowOwnerName");
    defer axui.CFRelease(ownerNameAttribute);

    const owner_pid = newCFString("kCGWindowOwnerPID");
    defer axui.CFRelease(owner_pid);

    // NOTE: these bounds are not that useful... there were
    // 0 0 1920 0 for the reminders app no matter it's location
    // const bounds_attr = newCFString("kCGWindowBounds");
    // defer axui.CFRelease(bounds_attr);

    // https://developer.apple.com/documentation/coregraphics/required-window-list-keys?language=objc
    for (0..@intCast(axui.CFArrayGetCount(win_infos))) |window_number| {
        const info: axui.CFDictionaryRef = @ptrCast(axui.CFArrayGetValueAtIndex(
            win_infos,
            @intCast(window_number),
        ));

        const owner = try CFValue.from(
            ally,
            axui.CFDictionaryGetValue(info, ownerNameAttribute),
        );
        const owner_str = owner.string;
        defer ally.free(owner_str);
        //std.debug.print("compare {s} = {s}\n", .{ name, owner_str });
        if (std.ascii.endsWithIgnoreCase(owner_str, name)) {
            const pid_value = try CFValue.from(
                ally,
                axui.CFDictionaryGetValue(info, owner_pid),
            );

            // const raw_bounds: axui.CFDictionaryRef = @ptrCast(axui.CFDictionaryGetValue(info, bounds_attr));
            // defer axui.CFRelease(raw_bounds);
            // std.debug.assert(raw_bounds != null);
            // var bounds: axui.CGRect = .{};
            // std.debug.assert(true == axui.CGRectMakeWithDictionaryRepresentation(raw_bounds, &bounds));

            return .{
                .pid = @intCast(pid_value.int),
                // .bounds = .{
                //     .x = bounds.origin.x,
                //     .y = bounds.origin.y,
                //     .width = bounds.size.width,
                //     .height = bounds.size.height,
                // }
            };
        }
    }
    return null;
}

pub fn focusByPid(pid: u32) !void {
    // NOTE: one can only focus the application not the window?????
    const app_ref = axui.AXUIElementCreateApplication(@intCast(pid));
    defer axui.CFRelease(app_ref);

    // name of the attribute to retrieve
    const windows_attribute = axui.CFStringCreateWithCString(
        axui.CFAllocatorGetDefault(),
        "AXWindows", // kAXWindowsAttribute
        axui.kCFStringEncodingUTF8,
    );
    defer axui.CFRelease(windows_attribute);

    const front_most_attr = newCFString("AXFrontmost");
    defer axui.CFRelease(front_most_attr);
    osx.checkAXError(axui.AXUIElementSetAttributeValue(
        app_ref, // appref
        front_most_attr,
        axui.kCFBooleanTrue,
    )) catch |err| {
        std.debug.print("failed setting attribute due to: {}\n", .{err});
        std.process.exit(1);
    };
}

fn eventCallback(
    proxy: axui.CGEventTapProxy,
    event_type: axui.CGEventType,
    event_ref: axui.CGEventRef,
    context: ?*anyopaque,
) callconv(.c) axui.CGEventRef {
    _ = context; // autofix

    if (event_type != axui.kCGEventKeyDown) {
        return event_ref;
    }

    const key_code = axui.CGEventGetIntegerValueField(
        event_ref, 
        axui.kCGKeyboardEventKeycode,
    );
    std.debug.print("{d} key is pressed\n", .{key_code});

    const flags = axui.CGEventGetFlags(event_ref);
    if (flags & axui.kCGEventFlagMaskControl > 0) {
        std.debug.print("control key is pressed\n", .{});
        axui.CGEventSetIntegerValueField(event_ref, axui.kCGKeyboardEventKeycode, axui.kVK_ANSI_C);
        return event_ref;
    }
    if (flags & axui.kCGEventFlagMaskShift > 0) {
        std.debug.print("shift key is pressed\n", .{});

        // create a source with witch
        //  - the system can better check the timing between actions
        //  - the state is clean, meaning that we send the keys that we want to send
        //      no matter if the user actually presses a modifier key at the same
        //      time which would normally be mixed when we use NULL as the evnet source
        //      when creating a event.
        const event_source = axui.CGEventSourceCreate(axui.kCGEventSourceStateHIDSystemState);
        defer axui.CFRelease(event_source);

        const new_event_ref = axui.CGEventCreateKeyboardEvent(
            event_source,
            axui.kVK_ANSI_X,
            true,
        );
        axui.CGEventSetFlags(new_event_ref, axui.kCGEventFlagMaskShift);

        // use the function stead of axui.CGEventPost to avoid recursion
        // which is specifically made for this
        axui.CGEventTapPostEvent(proxy, new_event_ref);
        axui.CFRelease(new_event_ref);

        // Give the system a brief moment to register the key down
        std.Thread.sleep(10_000);

        // --- 2. Key Up Event ---
        const key_up_event = axui.CGEventCreateKeyboardEvent(
            event_source,
            axui.kVK_ANSI_X,
            false,
        );
        axui.CGEventSetFlags(
            key_up_event,
            axui.kCGEventFlagMaskShift,
        );
        
        // Post the Key Up event to the system
        axui.CGEventTapPostEvent(proxy, key_up_event);
        //axui.CGEventPost(axui.kCGHIDEventTap, key_up_event);
        axui.CFRelease(key_up_event);
        std.debug.print(">>>>> sent event\n", .{});
    }

    var buff: [256]axui.UInt16  = undefined;
    var strlen: usize = 0;
    axui.CGEventKeyboardGetUnicodeString(
        event_ref,
        buff.len,
        &strlen,
        &buff,
    );
    const str = std.unicode.utf16LeToUtf8Alloc(std.heap.c_allocator, buff[0..strlen]) catch unreachable;
    defer std.heap.c_allocator.free(str);
    std.debug.print("TYPED: {s}\n", .{str});

    return event_ref;
}

pub fn listen() void {
    // TODO: the cleanup logic is prob missing here
    const port_ref = axui.CGEventTapCreate(
        axui.kCGSessionEventTap,
        axui.kCGTailAppendEventTap, // make this new last listenser
        // we do not only want to listen which is why we cannot use the default option here
        axui.kCGEventTapOptionDefault,// axui.kCGEventTapOptionListenOnly,
        axui.CGEventMaskBit(axui.kCGEventKeyDown),
        eventCallback,
        null, // some state that we can pass to the callback
    );
    const loop_source_ref = axui.CFMachPortCreateRunLoopSource(axui.CFAllocatorGetDefault(), port_ref, 0);

    const loop_ref = axui.CFRunLoopGetMain();
    axui.CFRunLoopAddSource(
        loop_ref,
        loop_source_ref, 
        axui.kCFRunLoopCommonModes,
    );
    axui.CGEventTapEnable(port_ref, true);
    axui.CFRunLoopRun();
}

pub fn fooByPid(pid: u32) void {
    // NOTE: one can only focus the application not the window?????
    const app_ref = axui.AXUIElementCreateApplication(@intCast(pid));
    defer axui.CFRelease(app_ref);

    const windows_attribute = axui.CFStringCreateWithCString(
        axui.CFAllocatorGetDefault(),
        "AXWindows", // kAXWindowsAttribute
        axui.kCFStringEncodingUTF8,
    );
    defer axui.CFRelease(windows_attribute);

    var window_list: axui.CFArrayRef = null;
    osx.checkAXError(axui.AXUIElementCopyAttributeValue(
        app_ref,
        windows_attribute,
        @ptrCast(&window_list),
    )) catch |err| {
        std.debug.print("failed getting attribute due to: {}\n", .{err});
        std.process.exit(1);
    };
    defer axui.CFRelease(window_list);
    std.debug.print("THERE ARE {d} WINDOWS\n", .{axui.CFArrayGetCount(window_list)});
}

// pub fn setWorkspace(num: u8) void {
//     // one can also specify the transition to be used here!
//     checkCGError(externi.CGSSetWorkspace(
//         externi._CGSDefaultConnection(),
//         num,
//     )) catch |err| {
//         std.debug.print("failed setting new workspace due to: {}\n", .{err});
//         std.process.exit(1);
//     };
// }
//

pub const Bounds = struct {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
};
pub fn getBoundsByPid(pid: u32) Bounds {
    const ax_element = AXElement.fromPid(pid);
    defer ax_element.deinit();

    const attr = newCFString("AXPosition"); // axui.kAXPositionAttribute
    defer axui.CFRelease(attr);

    // https://developer.apple.com/documentation/coregraphics/kcgwindowbounds
    var pos_value: axui.AXValueRef = null;
    osx.checkAXError(axui.AXUIElementCopyAttributeValue(
        ax_element.element, // appref
        attr,
        &pos_value,
    )) catch |err| {
        std.debug.print("failed retrieving position attribute due to: {}\n", .{err});
        std.process.exit(1);
    };
    defer axui.CFRelease(pos_value);

    var pos: axui.CGPoint = .{};
    std.debug.assert(1 == axui.AXValueGetValue(pos_value, axui.kAXValueCGPointType, @ptrCast(&pos)));

    //

    //axui.kAXPositionAttribute
    const attr2 = newCFString("AXSize"); // axui.kAXSizeAttribute
    defer axui.CFRelease(attr2);

    // https://developer.apple.com/documentation/coregraphics/kcgwindowbounds
    var size_value: axui.AXValueRef = null;
    osx.checkAXError(axui.AXUIElementCopyAttributeValue(
        ax_element.element,
        attr2,
        &size_value,
    )) catch |err| {
        std.debug.print("failed retrieving size attribute due to: {}\n", .{err});
        std.process.exit(1);
    };
    defer axui.CFRelease(size_value);

    var size: axui.CGSize = .{};
    std.debug.assert(1 == axui.AXValueGetValue(size_value, axui.kAXValueCGSizeType, @ptrCast(&size)));

    return .{
        .x = pos.x,
        .y = pos.y,
        .width = size.width,
        .height = size.height,
    };
}

pub fn setPosByPid(pid: u32, posX: f64, posY: f64) void {
    const ax_element = AXElement.fromPid(pid);
    defer ax_element.deinit();

    var pos: axui.CGPoint = .{ .x = posX, .y = posY };
    const value = axui.AXValueCreate(axui.kAXValueCGPointType, &pos);
    std.debug.assert(value != null);
    defer axui.CFRelease(value);

    const attr = newCFString("AXPosition"); // axui.kAXPositionAttribute
    defer axui.CFRelease(attr);

    // https://developer.apple.com/documentation/coregraphics/kcgwindowbounds
    osx.checkAXError(axui.AXUIElementSetAttributeValue(
        ax_element.element,
        attr,
        value,
    )) catch |err| {
        std.debug.print("failed setting position attribute due to: {}\n", .{err});
        std.process.exit(1);
    };
}

pub fn setSizeByPid(pid: u32, width: f64, height: f64) void {
    const ax_element = AXElement.fromPid(pid);
    defer ax_element.deinit();

    var size: axui.CGSize = .{ .width = width, .height = height };
    const value = axui.AXValueCreate(axui.kAXValueCGSizeType, &size);
    std.debug.assert(value != null);
    defer axui.CFRelease(value);

    const attr = newCFString("AXSize"); // axui.kAXPositionAttribute
    defer axui.CFRelease(attr);

    // https://developer.apple.com/documentation/coregraphics/kcgwindowbounds
    osx.checkAXError(axui.AXUIElementSetAttributeValue(
        ax_element.element,
        attr,
        value,
    )) catch |err| {
        std.debug.print("failed setting position attribute due to: {}\n", .{err});
        std.process.exit(1);
    };
}

pub fn makeFullscreenByPid(pid: u32) void {
    const ax_element = AXElement.fromPid(pid);
    defer ax_element.deinit();

    const attr = newCFString("AXFullScreen");
    defer axui.CFRelease(attr);

    osx.checkAXError(axui.AXUIElementSetAttributeValue(
        ax_element.element,
        attr,
        axui.kCFBooleanTrue,
    )) catch |err| {
        std.debug.print("failed setting fullscreen attribute due to: {}\n", .{err});
        std.process.exit(1);
    };

    // well the stuff below works but changing the attribute is easier??

    // WARN: this button does not always exist eg. when the window is already in fullscreen
    // const button_attr = newCFString("AXFullScreenButton");
    // defer axui.CFRelease(button_attr);
    //
    // var button: axui.AXUIElementRef = null;
    // defer axui.CFRelease(button);
    // check(axui.AXUIElementCopyAttributeValue(
    //     ax_element.element,
    //     button_attr,
    //     &button,
    // )) catch |err| {
    //     std.debug.print("failed to obtain fullscreen button: {}\n", .{err});
    //     std.process.exit(1);
    // };
    //
    // const action = newCFString("AXPress");
    // defer axui.CFRelease(action);
    // check(axui.AXUIElementPerformAction(button, action)) catch |err| {
    //     std.debug.print("failed to press fullscreen button: {}\n", .{err});
    //     std.process.exit(1);
    // };
}

pub fn printScreens() void {
    var displays  = std.mem.zeroes([16]axui.CGDirectDisplayID);
    var num_displays: u32 = 0;

    osx.checkCGError(axui.CGGetActiveDisplayList(
        displays.len,
        &displays,
        &num_displays,
    )) catch |err| {
        std.debug.print("failed getting active displays due to: {}\n", .{err});
        std.process.exit(1);
    };

    for (0..num_displays) |i| {
        const rect = axui.CGDisplayBounds(displays[i]);
        std.debug.print(
            "SCREEN [{d}/{d}]: {d}x{d} (start) | {d}x{d} (size)\n",
            .{
                i,
                num_displays,
                rect.origin.x,
                rect.origin.y,
                rect.size.width,
                rect.size.height,
            },
        );
    }
}

const AXElement = struct {
    element: axui.AXUIElementRef,

    fn fromPid(pid: u32) AXElement {
        const app_ref = axui.AXUIElementCreateApplication(@intCast(pid));
        defer axui.CFRelease(app_ref);

        // attribute to get the focused window
        const focused_attribute = axui.CFStringCreateWithCString(
            axui.CFAllocatorGetDefault(),
            "AXFocusedWindow", // kAXWindowsAttribute
            axui.kCFStringEncodingUTF8,
        );
        defer axui.CFRelease(focused_attribute);

        var ui_element: axui.AXUIElementRef = null;
        osx.checkAXError(axui.AXUIElementCopyAttributeValue(
            app_ref,
            focused_attribute,
            @ptrCast(&ui_element),
        )) catch |err| {
            std.debug.print("failed getting attribute due to: {}\n", .{err});
            std.process.exit(1);
        };
        return .{ .element = ui_element };

        // the following code can be used to get all windows of app_ref this is usually an empty array

        // attribute to get a list of all windows
        // const windows_attribute = axui.CFStringCreateWithCString(
        //     axui.CFAllocatorGetDefault(),
        //     "AXWindows", // kAXWindowsAttribute
        //     axui.kCFStringEncodingUTF8,
        // );
        // defer axui.CFRelease(windows_attribute);
        //
        // var window_list: axui.CFArrayRef = null;
        // check(axui.AXUIElementCopyAttributeValue(
        //     app_ref,
        //     windows_attribute,
        //     @ptrCast(&window_list),
        // )) catch |err| {
        //     std.debug.print("failed getting attribute due to: {}\n", .{err});
        //     std.process.exit(1);
        // };
        // defer axui.CFRelease(window_list);
        // std.debug.print("THERE ARE {d} WINDOWS\n", .{axui.CFArrayGetCount(window_list)});
    }

    fn printAttributeNames(self: *const @This()) void {
        var attr_names: axui.CFArrayRef = null;
        defer axui.CFRelease(attr_names);
        osx.checkAXError(axui.AXUIElementCopyAttributeNames(
            self.element, // appref
            &attr_names,
        )) catch |err| {
            std.debug.print("failed retrieving position attribute due to: {}\n", .{err});
            std.process.exit(1);
        };
        for (0..@intCast(axui.CFArrayGetCount(attr_names))) |i| {
            const value = CFValue.from(
                std.heap.c_allocator,
                axui.CFArrayGetValueAtIndex(attr_names, @intCast(i)),
            ) catch unreachable;
            std.debug.print("ATTR: {f}\n", .{value});
            std.heap.c_allocator.free(value.string);
        }
    }

    fn deinit(self: *const @This()) void {
        defer axui.CFRelease(self.element);
    }
};
