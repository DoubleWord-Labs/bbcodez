//! BBCode Document parser and tree structure.
//!
//! This module provides the main Document type for parsing BBCode text into a tree structure
//! that can be traversed and analyzed. The Document acts as the root of the parse tree.

arena: std.heap.ArenaAllocator,
root: Node = .{
    .type = .document,
    .value = .document,
},

pub const Options = struct {
    tokenizer_options: ?tokenizer.Options = null,
    parser_options: ?parser.Options = null,
};

/// Parses BBCode text and builds the internal tree structure.
///
/// Takes a BBCode string and parses it into a tree of nodes
/// that can be traversed using the document's methods or Walker.
///
/// Args:
///   bbcode: BBCode string to parse
pub fn load(allocator: Allocator, reader: std.io.AnyReader, options: Options) !Document {
    var tokens = try tokenizer.tokenize(allocator, reader, options.tokenizer_options orelse .{});
    defer tokens.deinit(allocator);
    return try parser.parse(allocator, tokens, options.parser_options orelse .{});
}

pub fn loadFromBuffer(allocator: Allocator, bbcode: []const u8, options: Options) !Document {
    var fbs = std.io.fixedBufferStream(bbcode);
    return try load(allocator, fbs.reader().any(), options);
}

/// Frees resources associated with the document.
///
/// Must be called when done with the document to prevent memory leaks.
/// After calling this, the document should not be used.
pub fn deinit(self: Document) void {
    self.arena.deinit();
}

pub fn format(self: Document, fmt: anytype, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = fmt;
    _ = options;

    try self.print(writer);
}

pub fn print(self: Document, writer: anytype) !void {
    try self.root.print(writer, 0);
}

pub fn walk(self: Document, allocator: Allocator, order: Walker.TraversalOrder) !Walker {
    return Walker.init(self, allocator, order);
}

/// Tree walker for traversing all nodes in a document.
///
/// Each call to `next()` returns the next node in traversal order.
pub const Walker = struct {
    const TraversalFrame = struct {
        node: Node,
        iterator: ?Node.Iterator = null,
    };

    const TraversalOrder = enum {
        pre,
        post,
    };

    allocator: Allocator,
    document: Document,
    stack: std.ArrayListUnmanaged(TraversalFrame),
    order: TraversalOrder,

    /// Creates a new walker for the given document.
    ///
    /// The walker will traverse all nodes in the document in depth-first order.
    /// Call `deinit()` when done to free allocated memory.
    ///
    /// Args:
    ///   document: The Document to traverse
    ///   allocator: Memory allocator for internal state
    /// Returns: A new Walker instance
    pub fn init(document: Document, allocator: Allocator, order: TraversalOrder) !Walker {
        var walker = Walker{
            .allocator = allocator,
            .document = document,
            .stack = .empty,
            .order = order,
        };

        try walker.stack.append(allocator, .{
            .node = document.root,
            .iterator = document.root.iterator(),
        });

        return walker;
    }

    /// Frees resources associated with the walker.
    ///
    /// Must be called when done with the walker to prevent memory leaks.
    pub fn deinit(self: *Walker) void {
        self.stack.deinit(self.allocator);
    }

    /// Returns the next node in the traversal sequence.
    ///
    /// Performs depth-first traversal of the document tree. Returns null
    /// when all nodes have been visited. The first call returns the first
    /// top-level node, subsequent calls return child nodes depth-first.
    ///
    /// Returns: The next Node in traversal order, or null if finished
    pub fn next(self: *Walker) !?Node {
        return try switch (self.order) {
            .pre => self.preOrderTraversal(),
            .post => self.postOrderTraversal(),
        };
    }

    pub fn preOrderTraversal(self: *Walker) !?Node {
        while (self.stack.items.len > 0) {
            const frame = self.stack.pop() orelse return null;
            const node = frame.node;

            var i = node.children.items.len;
            while (i > 0) : (i -= 1) {
                const child_node: Node = node.children.items[i - 1];

                try self.stack.append(self.allocator, .{
                    .node = child_node,
                });
            }

            return node;
        }

        return null;
    }

    pub fn postOrderTraversal(self: *Walker) !?Node {
        while (self.stack.items.len > 0) {
            var top = &self.stack.items[self.stack.items.len - 1];
            var it = &(top.iterator orelse std.debug.panic("Iterator not initialized", .{}));

            if (it.next()) |node| {
                switch (node.type) {
                    .element => {
                        try self.stack.append(self.allocator, .{
                            .node = node,
                            .iterator = node.iterator(),
                        });
                    },
                    else => return node,
                }
            } else if (self.stack.pop()) |item| {
                return item.node;
            }
        }

        return null;
    }

    /// Resets the walker to start traversal from the beginning.
    ///
    /// After calling this, the next call to `next()` will return the first node again.
    /// Useful for making multiple passes over the same document.
    pub fn reset(self: *Walker) void {
        self.stack.clearRetainingCapacity();
    }
};

const std = @import("std");
const Document = @This();
const Node = @import("Node.zig");
const Allocator = std.mem.Allocator;
const parser = @import("parser.zig");
const tokenizer = @import("tokenizer.zig");
