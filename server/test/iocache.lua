-- 测试期的装载缓存：把「扫目录 / 读文件 / 预解析试跑」的结果留住（产品代码零改动，只在 server/test.lua 里启用）
-- 测试进程内随仓库走的文件不会变，所以能这么干；但探针套件会往 tmp/ 下反复删建目录
-- ⇒ 只缓存 package/ 下的路径，tmp/ 一律直通（保证探针用例永远读到刚写下的内容）。
-- 本文件整篇都是「替掉内核函数」的包装，类型面按原签名对不上 ⇒ 这几条诊断整文件关掉：
---@diagnostic disable: duplicate-set-field, param-type-mismatch, assign-type-mismatch, return-type-mismatch, cast-local-type

local fs = require 'bee.filesystem'

local M = {}

---@param path string
---@return boolean # 能不能缓存（只缓存仓库里的产品包；探针 / fixture 在 tmp/ 下，会变）
local function cacheable(path)
    return path:find('[/\\]package[/\\]') ~= nil
end

function M.enable()
    -- 目录列表：package/ 下的目录在测试期不会变，记一次就够
    ---@type table<string, string[]>
    local dirCache = {}
    local realPairs = fs.pairs
    fs.pairs = function (dir)
        local key = dir:string()
        if not cacheable(key) then
            return realPairs(dir)
        end
        local list = dirCache[key]
        if not list then
            list = {}
            for entry in realPairs(dir) do
                list[#list+1] = entry
            end
            dirCache[key] = list
        end
        local index = 0
        return function ()
            index = index + 1
            return list[index]
        end
    end

    -- 文件内容
    ---@type table<string, string>
    local fileCache = {}
    local realLoadFile = moe.util.loadFile
    moe.util.loadFile = function (path)
        if not cacheable(path) then
            return realLoadFile(path)
        end
        local text = fileCache[path]
        if text == nil then
            local err
            text, err = realLoadFile(path)
            if text == nil then
                return nil, err
            end
            fileCache[path] = text
        end
        return text
    end

    -- 预解析试跑只做一件事：让 chunk 去调 stub 上那五个函数（Depends / Card / Buff / Hero / Skill）
    -- ⇒ 记下这些调用，下次直接重放（不编译、不执行 chunk）
    ---@type table<string, { name: string, args: table }[]>
    local probeCache = {}

    ---@type string[]
    local RECORDED = { 'Depends', 'Card', 'Buff', 'Hero', 'Skill' }

    local preparse = require 'core.loader.preparse'
    local realRun  = preparse.run
    preparse.run = function (source, chunkname, env)
        if not cacheable(chunkname) then
            return realRun(source, chunkname, env)
        end
        local calls = probeCache[chunkname]
        if calls then
            for _, call in ipairs(calls) do
                env[call.name](table.unpack(call.args, 1, call.args.n))
            end
            return true
        end

        calls = {}
        for _, name in ipairs(RECORDED) do
            local real = env[name]
            env[name] = function (...)
                calls[#calls+1] = { name = name, args = table.pack(...) }
                return real(...)
            end
        end

        local ok, err = realRun(source, chunkname, env)
        if ok then
            probeCache[chunkname] = calls
        end
        return ok, err
    end
end

return M
