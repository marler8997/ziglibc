const std = @import("std");
const json = std.json;

const IncludeGuardStyle = enum {
    pragma,
    ifdef,
};

const CType = union(enum) {
    @"void": void,
    int: void,
    ptr: *const CType,

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        _ = options;
        if (comptime std.mem.eql(u8, fmt, "s")) {
            switch (self) {
                .@"void" => try writer.writeAll("void"),
                .int => try writer.writeAll("int"),
                .ptr => |t| try writer.print("{s}*", .{t}),
            }
        } else @compileError("unknown fmt specifier for CType");
    }
};
const ctype_void = CType{ .@"void" = {} };

const global = struct {
    pub var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var header_map: std.StringHashMapUnmanaged(HeaderId) = .{};
    pub var headers: std.ArrayListUnmanaged([]const u8) = .{};
    pub var symbols: std.ArrayListUnmanaged([]const u8) = .{};
    pub var include_guard_style: IncludeGuardStyle = .pragma;

    pub fn toHeaderId(name_transient: []const u8) HeaderId {
        if (header_map.get(name_transient)) |id| return id;

        const name_permanent = arena.allocator().dupe(u8, name_transient) catch |e| oom(e);
        const new_id = HeaderId{ .index = @intCast(u16, header_map.count()) };
        header_map.put(arena.allocator(), name_permanent, new_id) catch |e| oom(e);
        headers.append(arena.allocator(), name_permanent) catch |e| oom(e);
        return new_id;
    }
    pub fn addSymbol(name: []const u8) SymbolId {
        const index = symbols.items.len;
        symbols.append(arena.allocator(), name) catch @panic("Out of memory");
        return SymbolId{ .index = @intCast(u32, index) };
    }
};

const HeaderId = struct {
    index: u16,
};
const SymbolId = struct {
    index: u32,
    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        _ = options;
        if (comptime std.mem.eql(u8, fmt, "s")) {
            try writer.writeAll(global.symbols.items[self.index]);
        } else @compileError("unknown fmt specifier for SymbolId");
    }
};

const Condition = struct {
    placeholder: []const u8,
};
const SymbolDef = struct {
    id: SymbolId,
    defs: []SuperDef,
    const SuperDef = struct {
        definition: Def,
        condition: Condition,
        // TODO: each of these headers could have their own
        //       set of 'reachability' conditions
        headers: []const HeaderId,
    };
    const Def = union(enum) {
        typedef: CType,
        global_var: CType,
        macro: []const u8,
        // TODO: remove this
        temp_generic_typedef: []const u8,
    };
};

pub fn main() !u8 {
    const full_args = try std.process.argsAlloc(global.arena.allocator());
    if (full_args.len <= 1) {
        try std.io.getStdErr().writer().writeAll("Usage: uh JSON_FILE OUT_DIR\n");
        return 0xff;
    }
    const args = full_args[1..];
    if (args.len != 2) {
        std.log.err("expected 2 cmdline args but got {}", .{args.len});
        return 0xff;
    }
    const json_filename = args[0];
    const out_dir_path = args[1];

    const symbol_defs = try parseJson(json_filename);

    try std.fs.cwd().makePath(out_dir_path);
    var out_dir = try std.fs.cwd().openDir(out_dir_path, .{});
    defer out_dir.close();

    {
        try out_dir.makePath("d");
        var d_dir = try out_dir.openDir("d", .{});
        defer d_dir.close();
        try generateSymbolFiles(out_dir_path, d_dir, symbol_defs);
    }

    const headers = try gen.prepare(global.arena.allocator(), symbol_defs);
    for (headers, 0..) |header, header_index| {
        const header_sub_path = global.headers.items[header_index];
        std.log.info("creating '{s}/{s}", .{out_dir_path, header_sub_path});
        if (std.fs.path.dirname(header_sub_path)) |dir| {
            try out_dir.makePath(dir);
        }
        var header_file = try out_dir.createFile(header_sub_path, .{});
        defer header_file.close();
        const writer = header_file.writer();
        switch (global.include_guard_style) {
            .pragma => try writer.writeAll("#pragma once\n"),
            .ifdef => @panic("not implemented"),
        }
        var symbol_it = header.symbols.iterator();
        while (symbol_it.next()) |pair| {
            try writer.print("#include \"d/{s}\"\n", .{global.symbols.items[pair.key_ptr.index]});
        }
    }
    return 0;
}

