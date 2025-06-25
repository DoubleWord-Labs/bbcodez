//! BBCode parse tree node representation.
//!
//! This module provides the Node type which represents individual elements in a BBCode
//! parse tree. Nodes can be text content, BBCode elements, or other structural components.
//! Each node may have children, parameters, and type-specific data.

const Node = @This();

pub const Type = enum {
    text,
    element,
    document,
};

pub const Value = union(Type) {
    text: []const u8,
    element: struct {
        name: []const u8,
    },
    document: void,
};

parent: ?*Node = null,
type: Type,
value: Value,
children: ArrayList(Node) = .empty,

pub fn deinit(self: *Node, allocator: Allocator) void {
    switch (self.value) {
        inline .document, .element => self.children.deinit(allocator),
        else => {},
    }
}

pub fn appendChild(self: *Node, allocator: Allocator, child: Node) !void {
    switch (self.value) {
        inline .document, .element => try self.children.append(allocator, child),
        else => return error.InvalidOperation,
    }
}

pub fn getLastChild(self: *Node) !?*Node {
    switch (self.value) {
        inline .document, .element => return &self.children.items[self.children.items.len - 1],
        else => return error.InvalidOperation,
    }
}

/// Gets the name of this node.
///
/// For element nodes, returns the tag name (e.g., "b", "i", "quote").
/// For text nodes, returns the text content.
/// Copies the name into the provided buffer and returns a slice of the actual content.
///
/// Args:
/// Returns: Slice of the buffer containing the actual name
pub fn getName(self: Node) ![]const u8 {
    switch (self.value) {
        .element => |v| return v.name,
        else => return error.InvalidNodeType,
    }
}

pub fn getText(self: Node) ![]const u8 {
    if (self.type == .text) {
        return self.value.text;
    }

    return error.InvalidNodeType;
}

/// Represents a key-value parameter pair from a BBCode element.
///
/// Contains allocated memory that must be freed using `deinit()`.
pub const Parameter = struct {
    /// Parameter name/key
    key: []u8,
    /// Parameter value
    value: []u8,

    /// Frees the allocated memory for both key and value.
    ///
    /// Must be called when done with the parameter to prevent memory leaks.
    ///
    /// Args:
    ///   allocator: The same allocator used to create this parameter
    pub fn deinit(self: Parameter, allocator: std.mem.Allocator) void {
        allocator.free(self.key);
        allocator.free(self.value);
    }
};

pub const Iterator = struct {
    node: Node,
    index: usize,

    pub fn next(self: *Iterator) ?Node {
        if (self.index >= self.node.children.items.len) return null;
        const child = self.node.children.items[self.index];
        self.index += 1;
        return child;
    }

    pub fn reset(self: *Iterator) void {
        self.index = 0;
    }
};

pub fn iterator(self: Node) Iterator {
    return Iterator{
        .node = self,
        .index = 0,
    };
}

const std = @import("std");
const ArrayList = std.ArrayListUnmanaged;
const Allocator = std.mem.Allocator;
