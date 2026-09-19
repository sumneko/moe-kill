local lm = require 'luamake'

lm.cxx = 'c++17'
lm.lua = "55"

local luaSrc  = lm:path("3rd/bee.lua/3rd/lua" .. lm.lua)
local luaDir  = lm:path("$builddir/moe-patched/lua" .. lm.lua)
local patches = {
    lm:path("3rd/bee.lua/3rd/lua-patch/optchain/lua" .. lm.lua .. ".patch"),
    lm:path("make/lua-patch/chinese-identifier/lua" .. lm.lua .. ".patch"),
}

lm:runlua "patch_lua" {
    script = "make/lua-patch/apply.lua",
    args = {
        luaSrc,
        luaDir,
        table.unpack(patches),
    },
    inputs = {
        lm:path("make/lua-patch/apply.lua"),
        luaSrc / "onelua.c",
        table.unpack(patches),
    },
    outputs = {
        luaDir / "onelua.c",
        luaDir / "lctype.h",
    },
}

lm:import "3rd/bee.lua/make.lua"

lm.luadir = luaDir

lm:source_set "source_moe_lua" {
    objdeps = "patch_lua",
    includes = {
        luaDir,
        "3rd/bee.lua/3rd/lua-patch",
    },
    sources = {
        luaDir / "onelua.c",
    },
    defines = "MAKE_LIB",
    visibility = "default",
    windows = {
        defines = "LUA_BUILD_AS_DLL",
    },
    macos = {
        defines = "LUA_USE_MACOSX",
    },
    linux = {
        defines = "LUA_USE_LINUX",
    },
    netbsd = {
        defines = "LUA_USE_LINUX",
    },
    freebsd = {
        defines = "LUA_USE_LINUX",
    },
    openbsd = {
        defines = "LUA_USE_LINUX",
    },
    android = {
        defines = "LUA_USE_LINUX",
    },
    msvc = lm.fast_setjmp ~= "off" and {
        defines = "BEE_FAST_SETJMP",
        flags = "/std:c11",
        sources = ("3rd/bee.lua/3rd/lua-patch/fast_setjmp_%s.s"):format(lm.arch),
    },
}

lm:executable "moe-kill" {
    deps = {
        "source_bee",
        "source_moe_lua",
        "source_bootstrap",
    },
    includes = {
        "3rd/bee.lua",
        luaDir,
        luaSrc,
    },
    sources = "make/modules.cpp",
}

local platform = require 'bee.platform'
local exe      = platform.os == 'windows' and ".exe" or ""

lm:copy "copy_moe-kill" {
    inputs = "$bin/moe-kill" .. exe,
    outputs = "server/bin/moe-kill" .. exe,
}

lm:copy "copy_bootstrap" {
    inputs = "make/bootstrap.lua",
    outputs = "server/bin/main.lua",
}

lm:msvc_copydll "copy_vcrt" {
    type = "vcrt",
    outputs = "server/bin",
}

lm:phony "all" {
    deps = {
        "moe-kill",
        "copy_moe-kill",
        "copy_bootstrap",
    },
    windows = {
        deps = {
            "copy_vcrt",
        },
    },
}

if lm.notest then
    lm:default {
        "all",
    }
    return
end

lm:rule "run-unit-test" {
    args = { "server/bin/moe-kill" .. exe, "--test" },
    description = "Run test.",
    pool = "console",
}

lm:build "unit-test" {
    rule = "run-unit-test",
    deps = { "all" },
}

lm:default {
    "unit-test",
}
