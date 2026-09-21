local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'event-probe'

---@type Game
local game

---@param sources? string[]
---@return Game
local function newGame(sources)
    return moe.game.create {
        desk    = moe.desk.create(4),
        random  = moe.random.create(1),
        sources = sources or { probeDir:string() .. '/*' },
    }
end

---@param items string[]
---@return string[] # 这一次实际执行过的文件
local function load(items)
    return moe.loader.install(game, { packages = items })
end

---@return unknown
local function prepare()
    fs.remove_all(probeDir)
    fs.create_directories(probeDir)
    game = newGame()
    return moe.util.defer(function ()
        fs.remove_all(probeDir)
    end)
end

---@param rel string
---@param content string
local function write(rel, content)
    local file = probeDir / rel
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), content)
    assert(ok, err)
end

---@param ... string
---@return string[]
local function list(...)
    return { ... }
end

lt.test('时机：加载期注册的回调能被触发', function ()
    local guard <close> = prepare()
    write('甲/开始.lua', 'game:on("游戏-开始", function (ctx) ctx.record = "甲" end)')

    load(list('甲'))

    ---@type table<string, any>
    local ctx = {}
    game:fire('游戏-开始', ctx)

    lt.assertEquals('回调被执行并拿到上下文', '甲', ctx.record)
end)

lt.test('时机：后注册的后执行，于是覆盖先前的', function ()
    local guard <close> = prepare()
    write('甲/开始.lua', 'game:on("游戏-开始", function (ctx) ctx.identity = "甲写的" end)')
    write('乙/开始.lua', 'game:on("游戏-开始", function (ctx) ctx.identity = "乙写的" end)')

    load(list('甲', '乙'))

    ---@type table<string, any>
    local ctx = {}
    game:fire('游戏-开始', ctx)

    lt.assertEquals('后加载的包后注册、后执行，写完的值生效', '乙写的', ctx.identity)
end)

lt.test('时机：注册返回的 disposer 能撤销', function ()
    local guard <close> = prepare()
    write('甲/开始.lua', 'local undo = game:on("游戏-开始", function (ctx) ctx.record = "甲" end)\n'
        .. 'if type(undo) ~= "function" then\n'
        .. '    error("注册没有返回撤销函数")\n'
        .. 'end\n'
        .. 'undo()')

    load(list('甲'))

    ---@type table<string, any>
    local ctx = {}
    game:fire('游戏-开始', ctx)
    lt.assertEquals('撤销后不再触发', nil, ctx.record)
end)

lt.test('时机：加载之外也能注册（订阅随下一次装载清空）', function ()
    local guard <close> = prepare()
    ---@type table<string, any>
    local ctx = {}
    local undo = game:on('游戏-开始', function (seen)
        ---@cast seen table<string, any>
        seen.record = '加载之外'
    end)

    game:fire('游戏-开始', ctx)
    lt.assertEquals('加载之外注册照常生效', '加载之外', ctx.record)

    undo()
    ctx.record = nil
    game:fire('游戏-开始', ctx)
    lt.assertEquals('撤销后不再触发', nil, ctx.record)
end)

lt.test('时机：清空重载后旧注册不再触发', function ()
    local guard <close> = prepare()
    write('甲/开始.lua', 'game:on("游戏-开始", function (ctx) ctx.record = "第一轮" end)')

    load(list('甲'))
    ---@type table<string, any>
    local first = {}
    game:fire('游戏-开始', first)
    lt.assertEquals('第一轮的注册生效', '第一轮', first.record)

    write('甲/开始.lua', 'Card("占位")')
    load(list('甲'))

    ---@type table<string, any>
    local second = {}
    game:fire('游戏-开始', second)
    lt.assertEquals('第二轮不再有旧回调', nil, second.record)
end)

lt.test('时机：未注册的时机名触发是空操作', function ()
    local guard <close> = prepare()
    write('甲/空.lua', 'Card("占位")')

    load(list('甲'))

    ---@diagnostic disable-next-line: invisible
    lt.assertEquals('没有注册过任何时机', 0, #game.events:getNames())
    game:fire('没有这个时机')
end)

lt.test('时机：同一个时机在多个文件里注册也按加载顺序执行', function ()
    local guard <close> = prepare()
    write('甲/一.lua', 'game:on("游戏-开始", function (ctx) ctx.order = (ctx.order or "") .. "一" end)')
    write('甲/二.lua', 'game:on("游戏-开始", function (ctx) ctx.order = (ctx.order or "") .. "二" end)')

    load(list('甲'))

    ---@type table<string, any>
    local ctx = {}
    game:fire('游戏-开始', ctx)

    lt.assertEquals('按文件加载顺序注册', '一二', ctx.order)
end)
