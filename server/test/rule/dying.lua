local lt      = require 'test.ltest'
local support = require 'test.rule.support'

---@param game Game
---@param name string
---@return Card # 抽牌里第一张叫这个名字的牌
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

---@param run Test.RuleSupport
---@return fun(player: Player): integer
local function seatOf(run)
    return function (player)
        return assert(run.desk:getIndex(player), '这个人不在桌上')
    end
end

lt.test('濒死：被打到 0 就进濒死，没人给桃就阵亡', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local target = run.players[2]

    local damage = run.game:damage(run.players[1], target, 5)

    lt.assertEquals('伤害本身没失败', nil, damage.err)
    lt.assertEquals('体力归零', 0, target:getAttr('体力'))
    lt.assertEquals('没人救 ⇒ 阵亡', false, target:isAlive())
    lt.assertEquals('手牌没被动过', 0, target:getZone('手牌'):count())
end)

lt.test('濒死：自己给一张桃就能活下来', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local target = run.players[2]
    local peach  = takeCard(run, target, '桃')

    run.game:on('卡牌-询问', function (ask)
        if ask.to == target then
            ask:answer(peach)
        end
    end)

    run.game:damage(run.players[1], target, 5)

    lt.assertEquals('被救回来，体力到 1', 1, target:getAttr('体力'))
    lt.assertEquals('还活着', true, target:isAlive())
    lt.assertEquals('桃不在手上了', 0, target:getZone('手牌'):count())
    lt.assertEquals('桃进了弃牌', 1, run.game:getZone('弃牌'):count())
    lt.assertEquals('处理只是路过', 0, assert(run.game:getZone('处理')):count())
end)

lt.test('濒死：从濒死者开始按行动顺序问，下家的桃也能救人', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local target = run.players[2]
    local helper = run.players[3]
    local peach  = takeCard(run, helper, '桃')
    local seat   = seatOf(run)

    ---@type Player[] # 被问过的人（按被问顺序）
    local asked = {}
    run.game:on('卡牌-询问', function (ask)
        asked[#asked + 1] = assert(ask.to)
        if ask.to == helper then
            ask:answer(peach)
        end
    end)

    run.game:damage(run.players[1], target, 5)

    lt.assertEquals('只问了两家', 2, #asked)
    lt.assertEquals('先问濒死者本人', 2, seat(asked[1]))
    lt.assertEquals('再问他的下家', 3, seat(asked[2]))
    lt.assertEquals('下家把桃用了出来', 1, target:getAttr('体力'))
    lt.assertEquals('还活着', true, target:isAlive())
end)

lt.test('濒死：差 2 点时同一个人可以连给两张', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local target = run.players[2]

    ---@type Card[]
    local remaining = { takeCard(run, target, '桃'), takeCard(run, target, '桃') }
    run.game:on('卡牌-询问', function (ask)
        if ask.to == target and #remaining > 0 then
            ask:answer(table.remove(remaining, 1))
        end
    end)

    run.game:damage(run.players[1], target, 6)

    lt.assertEquals('两张桃把体力顶回 1', 1, target:getAttr('体力'))
    lt.assertEquals('还活着', true, target:isAlive())
    lt.assertEquals('两张桃都进了弃牌', 2, run.game:getZone('弃牌'):count())
end)

lt.test('濒死：一圈都没人给桃时就真死，并且触发玩家-死亡', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local target = run.players[2]

    ---@type Player?
    local dead = nil
    run.game:on('玩家-死亡', function (player)
        dead = player
    end)

    run.game:damage(run.players[1], target, 5)

    lt.assertEquals('阵亡', false, target:isAlive())
    lt.assertEquals('「玩家-死亡」的上下文是这个玩家', target, dead)
end)

lt.test('桃：出牌阶段对自己使用，回复 1 点', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    user:setAttr('体力', 3)
    local peach = takeCard(run, user, '桃')

    run.game:useCard(user, peach, { user })

    lt.assertEquals('回到 4 点', 4, user:getAttr('体力'))
    lt.assertEquals('桃进了弃牌', 1, run.game:getZone('弃牌'):count())
end)

lt.test('桃：满血时用不了', function ()
    local run   = support.start { count = 2, packages = { '标准' } }
    local user  = run.players[1]
    local peach = takeCard(run, user, '桃')

    lt.assertFailed('满血 ⇒ 没有合法目标', run.game:useCard(user, peach, { user }))

    lt.assertEquals('体力没变', 5, user:getAttr('体力'))
    lt.assertEquals('桃还留在手上', 1, user:getZone('手牌'):count())
end)

lt.test('桃：别人既没受伤也没濒死时不能拿他当目标', function ()
    local run   = support.start { count = 2, packages = { '标准' } }
    local user  = run.players[1]
    local other = run.players[2]
    user:setAttr('体力', 3)
    local peach = takeCard(run, user, '桃')

    lt.assertFailed('桃不能给别人回血', run.game:useCard(user, peach, { other }))

    lt.assertEquals('桃还留在手上', 1, user:getZone('手牌'):count())
end)
