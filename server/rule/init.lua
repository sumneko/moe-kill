local vfs = require 'rule.vfs'

---@class Rule.Card
---@field name string # 裸名
---@field packageName string # 所属包名
---@field fullName string # 完整名（包名.名字）
---@field source string # 声明它的文件（逻辑路径）
---@field private handlers table<string, function[]>
local Card = Class 'Rule.Card'

---@param name string
---@param owner string
---@param source string
function Card:__init(name, owner, source)
    self.name        = name
    self.packageName = owner
    self.fullName    = owner .. '.' .. name
    self.source      = source
    self.handlers    = {}
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

---@type string[]
local ALLOWED_GLOBALS = {
    '_VERSION',
    'assert', 'error', 'getmetatable', 'ipairs', 'math', 'next', 'pairs', 'pcall',
    'print', 'rawequal', 'rawget', 'rawlen', 'rawset', 'select', 'setmetatable',
    'string', 'table', 'tonumber', 'tostring', 'type', 'utf8', 'xpcall',
}

---@class Rule
---@field cards table<string, table<string, Rule.Card>> # 包名 → 裸名 → 定义
---@field packages string[] # 包的加载顺序（首次出现的顺序）
---@field private context Rule.Context?
---@field private lastList string[]?
local M = {}

---@type string[] # 默认来源：仓库根下项目自己的包容器
M.DEFAULT_SOURCES = { './package/*' }

---@type table<string, table<string, Rule.Card>>
M.cards = {}

---@type string[] # 包的加载顺序
M.packages = {}

---@type string[] # 当前来源
M.sources = M.DEFAULT_SOURCES

---@private
---@type Rule.Context?
M.context = nil

---@private
---@type string[]?
M.lastList = nil

---@private
---@return table
local function makeEnv()
    ---@type table<string, any>
    local env = {
        rule = M,
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
end

---@param path string
---@return string
local function parentLogical(path)
    return path:match '^(.*)/[^/]*$' or ''
end

---@param ctx Rule.Context
---@param item string
---@return string
local function resolveLogical(ctx, item)
    if item:sub(1, 1) ~= '.' then
        return vfs.normalize(item)
    end
    local current = ctx.current
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
    if owner:find('.', 1, true) then
        error('包目录名里不能含 "."：{}' % { owner }, 0)
    end
    local source, err = ctx.vfs:read(logical)
    if not source then
        error('规则集文件读取失败：{}（{}）' % { logical, err }, 0)
    end
    local chunk, loadErr = load(source, '@' .. (ctx.vfs:resolve(logical) or logical), 't', makeEnv())
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
    local logical = resolveLogical(ctx, item)
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

---@param items string[]
function M.depends(items)
    local ctx = M.context
    if not ctx then
        error('rule.depends 只能在加载规则集时声明', 2)
    end
    for _, item in ipairs(items) do
        loadItem(ctx, item)
    end
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

    M.clear()

    ---@type Rule.Context
    local ctx = {
        vfs     = instance,
        loading = {},
        loaded  = {},
        order   = {},
    }
    M.context = ctx
    local guard <close> = moe.util.defer(function ()
        M.context = nil
    end)

    for _, item in ipairs(list) do
        loadItem(ctx, item)
    end

    return ctx.order
end

return M
