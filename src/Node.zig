//! BBCode parse tree node representation.
//!
//! This module provides the Node type which represents individual elements in a BBCode
//! parse tree. Nodes can be text content, BBCode elements, or other structural components.
//! Each node may have children, parameters, and type-specific data.

const Node = @This();
const Error = errors.Error;

/// Opaque handle to the underlying C++ BBCode node implementation
handle: *bbcpp.bbcpp_node_t,

/// Returns the type of this node.
///
/// Determines whether this node is a text node, element node, document node, or attribute.
/// Use this to determine which type-specific methods are available.
///
/// Returns: The NodeType enum value for this node
pub fn getType(self: Node) Error!NodeType {
    var node_type: bbcpp.bbcpp_node_type = 0;
    try errors.handleError(bbcpp.bbcpp_node_get_type(self.handle, &node_type));
    return @enumFromInt(node_type);
}

/// Gets the name of this node.
///
/// For element nodes, returns the tag name (e.g., "b", "i", "quote").
/// For text nodes, returns the text content.
/// Copies the name into the provided buffer and returns a slice of the actual content.
///
/// Args:
///   buf: Buffer to copy the node name into
/// Returns: Slice of the buffer containing the actual name
pub fn getName(self: Node, buf: []u8) Error![]u8 {
    var name_length: usize = 0;

    try errors.handleError(bbcpp.bbcpp_node_get_name(self.handle, buf.ptr, buf.len, &name_length));
    return buf[0..name_length];
}

/// Returns the number of child nodes.
///
/// Child nodes represent nested content within this node. For example,
/// a [b] element containing text and other elements would have multiple children.
///
/// Returns: Number of direct child nodes
pub fn getChildrenCount(self: Node) Error!usize {
    var count: usize = 0;
    try errors.handleError(bbcpp.bbcpp_node_get_children_count(self.handle, &count));
    return count;
}

/// Gets a child node at the specified index.
///
/// Retrieves a direct child of this node by its zero-based index.
/// Index must be less than the value returned by `getChildrenCount()`.
///
/// Args:
///   index: Zero-based index of the child to retrieve
/// Returns: The child Node at the given index, or null if not found
pub fn getChild(self: Node, index: usize) Error!?Node {
    var child_handle: ?*bbcpp.bbcpp_node_t = null;
    errors.handleError(bbcpp.bbcpp_node_get_child(self.handle, index, @ptrCast(&child_handle))) catch |err| switch (err) {
        Error.NotFound => return null,
        else => return err,
    };
    if (child_handle) |handle| {
        return Node{ .handle = handle };
    } else {
        return null;
    }
}

/// Gets the parent node of this node.
///
/// Returns the node that contains this node as a child, or null if this
/// is a root node (like a document child).
///
/// Returns: The parent Node, or null if this is a root node
pub fn getParent(self: Node) Error!?Node {
    var parent_handle: ?*bbcpp.bbcpp_node_t = null;
    try errors.handleError(bbcpp.bbcpp_node_get_parent(self.handle, @ptrCast(&parent_handle)));

    if (parent_handle) |handle| {
        return Node{ .handle = handle };
    } else {
        return null;
    }
}

/// Gets the text content of a text node.
///
/// Only valid for nodes of type `.text`. Copies the text content into the
/// provided buffer and returns a slice of the actual content.
///
/// Args:
///   buf: Buffer to copy the text content into
/// Returns: Slice of the buffer containing the actual text content
pub fn getTextContent(self: Node, buf: []u8) Error![]u8 {
    var content_length: usize = 0;
    try errors.handleError(bbcpp.bbcpp_text_get_content(self.handle, buf.ptr, buf.len, &content_length));
    return buf[0..content_length];
}

/// Gets the element type of an element node.
///
/// Only valid for nodes of type `.element`. Returns the specific element type
/// such as simple, value, parameter, or closing.
///
/// Returns: The ElementType enum value for this element
pub fn getElementType(self: Node) Error!ElementType {
    var element_type: bbcpp.bbcpp_element_type = 0;
    try errors.handleError(bbcpp.bbcpp_element_get_type(self.handle, &element_type));
    return @enumFromInt(element_type);
}

