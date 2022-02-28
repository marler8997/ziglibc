pub const core_objects = [_][]const u8{
    "lapi", "lcode",   "lctype",   "ldebug",  "ldo",    "ldump",   "lfunc",  "lgc", "llex",
    "lmem", "lobject", "lopcodes", "lparser", "lstate", "lstring", "ltable", "ltm", "lundump",
    "lvm",  "lzio",    "ltests",
};
pub const aux_objects = [_][]const u8{"lauxlib"};
pub const lib_objects = [_][]const u8{
    "lbaselib", "ldblib",  "liolib",   "lmathlib", "loslib", "ltablib", "lstrlib",
    "lutf8lib", "loadlib", "lcorolib", "linit",
};
