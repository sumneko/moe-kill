local lt = require 'test.ltest'

---@param count integer
---@return Game
---@return Player[] # 按座位号升序
local function newGame(count)
    local game = moe.game.create {
        seats   = count,
        random  = moe.random.create(1),
        sources = { lt.cardSource },
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
        hand:accept(card)
    end
end

lt.test('抵消：打出 = 抵消成立，读 .success', function ()
    local game, players = newGame(2)
    local jink = game:createCard('闪')
    putInHand(players[2], { jink })
    game:on('卡牌-询问', function (ask)
        return { card = jink }
    end)

    local ask = game:askOffsetCard(players[2], '测试', { name = '闪' })

    lt.assertEquals('种类标识', 'askOffsetCard', ask.kind)
    lt.assertEquals('答复拿到了', jink, ask.card)
    lt.assertEquals('抵消成立', true, ask.success)
end)

lt.test('抵消：没打出 = 不成立（原因写进 .err），也不发时机', function ()
    local game, players = newGame(2)
    local fired = 0
    game:on('效果-被抵消', function ()
        fired = fired + 1
    end)

    local ask = game:askOffsetCard(players[2], '测试', { name = '闪' })

    lt.assertEquals('没答上', nil, ask.card)
    lt.assertEquals('没成立', false, ask.success)
    lt.assertEquals('原因', '没有打出', ask.err)
    lt.assertEquals('没打出就不发事件', 0, fired)
end)

lt.test('抵消：订阅者在回调里 cancel = 驳回这次抵消（调用后不返回）', function ()
    local game, players = newGame(2)
    local jink = game:createCard('闪')
    putInHand(players[2], { jink })
    game:on('卡牌-询问', function (ask)
        return { card = jink }
    end)
    local seen = false
    local after = false
    game:on('效果-被抵消', function (ask)
        seen = ask.card == jink
        ask:cancel('测试驳回')
        after = true
    end)

    local ask = game:askOffsetCard(players[2], '测试', { name = '闪' })

    lt.assertEquals('驳回时答复还读得到', true, seen)
    lt.assertEquals('cancel 之后不会返回', false, after)
    lt.assertEquals('被驳回：不成立', false, ask.success)
    lt.assertEquals('驳回原因记在 .err', '测试驳回', ask.err)
    lt.assertEquals('被驳回后没有结果', nil, ask.card)
end)

lt.test('抵消：两段时机（全局 → 来源）', function ()
    local game, players = newGame(2)
    local jink = game:createCard('闪')
    putInHand(players[2], { jink })
    game:on('卡牌-询问', function (ask)
        return { card = jink }
    end)

    ---@type string[]
    local fired = {}
    game:on('效果-被抵消', function ()
        fired[#fired + 1] = '全局'
    end)
    players[1]:on('效果-来源-被抵消', function ()
        fired[#fired + 1] = '来源'
    end)

    ---@type AskOffsetCard?
    local asked = nil
    game:on('效果-能否生效', function (effect)
        if effect.kind == 'damage' then
            asked = game:askOffsetCard(players[2], '测试', { name = '闪' })
        end
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('两份、全局先', '全局,来源', table.concat(fired, ','))
    lt.assertEquals('打出成立', true, assert(asked).success)
end)

lt.test('抵消：全局段驳回 ⇒ 来源段不再被问', function ()
    local game, players = newGame(2)
    local jink = game:createCard('闪')
    putInHand(players[2], { jink })
    game:on('卡牌-询问', function (ask)
        return { card = jink }
    end)

    ---@type string[]
    local fired = {}
    game:on('效果-被抵消', function (ask)
        fired[#fired + 1] = '全局'
        ask:cancel('全局驳回')
    end)
    players[1]:on('效果-来源-被抵消', function ()
        fired[#fired + 1] = '来源'
    end)

    ---@type AskOffsetCard?
    local asked = nil
    game:on('效果-能否生效', function (effect)
        if effect.kind == 'damage' then
            asked = game:askOffsetCard(players[2], '测试', { name = '闪' })
        end
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('只发了全局那份', '全局', table.concat(fired, ','))
    lt.assertEquals('被驳回：不成立', false, assert(asked).success)
    lt.assertEquals('驳回原因', '全局驳回', assert(asked).err)
end)

lt.test('抵消：答复不在候选里 = 拒收（复用既有口径）', function ()
    local game, players = newGame(2)
    local held = game:createCard('闪')
    putInHand(players[2], { held })
    local other = game:createCard('闪')
    game:on('卡牌-询问', function (ask)
        return { card = other }
    end)

    local ask = game:askOffsetCard(players[2], '测试', { name = '闪' })

    lt.assertEquals('没拿到答复', nil, ask.card)
    lt.assertEquals('原因保留「不在可选项里」', '答复不在可选项里', ask.err)
    lt.assertEquals('不成立', false, ask.success)
end)

lt.test('抵消：声明成立的牌也算打出（两段时机照发）', function ()
    local game, players = newGame(2)
    players[2]:addViewAs('闪'):on('发动', function ()
        return true
    end)

    ---@type Card?
    local seen = nil
    game:on('效果-被抵消', function (ask)
        seen = ask.card
    end)

    local ask = game:askOffsetCard(players[2], '测试', { name = '闪' })

    lt.assertEquals('答复是内核照声明造的虚拟牌', '闪', assert(ask.card).name)
    lt.assertEquals('抵消成立', true, ask.success)
    lt.assertEquals('被抵消时机里拿到的就是那张', ask.card, seen)
end)
