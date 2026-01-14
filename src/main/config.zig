const std = @import("std");

const osx = @import("osx");
const win = osx.window;
const input = osx.input;

const actions = @import("actions.zig");
const layouts = @import("layouts.zig");

pub const Config = struct {
    actions: []struct {
        when: []input.Button,
        do: actions.Action,
    },

    layouts: []struct{
        when: []input.Button,
        do: union(enum) {
            maximize: []u8,
            split: struct {
                left: []u8,
                right: []u8,
            },
        },
    },
};

pub fn readConfig(ally: std.mem.Allocator) !std.json.Parsed(Config) {
    // we only ever run on mac so there is no reason to use a different function
    const home = std.posix.getenv("HOME");

    var pathbuff: [std.posix.PATH_MAX]u8 = undefined;
    const path = 
        if (home) |h| 
            // this cannot fail unless the USER variable got messed with
            std.fmt.bufPrint(
                &pathbuff, 
                "{s}/.config/owm/config.json", 
                .{h},
            ) catch @panic("invalid HOME variable")
        else
            "config.json";

    std.log.debug("loading config file: {s}", .{path});
    
    var filebuff: [4096]u8 = undefined;
    const content = try std.fs.cwd().readFile(path, &filebuff);

    const parse_result = try std.json.parseFromSlice(
        Config, 
        ally, 
        content, 
        .{},
    );
    return parse_result;
}

