const MarkdownElement = enum {
    bold,
    italic,
    underline,
    link,
    email,
    code,
};

const element_map = std.StaticStringMap(MarkdownElement).initComptime(&.{
    .{ "b", .bold },
    .{ "i", .italic },
    .{ "u", .underline },
    .{ "url", .link },
    .{ "email", .email },
    .{ "code", .code },
});

pub fn renderDocument(doc: Document, writer: std.io.AnyWriter) !void {
    try render(doc.root, writer);
}

pub fn render(root: Node, writer: std.io.AnyWriter) !void {
    var it = root.iterator();

    while (it.next()) |node| {
        switch (node.type) {
            .element => {
                const element_type = node.type;
                const markdown_element = element_map.get(try node.getName()) orelse std.debug.panic("Unknown element type: {}", .{element_type});

                try writeElement(node, markdown_element, writer);
            },
            .text => {
                const text = try node.getText();
                try writer.writeAll(text);
            },
            .document => {},
        }
    }
}

fn writeElement(node: Node, element: MarkdownElement, writer: std.io.AnyWriter) anyerror!void {
    switch (element) {
        .bold => try writeBoldElement(node, writer),
        .italic => try writeItalicElement(node, writer),
        .underline => try writeUnderlineElement(node, writer),
        .link => try writeLinkElement(node, writer),
        .email => try writeEmailElement(node, writer),
        .code => try writeCodeElement(node, writer),
    }
}

fn writeBoldElement(node: Node, writer: std.io.AnyWriter) !void {
    try writer.writeAll("**");
    try render(node, writer);
    try writer.writeAll("**");
}

fn writeItalicElement(node: Node, writer: std.io.AnyWriter) !void {
    try writer.writeAll("*");
    try render(node, writer);
    try writer.writeAll("*");
}

fn writeUnderlineElement(node: Node, writer: std.io.AnyWriter) !void {
    try writer.writeAll("__");
    try render(node, writer);
    try writer.writeAll("__");
}

fn writeCodeElement(node: Node, writer: std.io.AnyWriter) !void {
    try writer.writeAll("```\n");
    try render(node, writer);
    try writer.writeAll("\n```");
}

fn writeAllChildrenText(node: Node, writer: std.io.AnyWriter) !void {
    var it = node.iterator();
    while (it.next()) |child| {
        if (child.type == .text) {
            try writer.writeAll(try child.getText());
        }
    }
}

fn writeLinkElement(node: Node, writer: std.io.AnyWriter) !void {
    if (try node.getValue()) |value| {
        try writer.writeAll("[");
        try writeAllChildrenText(node, writer);
        try writer.print("]({s})", .{value});
    } else {
        const text = try node.getText();
        try writer.print("[{0s}]({0s})", .{text});
    }
}

fn writeEmailElement(node: Node, writer: std.io.AnyWriter) !void {
    if (try node.getValue()) |value| {
        try writer.writeAll("[");
        try writeAllChildrenText(node, writer);
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
    ;

    var document = try Document.loadFromBuffer(testing.allocator, bbcode_document);
    defer document.deinit();

    var out_buffer = std.ArrayListUnmanaged(u8){};
    defer out_buffer.deinit(testing.allocator);

    try renderDocument(document, out_buffer.writer(testing.allocator).any());

    const expected_markdown =
        \\**Hello, World!**
        \\*This is an italicized text*
        \\__Underlined text__
        \\[Link](https://example.com)
        \\[Email](mailto:user@example.com)
        \\```
        \\This is a code block
        \\```
    ;

    try testing.expectEqualStrings(expected_markdown, out_buffer.items);
}

const std = @import("std");
const testing = std.testing;
const Document = @import("../Document.zig");
const Node = @import("../Node.zig");
