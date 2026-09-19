local vfs      = require 'rule.vfs'
local preparse = require 'rule.preparse'

---@class Rule.Card
---@field name string # 裸名
---@field public package string # 所属包名（显式写 public：否则 package 会被当成访问修饰符）
---@field fullName string # 完整名（包名.名字）
---@field source string # 声明它的文件（逻辑路径）
---@field private handlers table<string, function[]>
local Card = Class 'Rule.Card'

---@param name string
---@param owner string
---@param source string
function Card:__init(name, owner, source)
    self.name     = name
    self.package  = owner
    self.fullName = owner .. '.' .. name
    self.source   = source
    self.handlers = {}
end

---@param event string
---@param handler function
---@return Rule.Card
function Card:on(event, handler)
    local list = self.handlers[event]
    if not list then
        list = {}
        self.handlers[event] = list
    end
    list[#list+1] = handler
    return self
end

---@param event string
---@return function[]
function Card:getHandlers(event)
    ---@type function[]
    local snapshot = {}
    local list = self.handlers[event]
    if list then
        table.move(list, 1, #list, 1, snapshot)
    end
    return snapshot
end

---@class Rule.Context
---@field vfs Rule.Vfs
---@field loading table<string, true>
---@field loaded table<string, true>
---@field order string[]
---@field current string?
---@field excludes table<string, string> # 互斥项 → 声明者

---@type string[]
local ALLOWED_GLOBALS = {
    '_VERSION',
    'assert', 'error', 'getmetatable', 'ipairs', 'math', 'next', 'pairs', 'pcall',
    'print', 'rawequal', 'rawget', 'rawlen', 'rawset', 'select', 'setmetatable',
    'string', 'table', 'tonumber', 'tostring', 'type', 'utf8', 'xpcall',
}

---@class Rule.MetaFile
---@field logical string
---@field source string
---@field ok boolean
---@field err? string
---@field entries string[]

---@class Rule.PackageMeta
---@field name string
---@field depends string[]
---@field excludes string[]
---@field entries string[]
---@field files Rule.MetaFile[]

---@class Rule.Plan
---@field meta table<string, Rule.PackageMeta>
---@field loaded table<string, true>
---@field excludes table<string, string>

---@class Rule
---@field cards table<string, table<string, Rule.Card>> # 包名 → 裸名 → 定义
---@field packages string[] # 包的加载顺序（首次出现的顺序）
---@field events Core.Event # 时机注册（随每次加载重置）
---@field meta table<string, Rule.PackageMeta> # 包元信息（预解析产物，随每次加载重建）
---@field values table<string, any> # 规则数值（按加载顺序后者覆盖前者，随每次加载清空）
---@field private context Rule.Context?
---@field private lastList string[]?
local M = {}

---@type string[] # 默认来源：仓库根下项目自己的包容器
M.DEFAULT_SOURCES = { './package/*' }

---@type table<string, table<string, Rule.Card>>
M.cards = {}

---@type string[] # 包的加载顺序
M.packages = {}

---@type Core.Event # 时机注册（每次加载重置）
M.events = moe.core.event.create()

---@type table<string, Rule.PackageMeta>
M.meta = {}

---@type table<string, any>
M.values = {}

---@type string[] # 当前来源
M.sources = M.DEFAULT_SOURCES

---@private
---@type Rule.Context?
M.context = nil

---@private
---@type string[]?
M.lastList = nil

---@param ruleTable table
---@return table
local function makeEnv(ruleTable)
    ---@type table<string, any>
    local env = {
        rule = ruleTable,
    }
    for _, name in ipairs(ALLOWED_GLOBALS) do
        env[name] = _G[name]
    end
    return env
end

---@param logical string
---@return string? # 包名（逻辑路径的第一层目录）
local function packageOf(logical)
    return logical:match '^([^/]+)/'
end

---@param name string
---@param level integer
local function checkSimpleName(name, level)
    if type(name) ~= 'string' or name == '' then
        error('规则名必须是非空字符串', level)
    end
    if name:find('.', 1, true) then
        error('规则名里不能含 "."（完整名由加载器拼接）：{}' % { name }, level)
    end
end

---@param name string
---@return string? # 包名（限定名才有）
---@return string # 条目名
local function splitName(name)
    if type(name) ~= 'string' or name == '' then
        error('规则名必须是非空字符串', 3)
    end
    local owner, entry = name:match '^([^%.]+)%.(.+)$'
    if owner then
        return owner, entry
    end
    return nil, name
end

---@param name string
---@return Rule.Card?
function M.getCard(name)
    local owner, entry = splitName(name)
    if owner then
        local cards = M.cards[owner]
        return cards and cards[entry] or nil
    end
    local ctx = M.context
    local current = ctx and ctx.current
    local mine    = current and packageOf(current)
    if mine then
        local cards = M.cards[mine]
        local found = cards and cards[entry]
        if found then
            return found
        end
    end
    for _, package in ipairs(M.packages) do
        local cards = M.cards[package]
        local found = cards and cards[entry]
        if found then
            return found
        end
    end
    return nil
end

---@param name string
---@return Rule.Card
function M.card(name)
    local ctx = M.context
    if not ctx then
        error('规则定义只能在加载规则集时声明', 2)
    end
    local current = ctx.current
    local owner   = current and packageOf(current)
    if not owner then
        error('规则定义只能写在包目录里的文件里', 2)
    end
    checkSimpleName(name, 2)
    local cards = M.cards[owner]
    if not cards then
        cards = {}
        M.cards[owner] = cards
        M.packages[#M.packages+1] = owner
    end
    local existing = cards[name]
    if existing then
        error('同一个包里重复声明了 {}：{} 与 {}' % { name, existing.source, current }, 2)
    end
    local card = New 'Rule.Card' (name, owner, current)
    cards[name] = card
    return card
end

---@private
function M.clear()
    M.cards    = {}
    M.packages = {}
    M.meta     = {}
    M.values   = {}
    M.events:clear()
end

---@param name string
---@param value any
function M:setValue(name, value)
    if type(name) ~= 'string' or name == '' then
        error('规则数值的名字必须是非空字符串', 2)
    end
    M.values[name] = value
end

---@param values table<string, any>
function M:setValues(values)
    if type(values) ~= 'table' then
        error('规则数值必须是一张名字到值的表', 2)
    end
    for name, value in pairs(values) do
        M:setValue(name, value)
    end
end

---@param name string
---@return any # 没设置过就是「不存在」
function M:getValue(name)
    if type(name) ~= 'string' or name == '' then
        error('规则数值的名字必须是非空字符串', 2)
    end
    return M.values[name]
end

---@return table<string, any>
function M:getValues()
    ---@type table<string, any>
    local result = {}
    for name, value in pairs(M.values) do
        result[name] = value
    end
    return result
end

---@return Core.AttributeSystem
function M:createAttributeSystem()
    return moe.core.attribute.create()
end

---@param name string
---@return Core.Card
function M:createCard(name)
    if type(name) ~= 'string' or name == '' then
        error('牌名必须是非空字符串', 2)
    end
    return moe.core.card.create(name)
end

---@return Core.Zone
function M:createZone()
    return moe.core.zone.create()
end

---@return Core.OrderedZone
function M:createOrderedZone()
    return moe.core.orderedZone.create()
end

---@param meta Rule.PackageMeta
---@return Rule.PackageMeta
local function copyMeta(meta)
    ---@type Rule.PackageMeta
    local copy = {
        name     = meta.name,
        depends  = {},
        excludes = {},
        entries  = {},
        files    = {},
    }
    table.move(meta.depends, 1, #meta.depends, 1, copy.depends)
    table.move(meta.excludes, 1, #meta.excludes, 1, copy.excludes)
    table.move(meta.entries, 1, #meta.entries, 1, copy.entries)
    for i, file in ipairs(meta.files) do
        ---@type Rule.MetaFile
        local copied = {
            logical = file.logical,
            source  = file.source,
            ok      = file.ok,
            err     = file.err,
            entries = {},
        }
        table.move(file.entries, 1, #file.entries, 1, copied.entries)
        copy.files[i] = copied
    end
    return copy
end

---@param name string
---@return Rule.PackageMeta?
function M:getPackageMeta(name)
    local meta = M.meta[name]
    if not meta then
        return nil
    end
    return copyMeta(meta)
end

---@return table<string, Rule.PackageMeta>
function M:getMetas()
    ---@type table<string, Rule.PackageMeta>
    local result = {}
    for name, meta in pairs(M.meta) do
        result[name] = copyMeta(meta)
    end
    return result
end

---@param path string
---@return string
local function parentLogical(path)
    return path:match '^(.*)/[^/]*$' or ''
end

---@param current string? # 当前文件的逻辑路径（相对路径的基准）
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

---@param ctx Rule.Context
---@param logical string
local function loadFile(ctx, logical)
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
    local chunk, loadErr = load(source, '@' .. (ctx.vfs:resolve(logical) or logical), 't', makeEnv(M))
    if not chunk then
        error('规则集文件解析失败：{}（{}）' % { logical, loadErr }, 0)
    end
    local previous = ctx.current
    ctx.current    = logical
    ctx.loading[logical] = true
    local guard <close> = moe.util.defer(function ()
        ctx.loading[logical] = nil
        ctx.current         = previous
    end)
    chunk()
    ctx.loaded[logical] = true
    ctx.order[#ctx.order+1] = logical
end

---@param ctx Rule.Context
---@param logicalDir string
local function loadDirectory(ctx, logicalDir)
    for _, logical in ipairs(ctx.vfs:listFiles(logicalDir)) do
        loadFile(ctx, logical)
    end
end

---@param ctx Rule.Context
---@param item string
local function loadItem(ctx, item)
    if type(item) ~= 'string' or item == '' then
        error('规则集项必须是非空字符串', 0)
    end
    local logical = resolveItem(ctx.current, item)
    if ctx.vfs:isFile(logical) then
        loadFile(ctx, logical)
        return
    end
    if ctx.vfs:isFile(logical .. '.lua') then
        loadFile(ctx, logical .. '.lua')
        return
    end
    if ctx.vfs:isDirectory(logical) then
        loadDirectory(ctx, logical)
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

---@param meta table<string, Rule.PackageMeta>
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

---@param instance Rule.Vfs
---@param list string[]
---@return Rule.Plan
local function prepare(instance, list)
    ---@type Rule.Plan
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

        ---@type Rule.MetaFile
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
            depends = function (items)
                if type(items) ~= 'table' then
                    error('rule.depends 需要一个字符串列表', 2)
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
            card = function (name)
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

---@param items string[]
function M.depends(items)
    local ctx = M.context
    if not ctx then
        error('rule.depends 只能在加载规则集时声明', 2)
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
            loadItem(ctx, item)
        end
    end
end

---@param name string
---@param callback fun(context: table)
---@return function # 撤销这次注册
function M:on(name, callback)
    if not M.context then
        error('时机注册只能在加载规则集时声明', 2)
    end
    if type(name) ~= 'string' or name == '' then
        error('时机名必须是非空字符串', 2)
    end
    if type(callback) ~= 'function' then
        error('时机回调必须是函数', 2)
    end
    return M.events:on(name, callback)
end

---@param name string
---@param ... any
function M:fire(name, ...)
    if type(name) ~= 'string' or name == '' then
        error('时机名必须是非空字符串', 2)
    end
    M.events:fire(name, ...)
end

---@param sources string[]
function M.setRoots(sources)
    if type(sources) ~= 'table' then
        error('规则集来源必须是字符串列表', 2)
    end
    M.sources = sources
end

---@param root string|bee.fspath
function M.setRoot(root)
    M.setRoots { tostring(root) }
end

---@return string[]
function M.getRoots()
    return M.sources
end

---@param list? string[]
---@return string[] # 被加载的文件（逻辑路径），按执行完成的顺序
function M.load(list)
    if list then
        M.lastList = list
    end
    list = M.lastList
    if not list then
        error('没有可用的加载清单', 2)
    end
    local instance = vfs.create(M.sources, moe.env.ROOT_PATH:parent_path())

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

    M.clear()

    ---@type Rule.Context
    local ctx = {
        vfs      = instance,
        loading  = {},
        loaded   = {},
        order    = {},
        excludes = {},
    }
    M.context = ctx
    local guard <close> = moe.util.defer(function ()
        M.context = nil
    end)

    for _, item in ipairs(items) do
        loadItem(ctx, item)
    end

    checkExcludes(ctx.loaded, ctx.excludes)
    M.meta = plan.meta

    return ctx.order
end

return M