fn addHardcodedSymbols(symbol_defs: *std.ArrayListUnmanaged(SymbolDef)) void {
    const stdio_h = global.addHeader("stdio.h");
    const stdlib_h = global.addHeader("stdlib.h");
    const string_h = global.addHeader("string.h");
    const sys_types_h = global.addHeader("sys/types.h");
    const sys_socket_h = global.addHeader("sys/socket.h");
    const winsock2_h = global.addHeader("winsock2.h");

    {
        var null_def = SymbolDef{ .id = global.addSymbol("NULL") };
        null_def.defs.append(global.arena.allocator(), .{
            .definition = .{ .macro = "(void*)0" },
            .condition = .{ .placeholder = "1" },
            .headers = &[_]HeaderId {
                stdio_h, stdlib_h, string_h,
            },
        }) catch |e| oom(e);
        _ = symbol_defs;
        //symbol_defs.append(global.arena.allocator(), null_def) catch |e| oom(e);
    }

    {
        const socket_t_id = global.addSymbol("socket_t");
        var socket_t_def = SymbolDef{ .id = socket_t_id };
        socket_t_def.defs.append(global.arena.allocator(), .{
            .definition = .{ .typedef = .int },
            .condition = .{ .placeholder = "is_posix" },
            .headers = &[_]HeaderId {
                sys_types_h, sys_socket_h,
            },
        }) catch |e| oom(e);
        socket_t_def.defs.append(global.arena.allocator(), .{
            .definition = .{ .typedef = .{ .ptr = &ctype_void } },
            .condition = .{ .placeholder = "is_win32" },
            .headers = &[_]HeaderId {
                winsock2_h, sys_types_h, sys_socket_h,
            },
        }) catch |e| oom(e);
        //symbol_defs.append(global.arena.allocator(), socket_t_def) catch |e| oom(e);
    }
}



fn parseJson(json_filename: []const u8) ![]SymbolDef {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const content = blk: {
        var file = try std.fs.cwd().openFile(json_filename, .{});
        defer file.close();
        break :blk try file.readToEndAlloc(arena.allocator(), std.math.maxInt(usize));
    };

    const tree = blk: {
        var parser = json.Parser.init(arena.allocator(), .alloc_if_needed);
        defer parser.deinit();

        const start = if (std.mem.startsWith(u8, content, "\xEF\xBB\xBF")) 3 else @as(usize, 0);
        const json_content = content[start..];
        std.log.info("parsing '{s}'...", .{json_filename});
        break :blk try parser.parse(json_content);
    };

    var symbols = std.ArrayListUnmanaged(SymbolDef){ };
    errdefer symbols.deinit(global.arena.allocator());

    //addHardcodedSymbols(&symbols);

    var root_it = tree.root.object.iterator();
    while (root_it.next()) |pair| {
        const id = global.addSymbol(global.arena.allocator().dupe(u8, pair.key_ptr.*) catch |e| oom(e));
        // TODO: handle error that value_ptr is not an Object?
        var info_obj = pair.value_ptr.*.object;

        jsonObjEnforceKnownFieldsOnly(info_obj, &.{ "headers", "defs" }, json_filename);
        // TODO: handle error that headers is not an Array
        const headers_json = jsonObjGetRequired(info_obj, "headers", json_filename).array;
        // TODO: handle error that defs is not an Array?
        const defs_json = jsonObjGetRequired(info_obj, "defs", json_filename).array;

        const headers = blk: {
            var headers = std.ArrayListUnmanaged(HeaderId){};
            errdefer headers.deinit(global.arena.allocator());
            for (headers_json.items) |headers_json_node| {
                // TODO: handle error that headers_json_node is not a String
                headers.append(global.arena.allocator(), global.toHeaderId(headers_json_node.string)) catch |e| oom(e);
            }
            break :blk headers.toOwnedSlice(global.arena.allocator()) catch |e| oom(e);
        };

        var defs = std.ArrayListUnmanaged(SymbolDef.SuperDef){ };
        errdefer defs.deinit(global.arena.allocator());
        for (defs_json.items) |def_json_node| {
            // TODO: handle error that def_json is not an Object
            const def_json = def_json_node.object;
            // TODO: handle error that kind is not a String
            //const kind = jsonObjGetRequired(def_json, "kind", json_filename).string;
            // TODO: handle error that condition is not a string
            const condition = jsonObjGetRequired(def_json, "condition", json_filename).string;
            // TODO: handle error that def is not a string
            const definition_str = jsonObjGetRequired(def_json, "def", json_filename).string;
            //std.log.info("{s}  = '{s}' (condition='{s}')", .{id, definition_str, condition});
            defs.append(global.arena.allocator(), SymbolDef.SuperDef{
                .headers = headers,
                .condition = .{ .placeholder = global.arena.allocator().dupe(u8, condition) catch |e| oom(e) },
                .definition = .{ .temp_generic_typedef = global.arena.allocator().dupe(u8, definition_str) catch |e| oom(e) },
            }) catch |e| oom(e);
        }

        symbols.append(global.arena.allocator(), SymbolDef{
            .id = id,
            .defs = try defs.toOwnedSlice(global.arena.allocator()),
        }) catch |e| oom(e);
    }
    return symbols.toOwnedSlice(global.arena.allocator());
}
pub fn jsonPanic() noreturn {
    @panic("an assumption about the json format was violated");
}
pub fn jsonObjEnforceKnownFieldsOnly(map: std.json.ObjectMap, known_fields: []const []const u8, file_for_error: []const u8) void {
    var it = map.iterator();
    fieldLoop: while (it.next()) |kv| {
        for (known_fields) |known_field| {
            if (std.mem.eql(u8, known_field, kv.key_ptr.*))
                continue :fieldLoop;
        }
        std.log.err("{s}: JSON object has unknown field '{s}', expected one of: {}\n", .{
            file_for_error,
            kv.key_ptr.*,
            formatSliceT([]const u8, "s", known_fields),
        });
        std.os.exit(0xff);
    }
}
fn jsonObjGetRequired(map: json.ObjectMap, field: []const u8, file_for_error: []const u8) json.Value {
    return map.get(field) orelse {
        // TODO: print file location?
        std.debug.print("{s}: json object is missing '{s}' field: {}\n", .{file_for_error, field, fmtJson(map)});
        std.os.exit(0xff);
    };
}


