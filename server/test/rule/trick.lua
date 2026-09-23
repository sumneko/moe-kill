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

lt.test('南蛮入侵：所有其他角色各挨一次，打出杀的就不受伤', function ()
    local run   = support.start { count = 3, packages = { '标准' } }
    local user  = run.players[1]
    local card  = takeCard(run, user, '南蛮入侵')
    local slash = takeCard(run, run.players[2], '杀')

    run.game:on('卡牌-询问', function (ask)
        if ask.to == run.players[2] then
            ask:answer { card = slash }
        end
    end)

    run.game:useCard(user, card, { run.players[2], run.players[3] })

    lt.assertEquals('打出杀的不受伤', 5, run.players[2]:getAttr('体力'))
    lt.assertEquals('没杀可打的掉 1 点', 4, run.players[3]:getAttr('体力'))
    lt.assertEquals('使用者不受影响', 5, user:getAttr('体力'))
    lt.assertEquals('打出的杀进了弃牌', true, moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), slash))
end)

lt.test('万箭齐发：所有其他角色各挨一次，打出闪的就不受伤', function ()
    local run  = support.start { count = 3, packages = { '标准' } }
    local user = run.players[1]
    local card = takeCard(run, user, '万箭齐发')
    local jink = takeCard(run, run.players[3], '闪')

    run.game:on('卡牌-询问', function (ask)
        if ask.to == run.players[3] then
            ask:answer { card = jink }
        end
    end)

    run.game:useCard(user, card, { run.players[2], run.players[3] })

    lt.assertEquals('打出闪的不受伤', 5, run.players[3]:getAttr('体力'))
    lt.assertEquals('没闪可打的掉 1 点', 4, run.players[2]:getAttr('体力'))
    lt.assertEquals('使用者不受影响', 5, user:getAttr('体力'))
end)

lt.test('南蛮入侵 / 万箭齐发：合法目标是所有其他角色', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local user   = run.players[1]
    local nanman = takeCard(run, user, '南蛮入侵')
    local arrows = takeCard(run, user, '万箭齐发')

    local one = assert(select(3, run.game:canUse(user, nanman)), '南蛮该给出合法目标')
    lt.assertEquals('三个人的局里两个目标', 2, #one)
    lt.assertEquals('不含自己', false, moe.util.arrayHas(one, user))

    local other = assert(select(3, run.game:canUse(user, arrows)), '万箭该给出合法目标')
    lt.assertEquals('万箭一样', 2, #other)
    lt.assertEquals('不含自己', false, moe.util.arrayHas(other, user))
end)

lt.test('锦囊：三张的分类都是锦囊与非延时锦囊', function ()
    local run = support.start { count = 2, packages = { '标准' } }

    for _, name in ipairs({ '无中生有', '南蛮入侵', '万箭齐发' }) do
        local def = assert(run.game:getCard(name), '没有这张牌的定义')

        lt.assertEquals('{} 是锦囊' % { name }, true, def:isKind('锦囊'))
        lt.assertEquals('{} 是非延时锦囊' % { name }, true, def:isKind('非延时锦囊'))
        lt.assertEquals('{} 的两个分类都在' % { name }, '锦囊,非延时锦囊', table.concat(def:getKinds(), ','))
        lt.assertEquals('{} 从手牌用' % { name }, '手牌', def:getZone())
    end
end)
