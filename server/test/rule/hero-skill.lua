local fs      = require 'bee.filesystem'
local lt      = require 'test.ltest'
local support = require 'test.rule.support'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'hero-skill-probe'

---@param rel string
---@param content string
local function write(rel, content)
    local file = probeDir / rel
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), content)
    assert(ok, err)
end

---@return unknown # 配 <close> 用
local function useProbe()
    fs.remove_all(probeDir)
    fs.create_directories(probeDir)
    return moe.util.defer(function ()
        fs.remove_all(probeDir)
    end)
end

--- 探针包里备两个能站边的势力武将（标准包目前只有曹操）
local function defineHelpers()
    write('探针/武将.lua', [[
Hero '魏队友'
    : kingdom '魏'
    : hp(4)

Hero '蜀队友'
    : kingdom '蜀'
    : hp(4)

Hero '蜀对手'
    : kingdom '蜀'
    : hp(4)
]])
end

---@param player Player
---@param name string
---@return Skill # 他身上叫这个名字的技能实例
local function findSkill(player, name)
    for _, skill in ipairs(player:getSkills()) do
        if skill.name == name then
            return skill
        end
    end
    error('没有叫「{}」的技能' % { name })
end

---@param run Test.RuleSupport
---@param player Player
---@param name string
---@return Card # 已经摆进该玩家手牌的牌
local function takeCard(run, player, name)
    local deck = assert(run.game:getZone('抽牌'), '没有抽牌')
    for _, card in ipairs(deck:list()) do
        if card.name == name then
            assert(player:getZone('手牌')):accept(card)
            return card
        end
    end
    error('抽牌里没有「{}」' % { name })
end

---@param heroNames (string?)[] # 按座位给武将，不写的座位不装
---@return Test.RuleSupport # 4 人身份局（1 号位是主公）
local function startWithHeroes(heroNames)
    return support.start {
        count    = 4,
        sources  = { './package/*', probeDir:string() .. '/*' },
        packages = { '标准', '身份场', '探针' },
        beforeStart = function (game, players)
            for i = 1, 4 do
                local name = heroNames[i]
                if name then
                    local hero = game:getHero(name)
                    assert(hero, '没有叫「{}」的武将' % { name })
                    players[i]:setHero(hero)
                end
            end
        end,
    }
end

lt.test('护驾：曹操被要【闪】时，令其他魏势力角色打出一张【闪】顶上', function ()
    useProbe()
    defineHelpers()

    local run      = startWithHeroes { '曹操', nil, '魏队友' }
    local caocao   = run.players[1]
    local attacker = run.players[2]
    local helper   = run.players[3]

    lt.assertEquals('1 号位是主公，主公技挂上了', true, caocao:hasSkill('护驾'))

    local hujia = findSkill(caocao, '护驾')
    lt.assertEquals('auto 开着', true, hujia.auto)
    lt.assertEquals('挂了一份「视为」声明', 1, #caocao:getViewAsList())

    local slash = takeCard(run, attacker, '杀')
    local jink  = takeCard(run, helper, '闪')

    run.game:on('卡牌-询问', function (ask)
        if ask.to == helper then
            return { card = jink }
        end
    end)

    ---@type Card?
    local answered = nil
    ---@type string[]
    local kinds = {}
    run.game:on('卡牌-答复后', function (ask)
        kinds[#kinds + 1] = ask.kind
        if ask.to == caocao and ask.kind == 'askOffsetCard' then
            answered = ask.card
        end
    end)

    run.game:useCard(attacker, slash, { caocao })

    lt.assertEquals('曹操没掉血', 5, caocao:getAttr('体力'))
    lt.assertEquals('帮手交出了【闪】', 0, helper:getZone('手牌'):count())
    lt.assertEquals('【闪】进了弃牌堆', true,
        moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), jink))

    lt.assertEquals('帮手那次只是「要一张牌」', true, moe.util.arrayHas(kinds, 'askCard'))
    lt.assertEquals('没有多出一次「打出」', false, moe.util.arrayHas(kinds, 'askPlayCard'))

    local answer = assert(answered, '曹操那边答上了')
    lt.assertEquals('答的是一张虚拟牌（曹操「打出」的）', true, answer.virtual)
    lt.assertEquals('素材就是帮手打出的那张【闪】', jink, answer.subcards[1])
    lt.assertEquals('从这张虚拟牌追得到实体牌', jink, answer.physical[1])
end)

lt.test('护驾：其他魏势力角色不给，曹操照常挨打', function ()
    useProbe()
    defineHelpers()

    local run      = startWithHeroes { '曹操', nil, '魏队友' }
    local caocao   = run.players[1]
    local attacker = run.players[2]
    local helper   = run.players[3]

    local slash = takeCard(run, attacker, '杀')
    local jink  = takeCard(run, helper, '闪')

    run.game:useCard(attacker, slash, { caocao })

    lt.assertEquals('曹操掉 1 点体力', 4, caocao:getAttr('体力'))
    lt.assertEquals('帮手的【闪】还在手上', 1, helper:getZone('手牌'):count())
    lt.assertEquals('那张【闪】没动过', jink, helper:getZone('手牌'):list()[1])
end)

lt.test('护驾：非魏势力角色不参与（有【闪】也不问）', function ()
    useProbe()
    defineHelpers()

    local run      = startWithHeroes { '曹操', nil, '蜀对手' }
    local caocao   = run.players[1]
    local attacker = run.players[2]
    local helper   = run.players[3]

    lt.assertEquals('帮手是蜀势力', '蜀', helper.kingdom)

    local slash = takeCard(run, attacker, '杀')
    local jink  = takeCard(run, helper, '闪')

    run.game:on('卡牌-询问', function (ask)
        if ask.to == helper then
            return { card = jink }
        end
    end)

    run.game:useCard(attacker, slash, { caocao })

    lt.assertEquals('曹操掉血（蜀势力帮不上）', 4, caocao:getAttr('体力'))
    lt.assertEquals('那张【闪】没被问到、还在手上', 1, helper:getZone('手牌'):count())
end)

