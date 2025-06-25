const MarkdownElement = enum {
    bold,
    italic,
    underline,
    link,
    email,
};

const element_map = std.StaticStringMap(MarkdownElement).initComptime(&.{
    .{ "b", .bold },
    .{ "i", .italic },
    .{ "u", .underline },
    .{ "url", .link },
    .{ "email", .email },
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

                try writeMarkdownElement(markdown_element, writer);
                try render(node, writer);
                try writeMarkdownElement(markdown_element, writer);
            },
            .text => {
                const text = try node.getText();
                try writer.writeAll(text);
            },
            .document => {},
        }
    }
}

fn writeMarkdownElement(element: MarkdownElement, writer: std.io.AnyWriter) !void {
    switch (element) {
        .bold => try writer.writeAll("**"),
        .italic => try writer.writeAll("*"),
        .underline => try writer.writeAll("__"),
        .link => try writer.writeAll("["),
        .email => try writer.writeAll("["),
    }
}

test render {
    const bbcode_document =
        \\[b]Hello, World![/b]
        \\[i]This is an italicized text[/i]
        \\[u]Underlined text[/u]
        \\[url=https://example.com]Link[/url]
        \\[email=user@example.com]Email[/email]
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
    ;

    try testing.expectEqualStrings(expected_markdown, out_buffer.items);
}

const std = @import("std");
const testing = std.testing;
const Document = @import("../Document.zig");
const Node = @import("../Node.zig");
