///! management of all input releated functions and types

const std = @import("std");
const C = @import("c.zig").C;
const types = @import("types.zig");

pub const ButtonParseError = error {
    UnknownModifier,
    UnknownKey,
};

/// Name of a button
pub const Button = enum {
    Q,
    W,
    E,
    R,
    T,
    Y,
    U,
    I,
    O,
    P,
    A,
    S,
    D,
    F,
    G,
    H,
    J,
    K,
    L,
    Z,
    X,
    C,
    V,
    B,
    N,
    M,
    @"0",
    @"1",
    @"2",
    @"3",
    @"4",
    @"5",
    @"6",
    @"7",
    @"8",
    @"9",
    Space,
    Tab,
    CapsLock,
    Shift,
    Control,
    Option,
    Command,
    Return,
    Escape,
    Backspace,
    Delete,
    F1,
    F2,
    F3,
    F4,
    F5,
    F6,
    F7,
    F8,
    F9,
    F10,
    F11,
    F12,
    F20, // used when remapping CapsLock
    Left,
    Up,
    Down,
    Right,
    PageUp,
    PageDown,
    Home,
    Function,
    Quote,
    Semicolon,
    Backslash,
    Comma,
    Period,
    Slash,
    Equals,
    Minus,
    LeftBracket,
    RightBracket,
    Grave,          // `


    /// turns a window server event into a button state
    /// returning both the button and wheter is is pressed
    /// or not.
    /// Errors when the event cannot be understood or the button is
    /// not supported.
    fn fromEvent(
        event_type: C.CGEventType,
        event_ref: C.CGEventRef,
    ) ButtonParseError!struct{Button, bool} {
        std.debug.assert(
            event_type == C.kCGEventKeyDown
            or event_type == C.kCGEventKeyUp
            or event_type == C.kCGEventFlagsChanged
        );
        const key_code = C.CGEventGetIntegerValueField(
            event_ref, 
            C.kCGKeyboardEventKeycode,
        );

        // some keys do not trigger a normal key down event
        // but instead are checked using the event alpha mask
        if (event_type == C.kCGEventFlagsChanged) {
            const flags = C.CGEventGetFlags(event_ref);
            return try switch (key_code) {
                C.kVK_CapsLock => .{
                    Button.CapsLock,
                    flags & C.kCGEventFlagMaskAlphaShift == C.kCGEventFlagMaskAlphaShift,
                },
                C.kVK_Shift, C.kVK_RightShift => .{
                    Button.Shift,
                    flags & C.kCGEventFlagMaskShift == C.kCGEventFlagMaskShift
                },
                C.kVK_Control, C.kVK_RightControl => .{
                    Button.Control,
                    flags & C.kCGEventFlagMaskControl == C.kCGEventFlagMaskControl,
                },
                C.kVK_Command, C.kVK_RightCommand => .{
                    Button.Command,
                    flags & C.kCGEventFlagMaskCommand == C.kCGEventFlagMaskCommand,
                },
                C.kVK_Option, C.kVK_RightOption => .{
                    Button.Option,
                    flags & C.kCGEventFlagMaskAlternate == C.kCGEventFlagMaskAlternate,
                },
                else => ButtonParseError.UnknownModifier,
            };
        }

        const btn = try switch (key_code) {
            C.kVK_ANSI_Q => Button.Q,
            C.kVK_ANSI_W => Button.W,
            C.kVK_ANSI_E => Button.E,
            C.kVK_ANSI_R => Button.R,
            C.kVK_ANSI_T => Button.T,
            C.kVK_ANSI_Y => Button.Y,
            C.kVK_ANSI_U => Button.U,
            C.kVK_ANSI_I => Button.I,
            C.kVK_ANSI_O => Button.O,
            C.kVK_ANSI_P => Button.P,
            C.kVK_ANSI_A => Button.A,
            C.kVK_ANSI_S => Button.S,
            C.kVK_ANSI_D => Button.D,
            C.kVK_ANSI_F => Button.F,
            C.kVK_ANSI_G => Button.G,
            C.kVK_ANSI_H => Button.H,
            C.kVK_ANSI_J => Button.J,
            C.kVK_ANSI_K => Button.K,
            C.kVK_ANSI_L => Button.L,
            C.kVK_ANSI_Z => Button.Z,
            C.kVK_ANSI_X => Button.X,
            C.kVK_ANSI_C => Button.C,
            C.kVK_ANSI_V => Button.V,
            C.kVK_ANSI_B => Button.B,
            C.kVK_ANSI_N => Button.N,
            C.kVK_ANSI_M => Button.M,
            C.kVK_ANSI_0 => Button.@"0",
            C.kVK_ANSI_1 => Button.@"1",
            C.kVK_ANSI_2 => Button.@"2",
            C.kVK_ANSI_3 => Button.@"3",
            C.kVK_ANSI_4 => Button.@"4",
            C.kVK_ANSI_5 => Button.@"5",
            C.kVK_ANSI_6 => Button.@"6",
            C.kVK_ANSI_7 => Button.@"7",
            C.kVK_ANSI_8 => Button.@"8",
            C.kVK_ANSI_9 => Button.@"9",
            C.kVK_Space => Button.Space,
            C.kVK_Return => Button.Return,
            C.kVK_Escape => Button.Escape,
            C.kVK_Delete => Button.Backspace,
            C.kVK_ForwardDelete => Button.Delete,
            C.kVK_Tab => Button.Tab,
            C.kVK_F1 => Button.F1,
            C.kVK_F2 => Button.F2,
            C.kVK_F3 => Button.F3,
            C.kVK_F4 => Button.F4,
            C.kVK_F5 => Button.F5,
            C.kVK_F6 => Button.F6,
            C.kVK_F7 => Button.F7,
            C.kVK_F8 => Button.F8,
            C.kVK_F9 => Button.F9,
            C.kVK_F10 => Button.F10,
            C.kVK_F11 => Button.F11,
            C.kVK_F12 => Button.F12,
            C.kVK_F20 => Button.F20,
            C.kVK_LeftArrow => Button.Left,
            C.kVK_UpArrow => Button.Up,
            C.kVK_DownArrow => Button.Down,
            C.kVK_RightArrow => Button.Right,
            C.kVK_PageDown => Button.PageDown,
            C.kVK_PageUp => Button.PageUp,
            C.kVK_Home => Button.Home,
            C.kVK_Function => Button.Function,
            C.kVK_ANSI_Grave => Button.Grave,
            C.kVK_ANSI_Quote => Button.Quote,
            C.kVK_ANSI_Backslash => Button.Backslash,
            C.kVK_ANSI_Semicolon => Button.Semicolon,
            C.kVK_ANSI_Comma => Button.Comma,
            C.kVK_ANSI_Period => Button.Period,
            C.kVK_ANSI_Slash => Button.Slash,
            C.kVK_ANSI_Equal => Button.Equals,
            C.kVK_ANSI_Minus => Button.Minus,
            C.kVK_ANSI_LeftBracket => Button.LeftBracket,
            C.kVK_ANSI_RightBracket => Button.RightBracket,
            else => error.UnknownKey,
        };

        return .{btn, event_type == C.kCGEventKeyDown};
    }

    /// Return the the kernel level HID code for given button which is
    /// different from the codes used inside the window server
    fn toHidCode(
        comptime self: @This(),
    ) u64 {
        // see: https://usb.org/sites/default/files/hut1_21.pdf
        // see: https://developer.apple.com/library/archive/technotes/tn2450/_index.html
        // NOTE: this currently only supports the keys used for the remapping to handle
        // the caps lock issue which is why this is comptime evaluated
        return comptime switch (self) {
            Button.CapsLock => 0x700000039,
            Button.F20 => 0x70000006F,
            else => unreachable,
        };
    }

    /// Return the window server compatible code for the button
    fn toCode(
        self: @This(),
    ) C.CGKeyCode {
        return switch (self) {
            Button.Q => C.kVK_ANSI_Q,
            Button.W => C.kVK_ANSI_W,
            Button.E => C.kVK_ANSI_E,
            Button.R => C.kVK_ANSI_R,
            Button.T => C.kVK_ANSI_T,
            Button.Y => C.kVK_ANSI_Y,
            Button.U => C.kVK_ANSI_U,
            Button.I => C.kVK_ANSI_I,
            Button.O => C.kVK_ANSI_O,
            Button.P => C.kVK_ANSI_P,
            Button.A => C.kVK_ANSI_A,
            Button.S => C.kVK_ANSI_S,
            Button.D => C.kVK_ANSI_D,
            Button.F => C.kVK_ANSI_F,
            Button.G => C.kVK_ANSI_G,
            Button.H => C.kVK_ANSI_H,
            Button.J => C.kVK_ANSI_J,
            Button.K => C.kVK_ANSI_K,
            Button.L => C.kVK_ANSI_L,
            Button.Z => C.kVK_ANSI_Z,
            Button.X => C.kVK_ANSI_X,
            Button.C => C.kVK_ANSI_C,
            Button.V => C.kVK_ANSI_V,
            Button.B => C.kVK_ANSI_B,
            Button.N => C.kVK_ANSI_N,
            Button.M => C.kVK_ANSI_M,
            Button.@"0" => C.kVK_ANSI_0,
            Button.@"1" => C.kVK_ANSI_1,
            Button.@"2" => C.kVK_ANSI_2,
            Button.@"3" => C.kVK_ANSI_3,
            Button.@"4" => C.kVK_ANSI_4,
            Button.@"5" => C.kVK_ANSI_5,
            Button.@"6" => C.kVK_ANSI_6,
            Button.@"7" => C.kVK_ANSI_7,
            Button.@"8" => C.kVK_ANSI_8,
            Button.@"9" => C.kVK_ANSI_9,
            Button.Space => C.kVK_Space,
            Button.Return => C.kVK_Return,
            Button.Escape => C.kVK_Escape,
            Button.Backspace => C.kVK_Delete,
            Button.Delete => C.kVK_ForwardDelete,
            Button.CapsLock => C.kVK_CapsLock,
            Button.Control => C.kVK_Shift,
            Button.Option => C.kVK_Option,
            Button.Shift => C.kVK_RightShift,
            Button.Command => C.kVK_Command,
            Button.Tab => C.kVK_Tab,
            Button.F1 => C.kVK_F1,
            Button.F2 => C.kVK_F2,
            Button.F3 => C.kVK_F3,
            Button.F4 => C.kVK_F4,
            Button.F5 => C.kVK_F5,
            Button.F6 => C.kVK_F6,
            Button.F7 => C.kVK_F7,
            Button.F8 => C.kVK_F8,
            Button.F9 => C.kVK_F9,
            Button.F10 => C.kVK_F10,
            Button.F11 => C.kVK_F11,
            Button.F12 => C.kVK_F12,
            Button.F20 => C.kVK_F20,
            Button.Left => C.kVK_LeftArrow,
            Button.Up, => C.kVK_UpArrow,
            Button.Down, => C.kVK_DownArrow,
            Button.Right, => C.kVK_RightArrow,
            Button.PageDown => C.kVK_PageDown,
            Button.PageUp => C.kVK_PageUp,
            Button.Home => C.kVK_Home,
            Button.Function => C.kVK_Function,
            Button.Quote => C.kVK_ANSI_Quote,
            Button.Backslash => C.kVK_ANSI_Backslash,
            Button.Semicolon => C.kVK_ANSI_Semicolon,
            Button.Comma => C.kVK_ANSI_Comma,
            Button.Period => C.kVK_ANSI_Period,
            Button.Slash => C.kVK_ANSI_Slash,
            Button.Equals => C.kVK_ANSI_Equal,
            Button.Minus => C.kVK_ANSI_Minus,
            Button.LeftBracket => C.kVK_ANSI_LeftBracket,
            Button.RightBracket => C.kVK_ANSI_RightBracket,
            Button.Grave => C.kVK_ANSI_Grave,
        };
    }
};