const JsonFormatter = struct {
    value: std.json.Value,
    pub fn format(
        self: JsonFormatter,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try std.json.stringify(self.value, .{}, writer);
    }
};
pub fn fmtJson(value: anytype) JsonFormatter {
    if (@TypeOf(value) == std.json.ObjectMap) {
        return .{ .value = .{ .object = value } };
    }
    if (@TypeOf(value) == std.json.array) {
        return .{ .value = .{ .array = value } };
    }
    if (@TypeOf(value) == []std.json.Value) {
        return .{ .value = .{ .array = std.json.Array  { .items = value, .capacity = value.len, .allocator = undefined } } };
    }
    return .{ .value = value };
}

fn SliceFormatter(comptime T: type, comptime spec: []const u8) type { return struct {
    slice: []const T,
    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        var first : bool = true;
        for (self.slice) |e| {
            if (first) {
                first = false;
            } else {
                try writer.writeAll(", ");
            }
            try std.fmt.format(writer, "{" ++ spec ++ "}", .{e});
        }
    }
};}
pub fn formatSliceT(comptime T: type, comptime spec: []const u8, slice: []const T) SliceFormatter(T, spec) {
    return .{ .slice = slice };
}

fn generateSymbolFiles(out_dir_path: []const u8, d_dir: std.fs.Dir, symbol_defs: []const SymbolDef) !void {
    for (symbol_defs) |symbol_def| {
        const symbol_str = global.symbols.items[symbol_def.id.index];
        std.log.info("creating '{s}/d/{s}", .{out_dir_path, symbol_str});
        var symbol_file = try d_dir.createFile(symbol_str, .{});
        defer symbol_file.close();
        const writer = symbol_file.writer();
        switch (global.include_guard_style) {
            .pragma => try writer.writeAll("#pragma once\n"),
            .ifdef => @panic("not implemented"),
        }
        var el_prefix: []const u8 = "";
        for (symbol_def.defs) |*def| {
            try writer.print("#{s}if {s}\n", .{el_prefix, def.condition.placeholder});
            el_prefix = "el";
            try generateDefinition(writer, symbol_def.id, def.definition);
        }
        try writer.print("#endif\n", .{});
    }
}
fn generateDefinition(writer: anytype, id: SymbolId, def: SymbolDef.Def) !void {
    switch (def) {
        .typedef => |t| {
            try writer.print("typedef {s} {s};\n", .{t, id});
        },
        .global_var => |t| {
            try writer.print("{s} {s};\n", .{t, id});
        },
        .macro => |s| {
            try writer.print("#define {s} {s}\n", .{id, s});
        },
        .temp_generic_typedef => |s| {
            try writer.print("typedef {s} {s};\n", .{s, id,});
        },
    }
}

const gen = struct {
    pub const Header = struct {
        symbols: std.AutoArrayHashMapUnmanaged(SymbolId, void),
    };
    pub fn prepare(al: std.mem.Allocator, symbol_defs: []const SymbolDef) ![]Header {
        var headers = try al.alloc(Header, global.header_map.count());
        errdefer al.free(headers);
        for (headers) |*header| {
            header.* = .{ .symbols = .{} };
        }

        for (symbol_defs) |symbol_def| {
            for (symbol_def.defs) |*def| {
                for (def.headers) |header_id| {
                    try headers[header_id.index].symbols.put(al, symbol_def.id, {});
                }
            }
        }
        return headers;
    }
};

fn oom(err: std.mem.Allocator.Error) noreturn {
    _ = err catch {};
    @panic("Out of memory");
}
