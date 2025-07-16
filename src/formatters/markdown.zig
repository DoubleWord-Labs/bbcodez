//! Markdown formatter for BBCode documents.
//!
//! This module provides functionality to convert BBCode documents into Markdown
//! format. It supports the most common BBCode tags and converts them to their
//! Markdown equivalents where possible.
//!
//! ## Supported Conversions
//! - `[b]text[/b]` → `**text**`
//! - `[i]text[/i]` → `*text*`
//! - `[url=link]text[/url]` → `[text](link)`
//! - `[email=addr]text[/email]` → `[text](mailto:addr)`
//! - `[code]text[/code]` → `` `text` ``
//! - `[list][*]item1[*]item2[/list]` → Numbered lists
//! - `[quote]text[/quote]` → `> text`
//! - `[hr]` or `[line]` → `---`
//!
//! ## Basic Usage
//! ```zig
//! const markdown = @import("formatters/markdown.zig");
//!
//! var document = try Document.loadFromBuffer(allocator, bbcode_text, .{});
//! defer document.deinit();
//!
//! var output = std.ArrayList(u8).init(allocator);
//! defer output.deinit();
//!
//! try markdown.renderDocument(allocator, document, output.writer(), .{});
//! ```
//!
//! ## Custom Element Handling
//!
//! You can provide custom rendering logic for specific elements using callbacks:
//!
//! ```zig
//! fn customElementHandler(node: Node, ctx: ?*const anyopaque) !bool {
//!     const name = try node.getName();
//!     if (std.mem.eql(u8, name, "custom")) {
//!         // Handle custom element
//!         return true; // Element was handled
//!     }
//!     return false; // Use default handling
//! }
//!
//! try markdown.renderDocument(allocator, document, writer, .{
//!     .write_element_fn = customElementHandler,
//! });
//! ```

/// Callback function type for custom element rendering.
///
/// Called for each node during rendering to allow custom handling of specific
/// elements. Return true to indicate the element was handled and should be
/// skipped by the default renderer, false to use the default rendering logic.
///
/// This enables extending the formatter with custom BBCode tags or overriding
/// the default behavior for existing tags.
///
/// Args:
///   node: The Node being rendered
///   ctx: Rendering context containing writer and other state
/// Returns: True if element was handled, false to use default rendering
/// Errors: Any errors from writing to the output stream
pub const WriteElementFunction = *const fn (node: Node, ctx: ?*const anyopaque) anyerror!bool;

/// Context passed to element rendering functions.
///
/// Contains the state needed for rendering operations, including the output
/// writer, document being processed, and any custom user data. This context
/// is used internally by the rendering system and passed to custom element
/// handlers.
pub const WriteContext = struct {
    /// Memory allocator for temporary operations during rendering
    allocator: Allocator,
    /// The document being rendered
    document: Document,
    /// Output writer for the generated Markdown
    writer: std.io.AnyWriter,
    /// Optional custom element handler function
    write_element_fn: ?WriteElementFunction = null,
    /// Optional user data for custom handlers
    user_data: ?*anyopaque = null,
};

