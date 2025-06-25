pub fn parse(allocator: std.mem.Allocator, tokens: TokenResult) !Document {
    var doc = Document{
        .arena = std.heap.ArenaAllocator.init(allocator),
    };
    const a_allocator = doc.arena.allocator();

    var stack: ArrayList([]const u8) = .empty;
    defer stack.deinit(allocator);

    var it = tokens.iterator();
    var current = &doc.root;

    while (it.next()) |token| {
        switch (token.type) {
            .text => {
                const text_node = Node{
                    .type = .text,
                    .value = .{
                        .text = try a_allocator.dupe(u8, token.name),
                    },
                };

                try current.appendChild(a_allocator, text_node);
            },
            .element => {
                const element_node = Node{
                    .type = .element,
                    .value = .{
                        .element = .{
                            .name = try a_allocator.dupe(u8, token.name),
                        },
                    },
                };

                try current.appendChild(a_allocator, element_node);
                try stack.append(allocator, token.name);
                current = (try current.getLastChild()).?;
            },
            .closingElement => {
                const item = stack.getLastOrNull() orelse {
                    return error.UnexpectedClosingElement;
                };

                if (std.mem.eql(u8, item, try current.getName())) {
                    _ = stack.pop();
                } else {
                    return error.UnexpectedClosingElement;
                }
            },
        }
    }

    return doc;
}

// test "basic parsing" {
//     const bbcode =
//         \\[b]Hello, World![/b]
//         \\[email]user@example.com[/email]
//         \\[email=user@example.com]My email address[/email]
//         \\[url=https://example.com/]Example[/url]
//         \\Just text
//     ;

//     var document = try Document.loadFromBuffer(testing.allocator, bbcode);
//     defer document.deinit();

//     var walker = try document.walk(testing.allocator, .pre);
//     defer walker.deinit();

//     while (try walker.next()) |node| {
//         switch (node.type) {
//             .element => std.debug.print("Element: {s}\n", .{try node.getName()}),
//             .text => std.debug.print("Text: {s}\n", .{try node.getText()}),
//             .document => {},
//         }
//     }
// }

const std = @import("std");
const tokenizer = @import("tokenizer.zig");
const TokenResult = tokenizer.TokenResult;
const Document = @import("Document.zig");
const ArrayList = std.ArrayListUnmanaged;
const Node = @import("Node.zig");
