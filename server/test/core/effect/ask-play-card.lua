local lt = require 'test.ltest'

---@param count integer
---@return Game
---@return Player[] # 按座位号升序
local function newGame(count)
    local game = moe.game.create {
        seats   = count,
        random  = moe.random.create(1),
        sources = { './package/*', lt.cardSource },
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

lt.test('打出：替代窗口 —— 返回一张牌就顶替这次打出', function ()
    local game, players = newGame(2)
    local virtual = game:createVirtualCard('闪')
    players[2]:on('打出-装备替代', function ()
        return virtual
    end)

    ---@type AskPlayCard?
    local answered = nil
    game:on('卡牌-答复', function (askCard)
        ---@cast askCard AskPlayCard
        answered = askCard
    end)

    local ask = game:askPlayCard(players[2], '测试', { name = '闪' })

    lt.assertEquals('答复就是那张替代牌', virtual, ask.card)
    lt.assertEquals('也算答过（答复时机照发）', virtual, assert(answered).card)
    lt.assertEquals('替代牌没有实体牌、不进牌区', nil, virtual:getZone())
end)

lt.test('打出：替代成立时不再问应答方', function ()
    local game, players = newGame(2)
    local jink = game:createCard('闪')
    putInHand(players[2], { jink })
    local virtual = game:createVirtualCard('闪')
    players[2]:on('打出-装备替代', function ()
        return virtual
    end)
    ---@type integer
    local asked = 0
    game:on('卡牌-询问', function ()
        asked = asked + 1
    end)

    local ask = game:askPlayCard(players[2], '测试', { name = '闪' })

    lt.assertEquals('替代的算数', virtual, ask.card)
    lt.assertEquals('不再问应答方', 0, asked)
    lt.assertEquals('实体牌还在手上', 1, assert(players[2]:getZone('手牌')):count())
end)

lt.test('打出：替代窗口只问被问者，没人替代就照常要实体牌', function ()
    local game, players = newGame(2)
    local jink = game:createCard('闪')
    putInHand(players[2], { jink })

    ---@type integer
    local others = 0
    players[1]:on('打出-技能替代', function ()
        others = others + 1
    end)
    players[1]:on('打出-装备替代', function ()
        others = others + 1
    end)
    game:on('卡牌-询问', function (ask)
        return { card = jink }
    end)

    local ask = game:askPlayCard(players[2], '测试', { name = '闪' })

    lt.assertEquals('旁人收不到这个窗口', 0, others)
    lt.assertEquals('照常走实体牌', jink, ask.card)
end)

lt.test('打出：替代牌没有实体牌，不用交进临时区', function ()
    local game, players = newGame(2)
    local virtual = game:createVirtualCard('闪')
    players[2]:on('打出-装备替代', function ()
        return virtual
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
    lt.assertEquals('答复就是替代牌', virtual, ask.card)
    lt.assertEquals('没进任何牌区', nil, virtual:getZone())
    lt.assertEquals('也没进弃牌堆', false, moe.util.arrayHas(assert(game:getZone('弃牌')):list(), virtual))
end)

lt.test('打出：替代窗口先问技能段、再问装备段', function ()
    local game, players = newGame(2)
    local virtual = game:createVirtualCard('闪')

    ---@type string[]
    local trace = {}
    players[2]:on('打出-技能替代', function ()
        trace[#trace + 1] = '技能'
    end)
    players[2]:on('打出-装备替代', function ()
        trace[#trace + 1] = '装备'
        return virtual
    end)

    local ask = game:askPlayCard(players[2], '测试', { name = '闪' })

    lt.assertEquals('先技能、后装备', '技能,装备', table.concat(trace, ','))
    lt.assertEquals('装备段给出了替代', virtual, ask.card)
end)

lt.test('打出：技能段给了替代就不再问装备段', function ()
    local game, players = newGame(2)
    local virtual = game:createVirtualCard('闪')

    ---@type integer
    local equipment = 0
    players[2]:on('打出-技能替代', function ()
        return virtual
    end)
    players[2]:on('打出-装备替代', function ()
        equipment = equipment + 1
    end)

    local ask = game:askPlayCard(players[2], '测试', { name = '闪' })

    lt.assertEquals('技能段顶掉了这次打出', virtual, ask.card)
    lt.assertEquals('装备段没被问', 0, equipment)
end)
