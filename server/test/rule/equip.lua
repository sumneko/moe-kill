local fs      = require 'bee.filesystem'
local lt      = require 'test.ltest'
local support = require 'test.rule.support'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'equip-probe'

---@return unknown # 配 <close> 用
local function useProbe()
    fs.remove_all(probeDir)
    fs.create_directories(probeDir)
    return moe.util.defer(function ()
        fs.remove_all(probeDir)
    end)
end

---@param rel string
---@param content string
local function write(rel, content)
    local file = probeDir / rel
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), content)
    assert(ok, err)
end

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

lt.test('装备：游戏开始时给每个玩家建好四个装备子区', function ()
    local run = support.start { count = 3, packages = { '标准' } }

    for _, player in ipairs(run.players) do
        for _, name in ipairs { '武器', '防具', '进攻马', '防御马' } do
            local zone = assert(player:getZone(name), '没有 ' .. name .. ' 子区')
            lt.assertEquals(name .. '：是普通区', 'zone', zone.kind)
            lt.assertEquals(name .. '：归属这个玩家', player, zone.owner)
        end
    end

    lt.assertEquals('「装备」这个区名不再存在（四个子区取代了它）', nil, run.players[1]:getZone('装备'))
end)

lt.test('装备：别的包往 rule.equipZones 里追加子区，新子区会被建出来', function ()
    local guard <close> = useProbe()
    write('扩展/装备扩展.lua', [[
rule.equipZones[#rule.equipZones + 1] = '宝物'

Card '宝物牌'
    : extends '装备牌'
    : addKind '宝物'

Card '玉玺'
    : extends '宝物牌'
]])
    local run = support.start {
        count    = 2,
        packages = { '标准', '扩展' },
        sources  = { probeDir:string() .. '/*', './package/*' },
    }
    local user     = run.players[1]
    local treasure = assert(user:getZone('宝物'), '宝物子区没被建出来')

    local card = run.game:createCard('玉玺')
    assert(user:getZone('手牌'), '没有手牌区'):accept(card)
    run.game:useCard(user, card, {})

    lt.assertEquals('进了宝物子区', card, treasure:list()[1])
    lt.assertEquals('也算他身上的装备牌', true, moe.util.arrayHas(user.equipCards, card))
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

    lt.assertEquals('牌进了武器子区', card, assert(user:getZone('武器')):list()[1])
end)

lt.test('装备：用出去就落进对应的子区，并按数据加攻击范围', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]

    local card = equipCard(run, user, '麒麟弓')

    lt.assertEquals('进了武器子区', card, assert(user:getZone('武器')):list()[1])
    lt.assertEquals('武器子区就这一张', 1, assert(user:getZone('武器')):count())
    lt.assertEquals('攻击范围 1 + 4', 5, user:getAttr('攻击范围'))
    lt.assertEquals('结算完的牌没被收进弃牌堆', 0, assert(run.game:getZone('弃牌')):count())
end)

lt.test('装备：坐骑各进自己的子区，改的是距离修正', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]

    local horse  = equipCard(run, user, '赤兔')
    local shield = equipCard(run, user, '的卢')

    lt.assertEquals('进攻马进了进攻马子区', horse, assert(user:getZone('进攻马')):list()[1])
    lt.assertEquals('防御马进了防御马子区', shield, assert(user:getZone('防御马')):list()[1])
    lt.assertEquals('两个子区各一张', 2, #user.equipCards)
    lt.assertEquals('进攻修正 -1', -1, user:getAttr('进攻修正'))
    lt.assertEquals('防御修正 +1', 1, user:getAttr('防御修正'))
end)

