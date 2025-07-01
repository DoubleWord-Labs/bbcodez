//! Core enums for BBCode parsing and node classification.
//!
//! This module defines the fundamental types used throughout the BBCodeZ library
//! to classify nodes and elements in the parse tree. These enums are essential
//! for type-safe node traversal and custom element handling.
//!
//! ## Usage in Custom Handlers
//!
//! When creating custom BBCode processors, these enums help distinguish between
//! different node types during tree traversal:
//!
//! ```zig
//! fn processNode(node: Node) !void {
//!     switch (node.type) {
//!         .document => // Handle root document
//!         .element => // Handle BBCode tags like [b], [url], etc.
//!         .text => // Handle plain text content
//!     }
//! }
//! ```

/// Represents the type of a node in the BBCode parse tree.
///
/// Used to distinguish between different kinds of content when traversing
/// the document tree. Each node type has different properties and behaviors:
/// - `document`: The root container node that holds the entire parse tree
/// - `element`: A BBCode tag like [b], [url], [quote], etc.
/// - `text`: Plain text content between or outside of BBCode tags
pub const NodeType = enum {
    document,
    element,
    text,
};

/// Represents the type of a BBCode element/tag during tokenization.
///
/// Used internally by the tokenizer to classify different parsing patterns
/// and determine how to extract tag names, values, and parameters:
/// - `simple`: Basic tags without parameters like [b] or [i]
/// - `value`: Tags with values like [url=http://example.com] or [color=red]
/// - `parameter`: Tags with complex parameters (extended form of value)
/// - `closing`: Closing tags like [/b] or [/url]
pub const ElementType = enum {
    simple,
    value,
    parameter,
    closing,
};