/// Configuration options for Markdown rendering.
///
/// Controls how the BBCode document is converted to Markdown format,
/// including custom element handling and user data for callbacks.
pub const Options = struct {
    /// Optional callback for custom element rendering.
    ///
    /// If provided, this function is called for each element before the
    /// default rendering logic. Allows customization of how specific
    /// elements are converted to Markdown or adding support for custom tags.
    write_element_fn: ?WriteElementFunction = null,

    /// Optional user data passed to callback functions.
    ///
    /// This data is available in the WriteContext and can be used by
    /// custom element handlers for application-specific rendering logic.
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

/// Renders a BBCode document as Markdown text.
///
/// Converts the entire document tree to Markdown format, writing the output
/// to the provided writer. Uses the default conversion rules unless custom
/// element handlers are provided in the options.
///
/// The rendering process walks the document tree and converts each node
/// according to its type:
/// - Text nodes are written directly (with newline formatting)
/// - Element nodes are converted to their Markdown equivalents
/// - Unknown elements are left as-is with a warning
///
/// Args:
///   allocator: Memory allocator for temporary operations
///   doc: The Document to render
///   writer: Output writer for the Markdown text
///   options: Rendering configuration options
/// Errors: Any writer errors or allocation failures during rendering
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

/// Renders a node and its children recursively.
///
/// This is the core rendering function that processes a node and all its
/// children, converting them to Markdown format. It handles the dispatch
/// to appropriate rendering functions based on node type.
///
/// Args:
///   root: The root node to render
///   ctx: Write context containing output writer and configuration
/// Errors: Any errors from writing to the output stream
pub fn render(root: Node, ctx: *const WriteContext) !void {
    var it = root.iterator(.{});

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

fn getMarkdownElement(node: Node, _: *const WriteContext) !MarkdownElement {
    const name = try node.getName();
    return element_map.get(name) orelse .noOp;
}

/// Writes a specific BBCode element as its Markdown equivalent.
///
/// Dispatches to the appropriate specialized writing function based on the
/// element type. Each element type has its own conversion logic to produce
/// the correct Markdown output.
///
/// Args:
///   node: The element node to render
///   element: The classified Markdown element type
///   ctx: Write context containing output writer
/// Errors: Any errors from the specialized writing functions
pub fn writeElement(node: Node, element: MarkdownElement, ctx: *const WriteContext) anyerror!void {
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

pub fn writeUnderlineElement(node: Node, ctx: *const WriteContext) anyerror!void {
    try render(node, ctx);
}

pub fn writeNoOpElement(node: Node, ctx: *const WriteContext) anyerror!void {
    // output the bbcode then render children
    try ctx.writer.writeAll(node.raw);
    try render(node, ctx);

    logger.warn("Unsupported bbcode tag: {s}", .{node.raw});
}

pub fn writeListElement(node: Node, ctx: *const WriteContext) anyerror!void {
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

pub fn writeTextElement(node: Node, ctx: *const WriteContext) anyerror!void {
    const text = try std.mem.replaceOwned(
        u8,
        ctx.allocator,
        try node.getText(),
        "\n",
        "\n\n",
    );
    defer ctx.allocator.free(text);

    try ctx.writer.writeAll(text);
}

pub fn writeListItemElement(node: Node, ctx: *const WriteContext) anyerror!void {
    try render(node, ctx);
}

pub fn writeHorizontalRuleElement(_: Node, ctx: *const WriteContext) !void {
    try ctx.writer.writeAll("\n---\n");
}

pub fn writeBlockQuoteElement(node: Node, ctx: *const WriteContext) !void {
    try ctx.writer.writeAll("> ");
    try render(node, ctx);
}

pub fn writeBoldElement(node: Node, ctx: *const WriteContext) !void {
    try ctx.writer.writeAll("**");
    try render(node, ctx);
    try ctx.writer.writeAll("**");
}

pub fn writeItalicElement(node: Node, ctx: *const WriteContext) !void {
    try ctx.writer.writeAll("*");
    try render(node, ctx);
    try ctx.writer.writeAll("*");
}

pub fn writeCodeElement(node: Node, ctx: *const WriteContext) !void {
    try ctx.writer.writeAll("`");
    try render(node, ctx);
    try ctx.writer.writeAll("`");
}

pub fn writeAllChildrenText(node: Node, ctx: *const WriteContext) !void {
    var it = node.iterator(.{ .type = .text });
    while (it.next()) |child| {
        try ctx.writer.writeAll(try child.getText());
    }
}

pub fn writeLinkElement(node: Node, ctx: *const WriteContext) !void {
    if (try node.getValue()) |value| {
        try ctx.writer.writeAll("[");
        try writeAllChildrenText(node, ctx);
        try ctx.writer.print("]({s})", .{value});
    } else {
        const text = try node.getText();
        try ctx.writer.print("[{0s}]({0s})", .{text});
    }
}

pub fn writeEmailElement(node: Node, ctx: *const WriteContext) !void {
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
        \\
        \\*This is an italicized text*
        \\
        \\Underlined text
        \\
        \\[Link](https://example.com)
        \\
        \\[Email](mailto:user@example.com)
        \\
        \\`This is a code block`
        \\
        \\1. one
        \\2. two
        \\3. three
        \\
    ;

    try testing.expectEqualStrings(expected_markdown, out_buffer.items);

    try std.fs.cwd().writeFile(.{
        .sub_path = "snapshots/md/basic.md",
        .data = out_buffer.items,
    });
}

const Allocator = std.mem.Allocator;
const Node = @import("../Node.zig");
const Document = @import("../Document.zig");

const std = @import("std");
const testing = std.testing;
const logger = std.log.scoped(.markdown_formatter);