lt.test('装备：同子区换新装备，旧牌进弃牌堆、加成换成新的', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]

    local old = equipCard(run, user, '诸葛连弩')
    lt.assertEquals('先装上的是攻击范围 1', 1, user:getAttr('攻击范围'))

    local new = equipCard(run, user, '麒麟弓')

    lt.assertEquals('子区里是新的那张', new, assert(user:getZone('武器')):list()[1])
    lt.assertEquals('武器子区只有一张', 1, assert(user:getZone('武器')):count())
    lt.assertEquals('旧牌进了弃牌堆', true,
        moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), old))
    lt.assertEquals('攻击范围换成新的（旧的不再叠加）', 5, user:getAttr('攻击范围'))
end)

lt.test('装备：被【过河拆桥】拆走后修正回落，子区也空了', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local weapon = equipCard(run, target, '麒麟弓')
    local trick  = takeCard(run, user, '过河拆桥')
    local zone   = assert(target:getZone('武器'))

    run.game:on('卡牌-询问', function (ask)
        ask:answer { card = weapon }
    end)

    run.game:useCard(user, trick, { target })

    lt.assertEquals('武器子区空了', 0, zone:count())
    lt.assertEquals('攻击范围回落到 1', 1, target:getAttr('攻击范围'))
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

    run.game:moveCard(assert(assert(one:getZone('进攻马')):list()[1]), '弃牌')
    lt.assertEquals('马被拆走就回到原样', '2,4', reachable())
    lt.assertEquals('进攻修正也回落', 0, one:getAttr('进攻修正'))

    equipCard(run, two, '的卢')
    lt.assertEquals('防御马：别人到自己 +1 ⇒ 相邻的 2 号位也够不着了', '4', reachable())
    lt.assertEquals('防御修正记在骑着马的那个人身上', 1, two:getAttr('防御修正'))
    lt.assertEquals('进攻修正不受影响', 0, one:getAttr('进攻修正'))
end)

