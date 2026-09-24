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

---@param run Test.RuleSupport
---@param player Player
---@param name string
---@return Card # 已经用出去、装在自己装备区的牌
local function equipCard(run, player, name)
    local card = takeCard(run, player, name)
    run.game:useCard(player, card, {})
    return card
end

lt.test('装备：装备牌没有目标，出牌阶段能选中它并用出去', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    local card = takeCard(run, user, '诸葛连弩')

    ---@type AskCard.Option?
    local option = nil
    run.game:on('卡牌-询问', function (ask)
        local options = assert(ask.options)
        option = options[1]
        ask:answer(support.pickFirst(ask))
    end)

    local ask = run.game:askUseCard(user, '出牌', { zone = '手牌' })

    lt.assertEquals('选项里就是这张装备牌', card, assert(assert(option).card))
    lt.assertEquals('无目标牌的选项不带 targets', nil, assert(option).targets)
    lt.assertEquals('答复只有牌、没有目标', nil, ask.targets)

    run.game:useCard(user, assert(ask.card), ask.targets or {})

    lt.assertEquals('牌进了武器槽', card, assert(user:getZone('装备')):getSlot('武器'))
end)

lt.test('装备：用出去就落进对应的槽，并按数据加攻击范围', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]

    local card = equipCard(run, user, '麒麟弓')

    lt.assertEquals('进了武器槽', card, assert(user:getZone('装备')):getSlot('武器'))
    lt.assertEquals('装备区就这一张', 1, assert(user:getZone('装备')):count())
    lt.assertEquals('攻击范围 1 + 4', 5, user:getAttr('攻击范围'))
    lt.assertEquals('结算完的牌没被收进弃牌堆', 0, assert(run.game:getZone('弃牌')):count())
end)

lt.test('装备：坐骑各进自己的槽，改的是距离修正', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]

    local horse  = equipCard(run, user, '赤兔')
    local shield = equipCard(run, user, '的卢')

    lt.assertEquals('进攻马进了进攻马槽', horse, assert(user:getZone('装备')):getSlot('进攻马'))
    lt.assertEquals('防御马进了防御马槽', shield, assert(user:getZone('装备')):getSlot('防御马'))
    lt.assertEquals('两个槽位互不影响', 2, assert(user:getZone('装备')):count())
    lt.assertEquals('进攻修正 -1', -1, user:getAttr('进攻修正'))
    lt.assertEquals('防御修正 +1', 1, user:getAttr('防御修正'))
end)

lt.test('装备：同槽换新装备，旧牌进弃牌堆、加成换成新的', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]

    local old = equipCard(run, user, '诸葛连弩')
    lt.assertEquals('先装上的是攻击范围 1', 1, user:getAttr('攻击范围'))

    local new = equipCard(run, user, '麒麟弓')

    lt.assertEquals('槽里是新的那张', new, assert(user:getZone('装备')):getSlot('武器'))
    lt.assertEquals('装备区只有一张', 1, assert(user:getZone('装备')):count())
    lt.assertEquals('旧牌进了弃牌堆', true,
        moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), old))
    lt.assertEquals('攻击范围换成新的（旧的不再叠加）', 5, user:getAttr('攻击范围'))
end)

lt.test('装备：被【过河拆桥】拆走后修正回落，槽位也读不到了', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local weapon = equipCard(run, target, '麒麟弓')
    local trick  = takeCard(run, user, '过河拆桥')
    local equip  = assert(target:getZone('装备'))

    run.game:on('卡牌-询问', function (ask)
        ask:answer { card = weapon }
    end)

    run.game:useCard(user, trick, { target })

    lt.assertEquals('装备区空了', 0, equip:count())
    lt.assertEquals('攻击范围回落到 1', 1, target:getAttr('攻击范围'))
    lt.assertEquals('槽位读不到那张牌', nil, equip:getSlot('武器'))
    lt.assertEquals('拆走的牌进了弃牌堆', true,
        moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), weapon))
end)

