local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'ask-use-card-probe'

fs.remove_all(probeDir)
fs.create_directories(probeDir)
do
    local file = probeDir / '探针' / '牌.lua'
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), [[
Card '闪'
Card '测试牌'
    : targets {
        max = 1000,
        filter = function (player, plan)
            return player ~= plan.user
        end,
    }
Card '无目标牌'
    : targets { min = 0 }
Card '窄牌'
    : targets {
        filter = function (player, plan)
            return player ~= plan.user
        end,
    }
Card '双目标牌'
    : targets {
        min = 2,
        filter = function (player, plan)
            return player ~= plan.user
        end,
    }
]])
    assert(ok, err)
end

---@param count integer
---@return Game
---@return Player[] # 按座位号升序
local function newGame(count)
    local random = moe.random.create(1)
    local game   = moe.game.create {
        seats    = count,
        random   = random,
        sources  = { probeDir:string() .. '/*' },
        packages = { '探针' },
    }
    local desk = game.desk
    local attributeSystem = game:getAttributeSystem()
    attributeSystem:define('体力', {
        min    = -999999,
        max    = 999999,
        simple = true,
    })
    ---@type Player[]
    local players = {}
    for i = 1, count do
        local player = moe.player.create(game, { attributes = attributeSystem:createInstance() })
        desk:sit(i, player)
        player:setAttr('体力', 4)
        players[i] = player
    end
    return game, players
end

---@param player Player
---@param cards Card[] # 摆进这个玩家的手牌
local function putInHand(player, cards)
    local hand = assert(player:getZone('手牌'), '这个玩家没有手牌区')
    for _, card in ipairs(cards) do
        hand:accept(card)
    end
end

