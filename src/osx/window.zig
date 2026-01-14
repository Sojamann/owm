///! handling of applications and windows

const std = @import("std");
const objc = @import("objc");

const C = @import("c.zig").C;
const types = @import("types.zig");


/// Position and Size of some object in the virual screen
/// where the position can also be negative for monitors
/// being left of the main monitor for example.
pub const Bounds = C.CGRect;

/// An element returned from listApplications containing a minimal set
/// of information which can be used to instantiate a Application instance
pub const ListApplicationItem = struct {
    /// pid of the process that owns windows
    pid: c_int = 0,
    /// name of the application (must be freed)
    name: []u8 = undefined,
};

/// Errors that can be encountered when listing apps
const ListApplicationsError = error {
    /// the list window call failed which might happen when permissions were
    /// removed during execution of this process.
    CouldNotList,
} || std.mem.Allocator.Error;

/// Returns a list of running graphical applications.
/// ALLOC: The caller must free the memory
/// NOTE: that a application may have none or multiple windows which is disregarded here.
pub fn listApplications(ally: std.mem.Allocator) ListApplicationsError![]ListApplicationItem {
    const windows = C.CGWindowListCopyWindowInfo(
        C.kCGWindowListExcludeDesktopElements,
        C.kCGNullWindowID,
    ) orelse {
        return ListApplicationsError.CouldNotList;
    };
    defer C.CFRelease(windows);

    // prepare the keys used to index into the property dictionary we receive once per window.
    // all dictionaries have these properties which is why lookup should never fail
    const win_owner_name_attr = types.newCFString("kCGWindowOwnerName");
    defer C.CFRelease(win_owner_name_attr);
    const win_owner_pid_attr = types.newCFString("kCGWindowOwnerPID");
    defer C.CFRelease(win_owner_pid_attr);
    
    const window_count: usize = @intCast(C.CFArrayGetCount(windows));
    var apps = try ally.alloc(ListApplicationItem, window_count);
    errdefer ally.free(apps);

    // even if the OS gives us all windows we only care about the owners -> the app
    var number_of_apps: usize = 0;
window_loop:
    for (0..window_count) |window_number| {
        var app = ListApplicationItem{};

        // obtain all window attributes
        const window_attributes: C.CFDictionaryRef = @ptrCast(C.CFArrayGetValueAtIndex(
            windows,
            @intCast(window_number),
        ));

        // get the pid
        const cf_owner_pid: C.CFNumberRef = @ptrCast(C.CFDictionaryGetValue(
            window_attributes, 
            win_owner_pid_attr,
        ));
        std.debug.assert(1 == C.CFNumberGetValue(
            cf_owner_pid,
            C.CFNumberGetType(cf_owner_pid),
            &app.pid,
        ));

        // We only want to store each pid once but an application might have
        // multiple windows which we can inspect but this is not what this function
        // does as we only want to return the applications that OWN the windows.
        for (apps) |other| {
            if (app.pid == other.pid) {
                continue :window_loop;
            }
        }

        // get the name of the application that owns the window
        const cf_owner_str: C.CFStringRef = @ptrCast(C.CFDictionaryGetValue(
            window_attributes, 
            win_owner_name_attr,
        ));
        const cf_owner_str_len: usize = @intCast(C.CFStringGetLength(cf_owner_str));
        app.name = try ally.alloc(u8, cf_owner_str_len+1);
        errdefer ally.free(app.name);
        std.debug.assert(1 == C.CFStringGetCString(
            cf_owner_str,
            app.name.ptr,
            @intCast(app.name.len),
            C.kCFStringEncodingUTF8,
        ));
        app.name = app.name[0..app.name.len-1]; // cut away the 0 terminator

        // insert it in the array
        apps[number_of_apps] = app;
        number_of_apps += 1;
    }
    return apps[0..number_of_apps];
}

/// Opening an application can lead either to a standard accessibility or when the app
/// has no windows. The application reference could still be obtained but no window reference
/// which makes no sense for managing windows.
const ApplicationOpeningError = error{
    /// the application has no windows to control
    NoWindow,
    /// the application could not be found (it might already be closed in the meantime)
    NotFound,
} || types.AXError;

