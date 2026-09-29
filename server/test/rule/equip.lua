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
---@param name string
---@return Card # 已经用出去、装在自己装备区的牌
local function equipCard(run, player, name)
    local card = takeCard(run, player, name)
    run.game:useCard(player, card, {})
    return card
end

---@param run Test.RuleSupport
---@param player Player
---@param keep Card # 留着的那张
local function clearHandExcept(run, player, keep)
    local hand = assert(player:getZone('手牌'), '没有手牌区')
    for _, card in ipairs(hand:list()) do
        if card ~= keep then
            run.game:moveCard(card, '弃牌')
        end
    end
end

lt.test('装备：游戏开始时给每个玩家的装备区设好四条槽位', function ()
    local run = support.start { count = 3, packages = { '标准' } }

    for _, player in ipairs(run.players) do
        lt.assertEquals('槽位名按声明顺序', '武器,防具,进攻马,防御马',
            table.concat(assert(player:getZone('装备'), '没有装备区').slots, ','))
    end
end)

lt.test('装备：装备牌没有目标，出牌阶段能选中它并用出去', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    local card = takeCard(run, user, '诸葛连弩')

    ---@type AskUseCard.Option?
    local option = nil
    run.game:on('卡牌-询问', function (ask)
        ---@cast ask AskUseCard
        local options = assert(ask.options)
        option = options[1]
        ask:answer(support.pickFirst(ask))
    end)

    local ask = run.game:askUseCard(user, '出牌', { zone = '手牌' })

    lt.assertEquals('选项里就是这张装备牌', card, assert(assert(option).card))
    lt.assertEquals('无目标牌：可用目标是空表', 0, #assert(assert(option).plan.legal))
    lt.assertEquals('区间是 0、0', '0,0', assert(option).plan.min .. ',' .. assert(option).plan.max)
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
        local plan = assert(select(3, run.game:canUse(one, trick)), '该给出合法目标')
        local targets = assert(plan.legal)
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
    local plan = assert(select(3, run.game:canUse(one, trick)))
    lt.assertEquals('相邻的 2 号位照旧够得着（距离最小 1，不会减到 0）', true,
        moe.util.arrayHas(assert(plan.legal), two))

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
    ---@field range? integer # 官方攻击范围（牌上写的就是这个值）
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
            lt.assertEquals(name .. '：攻击范围与描述一致', want.range, def:getValue('攻击范围'))
        end
        if want.delta then
            lt.assertEquals(name .. '：距离修正', want.delta, def:getValue('距离修正'))
        end
    end
end)

lt.test('装备：两类坐骑各自是一个定义，分类与钩子都在这里备好', function ()
    local run = support.start { count = 2, packages = { '标准' } }

    local horse = assert(run.game:getCard('坐骑牌'), '没有坐骑牌')
    lt.assertEquals('坐骑牌：是装备', true, horse:isKind('装备'))
    lt.assertEquals('坐骑牌：是坐骑', true, horse:isKind('坐骑'))
    lt.assertEquals('坐骑牌：不沾具体哪种马', false, horse:isKind('进攻马'))
    lt.assertEquals('坐骑牌：不沾具体哪种马（二）', false, horse:isKind('防御马'))

    for _, name in ipairs { '进攻马', '防御马' } do
        local def = assert(run.game:getCard(name), '没有定义：' .. name)
        lt.assertEquals(name .. '：抄来了装备与坐骑', true, def:isKind('装备') and def:isKind('坐骑'))
        lt.assertEquals(name .. '：分类里有槽位名', true, def:isKind(name))
        lt.assertEquals(name .. '：两条马各管一边', false,
            def:isKind(name == '进攻马' and '防御马' or '进攻马'))
        lt.assertEquals(name .. '：距离修正也在这里定下', name == '进攻马' and -1 or 1,
            def:getValue('距离修正'))
        lt.assertEquals(name .. '：被动钩子也从坐骑牌抄来了', 1, #def:getHandlers('被动'))
        lt.assertEquals(name .. '：启停钩子（装备模板的）也在', 1, #def:getHandlers('进入区域'))
    end
end)

lt.test('装备：被动可以临时压制，松开后恢复', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    local weapon = equipCard(run, user, '麒麟弓')
    lt.assertEquals('先装上：攻击范围 1 + 4', 5, user:getAttr('攻击范围'))

    weapon:disablePassive()
    lt.assertEquals('压制住：加成被撤（牌还挂在槽里）', 1, user:getAttr('攻击范围'))

    weapon:enablePassive()
    lt.assertEquals('松开：重新应用', 5, user:getAttr('攻击范围'))
end)

lt.test('装备：进错槽位不启用被动', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    local weapon = takeCard(run, user, '麒麟弓')
    local equip  = assert(user:getZone('装备'))

    run.game:moveCardWithSlot(weapon, equip, '防具')

    lt.assertEquals('牌进了防具槽（槽位本身不挑分类）', weapon, equip:getSlot('防具'))
    lt.assertEquals('分类对不上：被动没启用，攻击范围还是 1', 1, user:getAttr('攻击范围'))
end)

lt.test('装备：离槽停用后放回，重新启用', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    local weapon = equipCard(run, user, '麒麟弓')
    local equip  = assert(user:getZone('装备'))

    run.game:moveCard(weapon, '弃牌')
    lt.assertEquals('离槽：加成回落', 1, user:getAttr('攻击范围'))

    run.game:moveCardWithSlot(weapon, equip, '武器')
    lt.assertEquals('放回槽位：重新应用', 5, user:getAttr('攻击范围'))
end)

lt.test('方天画戟：最后手牌用【杀】可指定两名目标，违规的用不出去', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local user   = run.players[1]
    local first  = run.players[2]
    local second = run.players[3]

    equipCard(run, user, '方天画戟')
    local card = takeCard(run, user, '杀')
    clearHandExcept(run, user, card)

    local ok, _, plan = run.game:canUse(user, card, { first, second })
    ---@cast plan Game.UsableTargets
    lt.assertEquals('两名目标成立', true, ok)
    lt.assertEquals('区间带上修正（不超合法目标数）', '1,2', plan.min .. ',' .. plan.max)
    lt.assertEquals('合法目标就是另外两名', 2, #assert(plan.legal))

    local over, overReason = run.game:canUse(user, card, { user, first, second })
    lt.assertEquals('三名（超合法数）用不出去', false, over)
    lt.assertEquals('上限就是合法目标数 2', '「标准.杀」至多指定 2 个目标', overReason)

    local none, noneReason = run.game:canUse(user, card, {})
    lt.assertEquals('不给目标用不出去', false, none)
    lt.assertEquals('原因是要至少一个', '「标准.杀」至少要指定 1 个目标', noneReason)

    local bad, badReason = run.game:canUse(user, card, { user, first })
    lt.assertEquals('含自己用不出去', false, bad)
    lt.assertEquals('原因点名这个角色', '「标准.杀」不能以这个角色为目标', badReason)

    local dup, dupReason = run.game:canUse(user, card, { first, first })
    lt.assertEquals('重复目标用不出去', false, dup)
    lt.assertEquals('原因点名重复', '「标准.杀」不能重复指定同一个目标', dupReason)
end)

lt.test('方天画戟：两名目标依次结算，一个目标的响应不影响另一个', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local user   = run.players[1]
    local first  = run.players[2]
    local second = run.players[3]

    equipCard(run, user, '方天画戟')
    local card = takeCard(run, user, '杀')
    clearHandExcept(run, user, card)
    local jink = takeCard(run, first, '闪')

    run.game:on('卡牌-询问', function (ask)
        if ask.to == first then
            ask:answer { card = jink }
        end
    end)

    run.game:useCard(user, card, { first, second })

    lt.assertEquals('先结算的目标打出了闪，不掉血', 5, first:getAttr('体力'))
    lt.assertEquals('后结算的目标没闪，掉 1 点', 4, second:getAttr('体力'))
end)

lt.test('方天画戟：不是最后手牌就不放宽', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local user   = run.players[1]
    local first  = run.players[2]
    local second = run.players[3]

    equipCard(run, user, '方天画戟')
    local card = takeCard(run, user, '杀')
    takeCard(run, user, '桃')   -- 手上还有别的

    local ok, reason = run.game:canUse(user, card, { first, second })
    lt.assertEquals('两名用不出去', false, ok)
    lt.assertEquals('原因就是默认上限 1', '「标准.杀」至多指定 1 个目标', reason)
    lt.assertEquals('一名照常能用', true, (run.game:canUse(user, card, { first })))
end)

lt.test('方天画戟：没装备就不放宽', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local user   = run.players[1]
    local first  = run.players[2]
    local second = run.players[3]

    local card = takeCard(run, user, '杀')
    clearHandExcept(run, user, card)

    local ok, reason = run.game:canUse(user, card, { first, second })
    lt.assertEquals('两名用不出去', false, ok)
    lt.assertEquals('原因就是默认上限 1', '「标准.杀」至多指定 1 个目标', reason)
end)

lt.test('方天画戟：拆下后失效', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local user   = run.players[1]
    local first  = run.players[2]
    local second = run.players[3]

    local weapon = equipCard(run, user, '方天画戟')
    local card   = takeCard(run, user, '杀')
    clearHandExcept(run, user, card)

    lt.assertEquals('装着的时候两名能用', true, (run.game:canUse(user, card, { first, second })))

    run.game:moveCard(weapon, '弃牌')
    local ok, reason = run.game:canUse(user, card, { first, second })
    lt.assertEquals('拆走后两名用不出去', false, ok)
    lt.assertEquals('原因就是默认上限 1', '「标准.杀」至多指定 1 个目标', reason)
end)

lt.test('方天画戟：只放宽【杀】，别的牌照旧', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local user   = run.players[1]
    local first  = run.players[2]
    local second = run.players[3]

    equipCard(run, user, '方天画戟')
    local card = takeCard(run, user, '决斗')
    clearHandExcept(run, user, card)

    local ok, reason = run.game:canUse(user, card, { first, second })
    lt.assertEquals('决斗两名用不出去', false, ok)
    lt.assertEquals('原因就是默认上限 1', '「标准.决斗」至多指定 1 个目标', reason)
end)

lt.test('方天画戟：只认装备主用的【杀】', function ()
    local run   = support.start { count = 3, packages = { '标准' } }
    local owner = run.players[1]
    local user  = run.players[2]
    local other = run.players[3]

    equipCard(run, owner, '方天画戟')
    local card = takeCard(run, user, '杀')
    clearHandExcept(run, user, card)

    local ok, reason = run.game:canUse(user, card, { owner, other })
    lt.assertEquals('别人用杀不受影响，两名用不出去', false, ok)
    lt.assertEquals('原因就是默认上限 1', '「标准.杀」至多指定 1 个目标', reason)
end)

lt.test('方天画戟：出牌阶段的选项带上放宽后的数量区间', function ()
    local run  = support.start { count = 3, packages = { '标准' } }
    local user = run.players[1]

    equipCard(run, user, '方天画戟')
    local card = takeCard(run, user, '杀')
    clearHandExcept(run, user, card)

    ---@type AskUseCard.Option?
    local option = nil
    run.game:on('卡牌-询问', function (ask)
        if ask.kind ~= 'askUseCard' then
            return   -- 用出去的【杀】会再问一次【闪】，那次不管
        end
        ---@cast ask AskUseCard
        option = assert(assert(ask.options)[1], '选项里没有这张杀')
        ask:answer(support.pickFirst(ask))
    end)

    run.game:askUseCard(user, '出牌', { zone = '手牌' })

    lt.assertEquals('选项就是这张杀', card, assert(option).card)
    lt.assertEquals('最少 1', 1, assert(option).plan.min)
    lt.assertEquals('最多放宽到 2（不超可用目标数）', 2, assert(option).plan.max)
    lt.assertEquals('可用目标两名', 2, #assert(assert(option).plan.legal))
end)

lt.test('仁王盾：黑色的【杀】对装备者无效，连【闪】都不问', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local other  = run.players[3]

    equipCard(run, target, '仁王盾')
    local hand = assert(user:getZone('手牌'))
    local black = run.game:createCard('杀', '黑桃', 7)
    hand:accept(black)

    local asked = 0
    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askPlayCard' then
            asked = asked + 1
        end
    end)

    run.game:useCard(user, black, { target })

    lt.assertEquals('无效：不掉血', 5, target:getAttr('体力'))
    lt.assertEquals('连【闪】都没问（整段生效没跑）', 0, asked)

    local black2 = run.game:createCard('杀', '黑桃', 8)
    hand:accept(black2)
    run.game:useCard(user, black2, { other })

    lt.assertEquals('打没盾的人：问了一次【闪】', 1, asked)
    lt.assertEquals('没人答闪 ⇒ 掉 1 点', 4, other:getAttr('体力'))
    lt.assertEquals('两张杀都照常进弃牌', 2, assert(run.game:getZone('弃牌')):count())
end)

lt.test('仁王盾：红色的【杀】照常吃', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]

    equipCard(run, target, '仁王盾')
    local card = run.game:createCard('杀', '红桃', 7)
    assert(user:getZone('手牌')):accept(card)

    run.game:useCard(user, card, { target })

    lt.assertEquals('红杀不被拦：掉 1 点', 4, target:getAttr('体力'))
end)

lt.test('仁王盾：拆下后黑杀恢复', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]

    local shield = equipCard(run, target, '仁王盾')
    local hand   = assert(user:getZone('手牌'))
    local first  = run.game:createCard('杀', '梅花', 7)
    hand:accept(first)
    run.game:useCard(user, first, { target })
    lt.assertEquals('装着的时候黑杀无效', 5, target:getAttr('体力'))

    run.game:moveCard(shield, '弃牌')
    local second = run.game:createCard('杀', '梅花', 8)
    hand:accept(second)
    run.game:useCard(user, second, { target })
    lt.assertEquals('拆走后黑杀照常掉血', 4, target:getAttr('体力'))
end)
