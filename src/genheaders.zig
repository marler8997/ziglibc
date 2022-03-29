const std = @import("std");

var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const arena = arena_instance.allocator();

pub fn main() !u8 {
    const all_args = try std.process.argsAlloc(arena);

    if (all_args.len <= 1) {
        std.debug.print("Usage: genheaders CAPI_TXT_FILE\n", .{});
        return 0xff;
    }
    const args = all_args[1..];
    if (args.len != 1) {
        std.log.err("expected 1 cmd-line argument but got {}", .{args.len});
        return 0xff;
    }
    const capi_filename = args[0];
    std.log.info("reading api from '{s}'...", .{capi_filename});
    const contents = try std.fs.cwd().readFileAlloc(arena, capi_filename, std.math.maxInt(usize));

    var parser = Parser.init(arena, capi_filename, contents);
    try parser.genHeaders();
    if (parser.total_errors > 0) {
        std.log.err("{d} errors", .{parser.total_errors});
        return 0xff;
    }
    return 0;
}


const ErrorReporter = struct {
    filename: []const u8,
    base_line_number: u32,
    count: u32,
    fn report(self: *ErrorReporter, line_offset: u32, comptime msg: []const u8, args: anytype) void {
        self.count += 1;
        std.log.err("{s}:{d} " ++ msg, .{self.filename, self.base_line_number + line_offset} ++ args);
    }
};

fn parseDefinition(error_reporter: *ErrorReporter, text: []const u8) !?Definition {
    var line_it = std.mem.split(u8, text, "\n");
    const first_line = line_it.next().?;
    if (!std.mem.eql(u8, first_line, "c89")) {
        std.debug.panic("first line not being 'c89', instead is '{s}', not implemented", .{first_line});
    }
    var line_offset: u32 = 1;
    const second_line = line_it.next() orelse {
        error_reporter.report(line_offset, "definition is missing it's second line", .{});
        return null;
    };
    line_offset += 1;
    _ = second_line;

    error_reporter.report(line_offset, "not implemented", .{});
    return null;
}

const Parser = struct {
    filename: []const u8,
    contents: []const u8,
    definitions: std.ArrayList(Definition),
    total_errors: u32 = 0,
    pub fn init(allocator: std.mem.Allocator, filename: []const u8, contents: []const u8) Parser {
        return .{
            .filename = filename,
            .contents = contents,
            .definitions = std.ArrayList(Definition).init(allocator),
        };
    }
    // TODO: deini?

    
    fn genHeaders(self: *Parser) !void {

        var started: ?struct { ptr: [*]const u8, line_number: u32 } = null;
        var line_it = std.mem.split(u8, self.contents, "\n");
        var line_number: u32 = 0;

        while (line_it.next()) |line_untrimmed| {
            line_number += 1;
            // TODO: assert that line has no '\r\n'?
            const line = std.mem.trim(u8, line_untrimmed, " \t");
            //std.log.info("line {d} '{s}'", .{line_number, line});

            if (line.len == 0) {
                if (started) |info| {
                    try self.addDefinition(info.line_number, info.ptr, line.ptr);
                    started = null;
                }
            } else {
                if (started) |_| { } else {
                    started = .{ .line_number = line_number, .ptr = line.ptr };
                }
            }
        }
        if (started) |info| {
            try self.addDefinition(info.line_number, info.ptr, self.contents.ptr + self.contents.len);
        }
    }

    fn addDefinition(self: *Parser, line_number: u32, start: [*]const u8, limit: [*]const u8) !void {
        var error_reporter = ErrorReporter {
            .filename = self.filename,
            .base_line_number = line_number,
            .count = 0,
        };
        if (try parseDefinition(&error_reporter, start[0 .. @ptrToInt(limit) - @ptrToInt(start)])) |def| {
            std.debug.assert(error_reporter.count == 0);
            try self.definitions.append(def);
        } else {
            std.debug.assert(error_reporter.count > 0);
            self.total_errors += error_reporter.count;
        }
    }
};

const Definition = struct {
    headers: []const []const u8,
    def: union(enum) {
        define: Define,
        type: Type,
        extern_var: ExternVar,
        function: Function,

        const Define = struct {
            name: []const u8,
            value: []const u8,
        };
        
        const Type = union(enum) {
            builtin: struct {
                name: []const u8,
            },
            typedef: struct {
                name: []const u8,
                definition: *const Type,
            },
            opaque_struct: struct {
                name: []const u8,
                provide_size: bool, // I think the FILE is supposed to be opaque but gcc provides the size
            },
            ptr: struct {
                target: *const Type,
                is_const: bool,
            },
        };
        
        const ExternVar = struct {
            name: []const u8,
            type: *const Type,
        };
        
        const Param = struct {
            name: []const u8,
            type: *const Type,
        };
        
        const Function = struct {
            name: []const u8,
            return_type: *const Type,
            params: []const Param,
        };
    },
};

//const defs = [_]Definition {
//    Definition{
//        .headers = &[_][]const u8 {
//            "stddef.h", // c89
//            "stdio.h", // c89
//            "stdlib.h", // c89
//            "string.h", // c89
//            "time.h", // c89
//            "locale.h", // c89
//        },
//        .def = .{ .define = .{ .name = "NULL", .value = "((void*)0)" } },
//    },
//};
//
