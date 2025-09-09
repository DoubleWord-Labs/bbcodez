pub const std_options: Options = .{
    .log_level = Level.err,
};

var config = struct {
    input: ?[]const u8 = null,
    output: ?[]const u8 = null,
}{};

const StreamSource = enum {
    file,
    stdin,
};

const StreamDestination = enum {
    file,
    stdout,
};

pub fn main() !void {
    var r = try cli.AppRunner.init(std.heap.page_allocator);

    const app = cli.App{
        .command = cli.Command{
            .name = "bbcodez",
            .options = try r.allocOptions(&.{
                .{
                    .long_name = "input",
                    .help = "input file",
                    .value_ref = r.mkRef(&config.input),
                },
                .{
                    .long_name = "output",
                    .help = "output file",
                    .value_ref = r.mkRef(&config.output),
                },
            }),
            .target = cli.CommandTarget{
                .action = cli.CommandAction{ .exec = processConfig },
            },
        },
    };
    return r.run(&app);
}

fn processConfig() !void {
    var input_file: File = undefined;
    defer input_file.close();

    var output_file: File = undefined;
    defer output_file.close();

    const input_source: StreamSource = if (config.input == null) .stdin else .file;
    const output_source: StreamDestination = if (config.output == null) .stdout else .file;

    switch (input_source) {
        .file => {
            input_file = try cwd().openFile(config.input.?, .{});
        },
        .stdin => {
            input_file = std.fs.File.stdin();
        },
    }

    switch (output_source) {
        .file => {
            output_file = try cwd().openFile(config.output.?, .{});
        },
        .stdout => {
            output_file = std.fs.File.stdout();
        },
    }

    var in_buf: [1024]u8 = undefined;
    var out_buf: [1024]u8 = undefined;

    var reader = input_file.reader(&in_buf).interface;
    var writer = output_file.writer(&out_buf).interface;

    var arena = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const document = try lib.load(allocator, &reader, .{});
    defer document.deinit();

    try renderDocument(allocator, document, &writer, .{});
}

const cwd = std.fs.cwd;
const renderDocument = lib.fmt.md.renderDocument;

const File = std.fs.File;
const AnyReader = std.io.AnyReader;
const AnyWriter = std.io.AnyWriter;
const ArenaAllocator = std.heap.ArenaAllocator;
const Level = std.log.Level;
const Options = std.Options;

const std = @import("std");
const cli = @import("cli");
const lib = @import("lib");
