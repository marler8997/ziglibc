const std = @import("std");

const SymbolDef = struct {
    definition: []const u8,
    condition: []const u8,
    //headers: std.ArrayListUnmanaged([]const u8),
};
const Symbol = struct {
    name: []const u8,
    headers: std.ArrayListUnmanaged([]const u8),
    defs: std.ArrayListUnmanaged(SymbolDef),
};
const Symbols = struct {
    allocator: std.mem.Allocator,
    map: std.StringHashMapUnmanaged(SymbolId) = .{},
    filename_set: std.StringHashMapUnmanaged([]const u8) = .{},
    list: std.ArrayListUnmanaged(Symbol) = .{},
    pub fn dupe(self: Symbols, comptime T: type, m: []const T) []T {
        return self.allocator.dupe(T, m) catch |e| oom(e);
    }
    pub fn newFilename(self: *Symbols, optional_base: ?[]const u8, sub: []const u8) []const u8 {
        if (optional_base) |base| {
            var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
            const path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{base, sub}) catch @panic("filename too long");
            return self.newFilename(null, path);
        } else {
            if (self.filename_set.get(sub)) |perm| return perm;
            const perm = self.dupe(u8, sub);
            self.filename_set.put(self.allocator, perm, perm) catch |e| oom(e);
            return perm;
        }
    }
    pub fn lookup(self: *Symbols, name_transient: []const u8) SymbolId {
        if (self.map.get(name_transient)) |id| return id;

        const name_permanent = self.allocator.dupe(u8, name_transient) catch |e| oom(e);
        const new_id = SymbolId{ .index = self.list.items.len };
        self.map.put(self.allocator, name_permanent, new_id) catch |e| oom(e);
        self.list.append(self.allocator, Symbol{
            .name = name_permanent,
            .defs = .{},
            .headers = .{},
        }) catch |e| oom(e);
        return new_id;
    }
    pub fn getRef(self: *Symbols, id: SymbolId) *Symbol {
        return &self.list.items[id.index];
    }
    pub fn addHeader(self: *Symbols, id: SymbolId, filename: []const u8) void {
        std.debug.assert(filename.ptr == self.newFilename(null, filename).ptr);
        for (self.getRef(id).headers.items) |existing| {
            if (existing.ptr == filename.ptr)
                return;
        }
        self.getRef(id).headers.append(self.allocator, filename) catch |e| oom(e);
    }
    pub fn addDef(self: *Symbols, id: SymbolId, def: SymbolDef) void {
        self.getRef(id).defs.append(self.allocator, def) catch |e| oom(e);
    }
};

const SymbolId = struct {
    index: usize,
    pub fn toStr(self: SymbolId, symbols: *Symbols) []const u8{
        return symbols.list.items[self.index].name;
    }
};

fn fatal(comptime fmt: []const u8, args: anytype) noreturn {
    std.log.err(fmt, args);
    std.os.exit(0xff);
}
fn oom(err: std.mem.Allocator.Error) noreturn {
    _ = err catch {};
    @panic("Out of memory");
}

pub fn main() !u8 {
    var args_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // no need to free
    const full_args = try std.process.argsAlloc(args_arena.allocator());
    if (full_args.len <= 1) {
        try std.io.getStdErr().writer().writeAll("Usage: uhscrape OUT_FILE INCLUDE_PATHS...\n");
        return 0xff;
    }
    const args = full_args[1..];
    if (args.len < 2) {
        std.log.err("expected at least 2 cmdline args but got {}", .{args.len});
        return 0xff;
    }
    const out_filename = args[0];
    const in_dirs = args[1..];

    var symbols_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // no need to free
    var symbols = Symbols{ .allocator = symbols_arena.allocator() };
    
    for (in_dirs) |in_dir| {
        var dir  = try std.fs.cwd().openIterableDir(in_dir, .{});
        defer dir.close();
        try scrapeDir(&symbols, dir, null);
    }

    try writeJson(out_filename, symbols);
    
    return 0;
}

fn writeJson(out_filename: []const u8, symbols: Symbols) !void {
    var out_file = try std.fs.cwd().createFile(out_filename, .{});
    defer out_file.close();
    const writer = out_file.writer();
    try writer.writeAll("{\n");
    var top_level_key_prefix: []const u8 = " ";
    for (symbols.list.items) |*sym| {
        try writer.print("{s}\"{s}\": {{ \"headers\": [\n", .{top_level_key_prefix, sym.name});
        // TODO: should we sort the headers for pure output?
        {
            var list_prefix: []const u8 = " ";
            for (sym.headers.items) |header| {
                try writer.print("    {s}\"{s}\"\n", .{list_prefix, header});
                list_prefix = ",";
            }
            try writer.writeAll("], \"defs\": [\n");
        }
        {
            var list_prefix: []const u8 = " ";
            for (sym.defs.items) |def| {
                try writer.print("  {s}{{ \"condition\": \"{s}\", \"def\": \"{s}\" }}\n", .{list_prefix, def.condition, fmtNoTabs(def.definition)});
                list_prefix = ",";
            }
            try writer.writeAll("]}\n");
        }
        top_level_key_prefix = ",";
    }
    try writer.writeAll("}\n");
}

