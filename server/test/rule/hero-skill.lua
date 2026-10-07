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
    : on('使用', function (skill, cast)
        cast:setTag('跑过', skill.name)
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
        return skill
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