/// Representation of a distinct keyboard state holding which buttons are currently pressed
//  A thin wrapper over the BitSet to not expose the enum casting.
pub const KeyState = struct {
    buttons: std.StaticBitSet(@typeInfo(Button).@"enum".fields.len) = .initEmpty(),

    const Self = @This();

    /// initialized a KeyState where the provided buttons are considered pressed
    pub fn withButtons(buttons: []const Button) KeyState {
        var state = KeyState{};
        for (buttons) |btn| {
            state.buttons.toggle(@intFromEnum(btn));
        }
        return state;
    }

    pub fn isSet(self: *const Self, btn: Button) bool {
        return self.buttons.isSet(@intFromEnum(btn));
    }
    pub fn set(self: *Self, btn: Button) void {
        self.buttons.set(@intFromEnum(btn));
    }
    pub fn unset(self: *Self, btn: Button) void {
        self.buttons.unset(@intFromEnum(btn));
    }
    pub fn setValue(self: *Self, btn: Button, value: bool) void {
        self.buttons.setValue(@intFromEnum(btn), value);
    }
    pub fn eql(self: *const Self, other: Self) bool {
        return self.buttons.eql(other.buttons);
    }
};


/// The KeyAction describes what should be done with a user generated event
pub const HandlerAction = union(enum) {
    /// allow the user action to propagate through
    Accept: void,
    /// block the action making the press for example not register in the system
    Block: void,
    /// changes the latest event to the desiered one
    Change: Button,
};

