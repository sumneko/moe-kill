local lt = require 'test.ltest'

--- 造一对对接好、都起了读循环的客户端
---@return Client # 前端侧
---@return Client # 后端侧
local function connect()
    local a, b = moe.link.pair()
    local front = moe.client.create(a)
    local back  = moe.client.create(b)
    front:start()
    back:start()
    return front, back
end

--- 搭一个两人局：每人坐好、都接了客户端并接入下行
---@return Game
---@return Player[]
local function newGame()
    local game = moe.game.create {
        seats   = 2,
        random  = moe.random.create(1),
        sources = { lt.cardSource },
    }
    ---@type Player[]
    local players = {}
    for i = 1, 2 do
        local player = moe.player.create(game, { attributes = game:getAttributeSystem():createInstance() })
        local _, back = connect()
        game.desk:sit(i, player)
        player:setUser(New 'ClientUser' (game, back))
        assert(player.user):attach()
        players[i] = player
    end
    return game, players
end

--- 发两张候选牌并搬进他的手牌（他那份卡牌视图账里才有号）
---@async
---@param game Game
---@param player Player
---@return Card
---@return Card
local function dealCards(game, player)
    local c1 = game:createCard('杀', '黑桃', 7)
    local c2 = game:createCard('闪', '红桃', 2)
    game:moveCard({ c1, c2 }, player:getZone('手牌'))
    moe.await.sleep(0)
    return c1, c2
end

---@async
lt.test('询问：要牌时问客户端，回包的 id 转回牌', function ()
    local game, players = newGame()
    local me = assert(players[1])

    local c1, c2 = dealCards(game, me)

    ---@type Proto.Request.Ask.Select?
    local sent = nil
    local _ <close> = moe.client.register('Ask.Select', function (_, params)
        ---@cast params Proto.Request.Ask.Select
        sent = params
        local condition = assert(params.card)
        return { card = { condition.ids[1] } }
    end)

    local ask = moe.askCard.create {
        game      = game,
        to        = me,
        reason    = '测试',
        condition = { card = { c1, c2 } },
    }
    ask:apply():await()

    local params = assert(sent, '没问过客户端')
    lt.assertEquals('两张都是候选', 2, #assert(params.card).ids)
    lt.assertEquals('张数区间带上了', 1, assert(params.card).min)
    lt.assertEquals('这次成了', true, ask.success)
    lt.assertEquals('拿到的是一张真牌', true, ask.card == c1 or ask.card == c2)
end)

---@async
lt.test('询问：回包里的牌 id 不认 ⇒ 这次不算成立', function ()
    local game, players = newGame()
    local me = assert(players[1])

    local c1 = dealCards(game, me)

    local _ <close> = moe.client.register('Ask.Select', function ()
        return { card = { 9999 } }
    end)

    local ask = moe.askCard.create {
        game      = game,
        to        = me,
        reason    = '乱答',
        condition = { card = { c1 } },
    }
    ask:apply():await()

    lt.assertEquals('这次没成', false, ask.success)
    lt.assertEquals('没有牌', nil, ask.card)
end)

---@async
lt.test('询问：没给条件时不筛（候选 = 他牌区里的牌）', function ()
    local game, players = newGame()
    local me = assert(players[1])

    local c1, c2 = dealCards(game, me)

    ---@type Proto.Request.Ask.Select?
    local sent = nil
    local _ <close> = moe.client.register('Ask.Select', function (_, params)
        ---@cast params Proto.Request.Ask.Select
        sent = params
        local condition = assert(params.card)
        return { card = { condition.ids[1] } }
    end)

    local ask = moe.askCard.create {
        game   = game,
        to     = me,
        reason = '随便',
    }
    ask:apply():await()

    local params = assert(sent, '没问过客户端')
    lt.assertEquals('候选就是他手上那两张', 2, #assert(params.card).ids)
    lt.assertEquals('这次成了', true, ask.success)
    lt.assertEquals('拿到的是一张真牌', true, ask.card == c1 or ask.card == c2)
end)