lt.test('装备：牌表里 14 张装备都定义好了，各自进对了子区', function ()
    local run = support.start { count = 2, packages = { '标准' } }

    ---@class Test.EquipExpect
    ---@field zone string # 该进的子区名
    ---@field range? integer # 官方攻击范围（牌上写的就是这个值）
    ---@field delta? integer # 距离修正

    ---@type table<string, Test.EquipExpect>
    local expected = {
        ['诸葛连弩']   = { zone = '武器', range = 1 },
        ['雌雄双股剑'] = { zone = '武器', range = 2 },
        ['青釭剑']     = { zone = '武器', range = 2 },
        ['青龙偃月刀'] = { zone = '武器', range = 3 },
        ['丈八蛇矛']   = { zone = '武器', range = 3 },
        ['贯石斧']     = { zone = '武器', range = 3 },
        ['方天画戟']   = { zone = '武器', range = 4 },
        ['麒麟弓']     = { zone = '武器', range = 5 },
        ['赤兔']       = { zone = '进攻马', delta = -1 },
        ['大宛']       = { zone = '进攻马', delta = -1 },
        ['紫骍']       = { zone = '进攻马', delta = -1 },
        ['的卢']       = { zone = '防御马', delta = 1 },
        ['绝影']       = { zone = '防御马', delta = 1 },
        ['爪黄飞电']   = { zone = '防御马', delta = 1 },
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
        lt.assertEquals(name .. '：分类里有子区名（装备模板按它找子区）', true, def:isKind(want.zone))
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
    lt.assertEquals('压制住：加成被撤（牌还挂在子区里）', 1, user:getAttr('攻击范围'))

    weapon:enablePassive()
    lt.assertEquals('松开：重新应用', 5, user:getAttr('攻击范围'))
end)

lt.test('装备：进错子区不启用被动', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    local weapon = takeCard(run, user, '麒麟弓')

    run.game:moveCard(weapon, assert(user:getZone('防具')))

    lt.assertEquals('牌进了防具子区（子区本身不挑分类）', weapon, assert(user:getZone('防具')):list()[1])
    lt.assertEquals('分类对不上：被动没启用，攻击范围还是 1', 1, user:getAttr('攻击范围'))
end)

lt.test('装备：拆走后被动停用，放回子区重新启用', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    local weapon = equipCard(run, user, '麒麟弓')

    run.game:moveCard(weapon, '弃牌')
    lt.assertEquals('拆走：加成回落', 1, user:getAttr('攻击范围'))

    run.game:moveCard(weapon, assert(user:getZone('武器')))
    lt.assertEquals('放回武器子区：重新应用', 5, user:getAttr('攻击范围'))
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

lt.test('诸葛连弩：出牌阶段能连出两张【杀】', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    local foe  = run.players[2]

    equipCard(run, user, '诸葛连弩')
    local first  = takeCard(run, user, '杀')
    local second = takeCard(run, user, '杀')

    local phase <close> = run.game:enterPhase(user, '出牌')

    run.game:useCard(user, first, { foe })
    lt.assertEquals('第一张照常结算', 4, foe:getAttr('体力'))

    local result = run.game:useCard(user, second, { foe })
    lt.assertEquals('第二张也放行（没有被次数拦住）', true, result.success)
    lt.assertEquals('第二张也结算了', 3, foe:getAttr('体力'))
end)

lt.test('诸葛连弩：只帮装备主，不帮别人', function ()
    local run = support.start { count = 3, packages = { '标准' } }
    local a   = run.players[1]
    local b   = run.players[2]
    local foe = run.players[3]

    equipCard(run, a, '诸葛连弩')

    local first  = takeCard(run, b, '杀')
    local second = takeCard(run, b, '杀')

    local phase <close> = run.game:enterPhase(b, '出牌')

    run.game:useCard(b, first, { foe })
    local result = run.game:useCard(b, second, { foe })

    lt.assertEquals('B 没装连弩：第二张被拒', '本阶段已经用过「杀」了', result.err)
    lt.assertEquals('目标只掉一次血', 4, foe:getAttr('体力'))
end)

lt.test('诸葛连弩：拆下后限制立即回来', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    local foe  = run.players[2]

    local crossbow = equipCard(run, user, '诸葛连弩')
    local first    = takeCard(run, user, '杀')
    local second   = takeCard(run, user, '杀')

    local phase <close> = run.game:enterPhase(user, '出牌')

    run.game:useCard(user, first, { foe })
    run.game:moveCard(crossbow, '弃牌')

    local result = run.game:useCard(user, second, { foe })
    lt.assertEquals('拆掉连弩，第二张就出不了', '本阶段已经用过「杀」了', result.err)
end)

lt.test('诸葛连弩：出牌阶段中途装上立即生效', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    local foe  = run.players[2]

    local crossbow = takeCard(run, user, '诸葛连弩')
    local first    = takeCard(run, user, '杀')
    local second   = takeCard(run, user, '杀')

    local phase <close> = run.game:enterPhase(user, '出牌')

    run.game:useCard(user, first, { foe })
    lt.assertEquals('第一张照常结算', 4, foe:getAttr('体力'))

    run.game:useCard(user, crossbow, {})

    local result = run.game:useCard(user, second, { foe })
    lt.assertEquals('装上就能接着出', true, result.success)
    lt.assertEquals('第二张也结算了', 3, foe:getAttr('体力'))
end)

lt.test('青釭剑：无视防具，使用结束之后恢复', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]

    equipCard(run, user, '青釭剑')
    equipCard(run, target, '仁王盾')

    local hand = assert(user:getZone('手牌'))
    local black = run.game:createCard('杀', '黑桃', 7)
    hand:accept(black)
    run.game:useCard(user, black, { target })

    lt.assertEquals('防具被无视：黑杀照常造成伤害', 4, target:getAttr('体力'))

    -- 恢复：换别人打一张黑杀，盾又生效了（这次使用收尾时窗口已经关掉）
    local other = run.players[3]
    local black2 = run.game:createCard('杀', '黑桃', 8)
    assert(other:getZone('手牌')):accept(black2)
    run.game:useCard(other, black2, { target })

    lt.assertEquals('这次使用结束之后【仁王盾】恢复', 4, target:getAttr('体力'))
end)

lt.test('青釭剑：旁人用【杀】不被无视', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local other  = run.players[3]

    equipCard(run, user, '青釭剑')
    equipCard(run, target, '仁王盾')

    local black = run.game:createCard('杀', '黑桃', 7)
    assert(other:getZone('手牌')):accept(black)
    run.game:useCard(other, black, { target })

    lt.assertEquals('盾照常抵消', 5, target:getAttr('体力'))
end)

lt.test('青釭剑：窗口内剑被搬走，目标照样被无视（官方 §1 司马懿条）', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]

    local sword = equipCard(run, user, '青釭剑')
    equipCard(run, target, '仁王盾')

    local black = run.game:createCard('杀', '黑桃', 7)
    assert(user:getZone('手牌')):accept(black)

    -- 轮到目标结算时把剑搬走（模拟【反馈】/ 使用者死亡）：窗口不该跟着消失
    local moved = false
    run.game:on('效果-能否生效', function (effect)
        if moved or effect.kind ~= 'cardEffect' then
            return
        end
        moved = true
        run.game:moveCard(sword, '弃牌')
    end)

    run.game:useCard(user, black, { target })

    lt.assertEquals('剑已经进弃牌堆', assert(run.game:getZone('弃牌')), sword:getZone())
    lt.assertEquals('窗口还在：【仁王盾】照样无效', 4, target:getAttr('体力'))
end)

