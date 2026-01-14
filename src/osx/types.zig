///! types and functions to Zigify the OSX Apis

const std = @import("std");
const C = @import("c.zig").C;

/// returns a allocated NON-NULL CFStringRef
pub fn newCFString(value: [:0]const u8) *const C.struct___CFString {
    // if we as window manager cannot allocate a (probably) small string then we might as well
    // crash to relieve some memory as further operation do not make sense anymore anyways
    return C.CFStringCreateWithCString(
        C.kCFAllocatorDefault,
        value,
        C.kCFStringEncodingUTF8,
    ) orelse @panic("OOM");
}

/// an error set covering all cases of the enum defined in C.GCError
pub const CGError = error {
    Failure,
    IllegalArgument,
    InvalidConnection,
    InvalidContext,
    CannotComplete,
    NotImplemented,
    RangeCheck,
    TypeCheck,
    InvalidOperation,
    NoneAvailable,
};

/// converts a CGError returned from the OSX apis to a proper error set
pub fn checkCGError(value: C.CGError) CGError!void {
    return switch(value) {
        C.kCGErrorSuccess => {},
        C.kCGErrorFailure => CGError.Failure,
        C.kCGErrorIllegalArgument => CGError.IllegalArgument,
        C.kCGErrorInvalidConnection => CGError.InvalidConnection,
        C.kCGErrorInvalidContext => CGError.InvalidContext,
        C.kCGErrorCannotComplete => CGError.CannotComplete,
        C.kCGErrorNotImplemented => CGError.NotImplemented,
        C.kCGErrorRangeCheck => CGError.RangeCheck,
        C.kCGErrorTypeCheck => CGError.TypeCheck,
        C.kCGErrorInvalidOperation => CGError.InvalidOperation,
        C.kCGErrorNoneAvailable => CGError.NoneAvailable,
        else => @panic("unknown error"),
    };
}

/// an error set covering all cases of the enum defined in C.AXError
pub const AXError = error{
    Failure,
    IllegalArgument,
    InvalidUIElement,
    InvalidUIElemenentObserver,
    CannotComplete,
    AttributeUnsupported,
    ActionUnsupported,
    NotificationUnsupported,
    NotImplemented,
    NotificationAlreadyRegistered,
    NotificationNotRegistered,
    ApiDisabled,
    NoValue,
    ParamterizedAttributeUnsupported,
    NotEnoughPrecision,
};

/// converts a AXError returned from the OSX apis to a proper error set
pub fn checkAXError(value: C.AXError) AXError!void {
    return switch (value) {
        C.kAXErrorSuccess => {},
        C.kAXErrorFailure => AXError.Failure,
        C.kAXErrorIllegalArgument => AXError.IllegalArgument,
        C.kAXErrorInvalidUIElement => AXError.InvalidUIElement,
        C.kAXErrorInvalidUIElementObserver => AXError.InvalidUIElemenentObserver,
        C.kAXErrorCannotComplete => AXError.CannotComplete,
        C.kAXErrorAttributeUnsupported => AXError.AttributeUnsupported,
        C.kAXErrorActionUnsupported => AXError.ActionUnsupported,
        C.kAXErrorNotificationUnsupported => AXError.NotificationUnsupported,
        C.kAXErrorNotImplemented => AXError.NotImplemented,
        C.kAXErrorNotificationAlreadyRegistered => AXError.NotificationAlreadyRegistered,
        C.kAXErrorNotificationNotRegistered => AXError.NotificationNotRegistered,
        C.kAXErrorAPIDisabled => AXError.ApiDisabled,
        C.kAXErrorNoValue => AXError.NoValue,
        C.kAXErrorParameterizedAttributeUnsupported => AXError.ParamterizedAttributeUnsupported,
        C.kAXErrorNotEnoughPrecision => AXError.NotEnoughPrecision,
        else => @panic("unknown error"),
    };
}