/// Returns the number of parameters in an element node.
///
/// Only valid for element nodes. Parameters are key-value pairs like
/// `user="Alice"` in `[quote user="Alice"]`.
///
/// Returns: Number of parameters in this element
pub fn getParameterCount(self: Node) Error!usize {
    var count: usize = 0;
    try errors.handleError(bbcpp.bbcpp_element_get_parameter_count(self.handle, &count));
    return count;
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

/// Gets a parameter by its index.
///
/// Retrieves a parameter key-value pair by its zero-based index.
/// The returned Parameter contains allocated memory that must be freed
/// using `Parameter.deinit()`.
///
/// Args:
///   index: Zero-based index of the parameter to retrieve
///   allocator: Memory allocator for the parameter strings
/// Returns: Parameter struct containing the key and value
pub fn getParameterByIndex(self: Node, index: usize, allocator: std.mem.Allocator) Error!Parameter {
    var key_length: usize = 0;
    var value_length: usize = 0;

    var key_buf: [256]u8 = undefined;
    var value_buf: [256]u8 = undefined;

    try errors.handleError(bbcpp.bbcpp_element_get_parameter_by_index(self.handle, index, &key_buf, key_buf.len, &key_length, &value_buf, value_buf.len, &value_length));

    return Parameter{
        .key = try allocator.dupe(u8, key_buf[0..key_length]),
        .value = try allocator.dupe(u8, value_buf[0..value_length]),
    };
}

/// Gets the value of a parameter by its key name.
///
/// Looks up a parameter by name and returns its value as an allocated string.
/// The caller must free the returned string using the same allocator.
///
/// Args:
///   key: Parameter name to look up
///   allocator: Memory allocator for the returned value string
/// Returns: Allocated string containing the parameter value
pub fn getParameter(self: Node, key: []const u8) Error![]u8 {
    var value_length: usize = 0;
    var value_buf: [256]u8 = undefined;

    try errors.handleError(bbcpp.bbcpp_element_get_parameter(self.handle, key.ptr, &value_buf, value_buf.len, &value_length));

    return value_buf[0..value_length];
}

/// Checks if an element has a parameter with the given key.
///
/// Tests whether this element node contains a parameter with the specified name.
/// Useful for checking parameter existence before calling `getParameter()`.
///
/// Args:
///   key: Parameter name to check for
/// Returns: true if the parameter exists, false otherwise
pub fn hasParameter(self: Node, key: []const u8) Error!bool {
    var has_param: c_int = 0;
    try errors.handleError(bbcpp.bbcpp_element_has_parameter(self.handle, key.ptr, &has_param));
    return has_param != 0;
}

/// Extracts all text content from this node and its children.
///
/// Recursively collects all text content from this node's subtree,
/// ignoring BBCode markup. Useful for getting the plain text representation.
/// The returned string is allocated and must be freed by the caller.
///
/// Args:
///   allocator: Memory allocator for the returned string
/// Returns: Allocated string containing all text content from this subtree
pub fn getRawString(self: Node, buffer: []u8) Error![]u8 {
    var content_length: usize = 0;
    try errors.handleError(bbcpp.bbcpp_get_raw_string(self.handle, buffer.ptr, buffer.len, &content_length));

    return buffer[0..content_length];
}

const std = @import("std");
const testing = std.testing;
const bbcpp = @import("bbcpp");
const errors = @import("errors.zig");
const NodeType = @import("enums.zig").NodeType;
const ElementType = @import("enums.zig").ElementType;
const Document = @import("Document.zig");

test Node {
    const bbcode = "[b]Hello, world[/b]";

    const doc = try Document.parse(bbcode);
    defer doc.deinit();

    const node = try doc.getChild(0);

    var text_buf: [256]u8 = undefined;

    for (0..try node.getChildrenCount()) |i| {
        const child = (try node.getChild(i)).?;

        switch (try child.getType()) {
            .element => {
                try testing.expectEqual(ElementType.closing, try child.getElementType());
                try testing.expectEqualStrings("b", try child.getName(&text_buf));
            },
            .text => {
                try testing.expectEqualStrings("Hello, world", try child.getTextContent(&text_buf));
            },
            else => unreachable,
        }
    }
}
