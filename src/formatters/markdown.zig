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

pub fn render(allocator: Allocator, doc: Document, writer: std.io.AnyWriter) !void {
    var walker = try doc.walk(allocator);
    defer walker.deinit();

    var buf: [1024]u8 = undefined;

    var stack = std.ArrayListUnmanaged(MarkdownElement){};
    defer stack.deinit(allocator);

    while (try walker.next()) |node| {
        switch (try node.getType()) {
            .element => {
                const element_type = try node.getElementType();
                const markdown_element = element_map.get(try node.getName(&buf)) orelse std.debug.panic("Unknown element type: {}", .{element_type});

                if (element_type == .closing) {
                    if (stack.getLast() != markdown_element) {
                        std.debug.panic("Unmatched closing element: {}", .{markdown_element});
                    }
                    _ = stack.pop() orelse std.debug.panic("Unexpected closing element", .{});
                } else {
                    try stack.append(allocator, markdown_element);
                }

                switch (markdown_element) {
                    .bold => try writer.writeAll("**"),
                    .italic => try writer.writeAll("*"),
                    .underline => try writer.writeAll("__"),
                    .link => try writer.writeAll("["),
                    .email => try writer.writeAll("["),
                }
            },
            .text => {
                const text = try node.getTextContent(&buf);
                try writer.writeAll(text);
            },
            else => {
                std.debug.panic("Unhandled node type: {}", .{try node.getType()});
            },
        }
    }
}

// test render {
//     const bbcode_document =
//         \\[b]Hello, World![/b]
//         \\[i]This is an italicized text[/i]
//         \\[u]Underlined text[/u]
//         \\[url=https://example.com]Link[/url]
//         \\[email=user@example.com]Email[/email]
//     ;

//     const document = try Document.parse(bbcode_document);

//     var out_buffer = std.ArrayListUnmanaged(u8){};
//     defer out_buffer.deinit(testing.allocator);

//     try render(testing.allocator, document, out_buffer.writer(testing.allocator).any());

//     const expected_markdown =
//         \\**Hello, World!**
//         \\*This is an italicized text*
//         \\__Underlined text__
//         \\[Link](https://example.com)
//         \\[Email](mailto:user@example.com)
//     ;

//     try testing.expectEqualStrings(expected_markdown, out_buffer.items);
// }

const std = @import("std");
const testing = std.testing;
const Document = @import("../Document.zig");
const Node = @import("../Node.zig");
const Allocator = std.mem.Allocator;