lt.test('激将：刘备被要【杀】时，令其他蜀势力角色打出一张【杀】顶上', function ()
    useProbe()
    defineHelpers()

    local run      = startWithHeroes { '刘备', nil, '蜀队友' }
    local liubei   = run.players[1]
    local attacker = run.players[2]
    local helper   = run.players[3]

    lt.assertEquals('1 号位是主公，主公技挂上了', true, liubei:hasSkill('激将'))

    local havoc = takeCard(run, attacker, '南蛮入侵')
    local slash = takeCard(run, helper, '杀')

    run.game:on('卡牌-询问', function (ask)
        if ask.to == helper and ask.kind == 'askCard' then
            return { card = slash }
        end
    end)

    run.game:useCard(attacker, havoc, { helper, run.players[4], liubei })

    lt.assertEquals('刘备没掉血', 5, liubei:getAttr('体力'))
    lt.assertEquals('帮手交出了【杀】', 0, helper:getZone('手牌'):count())
    lt.assertEquals('【杀】进了弃牌堆', true,
        moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), slash))
end)

lt.test('激将：其他蜀势力角色不给，刘备照常挨打', function ()
    useProbe()
    defineHelpers()

    local run      = startWithHeroes { '刘备', nil, '蜀队友' }
    local liubei   = run.players[1]
    local attacker = run.players[2]
    local helper   = run.players[3]

    local havoc = takeCard(run, attacker, '南蛮入侵')
    local slash = takeCard(run, helper, '杀')

    run.game:useCard(attacker, havoc, { helper, run.players[4], liubei })

    lt.assertEquals('刘备掉 1 点体力', 4, liubei:getAttr('体力'))
    lt.assertEquals('帮手的【杀】还在手上', 1, helper:getZone('手牌'):count())
    lt.assertEquals('那张【杀】没动过', slash, helper:getZone('手牌'):list()[1])
end)

lt.test('激将：非蜀势力角色不参与（有【杀】也不问）', function ()
    useProbe()
    defineHelpers()

    local run      = startWithHeroes { '刘备', nil, '魏队友' }
    local liubei   = run.players[1]
    local attacker = run.players[2]
    local helper   = run.players[3]

    lt.assertEquals('帮手是魏势力', '魏', helper.kingdom)

    local havoc = takeCard(run, attacker, '南蛮入侵')
    local slash = takeCard(run, helper, '杀')

    run.game:on('卡牌-询问', function (ask)
        if ask.to == helper and ask.kind == 'askCard' then
            return { card = slash }
        end
    end)

    run.game:useCard(attacker, havoc, { helper, run.players[4], liubei })

    lt.assertEquals('刘备掉血（魏势力帮不上）', 4, liubei:getAttr('体力'))
    lt.assertEquals('那张【杀】没被问到、还在手上', 1, helper:getZone('手牌'):count())
end)

lt.test('护驾：直接要【闪】也能发动（不经过【杀】）', function ()

    local run    = startWithHeroes { '曹操', nil, '魏队友' }
    local caocao = run.players[1]
    local helper = run.players[3]

    local jink = takeCard(run, helper, '闪')

    local asked = false
    run.game:on('卡牌-询问', function (ask)
        if ask.to == helper then
            asked = true
            return { card = jink }
        end
    end)

    local ask = run.game:askOffsetCard(caocao, '探针', { name = '闪' })

    lt.assertEquals('问过帮手了', true, asked)
    lt.assertEquals('抵消成立', true, ask.success)
end)

lt.test('主动技：出牌阶段答「发动技能」那一路就发动', function ()
    useProbe()
    write('探针/主动技.lua', [[
Skill '探针技'
    : on('使用', function (cast)
        cast:setTag('跑过', cast.source.name)
    end)
]])

    local run    = startWithHeroes {}
    local player = run.players[1]
    local skill  = player:addSkill('探针技')

    ---@type AskUseSkill?
    local asked = nil
    local asks  = 0
    run.game:on('技能-询问', function (ask)
        moe.await.sleep(0)
        asks = asks + 1
        if asks > 1 then
            -- 第二轮不答 ⇒ 出牌阶段到此结束
            return nil
        end
        asked = ask
        return { skill = skill }
    end)
    run.game:on('卡牌-询问', function (ask)
        if ask.reason ~= '出牌' then
            return
        end
        -- 牌那一路永远不答：这一轮该由技能那一路说了算
        moe.await.sleep(0)
        return nil
    end)

    local _ <close> = run.game:enterPhase(player, '出牌')

    local skillAsk = assert(asked, '该问过技能那一路')
    local cast     = assert(skillAsk.cast, '该把它发动出去')
    lt.assertEquals('归因到技能名下', skill, cast.source)
    lt.assertEquals('发动者是他', player, cast.from)
    lt.assertEquals('钩子跑过了', '探针技', cast:getTag('跑过'))
    lt.assertEquals('问过两轮就收工（没答 ⇒ 结束出牌阶段）', 2, asks)
end)

lt.test('仁德：给 1 张不回，本阶段累计到 2 张时回 1 点', function ()
    useProbe()
    defineHelpers()

    local run    = startWithHeroes { '刘备' }
    local liubei = run.players[1]
    local friend = run.players[2]
    local renDe  = findSkill(liubei, '仁德')

    local first  = takeCard(run, liubei, '杀')
    local second = takeCard(run, liubei, '闪')
    liubei:setAttr('体力', 3)

    ---@type Card[]
    local plan  = { first, second }
    local index = 0
    local asked = 0
    run.game:on('技能-询问', function ()
        asked = asked + 1
        if asked == 2 then
            lt.assertEquals('给第 1 张后还没回血', 3, liubei:getAttr('体力'))
        end
        if asked > 2 then
            return nil -- 没答 ⇒ 结束出牌阶段
        end
        index = index + 1
        return { skill = renDe, cards = plan[index], targets = friend }
    end)

    local _ <close> = run.game:enterPhase(liubei, '出牌')

    lt.assertEquals('两张都给了朋友', 2, friend:getZone('手牌'):count())
    lt.assertEquals('累计到 2 张后回了 1 点（3 → 4）', 4, liubei:getAttr('体力'))
end)

lt.test('仁德：一次给 2 张直接回，此后不再回（每阶段只回一次）', function ()
    useProbe()
    defineHelpers()

    local run    = startWithHeroes { '刘备' }
    local liubei = run.players[1]
    local friend = run.players[2]
    local renDe  = findSkill(liubei, '仁德')

    local first  = takeCard(run, liubei, '杀')
    local second = takeCard(run, liubei, '闪')
    local third  = takeCard(run, liubei, '桃')
    liubei:setAttr('体力', 3)

    ---@type (Card|Card[])[]
    local plan  = { { first, second }, third }
    local index = 0
    local asked = 0
    run.game:on('技能-询问', function ()
        asked = asked + 1
        if asked == 2 then
            lt.assertEquals('第一次给 2 张后已经回过（3 → 4）', 4, liubei:getAttr('体力'))
        end
        if asked > 2 then
            return nil
        end
        index = index + 1
        return { skill = renDe, cards = plan[index], targets = friend }
    end)

    local _ <close> = run.game:enterPhase(liubei, '出牌')

    lt.assertEquals('三张都给了朋友', 3, friend:getZone('手牌'):count())
    lt.assertEquals('第二次给 1 张不再回（还是 4）', 4, liubei:getAttr('体力'))
end)

