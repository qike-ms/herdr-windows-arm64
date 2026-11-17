/// Comptime string repetition, replacing the removed Zig array repetition operator.
pub fn string(comptime text: []const u8, comptime count: usize) *const [text.len * count:0]u8 {
    const result = comptime blk: {
        @setEvalBranchQuota(count * 2 + 1000);
        var bytes: [text.len * count:0]u8 = undefined;
        for (0..count) |i| @memcpy(bytes[i * text.len ..][0..text.len], text);
        bytes[text.len * count] = 0;
        break :blk bytes;
    };
    return &result;
}
