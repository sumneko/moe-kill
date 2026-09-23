local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'event-probe'

---@type Game
local game

---@param sources? string[]
---@return Game
local function newGame(sources)
    return moe.game.create {
        seats   = 4,
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
    write('甲/开始.lua', 'game:on("游戏-开始", function (event) event.record = "甲" end)')

    load(list('甲'))

    ---@type table<string, any>
    local payload = {}
    game:fire('游戏-开始', payload)

    lt.assertEquals('回调被执行并拿到上下文', '甲', payload.record)
end)

lt.test('时机：后注册的后执行，于是覆盖先前的', function ()
    local guard <close> = prepare()
    write('甲/开始.lua', 'game:on("游戏-开始", function (event) event.identity = "甲写的" end)')
    write('乙/开始.lua', 'game:on("游戏-开始", function (event) event.identity = "乙写的" end)')

    load(list('甲', '乙'))

    ---@type table<string, any>
    local payload = {}
    game:fire('游戏-开始', payload)

    lt.assertEquals('后加载的包后注册、后执行，写完的值生效', '乙写的', payload.identity)
end)

lt.test('时机：注册返回的 disposer 能撤销', function ()
    local guard <close> = prepare()
    write('甲/开始.lua', 'local undo = game:on("游戏-开始", function (event) event.record = "甲" end)\n'
        .. 'if type(undo) ~= "function" then\n'
        .. '    error("注册没有返回撤销函数")\n'
        .. 'end\n'
        .. 'undo()')

    load(list('甲'))

    ---@type table<string, any>
    local payload = {}
    game:fire('游戏-开始', payload)
    lt.assertEquals('撤销后不再触发', nil, payload.record)
end)

lt.test('时机：加载之外也能注册（订阅随下一次装载清空）', function ()
    local guard <close> = prepare()
    ---@type table<string, any>
    local payload = {}
    local undo = game:on('游戏-开始', function (event)
        ---@cast event table<string, any>
        event.record = '加载之外'
    end)

    game:fire('游戏-开始', payload)
    lt.assertEquals('加载之外注册照常生效', '加载之外', payload.record)

    undo()
    payload.record = nil
    game:fire('游戏-开始', payload)
    lt.assertEquals('撤销后不再触发', nil, payload.record)
end)

lt.test('时机：清空重载后旧注册不再触发', function ()
    local guard <close> = prepare()
    write('甲/开始.lua', 'game:on("游戏-开始", function (event) event.record = "第一轮" end)')

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
    write('甲/一.lua', 'game:on("游戏-开始", function (event) event.order = (event.order or "") .. "一" end)')
    write('甲/二.lua', 'game:on("游戏-开始", function (event) event.order = (event.order or "") .. "二" end)')

    load(list('甲'))

    ---@type table<string, any>
    local payload = {}
    game:fire('游戏-开始', payload)

    lt.assertEquals('按文件加载顺序注册', '一二', payload.order)
end)

lt.test('快速返回：回调明确返回了返回值就跳过之后的事件，并以它为准', function ()
    local guard <close> = prepare()
    write('甲/空.lua', 'Card("占位")')
    load(list('甲'))

    ---@type string[]
    local ran = {}
    game:on('游戏-开始', function ()
        ran[#ran + 1] = '第一个'
        return false
    end)
    game:on('游戏-开始', function ()
        ran[#ran + 1] = '第二个'
    end)

    local result = game:fire('游戏-开始', {})

    lt.assertEquals('后面的回调没跑', '第一个', table.concat(ran, ','))
    lt.assertEquals('返回值就是那次返回', false, result)
end)

lt.test('快速返回：没人返回值时照常全部触发', function ()
    local guard <close> = prepare()
    write('甲/空.lua', 'Card("占位")')
    load(list('甲'))

    ---@type string[]
    local ran = {}
    game:on('游戏-开始', function ()
        ran[#ran + 1] = '第一个'
    end)
    game:on('游戏-开始', function ()
        ran[#ran + 1] = '第二个'
    end)

    local result = game:fire('游戏-开始', {})

    lt.assertEquals('两个都跑了', '第一个,第二个', table.concat(ran, ','))
    lt.assertEquals('没人返回值 ⇒ 结果是空', nil, result)
end)

lt.test('快速返回：回调报错不算「明确返回」，也不打断其余回调', function ()
    local guard <close> = prepare()
    write('甲/空.lua', 'Card("占位")')
    load(list('甲'))
    lt.expectErrors(1)

    ---@type string[]
    local ran = {}
    game:on('游戏-开始', function ()
        ran[#ran + 1] = '报错的'
        error('故意报错')
    end)
    game:on('游戏-开始', function ()
        ran[#ran + 1] = '后面的'
        return '后面的结论'
    end)

    local result = game:fire('游戏-开始', {})

    lt.assertEquals('报错的那条被隔离，后面的照常跑', '报错的,后面的', table.concat(ran, ','))
    lt.assertEquals('结果来自没报错的那条', '后面的结论', result)
end)

lt.test('快速返回：嵌套触发互不串', function ()
    local guard <close> = prepare()
    write('甲/空.lua', 'Card("占位")')
    load(list('甲'))

    ---@type any
    local inner = nil
    local depth = 0
    game:on('游戏-开始', function ()
        if depth > 0 then
            return '内层'
        end
        depth = depth + 1
        inner = game:fire('游戏-开始', {})
        return '外层'
    end)

    local outer = game:fire('游戏-开始', {})

    lt.assertEquals('内层拿到自己的结果', '内层', inner)
    lt.assertEquals('外层拿到自己的结果', '外层', outer)
end)
