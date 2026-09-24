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

--- 是不是「无懈可击」那个窗口的问（它在每张锦囊生效前问一圈；下面这些用例不关心它）
---@param ask AskCard
---@return boolean
local function isNullifyAsk(ask)
    return ask.kind == 'askUseCardToCard'
end

--- 这次询问是冲着哪次生效来的（看它的父效果 —— 询问里不带"对谁"，只有这次生效带着）
---@param ask AskCard
---@return CardEffect? # 父效果是「一张牌对某角色的一次生效」时给出
local function pendingEffect(ask)
    local effect = ask.parent
    if effect and effect.kind == 'cardEffect' then
        ---@cast effect CardEffect
        return effect
    end
    return nil
end

--- 某个效果下面第一个这种子效果（同级还有询问，所以按种类找）
---@param effect Effect
---@param kind string
---@return Effect?
local function childOf(effect, kind)
    for _, child in ipairs(effect.childs) do
        if child.kind == kind then
            return child
        end
    end
    return nil
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

lt.test('桃园结义：所有角色各回 1 点，满血的不变', function ()
    local run  = support.start { count = 3, packages = { '标准' } }
    local user = run.players[1]
    local card = takeCard(run, user, '桃园结义')
    user:setAttr('体力', 3)
    run.players[2]:setAttr('体力', 4)

    run.game:useCard(user, card, run.game.desk.alivePlayers)

    lt.assertEquals('受伤的使用者回到 4', 4, user:getAttr('体力'))
    lt.assertEquals('受伤的下家回到 5', 5, run.players[2]:getAttr('体力'))
    lt.assertEquals('满血的不变', 5, run.players[3]:getAttr('体力'))
    lt.assertEquals('弃牌里就是这张锦囊', card, assert(run.game:getZone('弃牌')):list()[1])
end)

