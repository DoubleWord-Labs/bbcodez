//! Shared constants and utilities used across the BBCodeZ library.
//!
//! This module contains common configuration values and helper functions
//! that are used by multiple components of the library. These shared
//! definitions ensure consistency across tokenization, parsing, and formatting.

/// Default list of tags that should be treated as verbatim.
///
/// Content inside these tags is not parsed for nested BBCode and is treated
/// as literal text. This is essential for code examples and other content
/// where BBCode-like syntax should be preserved exactly as written.
///
/// The "code" tag is included by default since code examples should preserve
/// their exact formatting including any BBCode-like syntax that appears within.
///
/// ## Example
/// ```
/// [code]This [b]bold[/b] won't be parsed as BBCode[/code]
/// ```
/// The content will remain as literal text: "This [b]bold[/b] won't be parsed as BBCode"
///
/// ## Custom Verbatim Tags
/// You can extend this list when configuring the tokenizer or parser:
/// ```zig
/// const custom_verbatim = &[_][]const u8{ "code", "pre", "literal" };
/// var tokens = try tokenizer.tokenize(allocator, reader, .{
///     .verbatim_tags = custom_verbatim,
/// });
/// ```
pub const default_verbatim_tags = &[_][]const u8{
    "code",
};