lt.test('仁德：账挂在自己的出牌阶段上，跨阶段重新累计', function ()
    useProbe()
    defineHelpers()

    local run    = startWithHeroes { '刘备' }
    local liubei = run.players[1]
    local friend = run.players[2]
    local renDe  = findSkill(liubei, '仁德')

    local first  = takeCard(run, liubei, '杀')
    local second = takeCard(run, liubei, '闪')
    local third  = takeCard(run, liubei, '桃')
    liubei:setAttr('体力', 3)

    ---@type Card[]
    local plan  = { first, second, third }
    local index = 0
    local asked = 0
    run.game:on('技能-询问', function ()
        asked = asked + 1
        if asked == 2 or asked > 4 then
            -- 第 2 次不答 ⇒ 结束第一个阶段；第 5 次不答 ⇒ 结束第二个阶段
            return nil
        end
        index = index + 1
        return { skill = renDe, cards = plan[index], targets = friend }
    end)

    do
        local _ <close> = run.game:enterPhase(liubei, '出牌')
    end
    lt.assertEquals('第 1 个阶段只给 1 张（不回）', 3, liubei:getAttr('体力'))

    do
        local _ <close> = run.game:enterPhase(liubei, '出牌')
    end
    lt.assertEquals('第 2 个阶段给到 2 张才回（3 → 4）', 4, liubei:getAttr('体力'))
end)

