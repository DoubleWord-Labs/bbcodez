pub const WriteElementFunction = *const fn (node: Node, ctx: ?*anyopaque) anyerror!bool;

pub const WriteContext = struct {
    allocator: Allocator,
    document: Document,
    writer: std.io.AnyWriter,
    write_element_fn: ?WriteElementFunction = null,
    user_data: ?*anyopaque = null,
};

pub const Options = struct {
    write_element_fn: ?WriteElementFunction = null,
    user_data: ?*anyopaque = null,
};

pub const MarkdownElement = enum {
    bold,
    italic,
    link,
    email,
    code,
    horizontalRule,
    blockquote,
    list,
    listItem,
    underline,
    noOp,
};

const element_map = std.StaticStringMap(MarkdownElement).initComptime(&.{
    .{ "b", .bold },
    .{ "i", .italic },
    .{ "url", .link },
    .{ "email", .email },
    .{ "code", .code },
    .{ "line", .horizontalRule },
    .{ "hr", .horizontalRule },
    .{ "quote", .blockquote },
    .{ "list", .list },
    .{ "*", .listItem },
    .{ "u", .underline },
});

pub fn renderDocument(allocator: Allocator, doc: Document, writer: std.io.AnyWriter, options: Options) !void {
    var ctx: WriteContext = .{
        .allocator = allocator,
        .document = doc,
        .writer = writer,
        .write_element_fn = options.write_element_fn,
        .user_data = options.user_data,
    };

    try render(doc.root, &ctx);
}

pub fn render(root: Node, ctx: *WriteContext) !void {
    var it = root.iterator();

    while (it.next()) |node| {
        if (ctx.write_element_fn) |cb| {
            if (try cb(node, @ptrCast(ctx))) {
                continue;
            }
        }

        switch (node.type) {
            .element => {
                const markdown_element = try getMarkdownElement(node, ctx);

                try writeElement(node, markdown_element, ctx);
            },
            .text => try writeTextElement(node, ctx),
            .document => {},
        }
    }
}

fn getMarkdownElement(node: Node, _: *WriteContext) !MarkdownElement {
    const name = try node.getName();
    return element_map.get(name) orelse .noOp;
}

pub fn writeElement(node: Node, element: MarkdownElement, ctx: *WriteContext) anyerror!void {
    switch (element) {
        .bold => try writeBoldElement(node, ctx),
        .italic => try writeItalicElement(node, ctx),
        .link => try writeLinkElement(node, ctx),
        .email => try writeEmailElement(node, ctx),
        .code => try writeCodeElement(node, ctx),
        .blockquote => try writeBlockQuoteElement(node, ctx),
        .horizontalRule => try writeHorizontalRuleElement(node, ctx),
        .list => try writeListElement(node, ctx),
        .listItem => try writeListItemElement(node, ctx),
        .underline => try writeUnderlineElement(node, ctx),
        .noOp => try writeNoOpElement(node, ctx),
    }
}

pub fn writeUnderlineElement(node: Node, ctx: *WriteContext) anyerror!void {
    try render(node, ctx);
}

pub fn writeNoOpElement(node: Node, ctx: *WriteContext) anyerror!void {
    // output the bbcode then render children
    try ctx.writer.writeAll(node.raw);
    try render(node, ctx);

    logger.warn("Unsupported bbcode tag: {s}", .{node.raw});
}

pub fn writeListElement(node: Node, ctx: *WriteContext) anyerror!void {
    // bbcode lists will be nested pairs of [*] and text
    // because [*] don't have closing tags
    // e.g.
    // <list>
    //     <*>
    //         one
    //         <*>
    //             two
    //             <*>
    //                 three
    //             </*>
    //         </*>
    //     </*>
    // </list>

    var doc = Document{
        .root = node,
        .arena = std.heap.ArenaAllocator.init(ctx.allocator),
    };

    var walker = try doc.walk(ctx.allocator, .pre);
    defer walker.deinit();

    var i: usize = 0;

    while (try walker.next()) |child| {
        switch (child.value) {
            .element => |el| {
                if (element_map.get(el.name)) |md_type| {
                    if (md_type == .listItem) {
                        i += 1;
                        try ctx.writer.print("{d}. ", .{i});
                    }
                }
            },
            .text => |v| {
                try writeTextElement(child, ctx);
                if (v[v.len - 1] != '\n') {
                    try ctx.writer.writeByte('\n');
                }
            },
            else => {},
        }
    }
}

