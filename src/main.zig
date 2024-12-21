const std = @import("std");
const net = std.net;
const mem = std.mem;
const print = std.debug.print;
const request = @import("./request.zig");

const ServeFileError = error{
    HeaderMalformed,
    MethodNotSupported,
    ProtoNotSupported,
    UnknownMimeType,
};

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();
    // const allocator = gpa.allocator();

    var args = std.process.args();
    // The first (0 index) Argument is the path to the program.
    _ = args.skip();
    const port_value = args.next() orelse {
        print("expect port as command line argument\n", .{});
        return error.NoPort;
    };
    const port = try std.fmt.parseInt(u16, port_value, 10);

    // const loopback = try net.Address.parseIp4("127.0.0.1", port);
    const addr = try net.Address.resolveIp("0.0.0.0", port);
    var server = try addr.listen(.{
        .reuse_port = true,
    });
    defer server.deinit();

    print("listening on {}\n", .{server.listen_address.getPort()});

    while (server.accept()) |conn| {
        print("accepted connection from {}\n", .{conn.address});
        var recv_buf: [4096]u8 = undefined;
        var recv_total: usize = 0;
        while (conn.stream.read(recv_buf[recv_total..])) |recv_len| {
            if (recv_len == 0) break;
            recv_total += recv_len;
            if (mem.containsAtLeast(u8, recv_buf[0..recv_total], 1, "\r\n\r\n")) {
                break;
            }
        } else |read_err| {
            return read_err;
        }

        const recv_data = recv_buf[0..recv_total];
        if (recv_data.len == 0) {
            print("got connection but no header\n", .{});
            continue;
        }

        const h = try request.parse(recv_data);
        h.print();

        const buf = "<!doctype html><html><body></body></html>";
        const httpHead =
            "HTTP/1.1 200 OK \r\n" ++
            "Connection: close\r\n" ++
            "Content-Type: {s}\r\n" ++
            "Content-Length: {}\r\n" ++
            "\r\n";
        _ = try conn.stream.writer().print(httpHead, .{ "text/html", buf.len });
        _ = try conn.stream.writer().write(buf);
    } else |err| {
        std.debug.print("error in accept: {}\n", .{err});
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const global = struct {
        fn testOne(input: []const u8) anyerror!void {
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(global.testOne, .{});
}
