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

lt.test('濒死：当场结算；没人喊脱离就由濒死结算杀死他', function ()
    local game, players = newGame(2)

    local dying = players[2]:enterDying()

    lt.assertEquals('种类标识', 'dying', dying.kind)
    lt.assertEquals('实例里是那个濒死的人', players[2], dying.player)
    lt.assertEquals('没传伤害就是空', nil, dying.damage)
    lt.assertEquals('没人喊脱离 ⇒ 阵亡', false, players[2]:isAlive())
    lt.assertEquals('结完账就清了', nil, players[2].dying)
end)

lt.test('濒死：带着那次伤害；喊了脱离就不杀', function ()
    local game, players = newGame(2)
    local damage = New 'Damage' (game, players[1], players[2], 1)
    local dying  = New 'Dying' (game, players[2], damage)
    players[2].dying = dying

    dying:leave()
    dying:apply():await()

    lt.assertEquals('传了伤害就带上了', damage, dying.damage)
    lt.assertEquals('喊过脱离 ⇒ 还活着', true, players[2]:isAlive())
    lt.assertEquals('脱离标记为真', true, dying:hasLeft())
    lt.assertEquals('脱离之后账也清了', nil, players[2].dying)
end)

lt.test('濒死：leave() 幂等', function ()
    local game, players = newGame(2)
    local dying  = New 'Dying' (game, players[2])
    players[2].dying = dying

    dying:leave()
    dying:leave()          -- 重复调

    lt.assertEquals('脱离标记为真', true, dying:hasLeft())
    lt.assertEquals('账没被弄脏', nil, players[2].dying)

    dying:apply():await()

    lt.assertEquals('重复调过也仍然活着', true, players[2]:isAlive())
end)

lt.test('濒死：已经在濒死中 ⇒ 返回同一个，致死伤害换成这一次', function ()
    local game, players = newGame(2)
    local first  = New 'Damage' (game, players[1], players[2], 1)
    local second = New 'Damage' (game, players[1], players[2], 3)

    local outer = New 'Dying' (game, players[2], first)
    players[2].dying = outer                          -- 模拟“他正在濒死中”

    local inner = players[2]:enterDying(second)       -- 濒死中再受伤

    lt.assertEquals('返回的是同一次结算', outer, inner)
    lt.assertEquals('致死伤害换成了后一次', second, outer.damage)
    lt.assertEquals('没有重开一次结算', outer, players[2].dying)
end)

lt.test('濒死：脱离之后再进濒死是新的一次', function ()
    local game, players = newGame(2)

    local oldone = New 'Dying' (game, players[2])
    players[2].dying = oldone
    oldone:leave()

    local newone = players[2]:enterDying()

    lt.assertEquals('旧的那次算是脱离了', true, oldone:hasLeft())
    lt.assertEquals('是新的一次结算', false, oldone == newone)
    lt.assertEquals('新那次没人喊脱离 ⇒ 阵亡', false, players[2]:isAlive())
end)
