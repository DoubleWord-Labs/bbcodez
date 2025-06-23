pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_bbcpp = b.dependency("bbcpp", .{});

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const translate_bbcpp = b.addTranslateC(.{
        .root_source_file = lib_bbcpp.builder.path("lib/bbcpp_c.h"),
        .target = target,
        .optimize = optimize,
    });

    const mod_bbcpp = b.createModule(.{
        .root_source_file = translate_bbcpp.getOutput(),
        .target = target,
        .optimize = optimize,
    });

    lib_mod.addCSourceFiles(.{
        .root = lib_bbcpp.builder.path("lib"),
        .files = &.{
            "bbcpputils.cpp",
            "BBDocument.cpp",
            "bbcpp_c.cpp",
        },
    });
    lib_mod.addIncludePath(lib_bbcpp.builder.path("lib"));
    lib_mod.addImport("bbcpp", mod_bbcpp);

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "bbcodez",
        .root_module = lib_mod,
    });
    lib.linkLibC();
    lib.linkLibCpp();

    var install = b.addInstallArtifact(lib, .{});

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Generate documentation");
    docs_step.dependOn(&install_docs.step);
    install.step.dependOn(docs_step);
}

const std = @import("std");