/// A handler might fail indicating that a shutdown should occurr
/// which it can communicate by returning an error
pub const HandlerError = error{
    Failed,
};

/// A Handler is is called conditionally on the current keystate
/// and is able to execute it's callback using it's context
pub const Handler = struct {
    /// the keystate the handler want's to respond to
    on: KeyState,
    /// the callback with which the handler responds and is also
    /// able to stop the listener entirely when it errors
    do: *const fn(context: *const anyopaque) HandlerError!void,
    /// a context passed into it's callback
    context: *const anyopaque,
};

/// listener is the internal state of the event listener which
/// records both the current keyboard state and the handlers it
/// is task to call once a certain keystate is reached
const Listener = struct {
    /// a reference to the running event loop
    loop_ref: C.CFRunLoopRef,
    /// the current keyboard state
    keystate: KeyState,
    /// a list of handlers that want to be called
    handlers: []const Handler,
    /// records if the listener encountered an error
    /// this is used to return something from the loop
    err: ?HandlerError = null,
};

/// callback for the window server when new events come in
fn onPress(
    _: C.CGEventTapProxy,
    event_type: C.CGEventType,
    event_ref: C.CGEventRef,
    context: ?*anyopaque,
) callconv(.c) C.CGEventRef {
    std.debug.assert(context != null);
    // this listener is only able to handle the following events
    // and should not receive any other ones
    std.debug.assert(
        event_type == C.kCGEventKeyDown
        or event_type == C.kCGEventKeyUp
        or event_type == C.kCGEventFlagsChanged
    );

    // get the button together with it's state based on the event
    const btn, const pressed = Button.fromEvent(
        event_type,
        event_ref,
    ) catch |err| {
        // TODO: do not log in here?
        std.log.debug("could not obtain key from event due to: {}", .{err});
        return event_ref;
    };

    // we default to accepting the input
    var action: HandlerAction = .Accept;

    const listener: *Listener = @ptrCast(@alignCast(context.?));
    listener.keystate.setValue(btn, pressed);

    // check if any handler want's to respond to the current keystate
    for (listener.handlers) |handler| {
        if (listener.keystate.eql(handler.on)) {
            // call the handler and exit if it errors
            handler.do(handler.context) catch |err| {
                C.CFRunLoopStop(listener.loop_ref);
                listener.err = err;
                break;
            };
            // we do not want to forward the keys if the handler got triggered
            action = .Block;
            break;
        }
    }

    // tell the window server how the event should be dealt with
    return switch (action) {
        .Accept => event_ref,
        .Block => null,
        .Change => |new_button| {
            // NOTE: this cannot be used for modifiers
            C.CGEventSetIntegerValueField(
                event_ref, 
                C.kCGKeyboardEventKeycode,
                new_button.toCode(),
            );
            return event_ref;
        },
    };
}


