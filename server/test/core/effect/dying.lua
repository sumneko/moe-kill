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

lt.test('濒死：不在结算里就当场起', function ()
    local game, players = newGame(2)

    ---@type Dying?
    local seen = nil
    game:on('濒死', function (dying)
        seen = dying
    end)

    game:enterDying(players[2])

    local dying = assert(seen, '「濒死」没有触发')
    lt.assertEquals('种类标识', 'dying', dying.kind)
    lt.assertEquals('上下文里是那个濒死的人', players[2], dying.player)
end)

lt.test('濒死：在结算里记账，要等这次结算收尾才起', function ()
    local game, players = newGame(2)

    ---@type string[]
    local trace = {}

    game:on('伤害-前', function ()
        trace[#trace + 1] = '伤害-前'
        game:enterDying(players[2])
    end)
    game:on('伤害-后', function ()
        trace[#trace + 1] = '伤害-后'
    end)
    game:on('濒死', function ()
        trace[#trace + 1] = '濒死'
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('濒死排在这次结算的最后', '伤害-前,伤害-后,濒死', table.concat(trace, ','))
end)

lt.test('濒死：记账可以被撤销', function ()
    local game, players = newGame(2)

    ---@type boolean
    local fired = false

    game:on('伤害-前', function ()
        local cancel = game:enterDying(players[2])
        cancel()
    end)
    game:on('濒死', function ()
        fired = true
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('撤销之后不再进濒死', false, fired)
end)

lt.test('濒死：已经阵亡的不再进濒死', function ()
    local game, players = newGame(2)

    ---@type boolean
    local fired = false

    game:on('伤害-前', function ()
        players[2]:setAlive(false)
        game:enterDying(players[2])
    end)
    game:on('濒死', function ()
        fired = true
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('阵亡的不再起濒死', false, fired)
end)

lt.test('濒死：濒死里再记账会再起一次（自然嵌套）', function ()
    local game, players = newGame(2)

    ---@type integer
    local count    = 0
    ---@type boolean
    local reentered = false

    game:on('濒死', function (dying)
        count = count + 1
        if not reentered then
            reentered = true
            game:enterDying(dying.player)
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
