local lt = require 'test.ltest'

---@param count integer
---@return Game
---@return Player[] # 按座位号升序
local function newGame(count)
    local game = moe.game.create {
        seats  = count,
        random = moe.random.create(1),
    }
    local desk = game.desk
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

---@param player Player
---@param cards Card[] # 摆进这个玩家的手牌
local function putInHand(player, cards)
    local hand = assert(player:getZone('手牌'), '这个玩家没有手牌区')
    for _, card in ipairs(cards) do
        hand:put(card)
    end
end

lt.test('打出：答复的牌当场交出来，进发起那次结算的临时区', function ()
    local game, players = newGame(2)
    local hand = assert(players[2]:getZone('手牌'))
    local jink = game:createCard('闪')
    hand:put(jink)
    game:on('卡牌-询问', function (ask)
        ask:answer { card = jink }
    end)

    ---@type AskPlayCard?
    local asked = nil
    ---@type boolean
    local inTemp = false
    game:on('卡牌-答复', function (askCard)
        local parent = askCard.parent
        local card   = askCard.card
        inTemp = parent ~= nil and card ~= nil and card:getZone() == parent:getTempZone()
    end)
    game:on('伤害-前', function ()
        asked = game:askPlayCard(players[2], '测试', { name = '闪' })
    end)

    game:damage(players[1], players[2], 1)

    local ask = assert(asked, '没问到')
    lt.assertEquals('种类标识', 'askPlayCard', ask.kind)
    lt.assertEquals('答复拿到了', jink, ask.card)
    lt.assertEquals('牌离开了手', 0, hand:count())
    lt.assertEquals('答复时机里已经在临时区了', true, inTemp)
    lt.assertEquals('收尾之后进了弃牌', assert(game:getZone('弃牌')), jink:getZone())
end)

lt.test('打出：没有父结算时不动那张牌（交给内容侧）', function ()
    local game, players = newGame(2)
    local hand = assert(players[2]:getZone('手牌'))
    local jink = game:createCard('闪')
    hand:put(jink)
    game:on('卡牌-询问', function (ask)
        ask:answer { card = jink }
    end)

    local ask = game:askPlayCard(players[2], '测试', { name = '闪' })

    lt.assertEquals('答复拿到了', jink, ask.card)
    lt.assertEquals('牌还在手上', 1, hand:count())
end)

lt.test('打出：候选按条件筛，答复多给目标会被拒收', function ()
    local game, players = newGame(3)
    local hand = assert(players[1]:getZone('手牌'))
    local jink  = game:createCard('闪')
    local slash = game:createCard('杀')
    hand:put(jink)
    hand:put(slash)
    game:on('卡牌-询问', function (ask)
        ask:answer { card = jink, targets = { players[2] } }
    end)

    local ask = game:askPlayCard(players[1], '测试', { name = '闪' })

    lt.assertEquals('候选只有那一张', 1, #assert(ask.options))
    lt.assertEquals('多给目标 ⇒ 没答复', nil, ask.card)
    lt.assertEquals('原因是「不该给目标」', '这次答复不该给目标', ask.err)
end)

lt.test('打出：答复的牌不在候选里就拒收', function ()
    local game, players = newGame(2)
    local hand = assert(players[2]:getZone('手牌'))
    local jink  = game:createCard('闪')
    local other = game:createCard('闪')
    hand:put(jink)
    game:on('卡牌-询问', function (ask)
        ask:answer { card = other }
    end)

    local ask = game:askPlayCard(players[2], '测试', { name = '闪' })

    lt.assertEquals('没拿到答复', nil, ask.card)
    lt.assertEquals('原因是「不在可选项里」', '答复不在可选项里', ask.err)
    lt.assertEquals('牌没被动', 1, hand:count())
end)
