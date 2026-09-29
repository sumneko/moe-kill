local lt = require 'test.ltest'

---@param count integer
---@return Game
---@return Player[] # 按座位号升序
local function newGame(count)
    local random = moe.random.create(1)
    local game   = moe.game.create { seats = count, random = random }
    local desk   = game.desk
    local attributeSystem = game:getAttributeSystem()
    attributeSystem:define('体力', {
        min    = -999999,
        max    = 999999,
        simple = true,
    })
    ---@type Player[]
    local players = {}
    for i = 1, count do
        local player = moe.player.create(game, { attributes = attributeSystem:createInstance() })
        desk:sit(i, player)
        player:setAttr('体力', 4)
        players[i] = player
    end
    game.turnPlayer = players[1]
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

lt.test('伤害：没有订阅者时照常', function ()
    local game, players = newGame(2)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('照样掉血', 3, players[2]:getAttr('体力'))
end)

lt.test('伤害：建实例先不结算就不掉血', function ()
    local game, players = newGame(2)
    local damage = New 'Damage' (game, players[1], players[2], 2)

    lt.assertEquals('实例带来源', players[1], damage.from)
    lt.assertEquals('实例带目标', players[2], damage.to)
    lt.assertEquals('实例带点数', 2, damage.amount)
    lt.assertEquals('实例知道自己属于哪一局', game, damage.game)
    lt.assertEquals('还没结算，体力不变', 4, players[2]:getAttr('体力'))

    damage:apply():await()

    lt.assertEquals('结算之后才变化', 2, players[2]:getAttr('体力'))
end)

lt.test('伤害：便利入口与手写两步等价', function ()
    local game, players = newGame(3)

    game:damage(players[1], players[2], 2)
    local other = New 'Damage' (game, players[1], players[3], 2)
    other:apply():await()

    lt.assertEquals('两条路的结果一样', players[2]:getAttr('体力'), players[3]:getAttr('体力'))
    lt.assertEquals('结果确实是 2', 2, players[3]:getAttr('体力'))
end)

lt.test('伤害：结算期间在栈上', function ()
    local game, players = newGame(2)

    ---@type Damage?
    local damageSeen = nil
    ---@type Effect?
    local topSeen = nil

    game:on('伤害-结束', function (damage)
        damageSeen = damage
        topSeen    = game:getEffect()
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('触发时栈顶就是这次伤害', damageSeen, topSeen)
    lt.assertEquals('种类标识', 'damage', assert(damageSeen).kind)
    lt.assertEquals('记牌器留下了这一条', 1, #game:getEffects())
end)