lt.test('仁德：目标只能选别人；牌给到对方手上，归因在技能名下', function ()
    useProbe()
    defineHelpers()

    local run    = startWithHeroes { '刘备' }
    local liubei = run.players[1]
    local friend = run.players[2]
    local renDe  = findSkill(liubei, '仁德')

    local card = takeCard(run, liubei, '杀')

    ---@type AskUseSkill?
    local skillAsk = nil
    local asked    = 0
    run.game:on('技能-询问', function (ask)
        asked = asked + 1
        if asked > 1 then
            return nil
        end
        ---@cast ask AskUseSkill
        skillAsk = ask
        return { skill = renDe, cards = card, targets = friend }
    end)

    local _ <close> = run.game:enterPhase(liubei, '出牌')

    local fromAnswerer = assert(skillAsk, '该问过技能那一路')
    local option = assert(fromAnswerer.options[1], '仁德该在选项里')
    lt.assertEquals('就是仁德', renDe, option.skill)
    local candidates = assert(option.targets, '仁德该带目标那半').legal
    lt.assertEquals('候选是其他三个人', 3, #candidates)
    lt.assertEquals('不含自己', false, moe.util.arrayHas(candidates, liubei))
    lt.assertEquals('牌那半摆的是手牌', 1, #assert(option.cards, '仁德该带牌那半').legal)

    lt.assertEquals('朋友手里就是那张牌', card, friend:getZone('手牌'):list()[1])
    lt.assertEquals('自己的手牌空了', 0, liubei:getZone('手牌'):count())

    local cast = assert(fromAnswerer.cast, '该把技能发动出去')
    lt.assertEquals('归因到技能名下', renDe, cast.source)
    lt.assertEquals('发动者是他', liubei, cast.from)
end)

lt.test('咆哮：张飞在出牌阶段能连出两张【杀】', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    local foe  = run.players[2]
    user:setHero(assert(run.game:getHero('张飞')))

    lt.assertEquals('技能随武将挂上', true, user:hasSkill('咆哮'))
    lt.assertEquals('是锁定技', true, findSkill(user, '咆哮').def:hasTag('锁定技'))

    local first  = takeCard(run, user, '杀')
    local second = takeCard(run, user, '杀')

    local _ <close> = run.game:enterPhase(user, '出牌')

    run.game:useCard(user, first, { foe })
    lt.assertEquals('第一张照常结算', 4, foe:getAttr('体力'))

    local result = run.game:useCard(user, second, { foe })
    lt.assertEquals('第二张也放行（无次数限制）', true, result.success)
    lt.assertEquals('第二张也结算了', 3, foe:getAttr('体力'))
end)

lt.test('咆哮：只帮张飞自己，别人照常限一次', function ()
    local run   = support.start { count = 3, packages = { '标准' } }
    local fei   = run.players[1]
    local other = run.players[2]
    local foe   = run.players[3]
    fei:setHero(assert(run.game:getHero('张飞')))

    local first  = takeCard(run, other, '杀')
    local second = takeCard(run, other, '杀')

    local _ <close> = run.game:enterPhase(other, '出牌')

    run.game:useCard(other, first, { foe })
    local result = run.game:useCard(other, second, { foe })
    lt.assertEquals('别人没这技能：第二张被拒', '本阶段已经用过「杀」了', result.err)
end)

lt.test('咆哮：技能停用后限制回到一次', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    local foe  = run.players[2]
    user:setHero(assert(run.game:getHero('张飞')))

    local first  = takeCard(run, user, '杀')
    local second = takeCard(run, user, '杀')

    local _ <close> = run.game:enterPhase(user, '出牌')
    run.game:useCard(user, first, { foe })

    findSkill(user, '咆哮'):disablePassive()

    local result = run.game:useCard(user, second, { foe })
    lt.assertEquals('停用后第二张被拒', '本阶段已经用过「杀」了', result.err)
end)

lt.test('武圣：出牌阶段把一张红色手牌当【杀】用出去', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    local foe  = run.players[2]
    user:setHero(assert(run.game:getHero('关羽')))

    lt.assertEquals('技能随武将挂上', true, user:hasSkill('武圣'))

    local red = takeCard(run, user, '桃')

    ---@type ViewAs?
    local chosen = nil
    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' then
            return { card = red }
        end
        ---@cast ask AskUseCard
        for _, option in ipairs(assert(ask.options)) do
            if option.viewAs then
                chosen = option.viewAs
                return { viewAs = option.viewAs, targets = { foe } }
            end
        end
    end)

    local ask  = run.game:askUseCard(user, '出牌', { zone = '手牌' })
    local card = assert(ask.card, '该用出去一张虚拟【杀】')

    lt.assertEquals('视为的是【杀】', '杀', card.name)
    lt.assertEquals('是虚拟牌', true, card.virtual)
    lt.assertEquals('关联是武圣', findSkill(user, '武圣'), assert(chosen).source)
    lt.assertEquals('素材就是那张红牌', red, card.subcards[1])
    lt.assertEquals('目标掉了 1 点血', 4, foe:getAttr('体力'))
    lt.assertEquals('素材进了弃牌堆', assert(run.game:getZone('弃牌')), red:getZone())
end)

lt.test('武圣：黑色牌当不了【杀】（进不了选项）', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    user:setHero(assert(run.game:getHero('关羽')))

    assert(user:getZone('手牌')):accept(run.game:createCard('闪', '黑桃', 2))

    local ask = run.game:askUseCard(user, '出牌', { zone = '手牌' })
    lt.assertEquals('没有选项', 0, #assert(ask.options))
end)

lt.test('武圣：判定区里的红牌当不了素材', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    user:setHero(assert(run.game:getHero('关羽')))

    assert(user:getZone('判定')):accept(run.game:createCard('桃', '红桃', 3))

    local ask = run.game:askUseCard(user, '出牌', { zone = '手牌' })
    lt.assertEquals('没有选项（判定区的牌不属于他）', 0, #assert(ask.options))
end)

lt.test('武圣：响应【南蛮入侵】时用红牌当【杀】顶上', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    local held = run.players[2]
    held:setHero(assert(run.game:getHero('关羽')))

    local havoc = takeCard(run, user, '南蛮入侵')
    local red   = takeCard(run, held, '桃')

    ---@type Card?
    local answered = nil
    run.game:on('卡牌-答复', function (ask)
        if ask.kind == 'askPlayCard' and ask.reason == '南蛮入侵' then
            answered = ask.card
        end
    end)
    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' and ask.reason == '杀' then
            return { card = red }
        end
    end)

    run.game:useCard(user, havoc, { held })

    local played = assert(answered)
    lt.assertEquals('打出的是虚拟【杀】', true, played.virtual)
    lt.assertEquals('视为的是【杀】', '杀', played.name)
    lt.assertEquals('关羽没掉血', 4, held:getAttr('体力'))
    lt.assertEquals('那张红牌进了弃牌堆', assert(run.game:getZone('弃牌')), red:getZone())
end)

lt.test('武圣：红色装备牌也能当【杀】（用了就离区、加成撤销）', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    local foe  = run.players[2]
    user:setHero(assert(run.game:getHero('关羽')))

    local steed = run.game:createCard('赤兔', '红桃', 5)
    assert(user:getZone('手牌')):accept(steed)
    run.game:moveCard(steed, assert(user:getZone('进攻马')))
    lt.assertEquals('装备的加成生效', -1, user:getAttr('进攻修正'))

    ---@type ViewAs?
    local chosen = nil
    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' then
            return { card = steed }
        end
        ---@cast ask AskUseCard
        for _, option in ipairs(assert(ask.options)) do
            if option.viewAs then
                chosen = option.viewAs
                return { viewAs = option.viewAs, targets = { foe } }
            end
        end
    end)

    local ask  = run.game:askUseCard(user, '出牌', { zone = '手牌' })
    local card = assert(ask.card, '该用装备区的红牌当【杀】')

    lt.assertEquals('素材就是那张装备牌', steed, card.subcards[1])
    lt.assertEquals('目标掉了 1 点血', 4, foe:getAttr('体力'))
    lt.assertEquals('装备牌进了弃牌堆', assert(run.game:getZone('弃牌')), steed:getZone())
    lt.assertEquals('离区后加成撤销', 0, user:getAttr('进攻修正'))
    lt.assertEquals('关联是武圣', findSkill(user, '武圣'), assert(chosen).source)
end)

lt.test('武圣：技能停用后就不再提供「视为」', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    user:setHero(assert(run.game:getHero('关羽')))
    takeCard(run, user, '桃')

    local ask = run.game:askUseCard(user, '出牌', { zone = '手牌' })
    lt.assertEquals('还没停用：声明在选项里', 1, #assert(ask.options))

    findSkill(user, '武圣'):disablePassive()

    local after = run.game:askUseCard(user, '出牌', { zone = '手牌' })
    lt.assertEquals('停用后声明跟着撤了', 0, #assert(after.options))
end)

lt.test('龙胆：把一张【杀】当【闪】打出，抵消那张【杀】', function ()
    local run     = support.start { count = 2, packages = { '标准' } }
    local user    = run.players[1]
    local zhaoyun = run.players[2]
    zhaoyun:setHero(assert(run.game:getHero('赵云')))

    lt.assertEquals('技能随武将挂上', true, zhaoyun:hasSkill('龙胆'))

    local slash = takeCard(run, user, '杀')
    local mine  = takeCard(run, zhaoyun, '杀')

    ---@type Card?
    local played = nil
    run.game:on('卡牌-答复', function (ask)
        if ask.kind == 'askOffsetCard' then
            played = ask.card
        end
    end)
    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' and ask.reason == '闪' then
            return { card = mine }
        end
    end)

    run.game:useCard(user, slash, { zhaoyun })

    local shown = assert(played, '该打出一张牌')
    lt.assertEquals('打出的是虚拟【闪】', '闪', shown.name)
    lt.assertEquals('是虚拟牌', true, shown.virtual)
    lt.assertEquals('素材就是那张【杀】', mine, shown.subcards[1])
    lt.assertEquals('赵云没掉血', 4, zhaoyun:getAttr('体力'))
    lt.assertEquals('那张【杀】进了弃牌堆', assert(run.game:getZone('弃牌')), mine:getZone())
end)

lt.test('龙胆：出牌阶段把一张【闪】当【杀】用出去', function ()
    local run     = support.start { count = 2, packages = { '标准' } }
    local zhaoyun = run.players[1]
    local foe     = run.players[2]
    zhaoyun:setHero(assert(run.game:getHero('赵云')))

    local jink = takeCard(run, zhaoyun, '闪')

    ---@type ViewAs?
    local chosen = nil
    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' then
            return { card = jink }
        end
        ---@cast ask AskUseCard
        for _, option in ipairs(assert(ask.options)) do
            if option.viewAs then
                chosen = option.viewAs
                return { viewAs = option.viewAs, targets = { foe } }
            end
        end
    end)

    local ask  = run.game:askUseCard(zhaoyun, '出牌', { zone = '手牌' })
    local card = assert(ask.card, '该用出去一张虚拟【杀】')

    lt.assertEquals('视为的是【杀】', '杀', card.name)
    lt.assertEquals('关联是龙胆', findSkill(zhaoyun, '龙胆'), assert(chosen).source)
    lt.assertEquals('素材就是那张【闪】', jink, card.subcards[1])
    lt.assertEquals('目标掉了 1 点血', 4, foe:getAttr('体力'))
    lt.assertEquals('素材进了弃牌堆', assert(run.game:getZone('弃牌')), jink:getZone())
end)

lt.test('龙胆：响应【南蛮入侵】时用一张【闪】当【杀】打出', function ()
    local run     = support.start { count = 2, packages = { '标准' } }
    local user    = run.players[1]
    local zhaoyun = run.players[2]
    zhaoyun:setHero(assert(run.game:getHero('赵云')))

    local havoc = takeCard(run, user, '南蛮入侵')
    local jink  = takeCard(run, zhaoyun, '闪')

    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' and ask.reason == '杀' then
            return { card = jink }
        end
    end)

    run.game:useCard(user, havoc, { zhaoyun })

    lt.assertEquals('赵云没掉血', 4, zhaoyun:getAttr('体力'))
    lt.assertEquals('那张【闪】进了弃牌堆', assert(run.game:getZone('弃牌')), jink:getZone())
end)

