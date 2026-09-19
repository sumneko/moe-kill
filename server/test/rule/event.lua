local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'event-probe'

---@return unknown
local function prepare()
    fs.remove_all(probeDir)
    fs.create_directories(probeDir)
    moe.rule.setRoots { probeDir:string() .. '/*' }
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
    write('甲/开始.lua', 'rule:on("游戏开始", function (ctx) ctx.记录 = "甲" end)')

    moe.rule.load(list('甲'))

    ---@type table<string, any>
    local ctx = {}
    moe.rule:fire('游戏开始', ctx)

    lt.assertEquals('回调被执行并拿到上下文', '甲', ctx.记录)
end)

lt.test('时机：后注册的后执行，于是覆盖先前的', function ()
    local guard <close> = prepare()
    write('甲/开始.lua', 'rule:on("游戏开始", function (ctx) ctx.身份 = "甲写的" end)')
    write('乙/开始.lua', 'rule:on("游戏开始", function (ctx) ctx.身份 = "乙写的" end)')

    moe.rule.load(list('甲', '乙'))

    ---@type table<string, any>
    local ctx = {}
    moe.rule:fire('游戏开始', ctx)

    lt.assertEquals('后加载的包后注册、后执行，写完的值生效', '乙写的', ctx.身份)
end)

lt.test('时机：注册返回的 disposer 能撤销', function ()
    local guard <close> = prepare()
    write('甲/开始.lua', 'local undo = rule:on("游戏开始", function (ctx) ctx.记录 = "甲" end)\n'
        .. 'if type(undo) ~= "function" then\n'
        .. '    error("注册没有返回撤销函数")\n'
        .. 'end\n'
        .. 'undo()')

    moe.rule.load(list('甲'))

    ---@type table<string, any>
    local ctx = {}
    moe.rule:fire('游戏开始', ctx)
    lt.assertEquals('撤销后不再触发', nil, ctx.记录)
end)

lt.test('时机：加载之外不能注册', function ()
    lt.assertError('加载之外注册报错', function ()
        moe.rule:on('游戏开始', function () end)
    end)
end)

lt.test('时机：清空重载后旧注册不再触发', function ()
    local guard <close> = prepare()
    write('甲/开始.lua', 'rule:on("游戏开始", function (ctx) ctx.记录 = "第一轮" end)')

    moe.rule.load(list('甲'))
    ---@type table<string, any>
    local first = {}
    moe.rule:fire('游戏开始', first)
    lt.assertEquals('第一轮的注册生效', '第一轮', first.记录)

    write('甲/开始.lua', 'rule.card("占位")')
    moe.rule.load(list('甲'))

    ---@type table<string, any>
    local second = {}
    moe.rule:fire('游戏开始', second)
    lt.assertEquals('第二轮不再有旧回调', nil, second.记录)
end)

lt.test('时机：未注册的时机名触发是空操作', function ()
    local guard <close> = prepare()
    write('甲/空.lua', 'rule.card("占位")')

    moe.rule.load(list('甲'))

    lt.assertEquals('没有注册过任何时机', 0, #moe.rule.events:getNames())
    moe.rule:fire('没有这个时机')
end)

lt.test('时机：同一个时机在多个文件里注册也按加载顺序执行', function ()
    local guard <close> = prepare()
    write('甲/一.lua', 'rule:on("游戏开始", function (ctx) ctx.顺序 = (ctx.顺序 or "") .. "一" end)')
    write('甲/二.lua', 'rule:on("游戏开始", function (ctx) ctx.顺序 = (ctx.顺序 or "") .. "二" end)')

    moe.rule.load(list('甲'))

    ---@type table<string, any>
    local ctx = {}
    moe.rule:fire('游戏开始', ctx)

    lt.assertEquals('按文件加载顺序注册', '一二', ctx.顺序)
end)
