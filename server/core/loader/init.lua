local vfs      = require 'core.loader.vfs'
local preparse = require 'core.loader.preparse'

---@class Loader.InstallOptions
---@field sources? string[] # 包来源（省略时用局上记的来源，再退到默认来源）
---@field packages? string[] # 加载清单（省略时用局上记的清单）

---@class Loader.Context
---@field vfs Loader.Vfs
---@field loading table<string, true>
---@field loaded table<string, true>
---@field order string[]
---@field current? string # 正在执行的文件（逻辑路径）
---@field public package? string # 正在执行的文件的所属包
---@field excludes table<string, string> # 互斥项 → 声明者

---@class Loader.MetaFile
---@field logical string
---@field source string
---@field ok boolean
---@field err? string
---@field entries string[]

---@class Loader.PackageMeta
---@field name string
---@field depends string[]
---@field excludes string[]
---@field entries string[]
---@field files Loader.MetaFile[]

---@class Loader.Plan
---@field meta table<string, Loader.PackageMeta>
---@field loaded table<string, true>
---@field excludes table<string, string>

---@class Loader # 装载器模块（无状态）：把规则装进某个局
---@field DEFAULT_SOURCES string[]
---@field install fun(game: Game, options?: Loader.InstallOptions): string[]
---@field declareDepends fun(game: Game, ctx: Loader.Context, items: string[])
local M = {}

---@type string[] # 默认来源：仓库根下项目自己的包容器
M.DEFAULT_SOURCES = { './package/*' }

---@type string[]
local ALLOWED_GLOBALS = {
    '_VERSION',
    'assert', 'error', 'getmetatable', 'ipairs', 'math', 'next', 'pairs', 'pcall',
    'print', 'rawequal', 'rawget', 'rawlen', 'rawset', 'select', 'setmetatable',
    'string', 'table', 'tonumber', 'tostring', 'type', 'utf8', 'xpcall',
}

---@param extra table<string, any> # 除标准库白名单外，额外注入的东西（game / Card / Depends）
---@return table
local function makeEnv(extra)
    ---@type table<string, any>
    local env = {}
    for _, name in ipairs(ALLOWED_GLOBALS) do
        env[name] = _G[name]
    end
    for name, value in pairs(extra) do
        env[name] = value
    end
    return env
end

---@param logical string
---@return string? # 包名（逻辑路径的第一层目录）
local function packageOf(logical)
    return logical:match '^([^/]+)/'
end

---@param path string
---@return string
local function parentLogical(path)
    return path:match '^(.*)/[^/]*$' or ''
end

---@param current? string # 当前文件的逻辑路径（相对路径的基准）
---@param item string
---@return string
local function resolveItem(current, item)
    if item:sub(1, 1) ~= '.' then
        return vfs.normalize(item)
    end
    if not current then
        error('相对路径只能用在规则集文件里：{}' % { item }, 0)
    end
    return vfs.normalize(parentLogical(current) .. '/' .. item)
end

