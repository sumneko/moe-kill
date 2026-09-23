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
---@return Card # 已经摆进该玩家装备区的牌
local function equipCard(run, player, name)
    local card, deck = findCard(run.game, name)
    local equip = assert(player:getZone('装备'), '没有装备区')
    deck:move(card, equip)
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

lt.test('过河拆桥：目标的手牌是暗的 ⇒ 从那个区随机弃一张', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local card   = takeCard(run, user, '过河拆桥')
    takeCard(run, target, '杀')
    takeCard(run, target, '闪')
    local hand   = assert(target:getZone('手牌'), '没有手牌区')
    local before = hand:list()

    ---@type AskCard?
    local asked = nil
    ---@type AskCard.Option[]
    local options = {}
    run.game:on('卡牌-询问', function (ask)
        asked   = ask
        options = assert(ask.options)
        ask:answer { zone = assert(options[1].zone) }
    end)

    run.game:useCard(user, card, { target })

    lt.assertEquals('问的是使用者', user, assert(asked).to)
    lt.assertEquals('候选只有一个：那个看不见的区', 1, #options)
    lt.assertEquals('候选就是手牌区', hand, options[1].zone)
    lt.assertEquals('暗区的候选里没有牌', nil, options[1].card)
    lt.assertEquals('目标少了一张手牌', 1, hand:count())

    local left = hand:list()
    local gone = left[1] == before[1] and before[2] or before[1]
    lt.assertEquals('剩下那张还在他手上', hand, left[1]:getZone())
    lt.assertEquals('弃掉的是他原来手上的那张', true,
        moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), gone))
end)

lt.test('过河拆桥：目标装备区的明牌由使用者挑一张', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local card   = takeCard(run, user, '过河拆桥')
    local weapon = equipCard(run, target, '诸葛连弩')
    local hidden = takeCard(run, target, '杀')
    local hand   = assert(target:getZone('手牌'), '没有手牌区')

    ---@type AskCard.Option[]
    local options = {}
    run.game:on('卡牌-询问', function (ask)
        options = assert(ask.options)
        ask:answer { card = weapon }
    end)

    run.game:useCard(user, card, { target })

    lt.assertEquals('两个候选项', 2, #options)
    lt.assertEquals('看得见的牌在前', weapon, options[1].card)
    lt.assertEquals('看不见的区在后', hand, options[2].zone)
    lt.assertEquals('装备区空了', 0, assert(target:getZone('装备')):count())
    lt.assertEquals('手牌没动', 1, hand:count())
    lt.assertEquals('暗牌还在他手上', hand, hidden:getZone())
    lt.assertEquals('被弃的那张进了弃牌', true,
        moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), weapon))
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

lt.test('顺手牵羊：把目标装备区的明牌拿进自己的手牌', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local card   = takeCard(run, user, '顺手牵羊')
    local weapon = equipCard(run, target, '诸葛连弩')
    local hand   = assert(user:getZone('手牌'), '没有手牌区')

    run.game:on('卡牌-询问', function (ask)
        ask:answer { card = weapon }
    end)

    run.game:useCard(user, card, { target })

    lt.assertEquals('牌到了自己手上', hand, weapon:getZone())
    lt.assertEquals('装备区空了', 0, assert(target:getZone('装备')):count())
    lt.assertEquals('手上就这一张（拿走的那张，用完的已出手）', 1, hand:count())
end)

lt.test('顺手牵羊：拿目标的手牌时只能随机拿一张', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local target = run.players[2]
    local card   = takeCard(run, user, '顺手牵羊')
    local stolen = takeCard(run, target, '杀')
    local hand   = assert(target:getZone('手牌'), '没有手牌区')

    run.game:on('卡牌-询问', function (ask)
        ask:answer { zone = assert(assert(ask.options)[1].zone) }
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

lt.test('锦囊：已落地的都归类为锦囊与非延时锦囊', function ()
    local run = support.start { count = 2, packages = { '标准' } }

    for _, name in ipairs({
        '无中生有', '南蛮入侵', '万箭齐发', '桃园结义', '决斗', '五谷丰登',
        '过河拆桥', '顺手牵羊',
    }) do
        local def = assert(run.game:getCard(name), '没有这张牌的定义')

        lt.assertEquals('{} 是锦囊' % { name }, true, def:isKind('锦囊'))
        lt.assertEquals('{} 是非延时锦囊' % { name }, true, def:isKind('非延时锦囊'))
        lt.assertEquals('{} 的两个分类都在' % { name }, '锦囊,非延时锦囊', table.concat(def:getKinds(), ','))
        lt.assertEquals('{} 从手牌用' % { name }, '手牌', def:getZone())
    end
end)
