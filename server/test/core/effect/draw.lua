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
        players[i] = player
    end
    game.turnPlayer = players[1]
    return game, players
end

lt.test('摸牌：把牌从抽牌堆顶抽进手牌', function ()
    local game, players = newGame(2)
    local deck = game:getZone('抽牌')
    for i = 1, 3 do
        deck:put(game:createCard('杀', '黑桃', i))
    end
    local beforeDeck = deck:count()
    local beforeHand = players[1]:getZone('手牌'):count()

    local draw = players[1]:draw(2)

    lt.assertEquals('种类标识', 'draw', draw.kind)
    lt.assertEquals('摸牌的人可读', players[1], draw.player)
    lt.assertEquals('摸几张可读', 2, draw.count)
    lt.assertEquals('抽牌堆少了 2 张', beforeDeck - 2, deck:count())
    lt.assertEquals('手牌多了 2 张', beforeHand + 2, players[1]:getZone('手牌'):count())
end)

lt.test('摸牌：结完没有结果、没有失败', function ()
    local game, players = newGame(2)

    local draw = players[1]:draw(1)

    lt.assertEquals('返回这次摸牌', 'draw', draw.kind)
    lt.assertEquals('没有结果', nil, draw.result)
    lt.assertEquals('也没有失败', nil, draw.err)
end)

lt.test('摸牌：已阵亡的不摸', function ()
    local game, players = newGame(2)
    local deck = game:getZone('抽牌')
    deck:put(game:createCard('杀'))
    local beforeDeck = deck:count()
    local beforeHand = players[1]:getZone('手牌'):count()

    players[1]:setAlive(false)
    local draw = players[1]:draw(1)

    lt.assertEquals('牌还在抽牌里', beforeDeck, deck:count())
    lt.assertEquals('手牌没变', beforeHand, players[1]:getZone('手牌'):count())
    lt.assertEquals('不算失败', nil, draw.err)
end)
