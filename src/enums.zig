pub const NodeType = enum(bbcpp.bbcpp_node_type) {
    document = bbcpp.BBCPP_NODE_DOCUMENT,
    element = bbcpp.BBCPP_NODE_ELEMENT,
    text = bbcpp.BBCPP_NODE_TEXT,
    attribute = bbcpp.BBCPP_NODE_ATTRIBUTE,
};

pub const ElementType = enum(bbcpp.bbcpp_element_type) {
    simple = bbcpp.BBCPP_ELEMENT_SIMPLE,
    value = bbcpp.BBCPP_ELEMENT_VALUE,
    parameter = bbcpp.BBCPP_ELEMENT_PARAMETER,
    closing = bbcpp.BBCPP_ELEMENT_CLOSING,
};

const bbcpp = @import("bbcpp");
