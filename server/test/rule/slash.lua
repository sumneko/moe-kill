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
---@return Card # 已经摆进该玩家手牌的「杀」
local function takeSlash(run, player)
    local card, deck = findCard(run.game, '杀')
    local hand = assert(player:getZone('手牌'), '没有手牌区')
    deck:move(card, hand)
    return card
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

    run.game:play(user, card, { target })

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

    lt.assertError('隔着两个人够不着', function ()
        run.game:play(user, card, { target })
    end)

    lt.assertEquals('目标没掉血', 5, target:getAttr('体力'))
    lt.assertEquals('牌还留在手上', 1, user:getZone('手牌'):count())
    lt.assertEquals('弃牌堆还是空的', 0, run.game:getZone('弃牌堆'):count())
end)
