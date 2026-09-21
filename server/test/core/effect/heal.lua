local lt = require 'test.ltest'

---@param count integer
---@return Game
---@return Player[] # 按座位号升序
local function newGame(count)
    local desk   = moe.desk.create(count)
    local random = moe.random.create(1)
    local game   = moe.game.create { desk = desk, random = random }
    local attributeSystem = game:getAttributeSystem()
    attributeSystem:define('体力', {
        min    = -999999,
        max    = 999999,
        simple = true,
    })
    ---@type Player[]
    local players = {}
    for i = 1, count do
        local player = moe.player.create { attributes = attributeSystem:createInstance() }
        desk:sit(i, player)
        player:setAttr('体力', 4)
        players[i] = player
    end
    return game, players
end

lt.test('回复：回复后体力上升', function ()
    local game, players = newGame(2)

    local heal = game:heal(players[2], 2)

    lt.assertEquals('种类标识', 'heal', heal.kind)
    lt.assertEquals('目标回 2 点', 6, players[2]:getAttr('体力'))
    lt.assertEquals('别人不受影响', 4, players[1]:getAttr('体力'))
    lt.assertEquals('入口返回已经结完的效果', nil, heal.err)
end)

lt.test('回复：三个时机的先后与上下文，改体力发生在「生效」里', function ()
    local game, players = newGame(2)
    local target = players[2]

    ---@type string[]
    local trace = {}
    ---@type Heal?
    local seen   = nil

    game:on('回复-前', function (ctx)
        trace[#trace + 1] = '前 {}' % { target:getAttr('体力') }
    end)
    game:on('回复-生效', function (ctx)
        trace[#trace + 1] = '生效 {}' % { target:getAttr('体力') }
        seen = ctx
    end)
    game:on('回复-后', function (ctx)
        trace[#trace + 1] = '后 {}' % { target:getAttr('体力') }
    end)

    game:heal(target, 2)

    lt.assertEquals('前还没加、生效与后已经加了', '前 4,生效 6,后 6', table.concat(trace, ','))
    lt.assertEquals('上下文就是这次回复', target, assert(seen).to)
end)

lt.test('回复：建实例先不结算就不回血', function ()
    local game, players = newGame(2)
    local heal = moe.heal.create {
        game   = game,
        to     = players[2],
        amount = 2,
    }

    lt.assertEquals('实例带目标', players[2], heal.to)
    lt.assertEquals('实例带点数', 2, heal.amount)
    lt.assertEquals('还没结算，体力不变', 4, players[2]:getAttr('体力'))

    heal:apply()

    lt.assertEquals('结算之后才变化', 6, players[2]:getAttr('体力'))
end)
