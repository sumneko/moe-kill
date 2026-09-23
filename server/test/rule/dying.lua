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
            ask:answer { card = peach, targets = { target } }
        end
    end)

    run.game:damage(run.players[1], target, 5)

    lt.assertEquals('被救回来，体力到 1', 1, target:getAttr('体力'))
    lt.assertEquals('还活着', true, target:isAlive())
    lt.assertEquals('桃不在手上了', 0, target:getZone('手牌'):count())
    lt.assertEquals('桃进了弃牌', 1, run.game:getZone('弃牌'):count())
    lt.assertEquals('处理只是路过', 0, assert(run.game:getZone('处理')):count())
end)

lt.test('濒死：从当前回合角色开始按行动顺序问，下家的桃也能救人', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local turn   = run.players[1]
    local target = run.players[2]
    local helper = run.players[3]
    local peach  = takeCard(run, helper, '桃')
    local seat   = seatOf(run)

    ---@type Player[] # 被问过的人（按被问顺序）
    local asked = {}
    run.game:on('卡牌-询问', function (ask)
        asked[#asked + 1] = assert(ask.to)
        if ask.to == helper then
            ask:answer { card = peach, targets = { target } }
        end
    end)

    run.game:damage(turn, target, 5)

    lt.assertEquals('一圈里三家各问一次', 3, #asked)
    lt.assertEquals('先问当前回合角色', 1, seat(asked[1]))
    lt.assertEquals('再问濒死者本人', 2, seat(asked[2]))
    lt.assertEquals('最后问濒死者的下家', 3, seat(asked[3]))
    lt.assertEquals('下家把桃用了出来', 1, target:getAttr('体力'))
    lt.assertEquals('还活着', true, target:isAlive())
end)

lt.test('濒死：差 2 点时同一个人可以连给两张', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local target = run.players[2]
    local seat   = seatOf(run)

    ---@type Card[]
    local remaining = { takeCard(run, target, '桃'), takeCard(run, target, '桃') }
    ---@type Player[] # 被问过的人（按被问顺序）
    local asked = {}
    run.game:on('卡牌-询问', function (ask)
        asked[#asked + 1] = assert(ask.to)
        if ask.to == target and #remaining > 0 then
            ask:answer { card = table.remove(remaining, 1), targets = { target } }
        end
    end)

    run.game:damage(run.players[1], target, 6)

    lt.assertEquals('两张桃把体力顶回 1', 1, target:getAttr('体力'))
    lt.assertEquals('还活着', true, target:isAlive())
    lt.assertEquals('两张桃都进了弃牌', 2, run.game:getZone('弃牌'):count())
    lt.assertEquals('回正之前一直问同一个人，不回头问前面的', '1,2,2',
        ('%s,%s,%s'):format(seat(asked[1]), seat(asked[2]), seat(asked[3])))
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

lt.test('濒死：判死发生在「伤害-后」之前', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local target = run.players[2]

    ---@type boolean?
    local aliveAtAfter = nil
    run.game:on('伤害-后', function ()
        aliveAtAfter = target:isAlive()
    end)

    run.game:damage(run.players[1], target, 5)

    lt.assertEquals('伤害收尾时人已经死了（濒死排在它之前）', false, aliveAtAfter)
    lt.assertEquals('阵亡', false, target:isAlive())
end)

lt.test('濒死：被救活 ⇒ 脱离时机当场发，且账清掉', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local target = run.players[2]
    local peach  = takeCard(run, target, '桃')

    ---@type Dying?
    local seen = nil
    ---@type integer
    local leftTimes = 0
    run.game:on('濒死-进入', function (dying)
        seen = dying
    end)
    run.game:on('濒死-离开', function () leftTimes = leftTimes + 1 end)
    run.game:on('卡牌-询问', function (ask)
        if ask.to == target then
            ask:answer { card = peach, targets = { target } }
        end
    end)

    local damage = run.game:damage(run.players[1], target, 5)
    local dying  = assert(seen, '没进濒死')

    lt.assertEquals('带着那次伤害', damage, dying.damage)
    lt.assertEquals('活下来了', true, target:isAlive())
    lt.assertEquals('体力回正 ⇒ 当场发过一次脱离', 1, leftTimes)
    lt.assertEquals('账已经清掉了', nil, run.game:getDying(target))
end)

lt.test('濒死：阵亡时，死亡时机里读得到致死伤害', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local target = run.players[2]

    ---@type Damage?
    local lethal = nil
    run.game:on('玩家-死亡', function (player)
        local dying = run.game:getDying(player)
        lethal = dying and dying.damage
    end)

    local damage = run.game:damage(run.players[1], target, 5)

    lt.assertEquals('就是那次伤害', damage, lethal)
    lt.assertEquals('凶手是打他的那个', run.players[1], assert(lethal).from)
    lt.assertEquals('结算完账就清了', nil, run.game:getDying(target))
end)

lt.test('濒死：濒死中再受伤，致死伤害与凶手都换最后一次', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local target = run.players[2]

    ---@type Damage?
    local second  = nil
    ---@type Damage?
    local lethal  = nil

    run.game:on('濒死-进入', function (dying)
        if not second then
            second = run.game:damage(run.players[3], dying.player, 3)   -- 濒死中再挨一下
        end
    end)
    run.game:on('玩家-死亡', function (player)
        local dying = run.game:getDying(player)
        lethal = dying and dying.damage
    end)

    run.game:damage(run.players[1], target, 5)

    lt.assertEquals('致死伤害是后一次', second, lethal)
    lt.assertEquals('凶手按后一次算', run.players[3], assert(lethal).from)
    lt.assertEquals('阵亡', false, target:isAlive())
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