lt.test('龙胆：手里没有【杀】/【闪】时声明不成立', function ()
    local run     = support.start { count = 2, packages = { '标准' } }
    local user    = run.players[1]
    local zhaoyun = run.players[2]
    zhaoyun:setHero(assert(run.game:getHero('赵云')))

    local slash = takeCard(run, user, '杀')
    takeCard(run, zhaoyun, '桃')

    ---@type integer
    local asked = 0
    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' then
            asked = asked + 1
        end
    end)

    run.game:useCard(user, slash, { zhaoyun })

    lt.assertEquals('没问过要素材', 0, asked)
    lt.assertEquals('照常受伤', 3, zhaoyun:getAttr('体力'))
end)

lt.test('奇袭：出牌阶段把一张黑色手牌当【过河拆桥】用出去', function ()
    local run     = support.start { count = 2, packages = { '标准' } }
    local ganning = run.players[1]
    local victim  = run.players[2]
    ganning:setHero(assert(run.game:getHero('甘宁')))

    lt.assertEquals('技能随武将挂上', true, ganning:hasSkill('奇袭'))

    local black = run.game:createCard('杀', '黑桃', 7)
    assert(ganning:getZone('手牌')):accept(black)
    local booty = takeCard(run, victim, '桃')

    ---@type ViewAs?
    local chosen = nil
    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' then
            if ask.condition?.colors then
                return { card = black }
            end
            return { card = booty }
        end
        ---@cast ask AskUseCard
        for _, option in ipairs(assert(ask.options)) do
            if option.viewAs then
                chosen = option.viewAs
                return { viewAs = option.viewAs, targets = { victim } }
            end
        end
    end)

    local ask  = run.game:askUseCard(ganning, '出牌', { zone = '手牌' })
    local card = assert(ask.card, '该用出去一张虚拟【过河拆桥】')

    lt.assertEquals('视为的是【过河拆桥】', '过河拆桥', card.name)
    lt.assertEquals('关联是奇袭', findSkill(ganning, '奇袭'), assert(chosen).source)
    lt.assertEquals('素材就是那张黑牌', black, card.subcards[1])
    lt.assertEquals('对方那张牌被拆掉', assert(run.game:getZone('弃牌')), booty:getZone())
    lt.assertEquals('黑牌也进了弃牌堆', assert(run.game:getZone('弃牌')), black:getZone())
end)

lt.test('奇袭：红色牌用不了（进不了选项）', function ()
    local run     = support.start { count = 2, packages = { '标准' } }
    local ganning = run.players[1]
    ganning:setHero(assert(run.game:getHero('甘宁')))

    takeCard(run, ganning, '桃')

    local ask = run.game:askUseCard(ganning, '出牌', { zone = '手牌' })
    lt.assertEquals('没有选项', 0, #assert(ask.options))
end)

lt.test('奇袭：黑色装备牌也能当【过河拆桥】（用了就离区、加成撤销）', function ()
    local run     = support.start { count = 2, packages = { '标准' } }
    local ganning = run.players[1]
    local victim  = run.players[2]
    ganning:setHero(assert(run.game:getHero('甘宁')))

    local weapon = run.game:createCard('丈八蛇矛', '黑桃', 12)
    assert(ganning:getZone('手牌')):accept(weapon)
    run.game:moveCard(weapon, assert(ganning:getZone('武器')))
    lt.assertEquals('装备的加成生效', 3, ganning:getAttr('攻击范围'))

    local booty = takeCard(run, victim, '桃')

    ---@type ViewAs?
    local chosen = nil
    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' then
            if ask.condition?.colors then
                return { card = weapon }
            end
            return { card = booty }
        end
        ---@cast ask AskUseCard
        for _, option in ipairs(assert(ask.options)) do
            if option.viewAs then
                chosen = option.viewAs
                return { viewAs = option.viewAs, targets = { victim } }
            end
        end
    end)

    local ask  = run.game:askUseCard(ganning, '出牌', { zone = '手牌' })
    local card = assert(ask.card, '该用装备区的黑牌当【过河拆桥】')

    lt.assertEquals('素材就是那把武器', weapon, card.subcards[1])
    lt.assertEquals('对方那张牌被拆掉', assert(run.game:getZone('弃牌')), booty:getZone())
    lt.assertEquals('武器进了弃牌堆', assert(run.game:getZone('弃牌')), weapon:getZone())
    lt.assertEquals('离区后加成撤销', 1, ganning:getAttr('攻击范围'))
    lt.assertEquals('关联是奇袭', findSkill(ganning, '奇袭'), assert(chosen).source)
end)

lt.test('反馈：受到伤害后，获得伤害来源的一张牌', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local sima = run.players[1]
    local foe  = run.players[2]
    sima:setHero(assert(run.game:getHero('司马懿')))

    lt.assertEquals('技能随武将挂上', true, sima:hasSkill('反馈'))

    local slash  = takeCard(run, foe, '杀')
    local spoils = takeCard(run, foe, '桃')

    ---@type AskCard?
    local asked = nil
    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' and ask.reason == '反馈' then
            ---@cast ask AskCard
            asked = ask
            return { card = spoils }
        end
    end)

    run.game:useCard(foe, slash, { sima })

    lt.assertEquals('司马懿掉了 1 点体力', 2, sima:getAttr('体力'))
    local ask = assert(asked, '该问过反馈')
    lt.assertEquals('候选只有来源手上那一张', 1, #assert(ask.options))
    lt.assertEquals('那张牌到了司马懿手上', spoils, sima:getZone('手牌'):list()[1])
    lt.assertEquals('来源手上空了', 0, foe:getZone('手牌'):count())
end)

