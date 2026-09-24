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
    : on('获取目标', function (target)
        return table.filter(game.desk.alivePlayers, function (player)
            return player ~= target.user
        end)
    end)
Card '无目标牌'
    : noTarget()
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
        sources  = { './package/*', probeDir:string() .. '/*' },
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
        hand:put(card)
    end
end

lt.test('要一次使用：只收能用的牌，选项带可用目标', function ()    local game, players = newGame(3)
    local usable = game:createCard('测试牌')
    local plain  = game:createCard('闪')
    putInHand(players[1], { usable, plain })
    game:on('卡牌-询问', function (ask)
        ask:answer { card = usable, targets = { players[2] } }
    end)

    local ask     = game:askUseCard(players[1], '出牌', { zone = '手牌' })
    local options = assert(ask.options)

    lt.assertEquals('种类标识', 'askUseCard', ask.kind)
    lt.assertEquals('没声明「获取目标」的不进选项', 1, #options)
    lt.assertEquals('选项带上了可用目标', 2, #assert(options[1].targets))
    lt.assertEquals('答复收下', usable, ask.card)
    lt.assertEquals('答复里的目标也收下', 1, #assert(ask.targets))
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
        ask:answer(replies[index])
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
    local targets = assert(options[1].targets)
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
        ask:answer(replies[index])
    end)

    local missing = game:askUseCard(players[1], '测试', { name = '测试牌' })
    lt.assertEquals('没给目标 ⇒ 没答复', nil, missing.card)
    lt.assertEquals('原因是「要给出目标」', '这次答复要给出目标', missing.err)

    local outside = game:askUseCard(players[1], '测试', { name = '测试牌' })
    lt.assertEquals('名单外的目标 ⇒ 没答复', nil, outside.card)
    lt.assertEquals('原因是「目标不在可选项里」', '答复的目标不在可选项里', outside.err)
end)

lt.test('要一次使用：答复的目标给单个或一张列表都行', function ()
    local game, players = newGame(3)
    local card = game:createCard('测试牌')
    putInHand(players[1], { card })
    local order = 1
    game:on('卡牌-询问', function (ask)
        if order == 1 then
            order = 2
            ask:answer { card = card, targets = players[2] }
        else
            ask:answer { card = card, targets = { players[2], players[3] } }
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

lt.test('要一次使用：没人应答时没有答复，也不算失败', function ()
    local game, players = newGame(2)
    putInHand(players[1], { game:createCard('测试牌') })
    lt.clearErrors()

    local ask = game:askUseCard(players[1], '测试', { name = '测试牌' })

    lt.assertEquals('没有答复', nil, ask.card)
    lt.assertEquals('不算失败', nil, ask.err)
    lt.assertEquals('没有记下错误', 0, #lt.errors)
end)
