local lt      = require 'test.ltest'
local support = require 'test.rule.support'

---@param game Game
---@param name string
---@return Card # 牌堆里第一张叫这个名字的牌
---@return Zone # 它所在的牌区
local function findCard(game, name)
    local deck = assert(game:getZone('抽牌'), '没有抽牌')
    for _, card in ipairs(deck:list()) do
        if card.name == name then
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
    hand:accept(card)
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
    lt.assertEquals('用过的牌进了弃牌', 1, run.game:getZone('弃牌'):count())
    lt.assertEquals('弃牌里的就是那张杀', card, run.game:getZone('弃牌'):list()[1])
end)

lt.test('杀：使用过程中记上「不能响应」就不问他出【闪】', function ()
    local run    = support.start { count = 5, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local other  = run.players[3]
    local card   = takeSlash(run, user)
    takeCard(run, target, '闪') -- 手里有闪也不问

    ---@type UseCard?
    local seen = nil
    run.game:on('卡牌-结算前', function (useCard)
        ---@cast useCard UseCard
        seen = useCard
        -- 连续追加两次：名单要累加，不是后者顶掉前者
        useCard:addUseOptions { unrespondable = target }
        useCard:addUseOptions { unrespondable = { other } }
    end)

    ---@type integer
    local asked = 0
    run.game:on('卡牌-询问', function (ask)
        if ask.reason == '杀' then
            asked = asked + 1
        end
    end)

    run.game:useCard(user, card, { target })

    local used = assert(seen)
    lt.assertEquals('单个角色', true, used:isResponseBanned(target))
    lt.assertEquals('一串角色', true, used:isResponseBanned(other))
    lt.assertEquals('没记的不算', false, used:isResponseBanned(run.players[5]))
    lt.assertEquals('没问他出不出闪', 0, asked)
end)

lt.test('杀：记成谓词 ⇒ 只按这次的目标筛', function ()
    local run    = support.start { count = 5, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local other  = run.players[3]
    local card   = takeSlash(run, user)
    takeCard(run, target, '闪')

    ---@type UseCard?
    local seen = nil
    run.game:on('卡牌-结算前', function (useCard)
        ---@cast useCard UseCard
        seen = useCard
        useCard:addUseOptions { unrespondable = function (player)
            return player == target
        end }
    end)

    ---@type integer
    local asked = 0
    run.game:on('卡牌-询问', function (ask)
        if ask.reason == '杀' then
            asked = asked + 1
        end
    end)

    run.game:useCard(user, card, { target })

    local used = assert(seen)
    lt.assertEquals('命中的目标', true, used:isResponseBanned(target))
    lt.assertEquals('不是目标的进不了名单', false, used:isResponseBanned(other))
    lt.assertEquals('没问他出不出闪', 0, asked)
end)

lt.test('杀：记成 true ⇒ 这次的目标都不能响应', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local card   = takeSlash(run, user)
    takeCard(run, target, '闪')

    ---@type UseCard?
    local seen = nil
    run.game:on('卡牌-结算前', function (useCard)
        ---@cast useCard UseCard
        seen = useCard
        useCard:addUseOptions { unrespondable = true }
    end)

    ---@type integer
    local asked = 0
    run.game:on('卡牌-询问', function (ask)
        if ask.reason == '杀' then
            asked = asked + 1
        end
    end)

    run.game:useCard(user, card, { target })

    lt.assertEquals('目标被拦住了', true, assert(seen):isResponseBanned(target))
    lt.assertEquals('没问他出不出闪', 0, asked)
end)

lt.test('杀：攻击范围外的目标用不了', function ()
    local run    = support.start { count = 4, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[3]
    local card   = takeSlash(run, user)

    lt.assertFailed('隔着两个人够不着', run.game:useCard(user, card, { target }))

    lt.assertEquals('目标没掉血', 5, target:getAttr('体力'))
    lt.assertEquals('牌还留在手上', 1, user:getZone('手牌'):count())
    lt.assertEquals('弃牌还是空的', 0, run.game:getZone('弃牌'):count())
end)

lt.test('杀：带「无视距离」的使用选项，范围外也够得着', function ()
    local run    = support.start { count = 4, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[3]
    local card   = takeSlash(run, user)

    lt.assertEquals('隔一位的 3 号位距离 2（distance 只给真值）', 2, user:distance(target))
    lt.assertEquals('照常不在射程内（攻击范围 1）', false, user:isInRange(target, 1))
    lt.assertEquals('「无视距离」的选项：算在', true, user:isInRange(target, 1, { ignoreDistance = true }))
    lt.assertEquals('射程给 nil ⇒ 按攻击范围算（还是够不着）', false, user:isInRange(target))
    lt.assertEquals('射程给 nil + 无视距离 ⇒ 算在', true, user:isInRange(target, nil, { ignoreDistance = true }))

    lt.assertFailed('照常够不着', run.game:useCard(user, card, { target }))

    run.game:useCard(user, card, { target }, { ignoreDistance = true })

    lt.assertEquals('带选项就打得着（掉 1 点体力）', 4, target:getAttr('体力'))
    lt.assertEquals('牌也正常用出去进了弃牌', 1, run.game:getZone('弃牌'):count())
end)

lt.test('杀：不能对自己用', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    local card = takeSlash(run, user)

    lt.assertFailed('自己的合法目标里没有自己', run.game:useCard(user, card, { user }))

    lt.assertEquals('自己没掉血', 5, user:getAttr('体力'))
    lt.assertEquals('牌还留在手上', 1, user:getZone('手牌'):count())
    lt.assertEquals('弃牌还是空的', 0, run.game:getZone('弃牌'):count())
end)

lt.test('杀：目标打出闪就不受伤，闪进弃牌', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local card   = takeSlash(run, user)
    local jink   = takeCard(run, target, '闪')

    run.game:on('卡牌-询问', function (ask)
        return { card = jink }
    end)

    run.game:useCard(user, card, { target })

    lt.assertEquals('目标不掉血', 5, target:getAttr('体力'))
    lt.assertEquals('闪已经离开手牌', 0, target:getZone('手牌'):count())
    local discard = assert(run.game:getZone('弃牌')):list()
    lt.assertEquals('闪进了弃牌', true, moe.util.arrayHas(discard, jink))
    lt.assertEquals('杀也进了弃牌', true, moe.util.arrayHas(discard, card))
end)

lt.test('杀：被闪响应会发「效果-被响应」两份（全局 → 来源）', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local card   = takeSlash(run, user)
    local jink   = takeCard(run, target, '闪')

    ---@type string[]
    local fired = {}
    ---@type AskPlayCard?
    local seen = nil
    run.game:on('效果-被响应', function (ask)
        fired[#fired + 1] = '全局'
        seen = ask
    end)
    user:on('效果-来源-被响应', function ()
        fired[#fired + 1] = '来源'
    end)
    run.game:on('卡牌-询问', function (ask)
        return { card = jink }
    end)

    run.game:useCard(user, card, { target })

    lt.assertEquals('两份、全局先', '全局,来源', table.concat(fired, ','))
    lt.assertEquals('载荷就是这次询问', 'askPlayCard', assert(seen).kind)
    lt.assertEquals('响应成立：没掉血', 5, target:getAttr('体力'))
    lt.assertEquals('闪也打掉了', 0, target:getZone('手牌'):count())
end)

lt.test('杀：默认只能指定一名目标', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local user   = run.players[1]
    local first  = run.players[2]
    local second = run.players[3]
    local card   = takeSlash(run, user)

    local useCard = run.game:useCard(user, card, { first, second })

    lt.assertEquals('两张一起指定 ⇒ 用不出去', '「标准.杀」至多指定 1 个目标', useCard.err)
    lt.assertEquals('牌还留在手上', 1, assert(user:getZone('手牌')):count())
    lt.assertEquals('没有谁受伤', 5, first:getAttr('体力'))
end)

lt.test('杀：应答方不给牌时照常结算，不会挂住', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local card   = takeSlash(run, user)

    run.game:on('卡牌-询问', function ()
        -- 不表态 ⇒ 没答上
    end)

    run.game:useCard(user, card, { target })

    lt.assertEquals('没答上 ⇒ 照常受伤', 4, target:getAttr('体力'))
end)

lt.test('杀：目标答一张不是【闪】的牌会被拒收，等于没打出', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local card   = takeSlash(run, user)
    -- 手上真有张【杀】，但它不是这次的选项
    local other  = takeCard(run, target, '杀')

    run.game:on('卡牌-询问', function (ask)
        return { card = other }
    end)

    run.game:useCard(user, card, { target })

    lt.assertEquals('没答上【闪】⇒ 照常受伤', 4, target:getAttr('体力'))
    lt.assertEquals('那张【杀】还留在手上', 1, target:getZone('手牌'):count())
end)