lt.test('要一次使用：只收能用的牌，选项带可用目标', function ()    local game, players = newGame(3)
    local usable = game:createCard('测试牌')
    local plain  = game:createCard('闪')
    putInHand(players[1], { usable, plain })
    game:on('卡牌-询问', function (ask)
        return { card = usable, targets = { players[2] } }
    end)

    local ask     = game:askUseCard(players[1], '出牌', { zone = '手牌' })
    local options = assert(ask.options)

    lt.assertEquals('种类标识', 'askUseCard', ask.kind)
    lt.assertEquals('没声明目标条件的不进选项', 1, #options)
    lt.assertEquals('选项带上了可用目标', 2, #options[1].plan.legal)
    lt.assertEquals('选项带上数量区间（取小到可用目标数）', '1,2',
        options[1].plan.min .. ',' .. options[1].plan.max)
    lt.assertEquals('答复收下', usable, ask.card)
    lt.assertEquals('答复里的目标也收下', 1, #assert(ask.targets))
end)

lt.test('要一次使用：选项的区间带上额外目标数，并取小到可用目标数', function ()
    local game, players = newGame(3)
    local card = game:createCard('窄牌')
    putInHand(players[1], { card })

    local index = 0
    game:on('卡牌-询问', function (ask)
        index = index + 1
        local option = assert(assert(ask.options)[1], '该有一个选项')
        if index == 1 then
            lt.assertEquals('没给选项：区间就是声明的 1、1', '1,1', option.plan.min .. ',' .. option.plan.max)
            return
        end
        lt.assertEquals('多给 1 个目标：区间带上、并取小到可用目标数 2', '1,2', option.plan.min .. ',' .. option.plan.max)
        return { card = option.card, targets = { players[2] } }
    end)

    local first = game:askUseCard(players[1], '出牌', { zone = '手牌' })
    lt.assertEquals('第一次没答复 ⇒ 牌还在', nil, first.card)

    game:on('卡牌-使用选项', function () return { extraTargets = 1 } end)

    local second = game:askUseCard(players[1], '出牌', { zone = '手牌' })
    lt.assertEquals('第二次答上了', card, second.card)
end)

lt.test('要一次使用：无目标牌的选项不带 targets，答复也不用给目标', function ()
    local game, players = newGame(3)
    local card = game:createCard('无目标牌')
    putInHand(players[1], { card })

    ---@type AskUseCard.Answer[] # 先给一个带目标的答复（该被拒收），再按不带目标答一次
    local replies = {
        { card = card, targets = { players[2] } },
        { card = card },
    }
    local index = 0
    game:on('卡牌-询问', function (ask)
        index = index + 1
        return replies[index]
    end)

    local refused = game:askUseCard(players[1], '测试', { name = '无目标牌' })
    lt.assertEquals('无目标牌的选项就是没有 targets', nil, assert(assert(refused.options)[1]).targets)
    lt.assertEquals('多给目标 ⇒ 被拒收', nil, refused.card)
    lt.assertEquals('原因', '这张牌不需要目标', refused.err)

    local ask = game:askUseCard(players[1], '测试', { name = '无目标牌' })
    lt.assertEquals('不带目标就收下', card, ask.card)
    lt.assertEquals('答复里没有目标', nil, ask.targets)
end)

lt.test('要一次使用：条件的 target ⇒ 可用目标要与它至少有一个重合', function ()
    local game, players = newGame(3)
    local card = game:createCard('测试牌')
    putInHand(players[1], { card })

    local ask     = game:askUseCard(players[1], '测试', { name = '测试牌', target = players[2] })
    local options = assert(ask.options)

    lt.assertEquals('能用在这张上 ⇒ 进选项', 1, #options)
    local targets = options[1].plan.legal
    lt.assertEquals('选项的目标就是交集（名单里那个）', 1, #targets)
    lt.assertEquals('就是 2 号位', players[2], targets[1])

    local none = game:askUseCard(players[1], '测试', { name = '测试牌', target = players[1] })
    lt.assertEquals('名单里没有能用的目标 ⇒ 没有候选', 0, #assert(none.options))

    local empty = game:askUseCard(players[1], '测试', { target = {} })
    lt.assertEquals('空的 target 名单 ⇒ 没有候选', 0, #assert(empty.options))
end)

lt.test('要一次使用：答复必须给目标，且只能从可用目标里选', function ()
    local game, players = newGame(3)
    local card = game:createCard('测试牌')
    putInHand(players[1], { card })

    ---@type AskUseCard.Answer[]
    local replies = {
        { card = card },                            -- 没给目标
        { card = card, targets = { players[1] } },  -- 自己不在可用目标里
    }
    local index = 0
    game:on('卡牌-询问', function (ask)
        index = index + 1
        return replies[index]
    end)

    local missing = game:askUseCard(players[1], '测试', { name = '测试牌' })
    lt.assertEquals('没给目标 ⇒ 没答复', nil, missing.card)
    lt.assertEquals('原因是「要给出目标」', '这次答复要给出目标', missing.err)

    local outside = game:askUseCard(players[1], '测试', { name = '测试牌' })
    lt.assertEquals('名单外的目标 ⇒ 没答复', nil, outside.card)
    lt.assertEquals('原因是「目标不在可选项里」', '答复的目标不在可选项里', outside.err)
end)

lt.test('要一次使用：答复的目标个数要落在选项的区间里', function ()
    local game, players = newGame(3)
    local one = game:createCard('窄牌')
    local two = game:createCard('双目标牌')
    putInHand(players[1], { one, two })

    ---@type AskUseCard.Answer[]
    local replies = {
        { card = one, targets = { players[2], players[3] } }, -- 太多（至多 1）
        { card = one, targets = { players[2] } },             -- 合适
        { card = two, targets = { players[2] } },             -- 太少（至少 2）
    }
    local index = 0
    game:on('卡牌-询问', function (ask)
        index = index + 1
        return replies[index]
    end)

    local over = game:askUseCard(players[1], '测试', { name = '窄牌' })
    lt.assertEquals('个数太多 ⇒ 拒收', nil, over.card)
    lt.assertEquals('原因', '至多指定 1 个目标', over.err)

    local fine = game:askUseCard(players[1], '测试', { name = '窄牌' })
    lt.assertEquals('个数合适 ⇒ 收下', one, fine.card)

    local under = game:askUseCard(players[1], '测试', { name = '双目标牌' })
    lt.assertEquals('个数太少 ⇒ 拒收', nil, under.card)
    lt.assertEquals('原因', '至少要指定 2 个目标', under.err)
end)

lt.test('要一次使用：答复的目标重复会被拒收', function ()
    local game, players = newGame(3)
    local card = game:createCard('测试牌')
    putInHand(players[1], { card })
    game:on('卡牌-询问', function (ask)
        return { card = card, targets = { players[2], players[2] } }
    end)

    local ask = game:askUseCard(players[1], '测试', { name = '测试牌' })

    lt.assertEquals('重复 ⇒ 拒收', nil, ask.card)
    lt.assertEquals('原因', '答复的目标重复了', ask.err)
end)

lt.test('要一次使用：答复的目标给单个或一张列表都行', function ()
    local game, players = newGame(3)
    local card = game:createCard('测试牌')
    local another = game:createCard('测试牌')
    putInHand(players[1], { card, another })
    local order = 1
    game:on('卡牌-询问', function (ask)
        if order == 1 then
            order = 2
            return { card = card, targets = players[2] }
        else
            return { card = another, targets = { players[2], players[3] } }
        end
    end)

    ---@type AskUseCard.Condition # 名单 = 2、3 号位（选项的目标就是交集）
    local condition = { name = '测试牌', target = { players[2], players[3] } }

    local single = game:askUseCard(players[1], '测试', condition)
    lt.assertEquals('牌读得到', card, single.card)
    local one = assert(single.targets)
    lt.assertEquals('单个目标也归一成列表', 1, #one)
    lt.assertEquals('列表里就是那个目标', players[2], one[1])

    local many = game:askUseCard(players[1], '测试', condition)
    lt.assertEquals('目标读得到（一张列表）', 2, #assert(many.targets))
end)

lt.test('要一次使用：条件里的 target 构造时归一成 targets 列表', function ()
    local game, players = newGame(3)
    local card = game:createCard('测试牌')
    putInHand(players[1], { card })
    game:on('卡牌-询问', function ()
        return { card = card, targets = players[2] }
    end)

    local ask = game:askUseCard(players[1], '测试', { name = '测试牌', target = players[2] })

    local condition = assert(ask.condition)
    local targets   = assert(condition.targets, '归一成 targets')
    lt.assertEquals('单值归一成列表', 1, #targets)
    lt.assertEquals('列表里就是他', players[2], targets[1])
    lt.assertEquals('旧的单字名不再留着', nil, rawget(condition, 'target'))
    lt.assertEquals('答复照旧读得到', players[2], assert(ask.targets)[1])
end)

lt.test('要一次使用：允许取消时，没人应答 = 取消（记成失败）', function ()
    local game, players = newGame(2)
    putInHand(players[1], { game:createCard('测试牌') })
    lt.clearErrors()

    local ask = game:askUseCard(players[1], '测试', { name = '测试牌' })

    lt.assertEquals('没有答复', nil, ask.card)
    lt.assertEquals('取消记在 .err 上', '取消', ask.err)
    lt.assertEquals('取消不是故障，不进错误处理器', 0, #lt.errors)
end)

lt.test('要一次使用：答复到手就自动用出去，那次使用记在询问上', function ()
    local game, players = newGame(3)
    local card = game:createCard('测试牌')
    putInHand(players[1], { card })
    local hand = assert(players[1]:getZone('手牌'))
    game:on('卡牌-询问', function (ask)
        return { card = card, targets = { players[2] } }
    end)

    local ask = game:askUseCard(players[1], '出牌', { zone = '手牌' })

    local useCard = assert(ask.useCard, '入口应该把它用出去')
    lt.assertEquals('就是一次使用', 'useCard', useCard.kind)
    lt.assertEquals('用出去的那张就是答复的牌', card, useCard.card)
    lt.assertEquals('目标就是答复的目标', players[2], assert(useCard.targets)[1])
    lt.assertEquals('牌已经离开手牌', 0, hand:count())
    lt.assertEquals('再调一次不会用第二遍', useCard, ask:use())
end)

lt.test('要一次使用：没人应答就没有那次使用', function ()
    local game, players = newGame(2)
    putInHand(players[1], { game:createCard('测试牌') })
    game:on('卡牌-询问', function (ask)
        return nil
    end)

    local ask = game:askUseCard(players[1], '测试', { name = '测试牌' })

    lt.assertEquals('没有答复', nil, ask.card)
    lt.assertEquals('也没有那次使用', nil, ask.useCard)
end)

lt.test('要一次使用：选中「视为」声明 ⇒ 收素材、造牌，当答复用出去', function ()
    local game, players = newGame(3)
    local first  = game:createCard('闪')
    local second = game:createCard('闪')
    putInHand(players[1], { first, second })

    ---@type ViewAs?
    local chosen = nil
    game:on('卡牌-询问', function (ask)
        ---@cast ask AskUseCard
        if ask.kind == 'askCard' then
            return { card = { first, second } }
        end
        local option = assert(assert(ask.options)[1], '声明该进选项')
        chosen = option.viewAs
        return { viewAs = option.viewAs, targets = { players[2] } }
    end)

    local viewAs = players[1]:addViewAs('测试牌', nil, { condition = { zone = '手牌', min = 2 } })
    local ask    = game:askUseCard(players[1], '出牌', { zone = '手牌' })

    local card = assert(ask.card)
    lt.assertEquals('选项就是这份声明', viewAs, chosen)
    lt.assertEquals('没传关联就是空', nil, assert(chosen).source)
    lt.assertEquals('造出来的是虚拟牌', true, card.virtual)
    lt.assertEquals('按声明的牌名造', '测试牌', card.name)
    lt.assertEquals('素材是那两张手牌', 2, #card.subcards)
    lt.assertEquals('照常发起使用', true, ask.useCard ~= nil)
    lt.assertEquals('两张手牌都进了弃牌堆', assert(game:getZone('弃牌')), first:getZone())
    lt.assertEquals('第二张也进了', assert(game:getZone('弃牌')), second:getZone())
end)

lt.test('要一次使用：素材不够时声明不进选项', function ()
    local game, players = newGame(3)
    putInHand(players[1], { game:createCard('闪') })
    players[1]:addViewAs('测试牌', nil, { condition = { zone = '手牌', min = 2 } })
    game:on('卡牌-询问', function (ask)
        return nil
    end)

    local ask = game:askUseCard(players[1], '出牌', { zone = '手牌' })

    lt.assertEquals('选项里什么都没有', 0, #assert(ask.options))
end)

lt.test('要一次使用：声明的牌名对不上这次要的牌就不进选项', function ()
    local game, players = newGame(3)
    putInHand(players[1], { game:createCard('测试牌'), game:createCard('闪') })
    players[1]:addViewAs('窄牌', nil, { condition = { zone = '手牌', min = 1 } })
    game:on('卡牌-询问', function (ask)
        return nil
    end)

    local ask     = game:askUseCard(players[1], '出牌', { name = '测试牌', zone = '手牌' })
    local options = assert(ask.options)

    lt.assertEquals('只剩那张实体牌', 1, #options)
    lt.assertEquals('它不是声明选项', nil, options[1].viewAs)
end)

lt.test('要一次使用：实体牌与声明一起出现在选项里', function ()
    local game, players = newGame(3)
    putInHand(players[1], { game:createCard('测试牌'), game:createCard('闪') })
    players[1]:addViewAs('测试牌', nil, { condition = { zone = '手牌', min = 2 } })
    game:on('卡牌-询问', function (ask)
        return nil
    end)

    local ask     = game:askUseCard(players[1], '出牌', { zone = '手牌' })
    local options = assert(ask.options)

    lt.assertEquals('实体一个 + 声明一个', 2, #options)
    lt.assertEquals('实体那个带着牌', '测试牌', assert(options[1].card).name)
    lt.assertEquals('声明那个带着声明、没有牌', true, options[2].viewAs ~= nil)
    lt.assertEquals('声明选项没有牌', nil, options[2].card)
end)

lt.test('要一次使用：选中声明却给不出素材 ⇒ 作废，不算失败', function ()
    local game, players = newGame(3)
    local first  = game:createCard('闪')
    local second = game:createCard('闪')
    putInHand(players[1], { first, second })

    game:on('卡牌-询问', function (ask)
        ---@cast ask AskUseCard
        if ask.kind == 'askCard' then
            return nil
        end
        return { viewAs = assert(assert(ask.options)[1]).viewAs, targets = { players[2] } }
    end)

    players[1]:addViewAs('测试牌', nil, { condition = { zone = '手牌', min = 2 } })
    local ask = game:askUseCard(players[1], '出牌', { zone = '手牌' })

    lt.assertEquals('没有答复', nil, ask.card)
    lt.assertEquals('原因是没给素材', '没有给出视为【测试牌】的素材', ask.err)
    lt.assertEquals('没有发起使用', nil, ask.useCard)
    lt.assertEquals('手牌一张没动', 2, assert(players[1]:getZone('手牌')):count())
    lt.assertEquals('不算失败（没进错误日志）', 0, #lt.errors)
end)

lt.test('要一次使用：声明选项的答复给错目标会被拒收', function ()
    local game, players = newGame(3)
    putInHand(players[1], { game:createCard('闪'), game:createCard('闪') })
    players[1]:addViewAs('测试牌', nil, { condition = { zone = '手牌', min = 2 } })
    game:on('卡牌-询问', function (ask)
        ---@cast ask AskUseCard
        return { viewAs = assert(assert(ask.options)[1]).viewAs, targets = { players[1] } }
    end)

    local ask = game:askUseCard(players[1], '出牌', { zone = '手牌' })

    lt.assertEquals('没拿到答复', nil, ask.card)
    lt.assertEquals('原因是目标不在可选范围里', '答复的目标不在可选项里', ask.err)
end)

lt.test('要一次使用：选中声明后不再问「发动吗」（玩家已经亲手选过了）', function ()
    local game, players = newGame(3)
    local first  = game:createCard('闪')
    local second = game:createCard('闪')
    putInHand(players[1], { first, second })

    local hand   = assert(players[1]:getZone('手牌'))
    local source = game:createCard('闪')
    hand:accept(source)

    ---@type integer
    local asked = 0
    game:on('决策-询问', function ()
        asked = asked + 1
        return '不发动'
    end)

    game:on('卡牌-询问', function (ask)
        ---@cast ask AskUseCard
        if ask.kind == 'askCard' then
            return { card = { first, second } }
        end
        for _, option in ipairs(assert(ask.options)) do
            if option.viewAs then
                return { viewAs = option.viewAs, targets = { players[2] } }
            end
        end
    end)

    players[1]:addViewAs('测试牌', source, { condition = { zone = '手牌', min = 2 }, confirm = true })
    local ask = game:askUseCard(players[1], '出牌', { zone = '手牌' })

    lt.assertEquals('一次都没问「发动」', 0, asked)
    lt.assertEquals('照常造出虚拟牌', true, assert(ask.card).virtual)
    lt.assertEquals('素材是那两张手牌', 2, #assert(ask.card).subcards)
end)

lt.test('只到 apply：不等它、也不替你用出去', function ()
    local game, players = newGame(3)
    local card = game:createCard('测试牌')
    putInHand(players[1], { card })
    local hand = assert(players[1]:getZone('手牌'))
    game:on('卡牌-询问', function (ask)
        return { card = card, targets = { players[2] } }
    end)

    local ask = game:startAskUseCard(players[1], '出牌', { zone = '手牌' })
    lt.assertEquals('刚起完：还没跑（选项都还没有）', nil, ask.options)

    ask:await()
    lt.assertEquals('等它才结：答复到手', card, ask.card)
    lt.assertEquals('不等你点头就不动牌', 1, hand:count())
    lt.assertEquals('也还没有那次使用', nil, ask.useCard)

    local useCard = ask:use()
    lt.assertEquals('用出去才有那次使用', card, assert(useCard).card)
    lt.assertEquals('牌这时才离开手牌', 0, hand:count())
    lt.assertEquals('再调一次不会用第二遍', useCard, ask:use())
end)
