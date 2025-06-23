const Document = @This();
const Node = @import("Node.zig");
const Error = errors.Error;

handle: *bbcpp.bbcpp_document_t,

pub fn init() Error!Document {
    if (bbcpp.bbcpp_document_create()) |handle| {
        return Document{ .handle = handle };
    } else {
        return Error.NullPointer;
    }
}

pub fn load(self: Document, bbcode: [:0]const u8) Error!void {
    try errors.handleError(bbcpp.bbcpp_document_load(self.handle, @ptrCast(bbcode)));
}

pub fn getChildrenCount(self: Document) Error!usize {
    var count: usize = 0;
    try errors.handleError(bbcpp.bbcpp_document_get_children_count(self.handle, &count));
    return count;
}

pub fn getChild(self: Document, index: usize) Error!Node {
    var node_handle: ?*bbcpp.bbcpp_node_t = null;
    try errors.handleError(bbcpp.bbcpp_document_get_child(self.handle, index, @ptrCast(&node_handle)));
    return Node{ .handle = node_handle.? };
}

pub fn print(self: Document) Error!void {
    try errors.handleError(bbcpp.bbcpp_document_print(self.handle));
}

pub fn deinit(self: Document) void {
    bbcpp.bbcpp_document_destroy(self.handle);
}

pub const Walker = struct {
    const TraversalFrame = struct {
        node: Node,
        current_child_index: usize,
        total_children: usize,
    };

    allocator: std.mem.Allocator,
    document: Document,
    stack: std.ArrayListUnmanaged(TraversalFrame),
    document_child_index: usize,
    document_children_count: usize,
    started: bool,

    pub fn init(document: Document, allocator: std.mem.Allocator) Error!Walker {
        const children_count = try document.getChildrenCount();
        return Walker{
            .allocator = allocator,
            .document = document,
            .stack = .empty,
            .document_child_index = 0,
            .document_children_count = children_count,
            .started = false,
        };
    }

    pub fn deinit(self: *Walker) void {
        self.stack.deinit(self.allocator);
    }

    pub fn next(self: *Walker) Error!?Node {
        // If we haven't started, initialize with the first document child
        if (!self.started) {
            self.started = true;
            return self.getNextDocumentChild();
        }

        // If stack is empty, get next document child
        if (self.stack.items.len == 0) {
            return self.getNextDocumentChild();
        }

        // Get current frame from top of stack
        var current_frame = &self.stack.items[self.stack.items.len - 1];

        // If current node has unvisited children, go deeper
        if (current_frame.current_child_index < current_frame.total_children) {
            const child = current_frame.node.getChild(current_frame.current_child_index) catch |err| switch (err) {
                Error.NotFound => {
                    current_frame.current_child_index += 1;
                    return self.next();
                },
                else => return err,
            };
            current_frame.current_child_index += 1;

            if (child) |child_node| {
                const child_count = child_node.getChildrenCount() catch 0;
                try self.stack.append(self.allocator, TraversalFrame{
                    .node = child_node,
                    .current_child_index = 0,
                    .total_children = child_count,
                });
                return child_node;
            } else {
                // Skip null child and try next
                return self.next();
            }
        }

        // Current node is exhausted, backtrack
        _ = self.stack.pop();
        return self.next();
    }

    fn getNextDocumentChild(self: *Walker) Error!?Node {
        if (self.document_child_index >= self.document_children_count) {
            return null;
        }

        const child = try self.document.getChild(self.document_child_index);
        self.document_child_index += 1;

        const child_count = child.getChildrenCount() catch 0;
        try self.stack.append(self.allocator, TraversalFrame{
            .node = child,
            .current_child_index = 0,
            .total_children = child_count,
        });

        return child;
    }

    pub fn reset(self: *Walker) void {
        self.stack.clearRetainingCapacity();
        self.document_child_index = 0;
        self.started = false;
    }
};

const errors = @import("errors.zig");
const bbcpp = @import("bbcpp");
const std = @import("std");

test Document {
    const document = try Document.init();

    try document.load("[b]Hello, World![/b]");

    const children_count = try document.getChildrenCount();
    std.debug.print("Children count: {}\n", .{children_count});
}

test "Walker traversal" {
    const allocator = std.testing.allocator;
    const document = try Document.init();
    defer document.deinit();

    try document.load("Hello [b]bold[/b] and [i]italic[/i] text");

    var walker = try Walker.init(document, allocator);
    defer walker.deinit();

    var content_buf: [64]u8 = undefined;
    var node_count: usize = 0;

    while (try walker.next()) |node| {
        node_count += 1;
        const node_type = try node.getType();
        const name = try node.getName();

        std.debug.print("Node {}: Type = {}", .{ node_count, node_type });

        switch (node_type) {
            .text => {
                if (node.getTextContent(&content_buf)) |content| {
                    std.debug.print(", Text = '{s}'", .{content});
                } else |_| {
                    std.debug.print(", Text = 'Error getting content'", .{});
                }
            },
            .element => {
                std.debug.print(", Element = '{s}'", .{name});
                const param_count = node.getParameterCount() catch 0;
                if (param_count > 0) {
                    std.debug.print(" (params: {})", .{param_count});
                }
            },
            else => {
                std.debug.print(", Name = '{s}'", .{name});
            },
        }
        std.debug.print("\n", .{});
    }

    std.debug.print("Total nodes traversed: {}\n", .{node_count});
    try std.testing.expect(node_count > 0);
}
