local lt = require 'test.ltest'
local support = require 'test.user.support'

--- 收消息的登记台（用例自己收，不摸内部字节）：按「哪条连接收到的」分桶
---@param method string
---@return fun(client: Client): any[] # 取某条连接收到的那些载荷
---@return fun() # 撤销登记
local function collect(method)
    ---@type table<Client, any[]>
    local got = {}
    local undo = moe.client.register(method, function (client, params)
        local list = got[client]
        if not list then
            list = {}
            got[client] = list
        end
        list[#list + 1] = params
    end)
    return function (client)
        return got[client] or {}
    end, undo
end

--- 只要声明过设置就会进快照：这里用一个最小定义，避免依赖内容包
---@param game Game
local function defineOne(game)
    game:defineSetting { name = '测试开关', default = true, describe = '用例用' }
end

---@async
lt.test('设置：快照里带本人的全量（定义 + 当前值）', function ()
    local game, players, fronts = support.newGame()
    defineOne(game)

    local front = assert(fronts[1])
    local snapshot, err = front:awaitRequest('Game.SnapShot', {})
    lt.assertEquals('没出错', nil, err)

    ---@cast snapshot Proto.SnapShot
    local settings = assert(snapshot.settings)
    lt.assertEquals('一条', 1, #settings)
    local only = assert(settings[1])
    lt.assertEquals('名字', '测试开关', only.name)
    lt.assertEquals('没改过 = 默认值', true, only.value)
    lt.assertEquals('默认值也带下来', true, only.default)
    lt.assertEquals('说明也带下来', '用例用', only.describe)
end)

---@async
lt.test('设置：改一项就把全量回给本人', function ()
    local game, players, fronts = support.newGame()
    defineOne(game)
    local me = assert(players[1])

    local front = assert(fronts[1])
    local result, err = front:awaitRequest('Settings.Change', { settings = { { name = '测试开关', value = false } } })
    lt.assertEquals('没出错', nil, err)

    ---@cast result Proto.Result.Settings.Change
    local settings = assert(result.settings)
    lt.assertEquals('这一项变了', false, assert(settings[1]).value)
    lt.assertEquals('本人读到的也是新值', false, me:getSetting('测试开关'))
end)

---@async
lt.test('设置：未知的名字整包拒收（一项都不生效）', function ()
    local game, players, fronts = support.newGame()
    defineOne(game)
    local me = assert(players[1])

    local front = assert(fronts[1])
    local _, err = front:awaitRequest('Settings.Change', {
        settings = {
            { name = '测试开关', value = false },
            { name = '不存在的设置', value = true },
        },
    })
    local error = assert(err, '该拒收')
    lt.assertEquals('参数错误', moe.jsonrpc.INVALID_PARAMS, error.code)
    lt.assertEquals('一项都没生效', true, me:getSetting('测试开关'))
end)

---@async
lt.test('设置：只有本人收到 Settings.Update', function ()
    local game, players, fronts = support.newGame()
    defineOne(game)

    local gotOf, undo = collect('Settings.Update')
    local _ <close> = setmetatable({}, { __close = function ()
        undo()
    end })

    local front = assert(fronts[1])
    local _, err = front:awaitRequest('Settings.Change', { settings = { { name = '测试开关', value = false } } })
    lt.assertEquals('没出错', nil, err)
    moe.await.sleep(0)

    local mine = gotOf(front)
    lt.assertEquals('本人收到一条', 1, #mine)
    lt.assertEquals('这条里是新值', false, assert(mine[1].settings[1]).value)
    lt.assertEquals('别人收不到', 0, #gotOf(assert(fronts[2])))
end)

---@async
lt.test('设置：跟着名字走（重开一局、换了连接都沿用）', function ()
    local function freshGame()
        local game = moe.game.create {
            seats   = 2,
            random  = moe.random.create(1),
            sources = { lt.cardSource },
        }
        defineOne(game)
        return game
    end
    local name = '设置用例甲'

    local first = freshGame()
    local firstPlayer = moe.player.create(first, { attributes = first:getAttributeSystem():createInstance(), name = name })
    firstPlayer:setUser(New 'User' (first))
    assert(firstPlayer.user):updateSettings { ['测试开关'] = false }
    lt.assertEquals('这一局里读得到', false, firstPlayer:getSetting('测试开关'))

    local second = freshGame()
    local again = moe.player.create(second, { attributes = second:getAttributeSystem():createInstance(), name = name })
    again:setUser(New 'User' (second))
    lt.assertEquals('新一局同一个名字仍是原来那份', false, again:getSetting('测试开关'))

    local stranger = moe.player.create(second, { attributes = second:getAttributeSystem():createInstance(), name = '设置用例乙' })
    stranger:setUser(New 'User' (second))
    lt.assertEquals('别人是默认值', true, stranger:getSetting('测试开关'))

    moe.settingsSync._bags[name] = nil
    moe.settingsSync._bags['设置用例乙'] = nil
end)
