local lt      = require 'test.ltest'
local support = require 'test.rule.support'

---@param game Game
---@param name string
---@return Card # 牌堆里第一张叫这个名字的牌
---@return Zone # 它所在的牌区
local function findCard(game, name)
    local deck = assert(game:getZone('抽牌'), '没有抽牌')
    for _, card in ipairs(deck:list()) do
        if card:getLabel() == name then
            return card, deck
        end
    end
    error('抽牌里没有「{}」' % { name })
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

lt.test('无中生有：用出去就摸两张', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    local card = takeCard(run, user, '无中生有')
    local deck = assert(run.game:getZone('抽牌'), '没有抽牌')
    local deckBefore = deck:count()

    run.game:useCard(user, card, { user })

    lt.assertEquals('手牌净多一张（用掉那张，又摸两张）', 2, assert(user:getZone('手牌')):count())
    lt.assertEquals('抽牌少了 2 张', deckBefore - 2, deck:count())
    lt.assertEquals('弃牌里就是那张锦囊', card, assert(run.game:getZone('弃牌')):list()[1])
    lt.assertEquals('处理只是路过', 0, assert(run.game:getZone('处理')):count())
end)

lt.test('无中生有：只能以自己为目标', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    local card = takeCard(run, user, '无中生有')

    local ok, _, legal = run.game:canUse(user, card, { user })
    local targets = assert(legal, '能用的牌该给出合法目标')
    lt.assertEquals('对自己用得了', true, ok)
    lt.assertEquals('合法目标就一个', 1, #targets)
    lt.assertEquals('那个目标就是自己', user, targets[1])

    local bad, reason = run.game:canUse(user, card, { run.players[2] })
    lt.assertEquals('对别人用不了', false, bad)
    lt.assertEquals('原因是不能以这个角色为目标', '「标准.无中生有」不能以这个角色为目标', reason)
end)

lt.test('无中生有：分类是锦囊与非延时锦囊', function ()
    local run = support.start { count = 2, packages = { '标准' } }
    local def = assert(run.game:getCard('无中生有'), '没有这张牌的定义')

    lt.assertEquals('是锦囊', true, def:isKind('锦囊'))
    lt.assertEquals('是非延时锦囊', true, def:isKind('非延时锦囊'))
    lt.assertEquals('两个分类都在', '锦囊,非延时锦囊', table.concat(def:getKinds(), ','))
    lt.assertEquals('从手牌用', '手牌', def:getZone())
end)
