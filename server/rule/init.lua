local fs = require 'bee.filesystem'

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
---@field root bee.fspath
---@field loading table<string, true>
---@field loaded table<string, true>
---@field order string[]

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
---@field private lastRoot bee.fspath?
local M = {}

---@type table<string, Rule.Card>
M.cards = {}

---@private
---@type Rule.Context?
M.context = nil

---@private
---@type string[]?
M.lastList = nil

---@private
---@type bee.fspath?
M.lastRoot = nil

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

---@param ctx Rule.Context
---@param path string
local function loadFile(ctx, path)
    if ctx.loaded[path] or ctx.loading[path] then
        return
    end
    local source, err = moe.util.loadFile(path)
    if not source then
        error('规则集文件读取失败：{}（{}）' % { path, err }, 0)
    end
    local chunk, loadErr = load(source, '@' .. path, 't', makeEnv())
    if not chunk then
        error('规则集文件解析失败：{}（{}）' % { path, loadErr }, 0)
    end
    ctx.loading[path] = true
    local guard <close> = moe.util.defer(function ()
        ctx.loading[path] = nil
    end)
    chunk()
    ctx.loaded[path] = true
    ctx.order[#ctx.order+1] = path
end

---@param ctx Rule.Context
---@param dir bee.fspath
local function loadDirectory(ctx, dir)
    ---@type string[]
    local files = {}
    for entry in fs.pairs(dir) do
        if fs.is_regular_file(entry) then
            if entry:filename():string():sub(-4) == '.lua' then
                files[#files+1] = entry:string()
            end
        elseif fs.is_directory(entry) then
            loadDirectory(ctx, entry)
        end
    end
    table.sort(files)
    for _, file in ipairs(files) do
        loadFile(ctx, file)
    end
end

---@param ctx Rule.Context
---@param item string
local function loadItem(ctx, item)
    local direct = ctx.root / item
    if fs.is_regular_file(direct) then
        loadFile(ctx, direct:string())
        return
    end
    local withExt = ctx.root / (item .. '.lua')
    if fs.is_regular_file(withExt) then
        loadFile(ctx, withExt:string())
        return
    end
    if fs.is_directory(direct) then
        loadDirectory(ctx, direct)
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

---@param root string|bee.fspath
function M.setRoot(root)
    M.lastRoot = fs.absolute(fs.path(root))
end

---@param list? string[]
---@param root? string|bee.fspath
---@return string[] # 被加载的文件，按执行完成的顺序
function M.load(list, root)
    if list then
        M.lastList = list
    end
    list = M.lastList
    if not list then
        error('没有可用的加载清单', 2)
    end
    if root then
        M.setRoot(root)
    end
    local base = M.lastRoot or (moe.env.ROOT_PATH:parent_path() / 'game')

    M.clear()

    ---@type Rule.Context
    local ctx = {
        root    = base,
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
