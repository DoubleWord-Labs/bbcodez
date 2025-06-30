pub const IsSelfClosingFunction = *const fn (user_data: ?*anyopaque, token: Token) bool;

pub const Options = struct {
    verbatim_tags: ?[]const []const u8 = shared.default_verbatim_tags,
    is_self_closing_fn: ?IsSelfClosingFunction = null,
    user_data: ?*anyopaque = null,
};

fn isSelfClosing(token: Token, options: Options) bool {
    if (options.is_self_closing_fn) |is_self_closing| {
        return is_self_closing(options.user_data, token);
    }
    return false;
}

pub fn parse(allocator: std.mem.Allocator, tokens: TokenResult, options: Options) !Document {
    var doc = Document{
        .arena = std.heap.ArenaAllocator.init(allocator),
    };
    const a_allocator = doc.arena.allocator();

    var stack: ArrayList([]const u8) = .empty;
    defer stack.deinit(allocator);

    var it = tokens.iterator();
    var current = &doc.root;

    while (it.next()) |token| {
        const token_raw = try a_allocator.dupe(u8, token.raw);

        switch (token.type) {
            .text => {
                const text_value = token.name;

                const text_node = Node{
                    .type = .text,
                    .value = .{
                        .text = try a_allocator.dupe(u8, text_value),
                    },
                    .parent = current,
                    .raw = token_raw,
                };

                try current.appendChild(a_allocator, text_node);
            },
            .element => {
                const element_name = std.mem.trim(u8, token.name, &std.ascii.whitespace);

                const element_node = Node{
                    .type = .element,
                    .value = .{
                        .element = .{
                            .name = try a_allocator.dupe(u8, element_name),
                            .value = if (token.value) |value| try a_allocator.dupe(
                                u8,
                                std.mem.trim(u8, value, " \n"),
                            ) else null,
                        },
                    },
                    .parent = current,
                    .raw = token_raw,
                };

                try current.appendChild(a_allocator, element_node);
                if (!isSelfClosing(token, options)) {
                    current = try current.getLastChild() orelse std.debug.panic("getLastChild() returned null", .{});
                    try stack.append(allocator, token.name);
                }
            },
            .closingElement => {
                _ = stack.pop();
                current = current.parent orelse break;
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

test "complex parsing" {
    const bbcode =
        \\Converts one or more arguments of any type to string in the best way possible and prints them to the console.
        \\The following BBCode tags are supported: [code]b[/code], [code]i[/code], [code]u[/code], [code]s[/code], [code]indent[/code], [code]code[/code], [code]url[/code], [code]center[/code], [code]right[/code], [code]color[/code], [code]bgcolor[/code], [code]fgcolor[/code].
        \\URL tags only support URLs wrapped by a URL tag, not URLs with a different title.
        \\When printing to standard output, the supported subset of BBCode is converted to ANSI escape codes for the terminal emulator to display. Support for ANSI escape codes varies across terminal emulators, especially for italic and strikethrough. In standard output, [code]code[/code] is represented with faint text but without any font change. Unsupported tags are left as-is in standard output.
        \\[codeblocks]
        \\[gdscript skip-lint]
        \\print_rich("[color=green][b]Hello world![/b][/color]") # Prints "Hello world!", in green with a bold font.
        \\[/gdscript]
        \\[csharp skip-lint]
        \\GD.PrintRich("[color=green][b]Hello world![/b][/color]"); // Prints "Hello world!", in green with a bold font.
        \\[/csharp]
        \\[/codeblocks]
        \\[b]Note:[/b] Consider using [method push_error] and [method push_warning] to print error and warning messages instead of [method print] or [method print_rich]. This distinguishes them from print messages used for debugging purposes, while also displaying a stack trace when an error or warning is printed.
        \\[b]Note:[/b] On Windows, only Windows 10 and later correctly displays ANSI escape codes in standard output.
        \\[b]Note:[/b] Output displayed in the editor supports clickable [code skip-lint][url=address]text[/url][/code] tags. The [code skip-lint][url][/code] tag's [code]address[/code] value is handled by [method OS.shell_open] when clicked.
    ;

    var fbs = std.io.fixedBufferStream(bbcode);

    var tokens = try tokenizer.tokenize(testing.allocator, fbs.reader().any(), .{
        .equals_required_in_parameters = false,
    });
    defer tokens.deinit(testing.allocator);

    // std.debug.print("Tokens: {s}\n", .{tokens});

    var document = try parse(testing.allocator, tokens, .{});
    defer document.deinit();

    // std.debug.print("Document: {s}\n", .{document});
}

const testing = std.testing;
const Token = tokenizer.TokenResult.Token;
const ArrayList = std.ArrayListUnmanaged;
const TokenResult = tokenizer.TokenResult;

const std = @import("std");
const Node = @import("Node.zig");
const shared = @import("shared.zig");
const Document = @import("Document.zig");
const tokenizer = @import("tokenizer.zig");
