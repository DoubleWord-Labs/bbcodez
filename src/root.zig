//! BBCodeZ - A Zig library for parsing BBCode markup.
//!
//! This library provides a fast and safe way to parse BBCode text into a tree structure
//! that can be traversed and analyzed.
//!
//! ## Quick Start
//!
//! ```zig
//! const bbcodez = @import("bbcodez");
//!
//! // Parse BBCode text
//! const doc = try bbcodez.Document.init();
//! defer doc.deinit();
//! try doc.load("Hello [b]world[/b]!");
//!
//! // Walk the parse tree
//! var walker = try bbcodez.Document.Walker.init(doc, allocator);
//! defer walker.deinit();
//! while (try walker.next()) |node| {
//!     // Process each node...
//! }
//! ```
//!
//! ## Main Types
//! - `Document`: Root container for parsed BBCode
//! - `Node`: Individual elements in the parse tree
//! - `Document.Walker`: Iterator for traversing the tree
//!
//! Source: https://github.com/DoubleWord-Labs/bbcodez

pub const Document = @import("Document.zig");
pub const Node = @import("Node.zig");
pub const tokenizer = @import("tokenizer.zig");
pub const parser = @import("parser.zig");

pub const ElementType = enums.ElementType;
pub const NodeType = enums.NodeType;

pub const parse = parser.parse;
pub const tokenize = tokenizer.tokenize;
pub const load = Document.load;
pub const loadFromBuffer = Document.loadFromBuffer;

const std = @import("std");
const enums = @import("enums.zig");

pub const fmt = struct {
    pub const md = @import("formatters/markdown.zig");
};

test {
    std.testing.refAllDeclsRecursive(@This());
}
