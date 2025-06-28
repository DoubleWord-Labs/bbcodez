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
        value: ?[]const u8 = null,
    },
    document: void,
};

parent: ?*Node = null,
type: Type,
value: Value,
children: ArrayList(Node) = .empty,
raw: []const u8,

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
    switch (self.type) {
        inline .document, .element => return &self.children.items[self.children.items.len - 1],
        else => return error.InvalidOperation,
    }
}

pub fn childrenOfType(self: Node, allocator: Allocator, ty: Type) !ArrayList(Node) {
    switch (self.type) {
        inline .document, .element => {
            var result = try ArrayList(Node).initCapacity(allocator, self.children.items.len);
            for (self.children.items) |child| {
                if (child.type == ty) try result.append(allocator, child);
            }
            return result;
        },
        else => return error.InvalidOperation,
    }
}

pub fn lastChildOfType(self: *Node, ty: Type) !?*Node {
    switch (self.type) {
        inline .document, .element => {
            var i: usize = self.children.items.len - 1;
            while (i >= 0) : (i -= 1) {
                if (self.children.items[i].type == ty) return &self.children.items[i];
            }
            return null;
        },
        else => return error.InvalidOperation,
    }
}

pub fn firstChildOfType(self: *Node, ty: Type) !?*Node {
    switch (self.type) {
        inline .document, .element => {
            for (self.children.items) |*child| {
                if (child.type == ty) return child;
            }
            return null;
        },
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
        .text => |v| return v,
        .document => return "document",
    }
}

pub fn getText(self: Node) ![]const u8 {
    if (self.type == .text) {
        return self.value.text;
    }

    return error.InvalidNodeType;
}

pub fn getValue(self: Node) !?[]const u8 {
    if (self.type == .element) {
        return self.value.element.value;
    }

    return error.InvalidNodeType;
}

pub fn format(self: Node, fmt: anytype, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = fmt;
    _ = options;

    try self.print(writer, 0);
}

pub fn print(self: Node, writer: anytype, depth: usize) !void {
    var printer = NodePrinter{
        .writer = writer,
        .depth = depth,
    };

    switch (self.type) {
        .document => {
            try printer.writeLine("<document>");
        },
        .element => {
            try printer.printLine("<{s}>", .{try self.getName()});
        },
        .text => {
            try printer.writeLine(try self.getText());
        },
    }

    var it = self.iterator();
    while (it.next()) |node| {
        try node.print(writer, depth + 1);
    }

    switch (self.type) {
        .document => try printer.writeLine("</document>"),
        .element => {
            try printer.printLine("</{s}>", .{try self.getName()});
        },
        .text => {},
    }
}

pub const NodePrinter = struct {
    const indent_size = 4;

    writer: std.io.AnyWriter,
    depth: usize = 0,
    indent: bool = true,

    pub fn write(self: NodePrinter, input: []const u8) !void {
        if (self.indent) {
            try self.writer.writeByteNTimes(' ', indent_size * self.depth);
        }

        _ = try self.writer.write(input);
    }

    pub fn writeLine(self: NodePrinter, input: []const u8) !void {
        try self.write(input);
        try self.writer.writeByte('\n');
    }

    pub fn print(self: NodePrinter, comptime fmt: []const u8, args: anytype) !void {
        if (self.indent) {
            try self.writer.writeByteNTimes(' ', indent_size * self.depth);
        }

        try self.writer.print(fmt, args);
    }

    pub fn printLine(self: NodePrinter, comptime fmt: []const u8, args: anytype) !void {
        try self.print(fmt, args);
        try self.writer.writeByte('\n');
    }
};

/// Represents a key-value parameter pair from a BBCode element.
///
/// Contains allocated memory that must be freed using `deinit()`.
pub const Parameter = struct {
    /// Parameter name/key
    key: []const u8,
    /// Parameter value
    value: []const u8,

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
