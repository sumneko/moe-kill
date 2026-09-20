local lt      = require 'test.ltest'
local support = require 'test.rule.support'

---@param game Game
---@param name string
---@return Card # 牌堆里第一张叫这个名字的牌
---@return Zone # 它所在的牌区
local function findCard(game, name)
    local deck = assert(game:getZone('抽牌堆'), '没有抽牌堆')
    for _, card in ipairs(deck:list()) do
        if card:getLabel() == name then
            return card, deck
        end
    end
    error('抽牌堆里没有「{}」' % { name })
end

---@param run Test.RuleSupport
---@param player Player
---@param name string
---@return Card # 已经摆进该玩家手牌的牌
local function takeCard(run, player, name)
    local card, deck = findCard(run.game, name)
    local hand = assert(player:getZone('手牌'), '没有手牌区')
    deck:move(card, hand)
    return card
end

---@param run Test.RuleSupport
---@param player Player
---@return Card # 已经摆进该玩家手牌的「杀」
local function takeSlash(run, player)
    return takeCard(run, player, '杀')
end

lt.test('杀：开局给每个玩家写入攻击范围', function ()
    local run = support.start { count = 2, packages = { '标准' } }

    lt.assertEquals('一号位', 1, run.players[1]:getAttr('攻击范围'))
    lt.assertEquals('二号位', 1, run.players[2]:getAttr('攻击范围'))
end)

lt.test('杀：对攻击范围内的目标造成 1 点伤害', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local card   = takeSlash(run, user)

    run.game:useCard(user, card, { target })

    lt.assertEquals('目标掉 1 点体力', 4, target:getAttr('体力'))
    lt.assertEquals('使用者不受影响', 5, user:getAttr('体力'))
    lt.assertEquals('牌离开了手牌', 0, user:getZone('手牌'):count())
    lt.assertEquals('用过的牌进了弃牌堆', 1, run.game:getZone('弃牌堆'):count())
    lt.assertEquals('弃牌堆里的就是那张杀', card, run.game:getZone('弃牌堆'):list()[1])
end)

lt.test('杀：攻击范围外的目标用不了', function ()
    local run    = support.start { count = 4, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[3]
    local card   = takeSlash(run, user)

    lt.assertFailed('隔着两个人够不着', run.game:useCard(user, card, { target }))

    lt.assertEquals('目标没掉血', 5, target:getAttr('体力'))
    lt.assertEquals('牌还留在手上', 1, user:getZone('手牌'):count())
    lt.assertEquals('弃牌堆还是空的', 0, run.game:getZone('弃牌堆'):count())
end)

lt.test('杀：不能对自己用', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    local card = takeSlash(run, user)

    lt.assertFailed('自己的合法目标里没有自己', run.game:useCard(user, card, { user }))

    lt.assertEquals('自己没掉血', 5, user:getAttr('体力'))
    lt.assertEquals('牌还留在手上', 1, user:getZone('手牌'):count())
    lt.assertEquals('弃牌堆还是空的', 0, run.game:getZone('弃牌堆'):count())
end)

lt.test('杀：目标打出闪就不受伤，闪进弃牌堆', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local card   = takeSlash(run, user)
    local jink   = takeCard(run, target, '闪')

    run.game.events:on('游戏-询问', function (ask)
        ask:answer(jink)
    end)

    run.game:useCard(user, card, { target })

    lt.assertEquals('目标不掉血', 5, target:getAttr('体力'))
    lt.assertEquals('闪已经离开手牌', 0, target:getZone('手牌'):count())
    local discard = assert(run.game:getZone('弃牌堆')):list()
    lt.assertEquals('闪进了弃牌堆', true, moe.util.arrayHas(discard, jink))
    lt.assertEquals('杀也进了弃牌堆', true, moe.util.arrayHas(discard, card))
end)

lt.test('杀：多目标依次结算，一个目标的响应不影响另一个', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local user   = run.players[1]
    local first  = run.players[2]
    local second = run.players[3]
    local card   = takeSlash(run, user)
    local jink   = takeCard(run, first, '闪')

    run.game.events:on('游戏-询问', function (ask)
        if ask.to == first then
            ask:answer(jink)
        end
    end)

    run.game:useCard(user, card, { first, second })

    lt.assertEquals('先结算的目标打出了闪，不掉血', 5, first:getAttr('体力'))
    lt.assertEquals('后结算的目标没闪，掉 1 点', 4, second:getAttr('体力'))
end)

lt.test('杀：应答方不给牌时照常结算，不会挂住', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local card   = takeSlash(run, user)

    run.game.events:on('游戏-询问', function ()
        -- 不调 ask:answer ⇒ 没答上
    end)

    run.game:useCard(user, card, { target })

    lt.assertEquals('没答上 ⇒ 照常受伤', 4, target:getAttr('体力'))
end)
