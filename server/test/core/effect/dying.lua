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
    game.turnPlayer = players[1]
    return game, players
end

lt.test('濒死：当场结算；没人喊脱离就由濒死结算杀死他', function ()
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
    lt.assertEquals('没人喊脱离 ⇒ 阵亡', false, players[2]:isAlive())
    lt.assertEquals('结完账就清了', nil, game:getDying(players[2]))
end)

lt.test('濒死：带着那次伤害；喊了脱离就不杀', function ()
    local game, players = newGame(2)
    local damage = moe.damage.create { game = game, from = players[1], to = players[2], amount = 1 }

    ---@type Dying?
    local seen = nil
    ---@type integer
    local leftTimes = 0
    game:on('濒死-进入', function (dying)
        seen = dying
        dying:leave()
    end)
    game:on('濒死-离开', function ()
        leftTimes = leftTimes + 1
    end)

    game:enterDying(players[2], damage)

    lt.assertEquals('传了伤害就带上了', damage, assert(seen).damage)
    lt.assertEquals('喊过脱离 ⇒ 还活着', true, players[2]:isAlive())
    lt.assertEquals('脱离时机当场就发了', 1, leftTimes)
    lt.assertEquals('脱离之后查不到这次的账', nil, game:getDying(players[2]))
end)

lt.test('濒死：leave() 幂等', function ()
    local game, players = newGame(2)

    ---@type Dying?
    local seen = nil
    ---@type integer
    local leftTimes = 0
    game:on('濒死-进入', function (dying)
        seen = dying
        dying:leave()
        dying:leave()          -- 重复调
    end)
    game:on('濒死-离开', function ()
        leftTimes = leftTimes + 1
    end)

    game:enterDying(players[2])

    lt.assertEquals('只发一次时机', 1, leftTimes)
    lt.assertEquals('还活着', true, players[2]:isAlive())
    lt.assertEquals('脱离标记为真', true, assert(seen):hasLeft())
end)

lt.test('濒死：已经在濒死中 ⇒ 返回同一个，致死伤害换成这一次', function ()
    local game, players = newGame(2)
    local first  = moe.damage.create { game = game, from = players[1], to = players[2], amount = 1 }
    local second = moe.damage.create { game = game, from = players[1], to = players[2], amount = 3 }

    ---@type Dying?
    local outer = nil
    ---@type Dying?
    local inner = nil
    ---@type integer
    local entered = 0

    game:on('濒死-进入', function (dying)
        entered = entered + 1
        if outer then
            return
        end
        outer = dying
        inner = game:enterDying(players[2], second)   -- 濒死中再受伤
        lt.assertEquals('返回的是同一次结算', dying, inner)
        lt.assertEquals('致死伤害换成了后一次', second, dying.damage)
    end)

    game:enterDying(players[2], first)

    lt.assertEquals('那次结算只进了一次', 1, entered)
    lt.assertEquals('返回的就是那一次', outer, inner)
    lt.assertEquals('没人喊脱离 ⇒ 照样会死', false, players[2]:isAlive())
end)

lt.test('濒死：脱离之后再进濒死是新的一次', function ()
    local game, players = newGame(2)

    ---@type Dying?
    local oldone = nil
    ---@type Dying?
    local newone = nil

    game:on('濒死-进入', function (dying)
        if oldone then
            return
        end
        oldone = dying
        dying:leave()
        newone = game:enterDying(players[2])
        lt.assertEquals('是新的一次结算', false, oldone == newone)
    end)

    game:enterDying(players[2])

    lt.assertEquals('旧的那次没杀他', true, assert(oldone):hasLeft())
    lt.assertEquals('新那次没人喊脱离 ⇒ 阵亡', false, players[2]:isAlive())
end)