/// start listening for user input
pub fn startListner(
    handlers: []const Handler,
) HandlerError!void {
    const loop_ref = C.CFRunLoopGetMain();

    var listener: Listener = .{
        .handlers = handlers,
        .keystate = KeyState{},
        .loop_ref = loop_ref,
    };

    const port_ref = C.CGEventTapCreate(
        // the HID event tap allows us to modify/block events before they even reach the window
        // server which allows the most granular control over where events flow
        C.kCGHIDEventTap, //C.kCGSessionEventTap,
        // we want to get the event as ealy as possible so that we can act upon the events
        // and maybe block events from passing though (consuming them)
        C.kCGHeadInsertEventTap,
        // as we not only want to observe events (TabOptionListenOnly) since we want to
        // update and block events from passing through the default option must be used.
        C.kCGEventTapOptionDefault,
        // we only want to know if something is being pressed and we do not care about how
        // long a key has been pressed etc.
        (
            C.CGEventMaskBit(C.kCGEventKeyDown)         // normal keys
            | C.CGEventMaskBit(C.kCGEventKeyUp)         // normal keys
            | C.CGEventMaskBit(C.kCGEventFlagsChanged)  // pure press of modifiers
        ),
        onPress,
        &listener,
    );
    defer C.CFRelease(port_ref);

    const loop_source_ref = C.CFMachPortCreateRunLoopSource(
        C.CFAllocatorGetDefault(),
        port_ref,
        0,
    );
    defer C.CFRelease(loop_source_ref);

    C.CFRunLoopAddSource(
        loop_ref,
        loop_source_ref, 
        C.kCFRunLoopCommonModes,
    );
    C.CGEventTapEnable(port_ref, true);
    defer C.CGEventTapEnable(port_ref, false);

    // this will run until the program is externally shutdown
    // or a unhandleable error occurrs like in a handler
    C.CFRunLoopRun();

    // we must assume that an error occurred otherwise
    // this code should not even run. We still check that
    // it is an error that we set explictly or if there is some
    // other unknown way of getting to this position
    if (listener.err) |err| {
        return err;
    }
}

