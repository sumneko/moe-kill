local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'ask-use-card-to-card-probe'

fs.remove_all(probeDir)
fs.create_directories(probeDir)
do
    local file = probeDir / '探针' / '牌.lua'
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), [[
Card '抵消牌'
    : on('获取卡牌目标', function (plan)
        return plan.targets
    end)
Card '另一张抵消牌'
    : on('获取卡牌目标', function (plan)
        return plan.targets
    end)
Card '没声明牌'
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
    game.turnPlayer = players[1]
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

lt.test('要对牌使用：候选逐张跑校验，选项带上目标牌', function ()
    local game, players = newGame(3)
    local usable = game:createCard('抵消牌')
    local plain  = game:createCard('没声明牌')
    putInHand(players[1], { usable, plain })
    local target = game:createCard('没声明牌')

    game:on('卡牌-询问', function (ask)
        ask:answer { card = usable }
    end)

    local ask     = game:askUseCardToCard(players[1], '没声明牌', { name = '抵消牌', target = target })
    local options = assert(ask.options)

    lt.assertEquals('种类标识', 'askUseCardToCard', ask.kind)
    lt.assertEquals('没声明「获取卡牌目标」的不进选项', 1, #options)
    lt.assertEquals('选项带上了目标牌', target, options[1].target)
    lt.assertEquals('答复收下', usable, ask.card)
end)

lt.test('要对牌使用：答复多给目标会被拒收', function ()
    local game, players = newGame(3)
    local usable = game:createCard('抵消牌')
    putInHand(players[1], { usable })
    local target = game:createCard('没声明牌')

    game:on('卡牌-询问', function (ask)
        ask:answer { card = usable, targets = { players[2] } }
    end)

    local ask = game:askUseCardToCard(players[1], '没声明牌', { name = '抵消牌', target = target })
    lt.assertEquals('多给目标 ⇒ 不存在', nil, ask.card)
    lt.assertEquals('原因', '这次答复不该给目标', ask.err)
end)

lt.test('要对牌使用：答复不在选项里 ⇒ 拒收，牌不动', function ()
    local game, players = newGame(3)
    local usable = game:createCard('抵消牌')
    local other  = game:createCard('另一张抵消牌')
    putInHand(players[1], { usable })
    local target = game:createCard('没声明牌')

    game:on('卡牌-询问', function (ask)
        ask:answer { card = other }
    end)

    local ask = game:askUseCardToCard(players[1], '没声明牌', { name = '抵消牌', target = target })
    lt.assertEquals('不在选项里 ⇒ 不存在', nil, ask.card)
    lt.assertEquals('手上那张还在', true, moe.util.arrayHas(players[1]:getZone('手牌'):list(), usable))
end)

lt.test('要对牌使用：没人应答 ⇒ 不存在，不算失败', function ()
    local game, players = newGame(3)
    local usable = game:createCard('抵消牌')
    putInHand(players[1], { usable })
    local target = game:createCard('没声明牌')

    game:on('卡牌-询问', function (ask)
        ask:answer(nil)
    end)

    local ask = game:askUseCardToCard(players[1], '没声明牌', { name = '抵消牌', target = target })
    lt.assertEquals('没有答复', nil, ask.card)
    lt.assertEquals('不算失败', nil, ask.err)
end)

lt.test('要对牌使用：缘由与被问者原样带到应答方', function ()
    local game, players = newGame(3)
    local usable = game:createCard('抵消牌')
    putInHand(players[2], { usable })
    local target = game:createCard('没声明牌')

    ---@type AskCard?
    local seen = nil
    game:on('卡牌-询问', function (ask)
        seen = ask
        ask:answer { card = usable }
    end)

    local ask = game:askUseCardToCard(players[2], '没声明牌', { name = '抵消牌', target = target })

    lt.assertEquals('被问者', players[2], assert(seen).to)
    lt.assertEquals('缘由原样带到', '没声明牌', assert(seen).reason)
    lt.assertEquals('答复收下', usable, ask.card)
end)

lt.test('要对牌使用：答复到手就自动用出去，那次使用记在询问上', function ()
    local game, players = newGame(3)
    local usable = game:createCard('抵消牌')
    putInHand(players[1], { usable })
    local target = game:createCard('没声明牌')
    game:on('卡牌-询问', function (ask)
        ask:answer { card = usable }
    end)

    local ask = game:askUseCardToCard(players[1], '没声明牌', { name = '抵消牌', target = target })

    local useCard = assert(ask.useCardToCard, '入口应该把它用出去')
    lt.assertEquals('就是一次对牌使用', 'useCardToCard', useCard.kind)
    lt.assertEquals('对的就是那张目标牌', target, useCard.targetCard)
    lt.assertEquals('牌已经离开手牌', 0, assert(players[1]:getZone('手牌')):count())
end)
