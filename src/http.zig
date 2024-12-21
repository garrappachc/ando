pub const Method = enum {
    GET,
    POST,

    pub fn str(self: Method) []const u8 {
        switch (self) {
            Method.GET => return "GET",
            Method.POST => return "POST",
        }
    }
};
