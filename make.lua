local lm = require 'luamake'

lm.cxx = 'c++17'
lm.lua = "55"
lm.optchain = true

lm:import "3rd/bee.lua/make.lua"

lm:executable "moe-kill" {
    deps = {
        "source_bee",
        "source_lua",
        "source_bootstrap",
    },
    includes = {
        "3rd/bee.lua",
        "3rd/bee.lua/3rd/lua" .. lm.lua,
    },
    sources = "make/modules.cpp",
}

local platform = require 'bee.platform'
local exe      = platform.os == 'windows' and ".exe" or ""

lm:copy "copy_moe-kill" {
    inputs = "$bin/moe-kill" .. exe,
    outputs = "bin/moe-kill" .. exe,
}

lm:copy "copy_bootstrap" {
    inputs = "make/bootstrap.lua",
    outputs = "bin/main.lua",
}

lm:msvc_copydll "copy_vcrt" {
    type = "vcrt",
    outputs = "bin",
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
    args = { "bin/moe-kill" .. exe, "--test" },
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
