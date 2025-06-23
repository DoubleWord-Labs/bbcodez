pub const Document = @import("Document.zig");
pub const Node = @import("Node.zig");

pub const Error = errors.Error;
pub const ElementType = enums.ElementType;
pub const NodeType = enums.NodeType;

const std = @import("std");
const errors = @import("errors.zig");
const enums = @import("enums.zig");

test {
    std.testing.refAllDecls(@This());
}
