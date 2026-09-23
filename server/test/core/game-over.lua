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
    return game, players
end

lt.test('游戏结束：没结束时没有结果', function ()
    local game = newGame(2)

    lt.assertEquals('没有结果', nil, game:getResult())
end)

lt.test('游戏结束：记下结果并触发「游戏-结束」', function ()
    local game, _ = newGame(2)

    ---@type Game.Result?
    local seen  = nil
    ---@type integer
    local fired = 0
    game:on('游戏-结束', function (result)
        seen  = result
        fired = fired + 1
    end)

    game:endGame { side = '反贼', reason = '主公阵亡' }

    local result = assert(game:getResult(), '没有记下结果')
    lt.assertEquals('胜方', '反贼', result.side)
    lt.assertEquals('理由', '主公阵亡', result.reason)
    lt.assertEquals('时机触发了一次', 1, fired)
    lt.assertEquals('上下文就是这个结果', result, seen)
end)

lt.test('游戏结束：只认第一次', function ()
    local game, _ = newGame(2)
    ---@type integer
    local fired = 0
    game:on('游戏-结束', function () fired = fired + 1 end)

    game:endGame { side = '反贼', reason = '主公阵亡' }
    game:endGame { side = '主公方', reason = '反贼与内奸全部阵亡' }

    lt.assertEquals('结果没被覆盖', '反贼', assert(game:getResult()).side)
    lt.assertEquals('时机也只触发一次', 1, fired)
end)

lt.test('游戏结束：结束后起的结算以取消收尾', function ()
    local game, players = newGame(2)

    game:endGame { side = '主公方', reason = '反贼与内奸全部阵亡' }

    local damage = moe.damage.create { game = game, from = players[1], to = players[2], amount = 2 }
    damage:apply():await()

    lt.assertEquals('以取消收尾', moe.task.CANCELED, damage.err)
    lt.assertEquals('没有结果', nil, damage.result)
    lt.assertEquals('体力没变', 4, players[2]:getAttr('体力'))
    lt.assertEquals('不进记牌器', 0, #game:getEffects())
end)

lt.test('游戏结束：结束后不再起新的濒死', function ()
    local game, players = newGame(2)

    ---@type integer
    local dyingFired = 0
    game:on('濒死-进入', function () dyingFired = dyingFired + 1 end)
    game:on('伤害-前', function ()
        game:endGame { side = '反贼', reason = '测试' }
        game:enterDying(players[2])
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('濒死没有起', 0, dyingFired)
end)
