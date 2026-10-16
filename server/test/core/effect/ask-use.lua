local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'ask-use-probe'

fs.remove_all(probeDir)
fs.create_directories(probeDir)
do
    local file = probeDir / '探针' / '牌.lua'
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), [[
Card '测试牌'
    : targets {
        max = 1000,
        filter = function (player, plan)
            return player ~= plan.user
        end,
    }
Card '无目标牌'
    : targets { min = 0 }
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

---@async
lt.test('要一次行动：牌子半摆出能用的牌，没有可发动的技能时技能半是空的', function ()
    local game, players = newGame(2)
    local me            = assert(players[1])
    local card          = game:createCard('测试牌')
    putInHand(me, { card })
    local _ <close> = game:on('卡牌-询问', function ()
        return nil
    end)

    local ask = game:askUse(me, '出牌', { zone = '手牌' })

    lt.assertEquals('种类标识', 'askUse', ask.kind)
    lt.assertEquals('缘由原样带着', '出牌', ask.reason)
    lt.assertEquals('牌子半摆出那张能用的', 1, #assert(ask.options))
    lt.assertEquals('技能半是空的（他身上没有技能）', 0, #ask.skills)
    lt.assertEquals('没答复 ⇒ 这次没成立', false, ask.success)
end)

---@async
lt.test('要一次行动：答复一张牌 ⇒ 直接把它用出去', function ()
    local game, players = newGame(2)
    local me            = assert(players[1])
    local other         = assert(players[2])
    local card          = game:createCard('测试牌')
    putInHand(me, { card })
    local _ <close> = game:on('卡牌-询问', function ()
        return { card = card, targets = { other } }
    end)

    local ask = game:askUse(me, '出牌', { zone = '手牌' })
    ask:use()

    lt.assertEquals('这次成了', true, ask.success)
    lt.assertEquals('答复的就是那张', card, ask.card)
    lt.assertEquals('目标也认下了', other, assert(ask.targets)[1])
    lt.assertEquals('那次使用发起来了', true, ask.useCard ~= nil)
end)

---@async
lt.test('要一次行动：答复一张不在选项里的牌 ⇒ 内核拒收', function ()
    local game, players = newGame(2)
    local me            = assert(players[1])
    local stray         = game:createCard('测试牌')
    local card          = game:createCard('测试牌')
    putInHand(me, { card })
    local _ <close> = game:on('卡牌-询问', function ()
        return { card = stray }
    end)

    local ask = game:askUse(me, '出牌', { zone = '手牌' })

    lt.assertEquals('这次没成', false, ask.success)
    lt.assertEquals('原因是答复不在选项里', '答复不在可选项里', ask.err)
end)

---@async
lt.test('要一次行动：答复空表 ⇒ 按取消收尾', function ()
    local game, players = newGame(2)
    local me            = assert(players[1])
    local card          = game:createCard('测试牌')
    putInHand(me, { card })
    local _ <close> = game:on('卡牌-询问', function ()
        return {}
    end)

    local ask = game:askUse(me, '出牌', { zone = '手牌' })

    lt.assertEquals('这次没成', false, ask.success)
    lt.assertEquals('按取消收尾', '取消', ask.err)
    lt.assertEquals('也没有那次使用', nil, ask.useCard)
end)

---@async
lt.test('要一次行动：牌与技能一条都问不出来 ⇒ 不发询问', function ()
    local game, players = newGame(2)
    local me            = assert(players[1])
    ---@type integer
    local asked         = 0
    local _ <close> = game:on('卡牌-询问', function ()
        asked = asked + 1
        return nil
    end)

    local ask = game:askUse(me, '出牌', { zone = '手牌' })

    lt.assertEquals('一条询问也没发出去', 0, asked)
    lt.assertEquals('这次没成立', false, ask.success)
    lt.assertEquals('原因是没得选', '没有可以做的事', ask.err)
end)
