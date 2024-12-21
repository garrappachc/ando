const std = @import("std");
const mem = std.mem;
const ArrayList = std.ArrayList;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();
const http = @import("./http.zig");

pub const HeaderName = enum {
    Accept,
    Host,
    @"Accept-Encoding",
    @"User-Agent",

    pub fn str(self: HeaderName) []const u8 {
        switch (self) {
            HeaderName.Accept => return "Accept",
            HeaderName.Host => return "Host",
            HeaderName.@"Accept-Encoding" => return "Accept-Encoding",
            HeaderName.@"User-Agent" => return "User-Agent",
            else => unreachable,
        }
    }
};

pub const Headers = struct {
    map: std.AutoHashMap(HeaderName, []const u8),

    pub fn get(self: Headers, key: []const u8) ![]const u8 {
        return try self.map.get(key);
    }
};

pub const Request = struct {
    method: http.Method,
    path: []const u8,
    protocol: []const u8,
    headers: std.AutoHashMap(HeaderName, []const u8) = std.AutoHashMap(HeaderName, []const u8).init(allocator),

    pub fn print(self: Request) void {
        std.debug.print("{s} {s}\n", .{
            http.Method.str(self.method),
            self.path,
        });
    }
};

pub const ParseRequestError = error{
    Malformed,
};

fn parseRequestLine(buffer: []const u8) !Request {
    var it = mem.splitScalar(u8, buffer, ' ');
    var i: u8 = 0;
    var request = Request{ .method = undefined, .path = undefined, .protocol = undefined };

    while (it.next()) |x| : (i += 1) {
        switch (i) {
            0 => {
                request.method = std.meta.stringToEnum(http.Method, x) orelse return ParseRequestError.Malformed;
            },
            1 => {
                request.path = x;
            },
            2 => {
                request.protocol = x;
            },
            else => return ParseRequestError.Malformed,
        }
    }

    return request;
}

pub fn parse(buffer: []const u8) !Request {
    var it = mem.tokenizeSequence(u8, buffer, "\r\n");
    const requestLine = it.next() orelse return ParseRequestError.Malformed;
    var request = try parseRequestLine(requestLine);
    while (it.next()) |line| {
        const nameStr = mem.sliceTo(line, ':');
        if (nameStr.len == line.len) {
            return ParseRequestError.Malformed;
        }

        const name = std.meta.stringToEnum(HeaderName, nameStr) orelse continue;
        const value = mem.trimLeft(u8, line[nameStr.len + 1 ..], " ");
        try request.headers.put(name, value);
    }
    return request;
}

const expect = std.testing.expect;
const expectError = std.testing.expectError;
test "parse()" {
    const data =
        "GET / HTTP/1.1\r\n" ++
        "Host: www.example.com\r\n" ++
        "User-Agent: Mozilla/5.0\r\n" ++
        "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8\r\n" ++
        "Accept-Language: en-GB,en;q=0.5\r\n" ++
        "Accept-Encoding: gzip, deflate, br\r\n" ++
        "Connection: keep-alive\r\n" ++
        "\r\n";
    const request = try parse(data);
    try expect(mem.eql(u8, request.path, "/"));
    try expect(request.method == http.Method.GET);
    try expect(mem.eql(u8, request.headers.get(HeaderName.@"User-Agent").?, "Mozilla/5.0"));
    try expect(mem.eql(u8, request.headers.get(HeaderName.Host).?, "www.example.com"));
}

test "parse() - unknown method" {
    const request =
        "FAIL / HTTP/1.1\r\n" ++
        "Host: www.example.com\r\n" ++
        "\r\n";
    try expectError(ParseRequestError.Malformed, parse(request));
}

test "parse() - host malformed" {
    const request =
        "GET / HTTP/1.1\r\n" ++
        "Host\r\n" ++
        "\r\n";
    try expectError(ParseRequestError.Malformed, parse(request));
}