lt.test('青釭剑：窗口内换防具，换上来的同样无效', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]

    equipCard(run, user, '青釭剑')
    local old = equipCard(run, target, '仁王盾')

    local black = run.game:createCard('杀', '黑桃', 7)
    assert(user:getZone('手牌')):accept(black)

    -- 压完之后把目标的防具换新：新区就是那块被禁的区
    local swapped = false
    run.game:on('卡牌-结算前', function (useCard)
        if swapped or useCard.card ~= black then
            return
        end
        swapped = true
        local fresh = run.game:createCard('仁王盾')
        assert(target:getZone('手牌')):accept(fresh)
        target:equipCard(fresh)
    end)

    run.game:useCard(user, black, { target })

    lt.assertEquals('旧防具进弃牌堆', assert(run.game:getZone('弃牌')), old:getZone())
    lt.assertEquals('新防具同样无效', 4, target:getAttr('体力'))
end)

lt.test('青釭剑：这次使用半路收场也不残留压制', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]

    equipCard(run, user, '青釭剑')
    equipCard(run, target, '仁王盾')

    local black = run.game:createCard('杀', '黑桃', 7)
    assert(user:getZone('手牌')):accept(black)

    -- 压完之后当场收局：目标那一次生效根本没轮到
    run.game:on('卡牌-结算前', function (useCard)
        if useCard.card == black then
            run.game:endGame { side = '平局', reason = '测试' }
        end
    end)

    run.game:useCard(user, black, { target })

    lt.assertEquals('没有残留状态', false, target:hasBuff('防具无效'))
    lt.assertEquals('防具区恢复启用', true, assert(target:getZone('防具')):isEnabled())
end)

lt.test('麒麟弓：用【杀】造成伤害时可以弃掉目标的一张坐骑', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]

    equipCard(run, user, '麒麟弓')
    local horse  = equipCard(run, target, '赤兔')
    local shield = equipCard(run, target, '的卢')
    local blade  = equipCard(run, target, '青釭剑')
    local card   = takeCard(run, user, '杀')

    ---@type AskCard.Option[]?
    local options = nil
    ---@type integer? # 询问时点目标的体力（应当还没扣）
    local hpWhenAsked = nil
    run.game:on('卡牌-询问', function (ask)
        if ask.kind ~= 'askCard' or ask.reason ~= '麒麟弓' then
            return
        end
        ---@cast ask AskCard
        options = ask.options
        hpWhenAsked = target:getAttr('体力')
        ask:answer { card = shield }
    end)

    run.game:useCard(user, card, { target })

    lt.assertEquals('询问时点还没扣血', 5, hpWhenAsked)
    lt.assertEquals('候选只有坐骑（武器不入选）', 2, #assert(options))
    lt.assertEquals('弃掉进弃牌堆的是答复那张', true,
        moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), shield))
    lt.assertEquals('另一张坐骑留着', horse, assert(target:getZone('进攻马')):list()[1])
    lt.assertEquals('武器也没动', blade, assert(target:getZone('武器')):list()[1])
    lt.assertEquals('防御修正回落（的卢没了）', 0, target:getAttr('防御修正'))
    lt.assertEquals('进攻修正还在（赤兔还在）', -1, target:getAttr('进攻修正'))
    lt.assertEquals('伤害照常', 4, target:getAttr('体力'))