/// The Application allows easy manipulation of (currently) one of it's windows
pub const Application = struct {
    /// a reference to the application
    ref: C.AXUIElementRef,
    /// a reference to a window of the app
    focused_window: C.AXUIElementRef,

    /// instatiate a Application from a pid which is supposed to be the owner PID
    /// of the windows one can for example obtain using the listApplications call
    pub fn fromPid(pid: c_int) ApplicationOpeningError!Application {
        // since the process is trusted getting a handle should not fail
        const app_ref = C.AXUIElementCreateApplication(@intCast(pid))
            orelse return ApplicationOpeningError.NotFound;

        const focused_attribute = types.newCFString("AXFocusedWindow");
        defer C.CFRelease(focused_attribute);

        var focused_window: C.AXUIElementRef = null;
        types.checkAXError(C.AXUIElementCopyAttributeValue(
            app_ref,
            focused_attribute,
            @ptrCast(&focused_window),
        )) catch |err| switch (err) {
            // this error comes if the application exists but has no open windows
            types.AXError.NoValue => return error.NoWindow,
            else => return err,
        };
        return .{
            .ref = app_ref,
            .focused_window = focused_window,
        };
    }

    /// Get a Application handle for the app which currently has keyboard focus
    pub fn getFocused() !Application {
        // NOTE: this is NOT the classical user facing workspace 'multiple desktops'
        const workspace = objc.getClass("NSWorkspace").?.msgSend(
            objc.Object,
            "sharedWorkspace",
            .{},
        );
        const frontmost = workspace.msgSend(
            objc.Object,
            "frontmostApplication",
            .{},
        );
        const pid = frontmost.msgSend(
            C.pid_t,
            "processIdentifier",
            .{},
        );
        return Application.fromPid(pid);
    }

    /// Give focus to the window
    pub fn focus(self: *const @This()) types.AXError!void {
        const front_most_attr = types.newCFString("AXFrontmost");
        defer C.CFRelease(front_most_attr);
        try types.checkAXError(C.AXUIElementSetAttributeValue(
            self.ref,
            front_most_attr,
            C.kCFBooleanTrue,
        ));
    }

    // Retrieve the location and size of the window 
    pub fn getBounds(self: *const @This()) types.AXError!Bounds {
        // prepare the position attribute for retrieval of it's property
        const pos_attr = types.newCFString("AXPosition"); // C.kAXPositionAttribute
        defer C.CFRelease(pos_attr);

        // https://developer.apple.com/documentation/coregraphics/kcgwindowbounds
        var pos_value: C.AXValueRef = null;

        try types.checkAXError(C.AXUIElementCopyAttributeValue(
            self.focused_window,
            pos_attr,
            &pos_value,
        ));
        defer C.CFRelease(pos_value);

        // convert to a point
        var pos: C.CGPoint = .{};
        std.debug.assert(1 == C.AXValueGetValue(pos_value, C.kAXValueCGPointType, @ptrCast(&pos)));

        // prepare the size attribute for retrieval of it's property
        const size_attr = types.newCFString("AXSize"); // C.kAXSizeAttribute
        defer C.CFRelease(size_attr);

        // https://developer.apple.com/documentation/coregraphics/kcgwindowbounds
        var size_value: C.AXValueRef = null;
        try types.checkAXError(C.AXUIElementCopyAttributeValue(
            self.focused_window,
            size_attr,
            &size_value,
        ));
        defer C.CFRelease(size_value);

        // convert to a size value
        var size: C.CGSize = .{};
        std.debug.assert(1 == C.AXValueGetValue(size_value, C.kAXValueCGSizeType, @ptrCast(&size)));

        return .{.origin = pos, .size = size};
    }
    
    /// moves the window to the position and adjusts it's size
    pub fn move(
        self: *const @This(),
        x: f64,
        y: f64,
        width: f64,
        height: f64,
    ) !void {
        var pos: C.CGPoint = .{ .x = x, .y = y };
        const pos_value = C.AXValueCreate(C.kAXValueCGPointType, &pos).?;
        defer C.CFRelease(pos_value);

        var size: C.CGSize = .{ .width = width, .height = height };
        const size_value = C.AXValueCreate(C.kAXValueCGSizeType, &size).?;
        defer C.CFRelease(size_value);

        // prepare the attributes for the dictionary
        const pos_attr = types.newCFString("AXPosition"); // axui.kAXPositionAttribute
        defer C.CFRelease(pos_attr);
        const size_attr = types.newCFString("AXSize"); // axui.kAXPositionAttribute
        defer C.CFRelease(size_attr);

        try types.checkAXError(C.AXUIElementSetAttributeValue(
            self.focused_window,
            pos_attr,
            pos_value,
        ));

        try types.checkAXError(C.AXUIElementSetAttributeValue(
            self.focused_window,
            size_attr,
            size_value,
        ));
    }


    /// free the references held to the application and window
    pub fn deinit(self: *const @This()) void {
        defer C.CFRelease(self.ref);
        defer C.CFRelease(self.focused_window);
    }
};


/// retrives the size of the screen that contains the mouse as it is deemed active
pub fn getActiveScreenSize() types.CGError!Bounds {
    // create a fake event so that the event location (the current position) can be retrieved
    const event: C.CGEventRef = C.CGEventCreate(null);
    defer C.CFRelease(event);
    const cursor_pos = C.CGEventGetLocation(event);

    var displays  = std.mem.zeroes([1]C.CGDirectDisplayID);
    var num_displays: u32 = 0;

    // just like i3 the active screen is the one that contains the mouse
    try types.checkCGError(C.CGGetDisplaysWithPoint(
        cursor_pos,
        displays.len,
        &displays,
        &num_displays,
    ));
    std.debug.assert(num_displays > 0);

    return C.CGDisplayBounds(displays[0]);
}

/// function used to sort a list of Bounds by their X coordinate
fn compareCGRect(_: usize, left: Bounds, right: Bounds) bool {
    return left.origin.x < right.origin.x;
}

/// returns a by x-coordinates sorted slice of screen
/// bounds with at most buff.len many screens
pub fn getScreens(buff: []Bounds) types.CGError![]Bounds {
    var display_count: u32 = 0;
    var display_ids: [64]u32 = undefined;
    // ensures that the display_ids buffer is large enough
    // for the subsequent operations and 64 screens should be plenty ...
    std.debug.assert(buff.len <= display_ids.len);

    try types.checkCGError(C.CGGetOnlineDisplayList(
        // the assertion ensures, that maxDisplays will fit
        @intCast(buff.len),
        &display_ids,
        &display_count,
    ));

    for (display_ids[0..display_count], 0..) |display_id, i| {
        const bounds = C.CGDisplayBounds(display_id);
        buff[i] = bounds;
    }

    const screens = buff[0..display_count];
    const context: usize = 0;
    std.mem.sort(
        C.CGRect,
        screens,
        context,
        compareCGRect,
    );

    return screens;
}