lt.test('反馈：无来源伤害不发动', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local sima = run.players[1]
    sima:setHero(assert(run.game:getHero('司马懿')))

    local hand = takeCard(run, sima, '桃')

    ---@type integer
    local asked = 0
    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' and ask.reason == '反馈' then
            asked = asked + 1
        end
    end)

    run.game:damage(nil, sima, 1)

    lt.assertEquals('没问过反馈', 0, asked)
    lt.assertEquals('体力照扣', 2, sima:getAttr('体力'))
    lt.assertEquals('自己的手牌没动', hand, sima:getZone('手牌'):list()[1])
end)

lt.test('反馈：伤害来源身上没牌就不问', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local sima = run.players[1]
    local foe  = run.players[2]
    sima:setHero(assert(run.game:getHero('司马懿')))

    -- 来源手上只有那张【杀】，用出去之后身上就没牌了
    local slash = takeCard(run, foe, '杀')

    ---@type integer
    local asked = 0
    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' and ask.reason == '反馈' then
            asked = asked + 1
        end
    end)

    run.game:useCard(foe, slash, { sima })

    lt.assertEquals('没问过反馈', 0, asked)
    lt.assertEquals('司马懿照常掉血', 2, sima:getAttr('体力'))
end)

lt.test('反馈：不发动时，来源的牌不动', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local sima = run.players[1]
    local foe  = run.players[2]
    sima:setHero(assert(run.game:getHero('司马懿')))

    local slash  = takeCard(run, foe, '杀')
    local spoils = takeCard(run, foe, '桃')

    ---@type integer
    local asked = 0
    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' and ask.reason == '反馈' then
            asked = asked + 1
            return nil
        end
    end)

    run.game:useCard(foe, slash, { sima })

    lt.assertEquals('问过了', 1, asked)
    lt.assertEquals('那张牌还在来源手上', spoils, foe:getZone('手牌'):list()[1])
    lt.assertEquals('司马懿手上还是空的', 0, sima:getZone('手牌'):count())
end)

lt.test('鬼才：把判定牌换成自己的一张手牌', function ()
    local run   = support.start { count = 2, packages = { '标准' } }
    local sima  = run.players[1]
    local other = run.players[2]
    sima:setHero(assert(run.game:getHero('司马懿')))

    lt.assertEquals('技能随武将挂上', true, sima:hasSkill('鬼才'))

    local hand = run.game:createCard('桃', '红桃', 3)
    assert(sima:getZone('手牌')):accept(hand)

    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' and ask.reason == '鬼才' then
            return { card = hand }
        end
    end)

    local judge = run.game:judge(other, '探针')

    lt.assertEquals('判定牌就是打出的那张手牌', hand, judge.card)
    lt.assertEquals('判定结果按它算', '红桃', assert(judge.card).suit)
    lt.assertEquals('换下的原判定牌记在账上', 1, #judge.replaced)
    lt.assertEquals('那张手牌离开了司马懿手上', 0, sima:getZone('手牌'):count())
    lt.assertEquals('换下的那张进了弃牌堆', assert(run.game:getZone('弃牌')), judge.replaced[1]:getZone())
    lt.assertEquals('改判后的判定牌也进了弃牌堆', assert(run.game:getZone('弃牌')), hand:getZone())
end)

lt.test('鬼才：这次改判归因在技能名下', function ()
    local run   = support.start { count = 2, packages = { '标准' } }
    local sima  = run.players[1]
    local other = run.players[2]
    sima:setHero(assert(run.game:getHero('司马懿')))

    local hand = takeCard(run, sima, '桃')

    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' and ask.reason == '鬼才' then
            return { card = hand }
        end
    end)

    ---@type Cast?
    local attribution = nil
    run.game:on('效果-能否生效', function (effect)
        if effect.kind == 'cast' then
            ---@cast effect Cast
            attribution = effect
        end
    end)

    run.game:judge(other, '探针')

    local cast = assert(attribution, '该有一次技能发动')
    lt.assertEquals('归因到鬼才名下', findSkill(sima, '鬼才'), cast.source)
    lt.assertEquals('发动者是他', sima, cast.from)
end)

lt.test('鬼才：不发动时判定照旧', function ()
    local run   = support.start { count = 2, packages = { '标准' } }
    local sima  = run.players[1]
    local other = run.players[2]
    sima:setHero(assert(run.game:getHero('司马懿')))

    local hand = takeCard(run, sima, '桃')

    ---@type integer
    local asked = 0
    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' and ask.reason == '鬼才' then
            asked = asked + 1
            return nil
        end
    end)

    local judge = run.game:judge(other, '探针')

    lt.assertEquals('问过了', 1, asked)
    lt.assertEquals('判定牌不是那张手牌', false, judge.card == hand)
    lt.assertEquals('手牌还在', hand, sima:getZone('手牌'):list()[1])
    lt.assertEquals('没有换牌记录', 0, #judge.replaced)
end)

lt.test('鬼才：自己手里没牌就不问', function ()
    local run   = support.start { count = 2, packages = { '标准' } }
    local sima  = run.players[1]
    local other = run.players[2]
    sima:setHero(assert(run.game:getHero('司马懿')))

    ---@type integer
    local asked = 0
    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' and ask.reason == '鬼才' then
            asked = asked + 1
        end
    end)

    run.game:judge(other, '探针')

    lt.assertEquals('没问过', 0, asked)
end)

lt.test('苦肉：出牌阶段失去 1 点体力摸两张牌（不是伤害，也不限次数）', function ()
    local run      = support.start { count = 2, packages = { '标准' } }
    local huanggai = run.players[1]
    huanggai:setHero(assert(run.game:getHero('黄盖')))

    lt.assertEquals('技能随武将挂上', true, huanggai:hasSkill('苦肉'))

    local skill = findSkill(huanggai, '苦肉')
    ---@type integer
    local round = 0
    run.game:on('技能-询问', function (ask)
        moe.await.sleep(0)
        round = round + 1
        if round > 2 then
            return nil
        end
        return { skill = skill }
    end)

    ---@type integer
    local damages = 0
    run.game:on('伤害-开始', function ()
        damages = damages + 1
    end)
    run.game:on('伤害-结束', function ()
        damages = damages + 1
    end)

    local _ <close> = run.game:enterPhase(huanggai, '出牌')

    lt.assertEquals('问了三轮（第三次不答就收工）', 3, round)
    lt.assertEquals('连发两次，失去 2 点体力', 2, huanggai:getAttr('体力'))
    lt.assertEquals('一共摸了 4 张', 4, assert(huanggai:getZone('手牌')):count())
    lt.assertEquals('一次伤害时机都没发', 0, damages)
end)

