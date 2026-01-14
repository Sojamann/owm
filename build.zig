const std = @import("std");

const IDENTIFIER = "com.sojamann.owm";

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("osx", .{
        .root_source_file = b.path("src/osx.zig"),
        .target = target,
        .link_libc = true,
        .imports = &.{
            .{
                .name = "objc",
                .module = b.dependency("zig_objc", .{
                    .target = target,
                    .optimize = optimize,
                }).module("objc"),
            },
        },
    });
    mod.linkFramework("ApplicationServices", .{});
    mod.linkFramework("CoreGraphics", .{});
    mod.linkFramework("CoreFoundation", .{});
    mod.linkFramework("Carbon", .{});
    mod.linkFramework("AppKit", .{}); // needed to access NSScreen
    mod.linkFramework("IOKit", .{}); // TODO: is this still needed??

    const exe = b.addExecutable(.{
        .name = "owm",
        // TODO: get that from somewhere else
        .version = try std.SemanticVersion.parse("0.0.0"),
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{
                    .name = "osx",
                    .module = mod,
                }
            },
        }),
    });
    b.installArtifact(exe);

    // create the necessary file structure so that Apple considers it a App
    const app_bundle = createAppBundle(b, exe);

    // sign the App otherwise Apple won't trust it
    const signed_bundle, const sign_step = signBundle(b, app_bundle);
    b.installDirectory(.{
        .source_dir = signed_bundle,
        .install_dir = .prefix,
        .install_subdir = "owm.app",
    });
    b.getInstallStep().dependOn(&sign_step.step);
    
    // create the launchd service object that the user can install
    const launchd_step = createLaunchdService(b);
    b.getInstallStep().dependOn(&launchd_step.step);

    // make `zig build run` execute
    addRunStep(b, exe);
}

fn createAppBundle(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
) *std.Build.Step.WriteFile {
    const wf = b.addWriteFiles();
    wf.step.dependOn(&exe.step);

    _ = wf.addCopyFile(
        exe.getEmittedBin(),
        b.fmt("Contents/MacOS/{s}", .{exe.out_filename}),
    );
    _ = wf.addCopyFile(
       b.path("assets/Owm.icns"),
       "Contents/Resources/Owm.icns",
    );
    const version = if (exe.version) |version|
        version
    else
        std.SemanticVersion{.major = 0, .minor = 0, .patch = 0}
    ;
    _ = wf.add(
        "Contents/Info.plist", 
        b.fmt(
            \\<?xml version="1.0" encoding="UTF-8"?>
            \\<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            \\<plist version="1.0">
            \\<dict>
            \\    <key>CFBundleExecutable</key>
            \\    <string>{s}</string>
            \\    <key>CFBundleIdentifier</key>
            \\    <string>com.sojamann.owm</string>
            \\    <key>CFBundleName</key>
            \\    <string>owm</string>
            \\    <key>CFBundleIconFile</key>
            \\    <string>Owm</string>
            \\    <key>CFBundlePackageType</key>
            \\    <string>APPL</string>
            \\    <key>CFBundleShortVersionString</key>
            \\    <string>{f}</string>
            \\    
            \\    <key>NSAccessibilityUsageDescription</key>
            \\    <string>owm uses accessibility to move windows and interact with UI elements.</string>

            \\    <key>NSInputMonitoringUsageDescription</key>
            \\    <string>owm needs to listen for global keyboard shortcuts to trigger actions.</string>
            \\</dict>
            \\</plist>
            ,
            .{exe.out_filename, version},
        ),
    );

    return wf;
}

fn signBundle(
    b: *std.Build,
    app_bundle: *std.Build.Step.WriteFile,
) struct{std.Build.LazyPath, *std.Build.Step.Run} {
    // we dont want to modify the the result of the previous step
    const wf = b.addWriteFiles();
    wf.step.dependOn(&app_bundle.step);

    const dir = wf.addCopyDirectory(
        app_bundle.getDirectory(),
        "",
        .{},
    );

    const cmd = b.addSystemCommand(&.{
        "codesign",
        "--force",
        "--options", "runtime",
        "--sign", "-",
    });
    cmd.addFileArg(dir);

    cmd.step.dependOn(&wf.step);
    return .{wf.getDirectory(), cmd};
}

fn createLaunchdService(b: *std.Build) *std.Build.Step.InstallFile {
    const home = std.posix.getenv("HOME") orelse @panic("'HOME' environment variable not found");

    const wf = b.addWriteFiles();
    const svc =  wf.add(
        "com.sojamann.com.plist",
        b.fmt(
            \\ <?xml version="1.0" encoding="UTF-8"?>
            \\ <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            \\ <plist version="1.0">
            \\ <dict>
            \\     <key>Label</key>
            \\     <string>{s}</string>
            \\ 
            \\     <key>ProgramArguments</key>
            \\     <array>
            \\     <string>open</string>
            \\     <string>-W</string>
            \\     <string>{s}/Applications/owm.app</string>
            \\     </array>
            \\ 
            \\     <key>RunAtLoad</key>
            \\     <true/>
            \\ 
            \\     <key>StandardOutPath</key>
            \\     <string>{s}/Library/Logs/{s}/out</string>
            \\ 
            \\     <key>StandardErrorPath</key>
            \\     <string>{s}/Library/Logs/{s}/err</string>
            \\ </dict>
            \\ </plist>
            ,
            .{
                IDENTIFIER,
                home,
                home,
                IDENTIFIER,
                home,
                IDENTIFIER,
            }
        )
    );

    const install_step = b.addInstallFile(
        svc,
        IDENTIFIER ++ ".plist",
    );
    install_step.step.dependOn(&wf.step);
    return install_step;
}

fn addRunStep(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
) void {
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);

    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
