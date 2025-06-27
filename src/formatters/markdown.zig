const Allocator = std.mem.Allocator;

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
});

pub fn renderDocument(allocator: Allocator, doc: Document, writer: std.io.AnyWriter) !void {
    try render(allocator, doc.root, writer);
}

pub fn render(allocator: Allocator, root: Node, writer: std.io.AnyWriter) !void {
    var it = root.iterator();

    while (it.next()) |node| {
        switch (node.type) {
            .element => {
                const markdown_element = element_map.get(try node.getName()) orelse .noOp;

                try writeElement(allocator, node, markdown_element, writer);
            },
            .text => {
                const text = try node.getText();
                try writer.writeAll(text);
            },
            .document => {},
        }
    }
}

fn writeElement(allocator: Allocator, node: Node, element: MarkdownElement, writer: std.io.AnyWriter) anyerror!void {
    switch (element) {
        .bold => try writeBoldElement(allocator, node, writer),
        .italic => try writeItalicElement(allocator, node, writer),
        .link => try writeLinkElement(allocator, node, writer),
        .email => try writeEmailElement(allocator, node, writer),
        .code => try writeCodeElement(allocator, node, writer),
        .blockquote => try writeBlockQuoteElement(allocator, node, writer),
        .horizontalRule => try writeHorizontalRuleElement(allocator, node, writer),
        .list => try writeListElement(allocator, node, writer),
        .listItem => try writeListItemElement(allocator, node, writer),
        .noOp => try render(allocator, node, writer),
    }
}

fn writeListElement(allocator: Allocator, node: Node, writer: std.io.AnyWriter) !void {
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
        .arena = std.heap.ArenaAllocator.init(allocator),
    };

    var walker = try doc.walk(allocator, .pre);
    defer walker.deinit();

    var i: usize = 0;

    while (try walker.next()) |child| {
        switch (child.value) {
            .element => |el| {
                const md_type = element_map.get(el.name) orelse .noOp;
                if (md_type == .listItem) {
                    i += 1;
                    try writer.print("{d}. ", .{i});
                }
            },
            .text => |v| {
                try writer.writeAll(v);

                if (v[v.len - 1] != '\n') {
                    try writer.writeByte('\n');
                }
            },
            else => {},
        }
    }
}

fn writeListItemElement(allocator: Allocator, node: Node, writer: std.io.AnyWriter) !void {
    try render(allocator, node, writer);
}

fn writeHorizontalRuleElement(_: Allocator, _: Node, writer: std.io.AnyWriter) !void {
    try writer.writeAll("\n---\n");
}

fn writeBlockQuoteElement(allocator: Allocator, node: Node, writer: std.io.AnyWriter) !void {
    try writer.writeAll("> ");
    try render(allocator, node, writer);
}

fn writeBoldElement(allocator: Allocator, node: Node, writer: std.io.AnyWriter) !void {
    try writer.writeAll("**");
    try render(allocator, node, writer);
    try writer.writeAll("**");
}

fn writeItalicElement(allocator: Allocator, node: Node, writer: std.io.AnyWriter) !void {
    try writer.writeAll("*");
    try render(allocator, node, writer);
    try writer.writeAll("*");
}

fn writeCodeElement(allocator: Allocator, node: Node, writer: std.io.AnyWriter) !void {
    try writer.writeAll("`");
    try render(allocator, node, writer);
    try writer.writeAll("`");
}

fn writeAllChildrenText(_: Allocator, node: Node, writer: std.io.AnyWriter) !void {
    var it = node.iterator();
    while (it.next()) |child| {
        if (child.type == .text) {
            try writer.writeAll(try child.getText());
        }
    }
}

fn writeLinkElement(allocator: Allocator, node: Node, writer: std.io.AnyWriter) !void {
    if (try node.getValue()) |value| {
        try writer.writeAll("[");
        try writeAllChildrenText(allocator, node, writer);
        try writer.print("]({s})", .{value});
    } else {
        const text = try node.getText();
        try writer.print("[{0s}]({0s})", .{text});
    }
}

fn writeEmailElement(allocator: Allocator, node: Node, writer: std.io.AnyWriter) !void {
    if (try node.getValue()) |value| {
        try writer.writeAll("[");
        try writeAllChildrenText(allocator, node, writer);
        try writer.print("](mailto:{s})", .{value});
    } else {
        const text = try node.getText();
        try writer.print("[{0s}](mailto:{0s})", .{text});
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

    try renderDocument(testing.allocator, document, out_buffer.writer(testing.allocator).any());

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

const std = @import("std");
const testing = std.testing;
const Document = @import("../Document.zig");
const Node = @import("../Node.zig");