pub fn writeTextElement(node: Node, ctx: *WriteContext) anyerror!void {
    try ctx.writer.writeAll(try node.getText());
}

pub fn writeListItemElement(node: Node, ctx: *WriteContext) anyerror!void {
    try render(node, ctx);
}

pub fn writeHorizontalRuleElement(_: Node, ctx: *WriteContext) !void {
    try ctx.writer.writeAll("\n---\n");
}

pub fn writeBlockQuoteElement(node: Node, ctx: *WriteContext) !void {
    try ctx.writer.writeAll("> ");
    try render(node, ctx);
}

pub fn writeBoldElement(node: Node, ctx: *WriteContext) !void {
    try ctx.writer.writeAll("**");
    try render(node, ctx);
    try ctx.writer.writeAll("**");
}

pub fn writeItalicElement(node: Node, ctx: *WriteContext) !void {
    try ctx.writer.writeAll("*");
    try render(node, ctx);
    try ctx.writer.writeAll("*");
}

pub fn writeCodeElement(node: Node, ctx: *WriteContext) !void {
    try ctx.writer.writeAll("`");
    try render(node, ctx);
    try ctx.writer.writeAll("`");
}

pub fn writeAllChildrenText(node: Node, ctx: *WriteContext) !void {
    var it = node.iterator();
    while (it.next()) |child| {
        if (child.type == .text) {
            try ctx.writer.writeAll(try child.getText());
        }
    }
}

pub fn writeLinkElement(node: Node, ctx: *WriteContext) !void {
    if (try node.getValue()) |value| {
        try ctx.writer.writeAll("[");
        try writeAllChildrenText(node, ctx);
        try ctx.writer.print("]({s})", .{value});
    } else {
        const text = try node.getText();
        try ctx.writer.print("[{0s}]({0s})", .{text});
    }
}

pub fn writeEmailElement(node: Node, ctx: *WriteContext) !void {
    if (try node.getValue()) |value| {
        try ctx.writer.writeAll("[");
        try writeAllChildrenText(node, ctx);
        try ctx.writer.print("](mailto:{s})", .{value});
    } else {
        const text = try node.getText();
        try ctx.writer.print("[{0s}](mailto:{0s})", .{text});
    }
}

test render {
    const bbcode_document =
        \\[b]Hello, World![/b]
        \\[i]This is an italicized text[/i]
        \\[u]Underlined text[/u]
        \\[url=https://example.com]Link[/url]
        \\[email=user@example.com]Email[/email]
        \\[code]This is a code block[/code]
        \\[list][*]one[*]two[*]three[/list]
    ;

    var document = try Document.loadFromBuffer(testing.allocator, bbcode_document, .{});
    defer document.deinit();

    var out_buffer = std.ArrayListUnmanaged(u8){};
    defer out_buffer.deinit(testing.allocator);

    try renderDocument(testing.allocator, document, out_buffer.writer(testing.allocator).any(), .{});

    const expected_markdown =
        \\**Hello, World!**
        \\*This is an italicized text*
        \\Underlined text
        \\[Link](https://example.com)
        \\[Email](mailto:user@example.com)
        \\`This is a code block`
        \\1. one
        \\2. two
        \\3. three
        \\
    ;

    try testing.expectEqualStrings(expected_markdown, out_buffer.items);
}

const Allocator = std.mem.Allocator;
const Node = @import("../Node.zig");
const Document = @import("../Document.zig");

const std = @import("std");
const testing = std.testing;
const logger = std.log.scoped(.markdown_formatter);
