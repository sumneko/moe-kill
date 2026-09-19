local vfs = require 'rule.vfs'

---@class Rule.Card
---@field name string
---@field private handlers table<string, function[]>
local Card = Class 'Rule.Card'

---@param name string
function Card:__init(name)
    self.name     = name
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

---@type string[]
local ALLOWED_GLOBALS = {
    '_VERSION',
    'assert', 'error', 'getmetatable', 'ipairs', 'math', 'next', 'pairs', 'pcall',
    'print', 'rawequal', 'rawget', 'rawlen', 'rawset', 'select', 'setmetatable',
    'string', 'table', 'tonumber', 'tostring', 'type', 'utf8', 'xpcall',
}

---@class Rule
---@field cards table<string, Rule.Card>
---@field private context Rule.Context?
---@field private lastList string[]?
local M = {}

---@type string[] # 默认来源：仓库根下项目自己的包容器
M.DEFAULT_SOURCES = { './package/*' }

---@type table<string, Rule.Card>
M.cards = {}

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

---@param name string
---@return Rule.Card?
function M.getCard(name)
    return M.cards[name]
end

---@param name string
---@return Rule.Card
function M.card(name)
    if type(name) ~= 'string' or name == '' then
        error('规则名必须是非空字符串', 2)
    end
    local card = M.cards[name]
    if not card then
        card = New 'Rule.Card' (name)
        M.cards[name] = card
    end
    return card
end

---@private
function M.clear()
    M.cards = {}
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
