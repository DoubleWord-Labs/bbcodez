pub const NodeType = enum {
    document,
    element,
    text,
    attribute,
};

pub const ElementType = enum {
    simple,
    value,
    parameter,
    closing,
};
