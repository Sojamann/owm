//! since it is recommended to cImport only once, it is done here
//! to export this one field.
pub const C = @cImport({
    @cInclude("ApplicationServices/ApplicationServices.h");
    @cInclude("CoreFoundation/CoreFoundation.h");
    @cInclude("CoreGraphics/CoreGraphics.h");
    @cInclude("Carbon/Carbon.h");
    @cInclude("IOKit/IOKitLib.h");
    @cInclude("IOKit/hidsystem/IOHIDEventSystemClient.h");
    @cInclude("IOKit/hidsystem/IOHIDServiceClient.h");
    @cInclude("IOKit/hid/IOHIDUsageTables.h");
});