end)

lt.test('麒麟弓：不答复就不发动', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]

    equipCard(run, user, '麒麟弓')
    local horse = equipCard(run, target, '赤兔')
    local card  = takeCard(run, user, '杀')

    local asked = 0
    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' and ask.reason == '麒麟弓' then
            asked = asked + 1
        end
    end)

    run.game:useCard(user, card, { target })

    lt.assertEquals('问过（有坐骑）', 1, asked)
    lt.assertEquals('坐骑还在原地', horse, assert(target:getZone('进攻马')):list()[1])
    lt.assertEquals('照常掉血', 4, target:getAttr('体力'))
end)

lt.test('麒麟弓：目标没有坐骑就不问', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]

    equipCard(run, user, '麒麟弓')
    equipCard(run, target, '青釭剑')   -- 有装备，但不是坐骑
    local card = takeCard(run, user, '杀')

    local asked = 0
    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' and ask.reason == '麒麟弓' then
            asked = asked + 1
        end
    end)

    run.game:useCard(user, card, { target })

    lt.assertEquals('不问', 0, asked)
    lt.assertEquals('照常掉血', 4, target:getAttr('体力'))
end)

lt.test('麒麟弓：别的牌造成的伤害不发动（【决斗】）', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]

    equipCard(run, user, '麒麟弓')
    local horse = equipCard(run, target, '赤兔')
    local card  = takeCard(run, user, '决斗')

    local asked = 0
    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' and ask.reason == '麒麟弓' then
            asked = asked + 1
        end
    end)

    run.game:useCard(user, card, { target })

    lt.assertEquals('不问', 0, asked)
    lt.assertEquals('坐骑还在', horse, assert(target:getZone('进攻马')):list()[1])
    lt.assertEquals('伤害照常（对方不出【杀】就掉血）', 4, target:getAttr('体力'))
end)

lt.test('麒麟弓：旁人用【杀】不发动', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local owner  = run.players[1]
    local user   = run.players[2]
    local target = run.players[3]

    equipCard(run, owner, '麒麟弓')
    local horse = equipCard(run, target, '赤兔')
    local card  = takeCard(run, user, '杀')

    local asked = 0
    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' and ask.reason == '麒麟弓' then
            asked = asked + 1
        end
    end)

    run.game:useCard(user, card, { target })

    lt.assertEquals('不问', 0, asked)
    lt.assertEquals('坐骑还在', horse, assert(target:getZone('进攻马')):list()[1])
    lt.assertEquals('目标照常掉血', 4, target:getAttr('体力'))
end)

lt.test('麒麟弓：拆下后就不发动', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]

    local bow   = equipCard(run, user, '麒麟弓')
    local horse = equipCard(run, target, '赤兔')
    local card  = takeCard(run, user, '杀')

    run.game:moveCard(bow, '弃牌')

    local asked = 0
    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' and ask.reason == '麒麟弓' then
            asked = asked + 1
        end
    end)

    run.game:useCard(user, card, { target })

    lt.assertEquals('不问', 0, asked)
    lt.assertEquals('坐骑还在', horse, assert(target:getZone('进攻马')):list()[1])
end)
