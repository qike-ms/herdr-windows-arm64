const std = @import("std");
pub fn bufPrintZ(buffer: []u8, comptime format: []const u8, args: anytype) std.fmt.BufPrintError![:0]u8 {
    return std.fmt.bufPrintSentinel(buffer, format, args, 0);
}