lt.test('苦肉：体力 1 时发动会进濒死，被【桃】救回来再摸两张', function ()
    local run      = support.start { count = 2, packages = { '标准' } }
    local huanggai = run.players[1]
    local saver    = run.players[2]
    huanggai:setHero(assert(run.game:getHero('黄盖')))

    local skill = findSkill(huanggai, '苦肉')
    huanggai:setAttr('体力', 1)
    local peach = takeCard(run, saver, '桃')

    ---@type integer
    local asked = 0
    run.game:on('技能-询问', function (ask)
        moe.await.sleep(0)
        asked = asked + 1
        if asked > 1 then
            return nil
        end
        return { skill = skill }
    end)

    ---@type integer
    local dyingAsked = 0
    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askUseCard' and ask.reason == '濒死' and ask.to == saver then
            dyingAsked = dyingAsked + 1
            return { card = peach, targets = { huanggai } }
        end
    end)

    local _ <close> = run.game:enterPhase(huanggai, '出牌')

    lt.assertEquals('问过濒死求桃', 1, dyingAsked)
    lt.assertEquals('救回来了', true, huanggai:isAlive())
    lt.assertEquals('体力回到 1', 1, huanggai:getAttr('体力'))
    lt.assertEquals('活下来才摸的两张', 2, assert(huanggai:getZone('手牌')):count())
end)

lt.test('苦肉：没人救就阵亡，也不再摸牌', function ()
    local run      = support.start { count = 2, packages = { '标准' } }
    local huanggai = run.players[1]
    huanggai:setHero(assert(run.game:getHero('黄盖')))

    local skill = findSkill(huanggai, '苦肉')
    huanggai:setAttr('体力', 1)

    ---@type integer
    local asked = 0
    run.game:on('技能-询问', function (ask)
        moe.await.sleep(0)
        asked = asked + 1
        if asked > 1 then
            return nil
        end
        return { skill = skill }
    end)

    ---@type Damage?
    local killerDamage = nil
    run.game:on('玩家-死亡', function (player)
        killerDamage = player.dying?.damage
    end)

    local _ <close> = run.game:enterPhase(huanggai, '出牌')

    lt.assertEquals('阵亡', false, huanggai:isAlive())
    lt.assertEquals('体力是 0', 0, huanggai:getAttr('体力'))
    lt.assertEquals('一张牌也没摸', 0, assert(huanggai:getZone('手牌')):count())
    lt.assertEquals('因失去体力而死，没有致死伤害', nil, killerDamage)
end)

lt.test('洛神：准备阶段判黑就拿到那张判定牌，再问重复时停下', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local zhenji = run.players[1]
    zhenji:setHero(assert(run.game:getHero('甄姬')))

    lt.assertEquals('技能随武将挂上', true, zhenji:hasSkill('洛神'))

    ---@type Card?
    local decided = nil
    run.game:on('判定-前', function (judge)
        if judge.reason == '洛神' then
            decided = run.game:createCard('杀', '黑桃', 7)
            judge:replace(decided)
        end
    end)

    ---@type integer
    local asked = 0
    run.game:on('决策-询问', function (ask)
        if ask.reason ~= '洛神' then
            return
        end
        ---@cast ask AskChoice
        asked = asked + 1
        if asked == 1 then
            return '发动'
        end
    end)

    local _ <close> = run.game:enterPhase(zhenji, '准备')

    lt.assertEquals('问过两次（重复那次答否就停）', 2, asked)
    local hand = assert(zhenji:getZone('手牌'))
    lt.assertEquals('拿到了那张判定牌', 1, hand:count())
    lt.assertEquals('就是判出来那张', decided, hand:peek(1))
end)

lt.test('洛神：判红就不拿，也不再问重复', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local zhenji = run.players[1]
    zhenji:setHero(assert(run.game:getHero('甄姬')))

    ---@type Card?
    local decided = nil
    run.game:on('判定-前', function (judge)
        if judge.reason == '洛神' then
            decided = run.game:createCard('杀', '红桃', 7)
            judge:replace(decided)
        end
    end)

    ---@type integer
    local asked = 0
    run.game:on('决策-询问', function (ask)
        if ask.reason ~= '洛神' then
            return
        end
        ---@cast ask AskChoice
        asked = asked + 1
        return '发动'
    end)

    local _ <close> = run.game:enterPhase(zhenji, '准备')

    lt.assertEquals('只问了一次（判红就结束）', 1, asked)
    lt.assertEquals('没拿到牌', 0, assert(zhenji:getZone('手牌')):count())
    lt.assertEquals('判出来那张进了弃牌堆', true,
        moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), decided))
end)

lt.test('倾国：把一张黑色手牌当【闪】打出，抵消那张【杀】', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local zhenji = run.players[2]
    zhenji:setHero(assert(run.game:getHero('甄姬')))

    lt.assertEquals('技能随武将挂上', true, zhenji:hasSkill('倾国'))

    local slash = takeCard(run, user, '杀')
    local black = run.game:createCard('杀', '梅花', 7)
    assert(zhenji:getZone('手牌')):accept(black)

    ---@type Card?
    local played = nil
    run.game:on('卡牌-答复', function (ask)
        if ask.kind == 'askOffsetCard' then
            played = ask.card
        end
    end)
    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' and ask.reason == '闪' then
            return { card = black }
        end
    end)

    run.game:useCard(user, slash, { zhenji })

    local shown = assert(played, '该打出一张牌')
    lt.assertEquals('打出的是虚拟【闪】', '闪', shown.name)
    lt.assertEquals('是虚拟牌', true, shown.virtual)
    lt.assertEquals('素材就是那张黑牌', black, shown.subcards[1])
    lt.assertEquals('甄姬没掉血', 3, zhenji:getAttr('体力'))
    lt.assertEquals('那张黑牌进了弃牌堆', assert(run.game:getZone('弃牌')), black:getZone())
end)