/// remaps keys to others on the kernel level which manually can be undone using e.g.
///
/// ```sh
/// hidutil property --set '{"UserKeyMapping":[]}'
/// ```
pub fn remap(
    comptime from: Button,
    comptime to: Button,
) !void {
    const from_key: u64 = from.toHidCode();
    const to_key: u64 = to.toHidCode();

    const keys: [2]C.CFStringRef = .{
        types.newCFString("HIDKeyboardModifierMappingSrc"),
        types.newCFString("HIDKeyboardModifierMappingDst"),
    };
    defer {for (keys) |k| {C.CFRelease(k);}}

    const src_num = C.CFNumberCreate(
        C.kCFAllocatorDefault, 
        C.kCFNumberLongLongType,
        &from_key,
    );
    const to_num = C.CFNumberCreate(
        C.kCFAllocatorDefault, 
        C.kCFNumberLongLongType,
        &to_key,
    );
    const values: [2]C.CFNumberRef = .{ src_num, to_num };
    defer {for (values) |v| {C.CFRelease(v);}}
 
    const remap_item = C.CFDictionaryCreate(
        C.kCFAllocatorDefault,
        @constCast(@ptrCast(&keys)),
        @constCast(@ptrCast(&values)),
        keys.len,
        &C.kCFTypeDictionaryKeyCallBacks,
        &C.kCFTypeDictionaryValueCallBacks,
    ).?;
    defer C.CFRelease(remap_item);

    const arr = [_]C.CFTypeRef {remap_item};
    const remaps = C.CFArrayCreate(
        C.kCFAllocatorDefault,
        @constCast(@ptrCast(&arr)),
        arr.len, 
        &C.kCFTypeArrayCallBacks,
    ).?;
    defer C.CFRelease(remaps);

    const client_key = types.newCFString("UserKeyMapping");
    defer C.CFRelease(client_key);
 
    const system = C.IOHIDEventSystemClientCreateSimpleClient(C.kCFAllocatorDefault).?;
    defer C.CFRelease(system);

    const services = C.IOHIDEventSystemClientCopyServices(@ptrCast(system)).?;
    defer C.CFRelease(services);

    for (0..@intCast(C.CFArrayGetCount(services))) |i| {
        const service: C.IOHIDServiceClientRef = @constCast(@ptrCast(C.CFArrayGetValueAtIndex(
           @constCast(@ptrCast(services)),
           @intCast(i),
        ).?));

        // we are looking for hid devices that are keyboards
        if (C.IOHIDServiceClientConformsTo(
            service, 
            C.kHIDPage_GenericDesktop, 
            C.kHIDUsage_GD_Keyboard,
        ) == 1) {
            // TODO: this errors for ALL devices with 'KERN_INVALID_ADDRESS' ... but it works
            // on the actual keyboard regardless. How can I check if it actually worked
            _ = C.IOHIDServiceClientSetProperty(
                service, 
                client_key,
                remaps,
            );
        }
    }
}

/// moves the cursor to the specified location
pub fn moveMouse(x: f64, y: f64) void {
    const event = C.CGEventCreateMouseEvent(
        null,
        C.kCGEventMouseMoved,
        C.CGPointMake(x, y),
        C.kCGMouseButtonLeft // Ignored for mouse move
    ).?;
    defer C.CFRelease(event);

    // Post the event to the system
    C.CGEventPost(C.kCGHIDEventTap, event);
}