---@param game Game
---@param ctx Loader.Context
---@param logical string
local function loadFile(game, ctx, logical)
    if ctx.loaded[logical] or ctx.loading[logical] then
        return
    end
    local owner = packageOf(logical)
    if not owner then
        error('规则集文件必须位于包目录里：{}' % { logical }, 0)
    end
    if logical:find('/@', 1, true) then
        error('"@" 只能出现在包目录名的开头：{}' % { logical }, 0)
    end
    if owner:find('.', 1, true) then
        error('包目录名里不能含 "."：{}' % { owner }, 0)
    end
    local source, err = ctx.vfs:read(logical)
    if not source then
        error('规则集文件读取失败：{}（{}）' % { logical, err }, 0)
    end
    local chunk, loadErr = load(source, '@' .. (ctx.vfs:resolve(logical) or logical), 't', makeEnv {
        game    = game,
        Card    = function (name) return game:declareCard(name) end,
        Depends = function (items) return M.declareDepends(game, ctx, items) end,
    })
    if not chunk then
        error('规则集文件解析失败：{}（{}）' % { logical, loadErr }, 0)
    end
    local previous        = ctx.current
    local previousPackage = ctx.package
    ctx.current           = logical
    ctx.package           = owner
    ctx.loading[logical]  = true
    local guard <close> = moe.util.defer(function ()
        ctx.loading[logical] = nil
        ctx.current          = previous
        ctx.package          = previousPackage
    end)
    chunk()
    ctx.loaded[logical] = true
    ctx.order[#ctx.order+1] = logical
end

---@param game Game
---@param ctx Loader.Context
---@param logicalDir string
local function loadDirectory(game, ctx, logicalDir)
    for _, logical in ipairs(ctx.vfs:listFiles(logicalDir)) do
        loadFile(game, ctx, logical)
    end
end

---@param game Game
---@param ctx Loader.Context
---@param item string
local function loadItem(game, ctx, item)
    if type(item) ~= 'string' or item == '' then
        error('规则集项必须是非空字符串', 0)
    end
    local logical = resolveItem(ctx.current, item)
    if ctx.vfs:isFile(logical) then
        loadFile(game, ctx, logical)
        return
    end
    if ctx.vfs:isFile(logical .. '.lua') then
        loadFile(game, ctx, logical .. '.lua')
        return
    end
    if ctx.vfs:isDirectory(logical) then
        loadDirectory(game, ctx, logical)
        return
    end
    error('规则集项不存在：{}' % { item }, 0)
end

---@param logical string
---@param item string
---@return boolean
local function matchItem(logical, item)
    return logical == item or logical:sub(1, #item + 1) == item .. '/'
end

---@param loaded table<string, true>
---@param item string
---@return string? # 命中的逻辑路径
local function findLoaded(loaded, item)
    for logical in pairs(loaded) do
        if matchItem(logical, item) then
            return logical
        end
    end
    return nil
end

---@param loaded table<string, true>
---@param excludes table<string, string>
local function checkExcludes(loaded, excludes)
    for item, owner in pairs(excludes) do
        local hit = findLoaded(loaded, item)
        if hit then
            error('互斥冲突：{} 声明了 !{}，但本轮加载了 {}' % { owner, item, hit }, 0)
        end
    end
end

---@param meta table<string, Loader.PackageMeta>
local function checkDuplicates(meta)
    for _, packageMeta in pairs(meta) do
        ---@type table<string, string>
        local owners = {}
        for _, file in ipairs(packageMeta.files) do
            for _, name in ipairs(file.entries) do
                local first = owners[name]
                if first then
                    error('同一个包里重复声明了 {}：{} 与 {}' % { name, first, file.logical }, 0)
                end
                owners[name] = file.logical
            end
        end
    end
end

---@param instance Loader.Vfs
---@param list string[]
---@return Loader.Plan
local function prepare(instance, list)
    ---@type Loader.Plan
    local plan = {
        meta     = {},
        loaded   = {},
        excludes = {},
    }
    ---@type string[]
    local queue = {}
    ---@type table<string, true>
    local seen = {}

    ---@param item string
    local function expandItem(item)
        local logical = vfs.normalize(item)
        ---@type string[]
        local found
        if instance:isFile(logical) then
            found = { logical }
        elseif instance:isFile(logical .. '.lua') then
            found = { logical .. '.lua' }
        elseif instance:isDirectory(logical) then
            found = instance:listFiles(logical)
        else
            error('规则集项不存在：{}' % { item }, 0)
        end
        for _, path in ipairs(found) do
            if not seen[path] then
                seen[path] = true
                queue[#queue+1] = path
            end
        end
    end

    for _, item in ipairs(list) do
        expandItem(item)
    end

    local index = 1
    while index <= #queue do
        local logical = queue[index]
        index = index + 1

        local owner = packageOf(logical)
        if not owner then
            error('规则集文件必须位于包目录里：{}' % { logical }, 0)
        end
        local packageMeta = plan.meta[owner]
        if not packageMeta then
            packageMeta = {
                name     = owner,
                depends  = {},
                excludes = {},
                entries  = {},
                files    = {},
            }
            plan.meta[owner] = packageMeta
        end

        local source, readErr = instance:read(logical)
        if not source then
            error('规则集文件读取失败：{}（{}）' % { logical, readErr }, 0)
        end

        ---@type Loader.MetaFile
        local file = {
            logical = logical,
            source  = instance:resolve(logical) or logical,
            ok      = true,
            entries = {},
        }
        packageMeta.files[#packageMeta.files+1] = file
        plan.loaded[logical] = true

        ---@type string[]
        local declaredDepends = {}
        ---@type string[]
        local declaredExcludes = {}

        local probe = {
            Depends = function (items)
                if type(items) ~= 'table' then
                    error('Depends 需要一个字符串列表', 2)
                end
                for _, item in ipairs(items) do
                    if type(item) ~= 'string' or item == '' then
                        error('依赖项必须是非空字符串', 2)
                    end
                    if item:sub(1, 1) == '!' then
                        declaredExcludes[#declaredExcludes+1] = resolveItem(logical, item:sub(2))
                    else
                        declaredDepends[#declaredDepends+1] = resolveItem(logical, item)
                    end
                end
            end,
            Card = function (name)
                if type(name) == 'string' and name ~= '' then
                    file.entries[#file.entries+1] = name
                    packageMeta.entries[#packageMeta.entries+1] = name
                end
            end,
        }

        local ok, err = preparse.run(source, '@' .. file.source, makeEnv(probe))
        if not ok then
            file.ok  = false
            file.err = err
            log.warn('规则集预解析失败：{}（{}）' % { logical, err })
        end

        for _, item in ipairs(declaredDepends) do
            packageMeta.depends[#packageMeta.depends+1] = item
            expandItem(item)
        end
        for _, item in ipairs(declaredExcludes) do
            packageMeta.excludes[#packageMeta.excludes+1] = item
            plan.excludes[item] = plan.excludes[item] or logical
        end
    end

    return plan
end

---@param game Game
---@param ctx Loader.Context
---@param items string[]
function M.declareDepends(game, ctx, items)
    if type(items) ~= 'table' then
        error('Depends 需要一个字符串列表', 2)
    end
    if game.loading ~= ctx then
        error('Depends 只能在加载规则集时声明', 2)
    end
    for _, item in ipairs(items) do
        if type(item) ~= 'string' or item == '' then
            error('依赖项必须是非空字符串', 2)
        end
        if item:sub(1, 1) == '!' then
            local target = resolveItem(ctx.current, item:sub(2))
            local hit    = findLoaded(ctx.loaded, target)
            if hit then
                error('互斥冲突：{} 声明了 !{}，但本轮已经加载了 {}' % { ctx.current, target, hit }, 2)
            end
            ctx.excludes[target] = ctx.excludes[target] or ctx.current
        else
            loadItem(game, ctx, item)
        end
    end
end

---@param game Game
---@param options? Loader.InstallOptions
---@return string[] # 实际执行过的文件（逻辑路径），按执行完成顺序
function M.install(game, options)
    options = options or {}
    if options.sources ~= nil and type(options.sources) ~= 'table' then
        error('规则集来源必须是字符串列表', 2)
    end
    if options.packages ~= nil and type(options.packages) ~= 'table' then
        error('加载清单必须是字符串列表', 2)
    end
    local sources = options.sources or game.sources or M.DEFAULT_SOURCES
    local list    = options.packages or game.list or {}
    game.sources  = sources
    game.list     = list

    local instance = vfs.create(sources, moe.env.ROOT_PATH:parent_path())

    ---@type string[]
    local items = {}
    for _, name in ipairs(instance:getDefaultPackages()) do
        items[#items+1] = name
    end
    for _, item in ipairs(list) do
        items[#items+1] = item
    end

    local plan = prepare(instance, items)

    checkExcludes(plan.loaded, plan.excludes)
    checkDuplicates(plan.meta)

    game:resetContent()

    ---@type Loader.Context
    local ctx = {
        vfs      = instance,
        loading  = {},
        loaded   = {},
        order    = {},
        excludes = {},
    }
    game.loading = ctx
    local guard <close> = moe.util.defer(function ()
        game.loading = nil
    end)

    for _, item in ipairs(items) do
        loadItem(game, ctx, item)
    end

    checkExcludes(ctx.loaded, ctx.excludes)
    game.meta        = plan.meta
    game.loadedFiles = ctx.order

    return ctx.order
end

return M
