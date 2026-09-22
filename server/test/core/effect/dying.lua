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

lt.test('濒死：当场结算，上下文里是濒死者与这次伤害', function ()
    local game, players = newGame(2)

    ---@type Dying?
    local seen = nil
    game:on('濒死-进入', function (dying)
        seen = dying
    end)

    game:enterDying(players[2])

    local dying = assert(seen, '「濒死-进入」没有触发')
    lt.assertEquals('种类标识', 'dying', dying.kind)
    lt.assertEquals('上下文里是那个濒死的人', players[2], dying.player)
    lt.assertEquals('没传伤害就是空', nil, dying.damage)

    local damage = moe.damage.create { game = game, from = players[1], to = players[2], amount = 1 }
    game:enterDying(players[2], damage)

    lt.assertEquals('传了伤害就带上了', damage, assert(seen).damage)
end)

lt.test('濒死：结完还活着就触发「濒死-离开」，判死就不触发', function ()
    local game, players = newGame(2)

    ---@type string[]
    local trace = {}
    game:on('濒死-进入', function (dying)
        trace[#trace + 1] = '进入:' .. tostring(dying.player:isAlive())
    end)
    game:on('濒死-离开', function ()
        trace[#trace + 1] = '离开'
    end)

    game:enterDying(players[1])

    lt.assertEquals('没人判死 ⇒ 进出各一次', '进入:true,离开', table.concat(trace, ','))

    game:on('濒死-进入', function (dying)
        dying.player:setAlive(false)
    end)
    game:enterDying(players[2])

    lt.assertEquals('判死 ⇒ 只有进入', '进入:true,离开,进入:true', table.concat(trace, ','))
end)

lt.test('濒死：濒死里再进濒死会自然嵌套', function ()
    local game, players = newGame(2)

    ---@type integer
    local count = 0
    ---@type boolean
    local reentered = false

    game:on('濒死-进入', function (dying)
        count = count + 1
        if not reentered then
            reentered = true
            game:enterDying(dying.player, dying.damage)
        end
    end)

    game:enterDying(players[2])

    lt.assertEquals('起了两次濒死', 2, count)
end)

lt.test('濒死：内核不判死，只把时机交给规则侧', function ()
    local game, players = newGame(2)

    game:enterDying(players[2])

    lt.assertEquals('没人处理 ⇒ 玩家照样活着', true, players[2]:isAlive())
    lt.assertEquals('体力也没被动过', 4, players[2]:getAttr('体力'))
end)
