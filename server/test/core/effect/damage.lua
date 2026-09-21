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
    ---@type Player?
    local seenTo = nil

    ---@param ctx Damage
    local function onBefore(ctx)
        trace[#trace + 1] = '前 {} {}' % { target:getAttr('体力'), ctx.amount }
    end

    ---@param ctx Damage
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

lt.test('伤害：建实例先不结算就不掉血', function ()
    local game, players = newGame(2)
    local damage = moe.damage.create {
        game   = game,
        from   = players[1],
        to     = players[2],
        amount = 2,
    }

    lt.assertEquals('实例带来源', players[1], damage.from)
    lt.assertEquals('实例带目标', players[2], damage.to)
    lt.assertEquals('实例带点数', 2, damage.amount)
    lt.assertEquals('实例知道自己属于哪一局', game, damage.game)
    lt.assertEquals('还没结算，体力不变', 4, players[2]:getAttr('体力'))

    damage:apply()

    lt.assertEquals('结算之后才变化', 2, players[2]:getAttr('体力'))
end)

lt.test('伤害：便利入口与手写两步等价', function ()
    local game, players = newGame(3)

    game:damage(players[1], players[2], 2)
    moe.damage.create {
        game   = game,
        from   = players[1],
        to     = players[3],
        amount = 2,
    }:apply()

    lt.assertEquals('两条路的结果一样', players[2]:getAttr('体力'), players[3]:getAttr('体力'))
    lt.assertEquals('结果确实是 2', 2, players[3]:getAttr('体力'))
end)

lt.test('伤害：两个时机收到同一个实例', function ()
    local game, players = newGame(2)

    ---@type Damage?
    local before = nil
    ---@type Damage?
    local after = nil

    ---@param ctx Damage
    local function onBefore(ctx)
        before = ctx
    end

    ---@param ctx Damage
    local function onAfter(ctx)
        after = ctx
    end

    game.events:on('伤害-前', onBefore)
    game.events:on('伤害-后', onAfter)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('前后是同一个对象', before, after)
    lt.assertEquals('就是这次伤害（点数对得上）', 1, after and after.amount)
end)

lt.test('伤害：结算期间在栈上', function ()
    local game, players = newGame(2)

    ---@type Damage?
    local ctxSeen = nil
    ---@type Effect?
    local topSeen = nil
    ---@type string?
    local kindSeen = nil

    ---@param ctx Damage
    local function onAfter(ctx)
        ctxSeen  = ctx
        topSeen  = game:getEffect()
        kindSeen = ctx.kind
    end

    game.events:on('伤害-后', onAfter)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('触发时栈顶就是这次伤害', ctxSeen, topSeen)
    lt.assertEquals('种类标识', 'damage', kindSeen)
    lt.assertEquals('记牌器留下了这一条', 1, #game:getEffects())
end)