lt.test('装备：进攻马让自己到别人的距离 -1、防御马让别人到自己的距离 +1', function ()
    local run   = support.start { count = 4, packages = { '标准' } }
    local one   = run.players[1]
    local two   = run.players[2]
    local three = run.players[3]

    for _, player in ipairs(run.players) do
        takeCard(run, player, '杀')   -- 每人都得身上有牌，顺手牵羊才有得挑
    end
    local trick = takeCard(run, one, '顺手牵羊')

    ---@return string # 顺手牵羊的合法目标（按座位号；用它观察距离：距离 1 以内且身上有牌）
    local function reachable()
        local targets = assert(select(3, run.game:canUse(one, trick)), '该给出合法目标')
        ---@type string[]
        local seats = {}
        for i, player in ipairs(targets) do
            seats[i] = tostring(assert(run.desk:getIndex(player)))
        end
        return table.concat(seats, ',')
    end

    lt.assertEquals('隔一位的 3 号位本来够不着（相邻的 2 / 4 号位够得着）', '2,4', reachable())

    equipCard(run, one, '赤兔')
    lt.assertEquals('进攻马：自己到别人 -1 ⇒ 3 号位也够得着了', '2,3,4', reachable())
    lt.assertEquals('相邻的 2 号位照旧够得着（距离最小 1，不会减到 0）', true,
        moe.util.arrayHas(assert(select(3, run.game:canUse(one, trick))), two))

    run.game:moveCard(assert(assert(one:getZone('装备')):getSlot('进攻马')), '弃牌')
    lt.assertEquals('马被拆走就回到原样', '2,4', reachable())
    lt.assertEquals('进攻修正也回落', 0, one:getAttr('进攻修正'))

    equipCard(run, two, '的卢')
    lt.assertEquals('防御马：别人到自己 +1 ⇒ 相邻的 2 号位也够不着了', '4', reachable())
    lt.assertEquals('防御修正记在骑着马的那个人身上', 1, two:getAttr('防御修正'))
    lt.assertEquals('进攻修正不受影响', 0, one:getAttr('进攻修正'))
end)

lt.test('装备：牌表里 14 张装备都定义好了，各自进对了槽', function ()
    local run = support.start { count = 2, packages = { '标准' } }

    ---@class Test.EquipExpect
    ---@field slot string # 该进的槽位名
    ---@field range? integer # 官方攻击范围（数据存的是在默认 1 之上的增量）
    ---@field delta? integer # 距离修正

    ---@type table<string, Test.EquipExpect>
    local expected = {
        ['诸葛连弩']   = { slot = '武器', range = 1 },
        ['雌雄双股剑'] = { slot = '武器', range = 2 },
        ['青紅剑']     = { slot = '武器', range = 2 },
        ['青龙偃月刀'] = { slot = '武器', range = 3 },
        ['丈八蛇矛']   = { slot = '武器', range = 3 },
        ['贯石斧']     = { slot = '武器', range = 3 },
        ['方天画戟']   = { slot = '武器', range = 4 },
        ['麒麟弓']     = { slot = '武器', range = 5 },
        ['赤兔']       = { slot = '进攻马', delta = -1 },
        ['大宛']       = { slot = '进攻马', delta = -1 },
        ['紫骍']       = { slot = '进攻马', delta = -1 },
        ['的卢']       = { slot = '防御马', delta = 1 },
        ['绝影']       = { slot = '防御马', delta = 1 },
        ['爪黄飞电']   = { slot = '防御马', delta = 1 },
    }

    ---@type table<string, true>
    local inTable = {}
    for _, entry in ipairs(assert(run.game:getValue('牌表'), '没有牌表')) do
        if expected[entry.name] then
            inTable[entry.name] = true
        end
    end

    for name, want in pairs(expected) do
        lt.assertEquals(name .. '：牌表里有这张牌', true, inTable[name] == true)

        local def = assert(run.game:getCard(name), '没有定义：' .. name)
        lt.assertEquals(name .. '：是装备', true, def:isKind('装备'))
        lt.assertEquals(name .. '：分类里有槽位名（内核按它找槽）', true, def:isKind(want.slot))
        if want.range then
            lt.assertEquals(name .. '：攻击范围增量', want.range - 1, def:getValue('攻击范围'))
        end
        if want.delta then
            lt.assertEquals(name .. '：距离修正', want.delta, def:getValue('距离修正'))
        end
    end
end)
