# BBCodeZ

A Zig library for parsing BBCode markup into traversable tree structures.

## Features

- **Safe parsing** - Built on [C++ bbcpp](https://github.com/zethon/bbcpp) library
- **Tree traversal** - Depth-first walker for processing all nodes
- **Full BBCode support** - Handles nested tags, parameters, and text content

## Quick Start

Add bbcodez to your Zig project

```bash
        zig fetch --save git+https://github.com/DoubleWord-Labs/bbcodez.git
```

Basic usage:

```zig
const std = @import("std");
const bbcodez = @import("bbcodez");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse BBCode
    const doc = try bbcodez.Document.init();
    defer doc.deinit();

    try doc.load("Hello [b]bold[/b] and [i]italic[/i] text!");

    // Walk the parse tree
    var walker = try bbcodez.Document.Walker.init(doc, allocator);
    defer walker.deinit();

    while (try walker.next()) |node| {
        const node_type = try node.getType();
        switch (node_type) {
            .text => {
                var buf: [256]u8 = undefined;
                const content = try node.getTextContent(&buf);
                std.debug.print("Text: '{s}'\n", .{content});
            },
            .element => {
                const name = try node.getName();
                std.debug.print("Element: {s}\n", .{name});
            },
            else => {},
        }
    }
}
```

## Documentation

See: https://doubleword-labs.github.io/bbcodez/

## Building

```bash
zig build        # Build library
zig build test   # Run tests
zig build docs   # Generate documentation
```

## Examples

### Extract All Text

```zig
const doc = try bbcodez.Document.init();
defer doc.deinit();
try doc.load("Text with [b]formatting[/b] and [url=example.com]links[/url]");

var walker = try bbcodez.Document.Walker.init(doc, allocator);
defer walker.deinit();

var text_content = std.ArrayList(u8).init(allocator);
defer text_content.deinit();

while (try walker.next()) |node| {
    if (try node.getType() == .text) {
        var buf: [1024]u8 = undefined;
        const content = try node.getTextContent(&buf);
        try text_content.appendSlice(content);
    }
}

std.debug.print("Plain text: {s}\n", .{text_content.items});
```

### Process BBCode Elements

```zig
while (try walker.next()) |node| {
    if (try node.getType() == .element) {
        const name = try node.getName();

        if (std.mem.eql(u8, name, "url")) {
            if (try node.hasParameter("href")) {
                const url = try node.getParameter("href", allocator);
                defer allocator.free(url);
                std.debug.print("Found link: {s}\n", .{url});
            }
        }
    }
}
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