lt.test('桃园结义：合法目标是所有存活角色，包含自己', function ()
    local run  = support.start { count = 3, packages = { '标准' } }
    local user = run.players[1]
    local card = takeCard(run, user, '桃园结义')

    local targets = assert(select(3, run.game:canUse(user, card)), '该给出合法目标')
    lt.assertEquals('三个人的局里三个目标', 3, #targets)
    lt.assertEquals('包含自己', true, moe.util.arrayHas(targets, user))
end)

lt.test('决斗：由目标先打出杀，先不出的挨 1 点', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local card   = takeCard(run, user, '决斗')
    local slash  = takeCard(run, user, '杀')

    ---@type table<Player, Card[]>
    local script = {
        [target] = { takeCard(run, target, '杀') },
        [user]   = { slash },
    }
    ---@type Player[] # 被问过的人（按被问顺序）
    local asked = {}
    run.game:on('卡牌-询问', function (ask)
        if isNullifyAsk(ask) then
            return
        end
        local to = assert(ask.to)
        asked[#asked + 1] = to
        local cards = script[to]
        if cards and #cards > 0 then
            ask:answer { card = table.remove(cards, 1) }
        end
    end)

    run.game:useCard(user, card, { target })

    lt.assertEquals('先问目标', target, asked[1])
    lt.assertEquals('再问使用者', user, asked[2])
    lt.assertEquals('目标打不出第二轮 ⇒ 又问他一次', target, asked[3])
    lt.assertEquals('被问了三次', 3, #asked)
    lt.assertEquals('目标挨 1 点', 4, target:getAttr('体力'))
    lt.assertEquals('使用者没事', 5, user:getAttr('体力'))
    lt.assertEquals('打出的杀进了弃牌', true,
        moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), slash))
end)

lt.test('决斗：目标手上没杀就直接挨 1 点', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local card   = takeCard(run, user, '决斗')

    run.game:useCard(user, card, { target })

    lt.assertEquals('目标挨 1 点', 4, target:getAttr('体力'))
    lt.assertEquals('使用者没事', 5, user:getAttr('体力'))
end)

lt.test('决斗：合法目标是其他角色，不含自己', function ()
    local run  = support.start { count = 3, packages = { '标准' } }
    local user = run.players[1]
    local card = takeCard(run, user, '决斗')

    local targets = assert(select(3, run.game:canUse(user, card)), '该给出合法目标')
    lt.assertEquals('三个人的局里两个目标', 2, #targets)
    lt.assertEquals('不含自己', false, moe.util.arrayHas(targets, user))
end)

lt.test('五谷丰登：亮出等同于目标数的牌，每人拿一张，剩余进弃牌', function ()
    local run  = support.start { count = 3, packages = { '标准' } }
    local user = run.players[1]
    local card = takeCard(run, user, '五谷丰登')
    local deck = assert(run.game:getZone('抽牌'), '没有抽牌')
    local before = deck:count()

    run.game:on('卡牌-询问', function (ask)
        local answer = support.pickFirst(ask)
        if answer then
            ask:answer(answer)
        end
    end)

    run.game:useCard(user, card, run.game.desk.alivePlayers)

    lt.assertEquals('亮出 3 张（抽牌少了 3 张）', before - 3, deck:count())
    lt.assertEquals('使用者拿一张', 1, assert(user:getZone('手牌')):count())
    lt.assertEquals('第二家拿一张', 1, assert(run.players[2]:getZone('手牌')):count())
    lt.assertEquals('第三家拿一张', 1, assert(run.players[3]:getZone('手牌')):count())
    lt.assertEquals('弃牌里只剩下那张用过的锦囊', 1, assert(run.game:getZone('弃牌')):count())
end)

lt.test('五谷丰登：没人答的那一轮拿不到牌，剩下的进弃牌', function ()
    local run  = support.start { count = 3, packages = { '标准' } }
    local user = run.players[1]
    local card = takeCard(run, user, '五谷丰登')

    run.game:on('卡牌-询问', function (ask)
        if ask.to == user then
            local answer = support.pickFirst(ask)
            if answer then
                ask:answer(answer)
            end
        end
    end)

    run.game:useCard(user, card, run.game.desk.alivePlayers)

    lt.assertEquals('只有答了的那家拿到牌', 1, assert(user:getZone('手牌')):count())
    lt.assertEquals('另外两家没拿到', 0, assert(run.players[2]:getZone('手牌')):count())
    lt.assertEquals('剩下的两张连用过的一起进弃牌', 3, assert(run.game:getZone('弃牌')):count())
end)

lt.test('五谷丰登：从顺序锚点起依次选牌', function ()
    local run  = support.start { count = 4, packages = { '标准' } }
    local user = run.players[1]
    local card = takeCard(run, user, '五谷丰登')

    ---@type string[] # 被问的座位号（按被问顺序）
    local asked = {}
    run.game:on('卡牌-询问', function (ask)
        if isNullifyAsk(ask) then
            return
        end
        local to = assert(ask.to)
        asked[#asked + 1] = tostring(assert(run.desk:getIndex(to)))
        local answer = support.pickFirst(ask)
        if answer then
            ask:answer(answer)
        end
    end)

    run.game:useCard(user, card, run.game.desk.alivePlayers)

    lt.assertEquals('一圈里四家各问一次', 4, #asked)
    lt.assertEquals('使用者（坐 1 号位）第一个，然后按行动顺序', '1,2,3,4', table.concat(asked, ','))
end)

lt.test('五谷丰登：起点是顺序锚点，不是使用者', function ()
    local run  = support.start { count = 3, packages = { '标准' } }
    local user = run.players[3]
    local card = takeCard(run, user, '五谷丰登')

    ---@type string[] # 被问的座位号（按被问顺序）
    local asked = {}
    run.game:on('卡牌-询问', function (ask)
        if isNullifyAsk(ask) then
            return
        end
        local to = assert(ask.to)
        asked[#asked + 1] = tostring(assert(run.desk:getIndex(to)))
        local answer = support.pickFirst(ask)
        if answer then
            ask:answer(answer)
        end
    end)

    run.game:useCard(user, card, run.game.desk.alivePlayers)

    lt.assertEquals('第一个选牌的是 1 号位（锚点），不是 3 号位的使用者', '1,2,3', table.concat(asked, ','))
end)

lt.test('过河拆桥：目标身上有牌的区都逐张当候选，弃掉挑中的那张', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local card   = takeCard(run, user, '过河拆桥')
    local hidden = takeCard(run, target, '杀')
    local weapon = equipCard(run, target, '诸葛连弩')
    local hand   = assert(target:getZone('手牌'), '没有手牌区')

    ---@type AskCard?
    local asked = nil
    ---@type AskCard.Option[]
    local options = {}
    run.game:on('卡牌-询问', function (ask)
        asked   = ask
        options = assert(ask.options)
        ask:answer { card = hidden }
    end)

    run.game:useCard(user, card, { target })

    lt.assertEquals('问的是使用者', user, assert(asked).to)
    lt.assertEquals('手牌与装备区的牌都在候选里', 2, #options)
    lt.assertEquals('按牌区的加入顺序（手牌在前）', hidden, options[1].card)
    lt.assertEquals('装备区的牌在后', weapon, options[2].card)
    lt.assertEquals('不是「使用」⇒ 不要求给目标', nil, options[1].targets)

    lt.assertEquals('挑中的手牌进了弃牌', true,
        moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), hidden))
    lt.assertEquals('目标手牌空了', 0, hand:count())
    lt.assertEquals('装备区没动', 1, assert(target:getZone('装备')):count())
end)

lt.test('过河拆桥：目标只有手牌时，候选就是那几张手牌', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local card   = takeCard(run, user, '过河拆桥')
    takeCard(run, target, '杀')
    takeCard(run, target, '闪')
    local hand   = assert(target:getZone('手牌'), '没有手牌区')

    ---@type AskCard.Option[]
    local options = {}
    run.game:on('卡牌-询问', function (ask)
        if isNullifyAsk(ask) then
            return
        end
        options = assert(ask.options)
        ask:answer { card = options[2].card }
    end)

    run.game:useCard(user, card, { target })

    lt.assertEquals('两张手牌都进了候选', 2, #options)
    lt.assertEquals('目标少了一张手牌', 1, hand:count())
    lt.assertEquals('剩下那张还在他手上', hand, assert(hand:list()[1]):getZone())
    lt.assertEquals('弃牌里有这张锦囊与被弃的那张', 2, assert(run.game:getZone('弃牌')):count())
end)

lt.test('过河拆桥：合法目标是「区域里有牌」的其他角色', function ()
    local run  = support.start { count = 3, packages = { '标准' } }
    local user = run.players[1]
    local card = takeCard(run, user, '过河拆桥')
    takeCard(run, run.players[2], '杀')

    local targets = assert(select(3, run.game:canUse(user, card)), '该给出合法目标')

    lt.assertEquals('只有身上有牌的 2 号位', 1, #targets)
    lt.assertEquals('就是 2 号位', run.players[2], targets[1])
    lt.assertEquals('不含自己', false, moe.util.arrayHas(targets, user))
end)

lt.test('借刀杀人：被借刀者用出【杀】，武器留在自己身上', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local user   = run.players[1]
    local holder = run.players[2]
    local victim = run.players[3]
    local card   = takeCard(run, user, '借刀杀人')
    local weapon = equipCard(run, holder, '诸葛连弩')
    local slash  = takeCard(run, holder, '杀')

    ---@type any # 这次问使用者的问法（内容侧自己解释：候选名单在里面）
    local question = nil
    ---@type Player? # 这次问的是谁
    local asked = nil
    run.game:on('决策-询问', function (ask)
        asked    = ask.to
        question = ask.question
        ask:answer(victim)
    end)
    run.game:on('卡牌-询问', function (ask)
        if ask.reason == '借刀杀人' then
            ask:answer { card = slash, targets = { victim } }
        end
    end)

    run.game:useCard(user, card, { holder })

    lt.assertEquals('指定谁问的是使用者', user, asked)
    lt.assertEquals('候选就是被借刀者能打到的人', true,
        moe.util.arrayHas(assert(question).candidates, victim))
    lt.assertEquals('打出的【杀】结算了：目标挨 1 点', 4, victim:getAttr('体力'))
    lt.assertEquals('武器还在他装备区', weapon, assert(holder:getZone('装备')):getSlot('武器'))
    lt.assertEquals('使用者没拿到武器', 0, assert(user:getZone('手牌')):count())
    lt.assertEquals('用过的【杀】与【借刀杀人】都进了弃牌堆', 2,
        assert(run.game:getZone('弃牌')):count())
end)

lt.test('借刀杀人：被借刀者手上没【杀】⇒ 武器交给使用者', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local user   = run.players[1]
    local holder = run.players[2]
    local victim = run.players[3]
    local card   = takeCard(run, user, '借刀杀人')
    local weapon = equipCard(run, holder, '诸葛连弩')
    local hand   = assert(user:getZone('手牌'), '没有手牌区')

    run.game:on('决策-询问', function (ask)
        ask:answer(victim)
    end)

    run.game:useCard(user, card, { holder })

    lt.assertEquals('武器进使用者手牌', hand, weapon:getZone())
    lt.assertEquals('手上就这一张', 1, hand:count())
    lt.assertEquals('装备区空了', 0, assert(holder:getZone('装备')):count())
    lt.assertEquals('被借刀者的攻击范围回落', 1, holder:getAttr('攻击范围'))
    lt.assertEquals('使用者的攻击范围没被带跑', 1, user:getAttr('攻击范围'))
end)

lt.test('借刀杀人：这阶段已经用过【杀】⇒ 也用不出来，武器照交', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local user   = run.players[1]
    local holder = run.players[2]
    local victim = run.players[3]
    local card   = takeCard(run, user, '借刀杀人')
    local weapon = equipCard(run, holder, '诸葛连弩')
    takeCard(run, holder, '杀')

    local phase <close> = run.game:enterPhase(holder, '出牌')
    phase:addUseCount('杀', 1)

    run.game:on('决策-询问', function (ask)
        ask:answer(victim)
    end)

    run.game:useCard(user, card, { holder })

    lt.assertEquals('【杀】用不出来 ⇒ 武器到了使用者手上',
        assert(user:getZone('手牌')), weapon:getZone())
    lt.assertEquals('那把【杀】还捏在手上', 1, assert(holder:getZone('手牌')):count())
end)

lt.test('借刀杀人：合法目标要有武器、且他攻击范围内还有别人', function ()
    local run   = support.start { count = 4, packages = { '标准' } }
    local user  = run.players[1]
    local card  = takeCard(run, user, '借刀杀人')
    local bare  = run.players[2]
    local armed = run.players[3]

    local ok = run.game:canUse(user, card, { bare })
    lt.assertEquals('装备区没武器的不能当目标', false, ok)

    equipCard(run, armed, '诸葛连弩')
    local targets = assert(select(3, run.game:canUse(user, card)), '有武器的该能当目标')
    lt.assertEquals('装武器的那个合法', true, moe.util.arrayHas(targets, armed))
    lt.assertEquals('不含自己', false, moe.util.arrayHas(targets, user))

    run.players[2]:setAlive(false)
    run.players[4]:setAlive(false)
    local around = run.game:canUse(user, card, { armed })
    lt.assertEquals('他攻击范围内没人了 ⇒ 也不合法', false, around)
end)

lt.test('借刀杀人：使用者没指定角色（答复不在候选里）⇒ 按没指定处理，武器照交', function ()
    local run    = support.start { count = 4, packages = { '标准' } }
    local user   = run.players[1]
    local holder = run.players[2]
    local out    = run.players[4]
    local card   = takeCard(run, user, '借刀杀人')
    local weapon = equipCard(run, holder, '诸葛连弩')

    run.game:on('决策-询问', function (ask)
        ask:answer(out)   -- 距离 2，不在他攻击范围内
    end)

    run.game:useCard(user, card, { holder })

    lt.assertEquals('答复不在候选里 ⇒ 按没指定处理，武器交给使用者',
        assert(user:getZone('手牌')), weapon:getZone())
    lt.assertEquals('装备区空了', 0, assert(holder:getZone('装备')):count())
end)

lt.test('借刀杀人：没人应答「指定谁」⇒ 同样按没指定处理', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local user   = run.players[1]
    local holder = run.players[2]
    local card   = takeCard(run, user, '借刀杀人')
    local weapon = equipCard(run, holder, '诸葛连弩')

    run.game:useCard(user, card, { holder })

    lt.assertEquals('没有答复 ⇒ 武器交给使用者',
        assert(user:getZone('手牌')), weapon:getZone())
end)

lt.test('顺手牵羊：挑中目标哪张，就把哪张拿进自己的手牌', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local card   = takeCard(run, user, '顺手牵羊')
    local weapon = equipCard(run, target, '诸葛连弩')
    takeCard(run, target, '杀')
    local hand   = assert(user:getZone('手牌'), '没有手牌区')

    ---@type AskCard.Option[]
    local options = {}
    run.game:on('卡牌-询问', function (ask)
        options = assert(ask.options)
        ask:answer { card = weapon }
    end)

    run.game:useCard(user, card, { target })

    lt.assertEquals('手牌与装备区的牌都在候选里', 2, #options)
    lt.assertEquals('牌到了自己手上', hand, weapon:getZone())
    lt.assertEquals('目标装备区空了', 0, assert(target:getZone('装备')):count())
    lt.assertEquals('手上就这一张（拿走的那张，用完的已出手）', 1, hand:count())
end)

lt.test('顺手牵羊：手牌也在候选里，挑中就直接拿走', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local card   = takeCard(run, user, '顺手牵羊')
    local stolen = takeCard(run, target, '杀')
    local hand   = assert(target:getZone('手牌'), '没有手牌区')

    run.game:on('卡牌-询问', function (ask)
        if isNullifyAsk(ask) then
            return
        end
        local option = assert(assert(ask.options)[1])
        lt.assertEquals('候选带的是牌（不是区）', true, option.card ~= nil)
        ask:answer { card = option.card }
    end)

    run.game:useCard(user, card, { target })

    lt.assertEquals('目标手牌空了', 0, hand:count())
    lt.assertEquals('拿到的就是那张', assert(user:getZone('手牌')), stolen:getZone())
end)

lt.test('顺手牵羊：合法目标要距离 1 以内且区域里有牌', function ()
    local run  = support.start { count = 4, packages = { '标准' } }
    local user = run.players[1]
    local card = takeCard(run, user, '顺手牵羊')
    takeCard(run, run.players[2], '杀')
    takeCard(run, run.players[3], '杀')

    local targets = assert(select(3, run.game:canUse(user, card)), '该给出合法目标')

    lt.assertEquals('只有相邻的 2 号位', 1, #targets)
    lt.assertEquals('就是 2 号位', run.players[2], targets[1])
    lt.assertEquals('距离 2 的 3 号位不算', false, moe.util.arrayHas(targets, run.players[3]))
    lt.assertEquals('距离 1 但身上没牌的 4 号位不算', false, moe.util.arrayHas(targets, run.players[4]))
    lt.assertEquals('不含自己', false, moe.util.arrayHas(targets, user))
end)

lt.test('无懈可击：没人用它 ⇒ 锦囊照常结算，但一圈里每个存活角色都被问过', function ()
    local run  = support.start { count = 3, packages = { '标准' } }
    local user = run.players[1]
    local card = takeCard(run, user, '无中生有')

    ---@type string[] # 被问无懈的座位号（按被问顺序）
    local asked = {}
    run.game:on('卡牌-询问', function (ask)
        if not isNullifyAsk(ask) then
            return
        end
        asked[#asked + 1] = tostring(assert(run.desk:getIndex(assert(ask.to))))
    end)

    run.game:useCard(user, card, { user })

    lt.assertEquals('从顺序锚点起问了一圈', '1,2,3', table.concat(asked, ','))
    lt.assertEquals('锦囊照常生效（摸到两张）', 2, assert(user:getZone('手牌')):count())
end)

lt.test('无懈可击：有人用它 ⇒ 那张锦囊对这个目标不生效', function ()
    local run     = support.start { count = 2, packages = { '标准' } }
    local user    = run.players[1]
    local card    = takeCard(run, user, '无中生有')
    local nullify = takeCard(run, run.players[2], '无懈可击')

    ---@type boolean
    local answered = false
    run.game:on('卡牌-询问', function (ask)
        if answered or not isNullifyAsk(ask) then
            return
        end
        if ask.to == run.players[2] then
            answered = true
            ask:answer { card = nullify }
        end
    end)

    run.game:useCard(user, card, { user })

    lt.assertEquals('一张也没摸到', 0, assert(user:getZone('手牌')):count())
    local discard = assert(run.game:getZone('弃牌')):list()
    lt.assertEquals('用掉的无懈进了弃牌堆', true, moe.util.arrayHas(discard, nullify))
    lt.assertEquals('被抵消的锦囊也进了弃牌堆', true, moe.util.arrayHas(discard, card))
end)

lt.test('无懈可击：它自己也能被抵消 ⇒ 原锦囊照常生效', function ()
    local run  = support.start { count = 3, packages = { '标准' } }
    local user = run.players[1]
    local card = takeCard(run, user, '无中生有')

    ---@type table<Player, Card>
    local hand = {
        [run.players[2]] = takeCard(run, run.players[2], '无懈可击'),
        [run.players[3]] = takeCard(run, run.players[3], '无懈可击'),
    }
    ---@type table<Player, true> # 每人只答一次
    local done = {}
    run.game:on('卡牌-询问', function (ask)
        if not isNullifyAsk(ask) then
            return
        end
        local to = assert(ask.to)
        if hand[to] and not done[to] then
            done[to] = true
            ask:answer { card = hand[to] }
        end
    end)

    local spell = run.game:useCard(user, card, { user })

    lt.assertEquals('两层互相抵消 ⇒ 原锦囊照常生效', 2, assert(user:getZone('手牌')):count())
    lt.assertEquals('两张无懈都进弃牌堆', true,
        moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), hand[run.players[3]]))

    local firstNullify = assert(childOf(assert(childOf(spell, 'cardEffect')), 'useCardToCard'))
    ---@cast firstNullify UseCardToCard
    local firstEffect  = assert(firstNullify.cardEffectToCard)
    lt.assertEquals('第一张无懈对那张无懈的生效被真的阻止（不是只把最外层阻止掉），原因也记着', '无懈可击',
        firstEffect.err)
    lt.assertEquals('它自己那次使用是成的', nil, firstNullify.err)
end)

lt.test('无懈可击：那张无懈自己又被抵消 ⇒ 这一圈没走完，接着问下一个人', function ()
    local run  = support.start { count = 4, packages = { '标准' } }
    local user = run.players[1]
    local card = takeCard(run, user, '无中生有')
    local nullify1 = takeCard(run, run.players[2], '无懈可击')
    local nullify2 = takeCard(run, run.players[3], '无懈可击')
    local nullify3 = takeCard(run, run.players[4], '无懈可击')

    --- 谁、对哪张牌、给出哪张无懈（第二条把第一条抵掉，于是这一圈继续走到第三条）
    local script = {
        { player = run.players[2], target = card,     card = nullify1, used = false },
        { player = run.players[3], target = nullify1, card = nullify2, used = false },
        { player = run.players[4], target = card,     card = nullify3, used = false },
    }
    run.game:on('卡牌-询问', function (ask)
        if not isNullifyAsk(ask) then
            return
        end
        local condition = assert(ask.condition)
        for _, step in ipairs(script) do
            if not step.used and step.player == ask.to and step.target == condition.target then
                step.used = true
                ask:answer { card = step.card }
                return
            end
        end
    end)

    run.game:useCard(user, card, { user })

    lt.assertEquals('第一张无懈没生效 ⇒ 这一圈接着问，第三个人把它抵掉了 ⇒ 锦囊不生效', 0,
        assert(user:getZone('手牌')):count())

    local discard = assert(run.game:getZone('弃牌')):list()
    lt.assertEquals('三张无懈都进弃牌堆', true,
        moe.util.arrayHas(discard, nullify1)
        and moe.util.arrayHas(discard, nullify2)
        and moe.util.arrayHas(discard, nullify3))
end)

lt.test('无懈可击：多目标锦囊可以对某一个目标单独抵消', function ()
    local run     = support.start { count = 3, packages = { '标准' } }
    local user    = run.players[1]
    local card    = takeCard(run, user, '南蛮入侵')
    local nullify = takeCard(run, run.players[3], '无懈可击')

    ---@type boolean
    local answered = false
    run.game:on('卡牌-询问', function (ask)
        if answered or not isNullifyAsk(ask) then
            return
        end
        local pending = pendingEffect(ask)
        if ask.to == run.players[3] and pending and pending.target == run.players[2] then
            answered = true
            ask:answer { card = nullify }
        end
    end)

    run.game:useCard(user, card, { run.players[2], run.players[3] })

    lt.assertEquals('被抵消的那个不受伤', 5, run.players[2]:getAttr('体力'))
    lt.assertEquals('另一个照常结算', 4, run.players[3]:getAttr('体力'))
end)

lt.test('无懈可击：非锦囊不问（【杀】照旧只问【闪】）', function ()
    local run   = support.start { count = 2, packages = { '标准' } }
    local user  = run.players[1]
    local slash = takeCard(run, user, '杀')

    ---@type boolean
    local askedNullify = false
    ---@type string[]
    local reasons = {}
    run.game:on('卡牌-询问', function (ask)
        if isNullifyAsk(ask) then
            askedNullify = true
            return
        end
        reasons[#reasons + 1] = ask.reason
    end)

    run.game:useCard(user, slash, { run.players[2] })

    lt.assertEquals('没出现要无懈的询问', false, askedNullify)
    lt.assertEquals('只问了那一次【闪】', 1, #reasons)
    lt.assertEquals('缘由是【杀】', '杀', reasons[1])
end)

lt.test('无懈可击：主动用不出去（只在「生效前」被问到时才用）', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local user = run.players[1]
    local card = takeCard(run, user, '无懈可击')
    takeCard(run, user, '无中生有')

    local options = run.game:askUseCard(user, '出牌', { zone = '手牌' }).options
    lt.assertEquals('出牌阶段的候选里只有那张锦囊', 1, #(options or {}))
    lt.assertEquals('就是【无中生有】', '无中生有', (options or {})[1].card.name)

    local ok, reason = run.game:canUse(user, card, {})
    lt.assertEquals('直接问也用不了', false, ok)
    lt.assertEquals('原因是它没有「对角色使用」这一支', '「标准.无懈可击」没有声明「获取目标」，现在用不了', reason)
end)

lt.test('无懈可击：答复的牌不在选项里 ⇒ 按没用处理，锦囊照常生效', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local card   = takeCard(run, user, '无中生有')
    local other  = takeCard(run, target, '杀')

    ---@type boolean
    local answered = false
    run.game:on('卡牌-询问', function (ask)
        if answered or not isNullifyAsk(ask) then
            return
        end
        if ask.to == target then
            answered = true
            ask:answer { card = other }   -- 手里没无懈可击，给一张别的
        end
    end)

    run.game:useCard(user, card, { user })

    lt.assertEquals('确实问过他', true, answered)
    lt.assertEquals('锦囊照常生效（摸到两张）', 2, assert(user:getZone('手牌')):count())
    lt.assertEquals('那张牌还在他手上', true,
        moe.util.arrayHas(assert(target:getZone('手牌')):list(), other))
end)

lt.test('锦囊：已落地的都归类为锦囊与非延时锦囊', function ()
    local run = support.start { count = 2, packages = { '标准' } }

    for _, name in ipairs({
        '无中生有', '南蛮入侵', '万箭齐发', '桃园结义', '决斗', '五谷丰登',
        '过河拆桥', '顺手牵羊', '无懈可击',
    }) do
        local def = assert(run.game:getCard(name), '没有这张牌的定义')

        lt.assertEquals('{} 是锦囊' % { name }, true, def:isKind('锦囊'))
        lt.assertEquals('{} 是非延时锦囊' % { name }, true, def:isKind('非延时锦囊'))
        lt.assertEquals('{} 的两个分类都在' % { name }, '锦囊,非延时锦囊', table.concat(def:getKinds(), ','))
        lt.assertEquals('{} 从手牌用' % { name }, '手牌', def:getZone())
    end
end)