lt.test('倾国：红色牌当不了【闪】（进不了选项）', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local zhenji = run.players[2]
    zhenji:setHero(assert(run.game:getHero('甄姬')))

    local slash = takeCard(run, user, '杀')
    takeCard(run, zhenji, '桃')

    ---@type integer
    local asked = 0
    run.game:on('卡牌-询问', function (ask)
        if ask.kind == 'askCard' then
            asked = asked + 1
        end
    end)

    run.game:useCard(user, slash, { zhenji })

    lt.assertEquals('没问过要素材', 0, asked)
    lt.assertEquals('照常受伤', 2, zhenji:getAttr('体力'))
end)

lt.test('刚烈：判红桃就什么都不发生（连来源都不问）', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local xiahou = run.players[2]
    xiahou:setHero(assert(run.game:getHero('夏侯惇')))

    lt.assertEquals('技能随武将挂上', true, xiahou:hasSkill('刚烈'))

    run.game:on('判定-前', function (judge)
        if judge.reason == '刚烈' then
            judge:replace(run.game:createCard('杀', '红桃', 7))
        end
    end)
    run.game:on('决策-询问', function (ask)
        if ask.reason == '刚烈' then
            ---@cast ask AskChoice
            return '发动'
        end
    end)

    ---@type integer
    local asked = 0
    run.game:on('卡牌-询问', function (ask)
        if ask.reason == '刚烈' then
            asked = asked + 1
        end
    end)

    local slash      = takeCard(run, user, '杀')
    local hpBefore   = xiahou:getAttr('体力')
    local fromBefore = user:getAttr('体力')
    run.game:useCard(user, slash, { xiahou })

    lt.assertEquals('夏侯惇照常掉 1 点', hpBefore - 1, xiahou:getAttr('体力'))
    lt.assertEquals('红桃 ⇒ 不问来源', 0, asked)
    lt.assertEquals('来源毫发无伤', fromBefore, user:getAttr('体力'))
end)

lt.test('刚烈：判非红桃就让来源弃两张手牌，他自己不掉血', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local xiahou = run.players[2]
    xiahou:setHero(assert(run.game:getHero('夏侯惇')))

    run.game:on('判定-前', function (judge)
        if judge.reason == '刚烈' then
            judge:replace(run.game:createCard('杀', '黑桃', 7))
        end
    end)
    run.game:on('决策-询问', function (ask)
        if ask.reason == '刚烈' then
            ---@cast ask AskChoice
            return '发动'
        end
    end)

    local first  = takeCard(run, user, '杀')
    local second = takeCard(run, user, '闪')
    local slash  = takeCard(run, user, '杀')
    run.game:on('卡牌-询问', function (ask)
        if ask.reason == '刚烈' then
            return { card = { first, second } }
        end
    end)

    local hpBefore = user:getAttr('体力')
    run.game:useCard(user, slash, { xiahou })

    lt.assertEquals('三张里用掉一张、弃掉两张 ⇒ 手里空了', 0, user:getZone('手牌'):count())
    lt.assertEquals('弃的两张进了弃牌堆', true,
        moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), first))
    lt.assertEquals('第二张也在弃牌堆', true,
        moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), second))
    lt.assertEquals('来源没掉血', hpBefore, user:getAttr('体力'))
end)

lt.test('刚烈：给不满两张就挨那 1 点（伤害来源是夏侯惇）', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local xiahou = run.players[2]
    xiahou:setHero(assert(run.game:getHero('夏侯惇')))

    run.game:on('判定-前', function (judge)
        if judge.reason == '刚烈' then
            judge:replace(run.game:createCard('杀', '梅花', 7))
        end
    end)
    run.game:on('决策-询问', function (ask)
        if ask.reason == '刚烈' then
            ---@cast ask AskChoice
            return '发动'
        end
    end)

    local only  = takeCard(run, user, '杀')
    local slash = takeCard(run, user, '杀')
    run.game:on('卡牌-询问', function (ask)
        if ask.reason == '刚烈' then
            return { card = only }
        end
    end)

    ---@type Damage?
    local caused = nil
    run.game:on('伤害-结束', function (damage)
        if damage.to == user and damage.from ~= nil then
            caused = damage
        end
    end)

    local hpBefore = user:getAttr('体力')
    run.game:useCard(user, slash, { xiahou })

    lt.assertEquals('来源掉 1 点', hpBefore - 1, user:getAttr('体力'))
    lt.assertEquals('只有那一张手牌，没被弃掉', true,
        moe.util.arrayHas(user:getZone('手牌'):list(), only))
    local damage = assert(caused, '该造成那 1 点伤害')
    lt.assertEquals('伤害来源是夏侯惇', xiahou, damage.from)
end)

lt.test('刚烈：来源取消不给，也一样挨那 1 点', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local xiahou = run.players[2]
    xiahou:setHero(assert(run.game:getHero('夏侯惇')))

    run.game:on('判定-前', function (judge)
        if judge.reason == '刚烈' then
            judge:replace(run.game:createCard('杀', '方块', 7))
        end
    end)
    run.game:on('决策-询问', function (ask)
        if ask.reason == '刚烈' then
            ---@cast ask AskChoice
            return '发动'
        end
    end)

    takeCard(run, user, '杀')
    takeCard(run, user, '闪')
    local slash = takeCard(run, user, '杀')
    -- 卡牌-询问不表态 = 取消（这次的询问允许取消）

    ---@type Damage?
    local caused = nil
    run.game:on('伤害-结束', function (damage)
        if damage.to == user and damage.from ~= nil then
            caused = damage
        end
    end)

    local hpBefore = user:getAttr('体力')
    run.game:useCard(user, slash, { xiahou })

    lt.assertEquals('来源掉 1 点', hpBefore - 1, user:getAttr('体力'))
    lt.assertEquals('两张手牌都还在', 2, user:getZone('手牌'):count())
    lt.assertEquals('伤害来源是夏侯惇', xiahou, assert(caused, '该造成那 1 点伤害').from)
end)

lt.test('刚烈：无来源的伤害不发动', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local xiahou = run.players[2]
    xiahou:setHero(assert(run.game:getHero('夏侯惇')))

    ---@type integer
    local asked = 0
    run.game:on('决策-询问', function (ask)
        if ask.reason == '刚烈' then
            asked = asked + 1
        end
    end)

    local hpBefore = xiahou:getAttr('体力')
    run.game:damage(nil, xiahou, 1)

    lt.assertEquals('照常掉 1 点', hpBefore - 1, xiahou:getAttr('体力'))
    lt.assertEquals('没来源 ⇒ 连问都不问', 0, asked)
end)
