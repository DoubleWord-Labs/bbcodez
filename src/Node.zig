const Node = @This();
const Error = errors.Error;

handle: *bbcpp.bbcpp_node_t,

pub fn getType(self: Node) Error!NodeType {
    var node_type: bbcpp.bbcpp_node_type = 0;
    try errors.handleError(bbcpp.bbcpp_node_get_type(self.handle, &node_type));
    return @enumFromInt(node_type);
}

pub fn getName(self: Node) Error![]const u8 {
    var name_length: usize = 0;
    var name_buf: [256]u8 = undefined;

    try errors.handleError(bbcpp.bbcpp_node_get_name(self.handle, &name_buf, name_buf.len, &name_length));

    return name_buf[0..name_length];
}

pub fn getChildrenCount(self: Node) Error!usize {
    var count: usize = 0;
    try errors.handleError(bbcpp.bbcpp_node_get_children_count(self.handle, &count));
    return count;
}

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

pub fn getParent(self: Node) Error!?Node {
    var parent_handle: ?*bbcpp.bbcpp_node_t = null;
    try errors.handleError(bbcpp.bbcpp_node_get_parent(self.handle, @ptrCast(&parent_handle)));

    if (parent_handle) |handle| {
        return Node{ .handle = handle };
    } else {
        return null;
    }
}

// Text node specific functions
pub fn getTextContent(self: Node, buf: []u8) Error![]u8 {
    var content_length: usize = 0;
    try errors.handleError(bbcpp.bbcpp_text_get_content(self.handle, buf.ptr, buf.len, &content_length));
    return buf[0..content_length];
}

// Element node specific functions
pub fn getElementType(self: Node) Error!ElementType {
    var element_type: bbcpp.bbcpp_element_type = 0;
    try errors.handleError(bbcpp.bbcpp_element_get_type(self.handle, &element_type));
    return @enumFromInt(element_type);
}

pub fn getParameterCount(self: Node) Error!usize {
    var count: usize = 0;
    try errors.handleError(bbcpp.bbcpp_element_get_parameter_count(self.handle, &count));
    return count;
}

pub const Parameter = struct {
    key: []u8,
    value: []u8,

    pub fn deinit(self: Parameter, allocator: std.mem.Allocator) void {
        allocator.free(self.key);
        allocator.free(self.value);
    }
};

pub fn getParameterByIndex(self: Node, index: usize, allocator: std.mem.Allocator) Error!Parameter {
    var key_length: usize = 0;
    var value_length: usize = 0;

    try errors.handleError(bbcpp.bbcpp_element_get_parameter_by_index(self.handle, index, null, 0, &key_length, null, 0, &value_length));

    const key_buffer = try allocator.alloc(u8, key_length);
    const value_buffer = try allocator.alloc(u8, value_length);

    try errors.handleError(bbcpp.bbcpp_element_get_parameter_by_index(self.handle, index, key_buffer.ptr, key_buffer.len, &key_length, value_buffer.ptr, value_buffer.len, &value_length));

    return Parameter{
        .key = key_buffer,
        .value = value_buffer,
    };
}

pub fn getParameter(self: Node, key: []const u8, allocator: std.mem.Allocator) Error![]u8 {
    var value_length: usize = 0;

    try errors.handleError(bbcpp.bbcpp_element_get_parameter(self.handle, key.ptr, null, 0, &value_length));

    const buffer = try allocator.alloc(u8, value_length);
    try errors.handleError(bbcpp.bbcpp_element_get_parameter(self.handle, key.ptr, buffer.ptr, buffer.len, &value_length));

    return buffer;
}

pub fn hasParameter(self: Node, key: []const u8) Error!bool {
    var has_param: c_int = 0;
    try errors.handleError(bbcpp.bbcpp_element_has_parameter(self.handle, key.ptr, &has_param));
    return has_param != 0;
}

// Utility functions
pub fn getRawString(self: Node, allocator: std.mem.Allocator) Error![]u8 {
    var content_length: usize = 0;

    // First call to get required length
    try errors.handleError(bbcpp.bbcpp_get_raw_string(self.handle, null, 0, &content_length));

    const buffer = try allocator.alloc(u8, content_length);
    try errors.handleError(bbcpp.bbcpp_get_raw_string(self.handle, buffer.ptr, buffer.len, &content_length));

    return buffer;
}

const std = @import("std");
const bbcpp = @import("bbcpp");
const errors = @import("errors.zig");
const NodeType = @import("enums.zig").NodeType;
const ElementType = @import("enums.zig").ElementType;