// pub fn checkKernelError(code: c_int) KernelError!void {
//     return switch (code) {
//         C.kIOReturnSuccess => {},
//         C.KERN_INVALID_ADDRESS => std.debug.print("invalid address", .{}),
//         C.KERN_PROTECTION_FAILURE => std.debug.print("KERN_PROTECTION_FAILURE", .{}),
//         C.KERN_INVALID_ARGUMENT => std.debug.print("KERN_INVALID_ARGUMENT", .{}),
//         C.KERN_FAILURE => std.debug.print("KERN_FAILURE", .{}),
//         C.KERN_NO_ACCESS => std.debug.print("KERN_NO_ACCESS", .{}),
//         C.KERN_MEMORY_FAILURE => std.debug.print("KERN_MEMORY_FAILURE", .{}),
//         C.KERN_MEMORY_ERROR => std.debug.print("KERN_MEMORY_ERROR", .{}),
//         C.KERN_ALREADY_IN_SET => std.debug.print("KERN_ALREADY_IN_SET", .{}),
//         C.KERN_NOT_IN_SET => std.debug.print("KERN_NOT_IN_SET", .{}),
//         C.KERN_NAME_EXISTS => std.debug.print("KERN_NAME_EXISTS", .{}),
//         C.KERN_ABORTED => std.debug.print("KERN_ABORTED", .{}),
//         C.KERN_INVALID_NAME => std.debug.print("KERN_INVALID_NAME", .{}),
//         C.KERN_INVALID_TASK => std.debug.print("KERN_INVALID_TASK", .{}),
//         C.KERN_INVALID_RIGHT => std.debug.print("KERN_INVALID_RIGHT", .{}),
//         C.KERN_INVALID_VALUE => std.debug.print("KERN_INVALID_VALUE", .{}),
//         C.KERN_UREFS_OVERFLOW => std.debug.print("KERN_UREFS_OVERFLOW", .{}),
//         C.KERN_INVALID_CAPABILITY => std.debug.print("KERN_INVALID_CAPABILITY", .{}),
//         C.KERN_RIGHT_EXISTS => std.debug.print("KERN_RIGHT_EXISTS", .{}),
//         C.KERN_INVALID_HOST => std.debug.print("KERN_INVALID_HOST", .{}),
//         C.KERN_MEMORY_PRESENT => std.debug.print("KERN_MEMORY_PRESENT", .{}),
//         C.KERN_MEMORY_DATA_MOVED => std.debug.print("KERN_MEMORY_DATA_MOVED", .{}),
//         C.KERN_MEMORY_RESTART_COPY => std.debug.print("KERN_MEMORY_RESTART_COPY", .{}),
//         C.KERN_INVALID_PROCESSOR_SET => std.debug.print("KERN_INVALID_PROCESSOR_SET", .{}),
//         C.KERN_POLICY_LIMIT => std.debug.print("KERN_POLICY_LIMIT", .{}),
//         C.KERN_INVALID_POLICY => std.debug.print("KERN_INVALID_POLICY", .{}),
//         C.KERN_INVALID_OBJECT => std.debug.print("KERN_INVALID_OBJECT", .{}),
//         C.KERN_ALREADY_WAITING => std.debug.print("KERN_ALREADY_WAITING", .{}),
//         C.KERN_DEFAULT_SET => std.debug.print("KERN_DEFAULT_SET", .{}),
//         C.KERN_EXCEPTION_PROTECTED => std.debug.print("KERN_EXCEPTION_PROTECTED", .{}),
//         C.KERN_INVALID_LEDGER => std.debug.print("KERN_INVALID_LEDGER", .{}),
//         C.KERN_INVALID_MEMORY_CONTROL => std.debug.print("KERN_INVALID_MEMORY_CONTROL", .{}),
//         C.KERN_INVALID_SECURITY => std.debug.print("KERN_INVALID_SECURITY", .{}),
//         C.KERN_NOT_DEPRESSED => std.debug.print("KERN_NOT_DEPRESSED", .{}),
//         C.KERN_TERMINATED => std.debug.print("KERN_TERMINATED", .{}),
//         C.KERN_NOT_SUPPORTED => std.debug.print("KERN_NOT_SUPPORTED", .{}),
//         C.KERN_OPERATION_TIMED_OUT => std.debug.print("KERN_OPERATION_TIMED_OUT", .{}),
//         C.KERN_CODESIGN_ERROR => std.debug.print("KERN_CODESIGN_ERROR", .{}),
//         C.KERN_POLICY_STATIC => std.debug.print("KERN_POLICY_STATIC", .{}),
//         C.KERN_INSUFFICIENT_BUFFER_SIZE => std.debug.print("KERN_INSUFFICIENT_BUFFER_SIZE", .{}),
//         C.KERN_DENIED => std.debug.print("KERN_DENIED", .{}),
//         C.KERN_NOT_FOUND => std.debug.print("KERN_NOT_FOUND", .{}),
//         else => unreachable,
//     }
// }
//
