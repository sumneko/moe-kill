local lt = require 'test.ltest'

---@param count integer
---@return Moe.Game
---@return Moe.Player[] # 按座位号升序
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
    ---@type Moe.Player[]
    local players = {}
    for i = 1, count do
        local player = moe.player.create { attributes = attributeSystem:createInstance() }
        desk:sit(i, player)
        player:setAttr('体力', 4)
        players[i] = player
    end
    return game, players
end

lt.test('伤害：造成伤害后体力下降', function ()
    local game, players = newGame(2)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('目标掉 1 点体力', 3, players[2]:getAttr('体力'))
    lt.assertEquals('来源不受影响', 4, players[1]:getAttr('体力'))
end)

lt.test('伤害：体力可以降到负数', function ()
    local game, players = newGame(2)

    players[2]:setAttr('体力', 1)
    game:damage(players[1], players[2], 3)

    lt.assertEquals('1 被减 3 之后是 -2', -2, players[2]:getAttr('体力'))
end)

lt.test('伤害：连续伤害逐次减去', function ()
    local game, players = newGame(2)

    game:damage(players[1], players[2], 1)
    game:damage(players[1], players[2], 2)

    lt.assertEquals('两次伤害累计', 1, players[2]:getAttr('体力'))
end)

lt.test('伤害：伤害前与伤害后时机的先后与上下文', function ()
    local game, players = newGame(2)
    local source, target = players[1], players[2]

    ---@type string[]
    local trace = {}
    ---@type Moe.Player?
    local seenTo = nil

    ---@param ctx Moe.Game.EventCtx.伤害
    local function onBefore(ctx)
        trace[#trace + 1] = '前 {} {}' % { target:getAttr('体力'), ctx.amount }
    end

    ---@param ctx Moe.Game.EventCtx.伤害
    local function onAfter(ctx)
        trace[#trace + 1] = '后 {} {}' % { target:getAttr('体力'), ctx.amount }
        seenTo = ctx.to
    end

    game.events:on('伤害-前', onBefore)
    game.events:on('伤害-后', onAfter)

    game:damage(source, target, 2)

    lt.assertEquals('前：体力还没变；后：已经变了', '前 4 2,后 2 2', table.concat(trace, ','))
    lt.assertEquals('上下文里的目标就是被打的那个', target, seenTo)
end)

lt.test('伤害：没有订阅者时照常', function ()
    local game, players = newGame(2)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('照样掉血', 3, players[2]:getAttr('体力'))
end)
