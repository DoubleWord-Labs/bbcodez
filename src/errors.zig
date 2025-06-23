pub const Error = error{
    NullPointer,
    InvalidArgument,
    BufferTooSmall,
    OutOfMemory,
    ParseError,
    NotFound,
};

pub const ErrorType = enum(bbcpp.bbcpp_error) {
    success = bbcpp.BBCPP_SUCCESS,
    nullPointer = bbcpp.BBCPP_ERROR_NULL_POINTER,
    invalidArgument = bbcpp.BBCPP_ERROR_INVALID_ARGUMENT,
    bufferTooSmall = bbcpp.BBCPP_ERROR_BUFFER_TOO_SMALL,
    outOfMemory = bbcpp.BBCPP_ERROR_OUT_OF_MEMORY,
    parseError = bbcpp.BBCPP_ERROR_PARSE_ERROR,
    notFound = bbcpp.BBCPP_ERROR_NOT_FOUND,
};

pub fn handleError(error_code: bbcpp.bbcpp_error) !void {
    const err: ErrorType = @enumFromInt(error_code);
    switch (err) {
        .success => return,
        .nullPointer => return error.NullPointer,
        .invalidArgument => return error.InvalidArgument,
        .bufferTooSmall => return error.BufferTooSmall,
        .outOfMemory => return error.OutOfMemory,
        .parseError => return error.ParseError,
        .notFound => return error.NotFound,
    }
}

const bbcpp = @import("bbcpp");