// TODO: this will not be needed eventually
const NoTabsFormatter = struct {
    s: []const u8,
    pub fn format(
        self: NoTabsFormatter,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        // this is slow, but only temporary
        for (self.s) |c| {
            try writer.writeIntNative(u8, if (c == '\t') ' ' else c);
        }
    }
};
pub fn fmtNoTabs(s: []const u8) NoTabsFormatter {
    return NoTabsFormatter{ .s = s };
}


fn scrapeDir(symbols: *Symbols, dir: std.fs.IterableDir, base: ?[]const u8) !void {
    //std.log.info("todo: scape '{s}'", .{path});
    var it = dir.iterate();
    while (try it.next()) |entry| {
        switch (entry.kind) {
            .directory => {
                var subdir = try dir.dir.openIterableDir(entry.name, .{});
                defer subdir.close();
                try scrapeDir(symbols, subdir, symbols.newFilename(base, entry.name));
            },
            .file => {
                var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
                defer arena.deinit();
                const content = blk: {
                    var file = try dir.dir.openFile(entry.name, .{});
                    defer file.close();
                    break :blk try file.readToEndAlloc(arena.allocator(), std.math.maxInt(usize));
                };
                try scrapeFile(symbols.newFilename(base, entry.name), symbols, content);
            },
            .sym_link => {
                var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
                const target = try dir.dir.readLink(entry.name, &path_buf);
                _ = target;
                //std.log.warn("TODO: handle symlink '{s}' > '{s}'", .{entry.name, target});
            },
            else => {
                std.log.err("file '{s}' has unexpected kind '{s}'", .{entry.name, @tagName(entry.kind)});
                std.os.exit(0xff);
            },
        }
    }

}

fn isIdentifierChar(c: u8) bool {
    return c == '_' or std.ascii.isAlphanumeric(c);
}

fn reverseScanWhile(s: []const u8, cond: *const fn(c: u8) bool) usize {
    var offset = s.len;
    while (offset > 0) {
        offset -= 1;
        if (!cond(s[offset])) {
            return offset + 1;
        }
    }
    return 0;
}

fn reverseScanWhileNot(s: []const u8, cond: *const fn(c: u8) bool) usize {
    var offset = s.len;
    while (offset > 0) {
        offset -= 1;
        if (cond(s[offset])) {
            return offset + 1;
        }
    }
    return 0;
}

const inline_whitespace = " \t\r";
    
fn scrapeFile(filename: []const u8, symbols: *Symbols, content: []const u8) !void {
    // really dumb scraper for now
    var line_it = std.mem.split(u8, content, "\n");
    var line_num: u32 = 0;
    while (line_it.next()) |line_raw| {
        line_num += 1;
        const line = std.mem.trim(u8, line_raw, inline_whitespace);
        if (std.mem.startsWith(u8, line, "#define")) {
            //std.log.info("    {}: '{s}'", .{line_num, line});
        } else if (std.mem.startsWith(u8, line, "typedef")) {
            if (!std.mem.endsWith(u8, line, ";")) {
                //std.log.info("ignoring {s}:{} '{s}'", .{filename, line_num, line});
                continue;
            }

            const typedef = std.mem.trim(u8, line[7..line.len - 1], inline_whitespace);
            if (std.mem.endsWith(u8, typedef, ")")) {
                //std.log.info("{s}:{} ignoring function typedef '{s}' = '{s}'", .{filename, line_num, symbol, def});
                continue;
            }
            if (std.mem.endsWith(u8, typedef, "]")) {
                //std.log.info("{s}:{} ignoring array typedef '{s}' = '{s}'", .{filename, line_num, symbol, def});
                continue;
            }
            if (std.mem.endsWith(u8, typedef, ">")) {
                //std.log.info("{s}:{} ignoring template typedef '{s}'", .{filename, line_num, typedef});
                continue;
            }

            const symbol_end = reverseScanWhileNot(typedef, isIdentifierChar);
            const symbol_start = reverseScanWhile(typedef[0..symbol_end], isIdentifierChar);

            const suffix = std.mem.trimLeft(u8, typedef[symbol_end..], inline_whitespace);
            const symbol = typedef[symbol_start .. symbol_end];
            const def = std.mem.trimRight(u8, typedef[0 .. symbol_start], inline_whitespace);

            if (suffix.len > 0)
                fatal("{s}:{} unhandled typedef suffix '{s}' '{s}'", .{filename, line_num, suffix, line});
            std.debug.assert(symbol.len > 0);
            if (def.len == 0)
                fatal("unhandled typedef line '{s}' def is empty", .{line});
            //_ = filename;

            //std.log.info("{s}:{}: TYPEDEF '{s}' = '{s}'", .{filename, line_num, symbol, def});
            const symbol_id = symbols.lookup(symbol);
            symbols.addHeader(symbol_id, filename);
            // TODO: put a real condition here
            const condition = "1";

            // check if the definition already exists
            const already_added = blk: {
                for (symbols.getRef(symbol_id).defs.items) |existing| {
                    if (std.mem.eql(u8, existing.definition, def) and std.mem.eql(u8, existing.condition, condition)) {
                        break :blk true; // already added
                    }
                }
                break :blk false; // not already added
            };
            if (!already_added) {
                symbols.addDef(symbol_id, SymbolDef{
                    .definition = symbols.dupe(u8, def),
                    .condition = condition,
                    //.headers = .{},
                });
            }
        }
    }
}

