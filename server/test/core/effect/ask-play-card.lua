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

lt.test('打出：答复的牌当场交出来，进发起那次结算的临时区', function ()
    local game, players = newGame(2)
    local hand = assert(players[2]:getZone('手牌'))
    local jink = game:createCard('闪')
    hand:accept(jink)
    game:on('卡牌-询问', function (ask)
        return { card = jink }
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
    game:on('效果-能否生效', function (effect)
        if effect.kind == 'damage' then
            asked = game:askPlayCard(players[2], '测试', { name = '闪' })
        end
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
    hand:accept(jink)
    game:on('卡牌-询问', function (ask)
        return { card = jink }
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
    hand:accept(jink)
    hand:accept(slash)
    game:on('卡牌-询问', function (ask)
        return { card = jink, targets = { players[2] } }
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
    hand:accept(jink)
    game:on('卡牌-询问', function (ask)
        return { card = other }
    end)

    local ask = game:askPlayCard(players[2], '测试', { name = '闪' })

    lt.assertEquals('没拿到答复', nil, ask.card)
    lt.assertEquals('原因是「不在可选项里」', '答复不在可选项里', ask.err)
    lt.assertEquals('牌没被动', 1, hand:count())
end)

lt.test('打出：视为声明 —— 说成立就顶替这次打出', function ()
    local game, players = newGame(2)
    players[2]:addViewAs('闪'):on('发动', function ()
        return true
    end)

    ---@type AskPlayCard?
    local answered = nil
    game:on('卡牌-答复', function (askCard)
        ---@cast askCard AskPlayCard
        answered = askCard
    end)

    local ask = game:askPlayCard(players[2], '测试', { name = '闪' })

    lt.assertEquals('答复是内核照声明造的虚拟牌', '闪', assert(ask.card).name)
    lt.assertEquals('是虚拟牌', true, assert(ask.card).virtual)
    lt.assertEquals('也算答过（答复时机照发）', ask.card, assert(answered).card)
    lt.assertEquals('它没有实体牌、不进牌区', nil, assert(ask.card):getZone())
end)

lt.test('打出：声明成立了就不再问应答方', function ()
    local game, players = newGame(2)
    local jink = game:createCard('闪')
    putInHand(players[2], { jink })
    players[2]:addViewAs('闪'):on('发动', function ()
        return true
    end)
    ---@type integer
    local asked = 0
    game:on('卡牌-询问', function ()
        asked = asked + 1
    end)

    local ask = game:askPlayCard(players[2], '测试', { name = '闪' })

    lt.assertEquals('声明成立的算数', '闪', assert(ask.card).name)
    lt.assertEquals('不再问应答方', 0, asked)
    lt.assertEquals('实体牌还在手上', 1, assert(players[2]:getZone('手牌')):count())
end)

lt.test('打出：只试被问者身上的声明，全不成再问实体牌', function ()
    local game, players = newGame(2)
    local jink = game:createCard('闪')
    putInHand(players[2], { jink })

    ---@type integer
    local others = 0
    players[1]:addViewAs('闪'):on('发动', function ()
        others = others + 1
    end)
    ---@type integer
    local tried = 0
    players[2]:addViewAs('闪'):on('发动', function ()
        tried = tried + 1
    end)
    game:on('卡牌-询问', function (ask)
        return { card = jink }
    end)

    local ask = game:askPlayCard(players[2], '测试', { name = '闪' })

    lt.assertEquals('旁人的声明不会被试', 0, others)
    lt.assertEquals('自己的声明试过了', 1, tried)
    lt.assertEquals('照常走实体牌', jink, ask.card)
end)

lt.test('打出：声明造的牌不用交进临时区', function ()
    local game, players = newGame(2)
    players[2]:addViewAs('闪'):on('发动', function ()
        return true
    end)

    ---@type AskPlayCard?
    local asked = nil
    game:on('效果-能否生效', function (effect)
        if effect.kind == 'damage' then
            asked = game:askPlayCard(players[2], '测试', { name = '闪' })
        end
    end)

    game:damage(players[1], players[2], 1)

    local ask = assert(asked, '没问到')
    lt.assertEquals('答复是内核照声明造的虚拟牌', '闪', assert(ask.card).name)
    lt.assertEquals('没进任何牌区', nil, assert(ask.card):getZone())
    lt.assertEquals('也没进弃牌堆', false, moe.util.arrayHas(assert(game:getZone('弃牌')):list(), ask.card))
end)

lt.test('打出：按声明顺序依次试，第一个成立了就不试下一个', function ()
    local game, players = newGame(2)

    ---@type string[]
    local trace = {}
    players[2]:addViewAs('闪'):on('发动', function ()
        trace[#trace + 1] = '第一份'
        return true
    end)
    players[2]:addViewAs('闪'):on('发动', function ()
        trace[#trace + 1] = '第二份'
        return true
    end)

    local ask = game:askPlayCard(players[2], '测试', { name = '闪' })

    lt.assertEquals('只试了第一份', '第一份', table.concat(trace, ','))
    lt.assertEquals('造出的还是声明的那张牌', '闪', assert(ask.card).name)
end)

lt.test('打出：前一份不成立才试下一份', function ()
    local game, players = newGame(2)

    ---@type string[]
    local trace = {}
    players[2]:addViewAs('闪'):on('发动', function ()
        trace[#trace + 1] = '第一份'
    end)
    players[2]:addViewAs('闪'):on('发动', function ()
        trace[#trace + 1] = '第二份'
        return true
    end)

    local ask = game:askPlayCard(players[2], '测试', { name = '闪' })

    lt.assertEquals('两份都试了', '第一份,第二份', table.concat(trace, ','))
    lt.assertEquals('第二份成立的算数', '闪', assert(ask.card).name)
end)

lt.test('打出：声明要的牌名对不上就不试', function ()
    local game, players = newGame(2)
    local slash = game:createCard('杀')
    putInHand(players[2], { slash })

    ---@type integer
    local tried = 0
    players[2]:addViewAs('闪'):on('发动', function ()
        tried = tried + 1
        return true
    end)
    game:on('卡牌-询问', function ()
        return { card = slash }
    end)

    local ask = game:askPlayCard(players[2], '测试', { name = '杀' })

    lt.assertEquals('要的是【杀】，声明不参与', 0, tried)
    lt.assertEquals('走的是实体牌', slash, ask.card)
end)
