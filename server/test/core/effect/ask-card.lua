local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'ask-card-probe'

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
    game:createZone('弃牌')
    game:createZone('处理')
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
        player:addZone('手牌')
        player:setAttr('体力', 4)
        players[i] = player
    end
    return game, players
end

---@param game Game
---@param answers Card[] # 按顺序给出的牌
local function answerWith(game, answers)
    local index = 0
    game:on('卡牌-询问', function (ask)
        index = index + 1
        if index > #answers then
            error('脚本里没有更多牌了', 2)
        end
        ask:answer { card = answers[index] }
    end)
end

---@param player Player
---@param cards Card[] # 摆进这个玩家的手牌（选项是内核从牌区里按条件算出来的）
local function putInHand(player, cards)
    local hand = assert(player:getZone('手牌'), '这个玩家没有手牌区')
    for _, card in ipairs(cards) do
        hand:put(card)
    end
end

lt.test('询问：一次往返（选项按条件算出来）', function ()
    local game, players = newGame(2)
    local jink = game:createCard('闪')
    putInHand(players[2], { jink })
    answerWith(game, { jink })

    local ask = game:askCard(players[2], nil, { name = '闪' })

    lt.assertEquals('拿到应答方给出的牌', jink, ask.card)
    lt.assertEquals('选项挂在询问上', jink, assert(ask.options)[1].card)
end)

lt.test('询问：候选可以来自给定的一批牌（不看被问者的牌区）', function ()
    local game, players = newGame(2)
    local mine    = game:createCard('闪')
    local outside = game:createCard('杀')
    putInHand(players[2], { mine })
    answerWith(game, { outside })

    local ask = game:askCard(players[2], nil, { card = { outside } })

    lt.assertEquals('选项就一个', 1, #assert(ask.options))
    lt.assertEquals('选项就是给的那张', outside, assert(ask.options)[1].card)
    lt.assertEquals('答复给这批里的牌就算数', outside, ask.card)
end)

lt.test('询问：候选来自给定的一批牌时，手牌里的牌不算数', function ()
    local game, players = newGame(2)
    local mine    = game:createCard('闪')
    local outside = game:createCard('杀')
    putInHand(players[2], { mine })
    answerWith(game, { mine })

    local ask = game:askCard(players[2], nil, { card = { outside } })

    lt.assertEquals('拒收 ⇒ 没有答复', nil, ask.card)
    lt.assertEquals('原因记在 err 上', true, ask.err ~= nil)
end)

lt.test('询问：被问者与选项挂在询问上，父效果是发起它的那个', function ()
    local game, players = newGame(2)
    local jink = game:createCard('闪')
    putInHand(players[2], { jink })

    ---@type AskCard?
    local asked = nil
    game:on('卡牌-询问', function (ask)
        asked = ask
        ask:answer { card = jink }
    end)

    game:on('伤害-前', function ()
        game:askCard(players[2], '测试', { name = '闪' })
    end)

    game:damage(players[1], players[2], 1)

    local ask = assert(asked, '应答方没被问到')
    lt.assertEquals('种类标识', 'askCard', ask.kind)
    lt.assertEquals('被问者', players[2], ask.to)
    lt.assertEquals('合法选项挂在询问上', jink, assert(ask.options)[1].card)
    lt.assertEquals('缘由也挂在询问上', '测试', ask.reason)
    lt.assertEquals('答复里有牌', true, ask.card ~= nil)
    lt.assertEquals('父效果是发起它的那次伤害', 'damage', assert(ask.parent).kind)
end)

lt.test('询问：同一结算里问多次互不串', function ()
    local game, players = newGame(3)
    local first  = game:createCard('闪')
    local second = game:createCard('闪')
    putInHand(players[2], { first })
    putInHand(players[3], { second })
    answerWith(game, { first, second })

    ---@type table<integer, Card>
    local answers = {}
    game:on('伤害-前', function ()
        answers[#answers + 1] = game:askCard(players[2], nil, { name = '闪' }).card
        answers[#answers + 1] = game:askCard(players[3], nil, { name = '闪' }).card
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('第一次拿到的牌', first, answers[1])
    lt.assertEquals('第二次拿到的牌', second, answers[2])
end)

lt.test('询问：没人应答时没有答复，也不算失败', function ()
    local game, players = newGame(2)
    local jink = game:createCard('闪')
    putInHand(players[2], { jink })
    lt.clearErrors()

    local ask = game:askCard(players[2], nil, { name = '闪' })

    lt.assertEquals('没有答复', nil, ask.card)
    lt.assertEquals('不算失败', nil, ask.err)
    lt.assertEquals('没有记下错误', 0, #lt.errors)
end)

lt.test('询问：重复应答不报错，先答的算数', function ()
    local game, players = newGame(2)
    local first  = game:createCard('闪')
    local second = game:createCard('闪')
    putInHand(players[2], { first, second })
    game:on('卡牌-询问', function (ask)
        ask:answer { card = first }
        ask:answer { card = second }
    end)
    lt.clearErrors()

    local ask = game:askCard(players[2], nil, { name = '闪' })
    lt.assertEquals('先答的算数', first, ask.card)
    lt.assertEquals('不算失败', nil, ask.err)
    lt.assertEquals('没有记下错误', 0, #lt.errors)
end)

---@async
lt.test('询问：应答方可以让出，稍后再答复', function ()
    local game, players = newGame(2)
    local jink = game:createCard('闪')
    putInHand(players[2], { jink })
    game:on('卡牌-询问', function (ask)
        moe.await.sleep(0)
        ask:answer { card = jink }
    end)

    lt.assertEquals('答复照旧拿到', jink, game:askCard(players[2], nil, { name = '闪' }).card)
end)

lt.test('询问：被取消的询问以「没有答复」结束，结算其余部分照常', function ()
    local game, players = newGame(2)
    local jink = game:createCard('闪')
    putInHand(players[2], { jink })
    answerWith(game, { jink })

    ---@type string[]
    local trace = {}
    game:on('即将生效', function (effect)
        ---@cast effect AskCard
        if effect.kind == 'askCard' then
            effect:remove()
        end
    end)
    game:on('伤害-前', function ()
        trace[#trace + 1] = '前'
        local card = game:askCard(players[2], nil, { name = '闪' }).card
        trace[#trace + 1] = '答复 {}' % { tostring(card) }
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('询问没答上，伤害照常结算', '前,答复 nil', table.concat(trace, ','))
    lt.assertEquals('目标掉了血', 3, players[2]:getAttr('体力'))
end)

lt.test('答复：有答复才触发答复时机，上下文是这次询问', function ()
    local game, players = newGame(2)

    ---@type AskCard[]
    local seen = {}
    ---@type (Card?)[]
    local atFire = {}
    local fired  = 0
    game:on('卡牌-答复', function (askCard)
        ---@cast askCard AskCard
        seen[#seen + 1] = askCard
        fired           = fired + 1
        atFire[fired]   = askCard.card
    end)

    local jink = game:createCard('闪')
    putInHand(players[2], { jink })

    game:askCard(players[2], nil, { name = '闪' })
    lt.assertEquals('没人应答就不触发', 0, #seen)

    answerWith(game, { jink })
    local answered = game:askCard(players[2], nil, { name = '闪' })
    lt.assertEquals('有人应答触发了一次', 1, #seen)
    lt.assertEquals('上下文就是这次询问', answered, seen[1])
    lt.assertEquals('读到的答复', jink, seen[1].card)
    lt.assertEquals('答复时机里结果已经定下', jink, atFire[1])
end)

lt.test('答复：`AskCard` 自己不处置那张牌', function ()
    local game, players = newGame(2)
    local hand = assert(players[2]:getZone('手牌'))
    local jink = game:createCard('闪')
    hand:put(jink)
    answerWith(game, { jink })

    local ask = game:askCard(players[2], '交出', { name = '闪' })

    lt.assertEquals('答复拿到了', jink, ask.card)
    lt.assertEquals('牌还在手上（去向由内容侧定）', 1, hand:count())
    lt.assertEquals('弃牌还是空的', 0, assert(game:getZone('弃牌')):count())
end)

lt.test('询问：答复不在可选项里时拒收，原因记在 `.err`', function ()
    local game, players = newGame(2)
    local jink  = game:createCard('闪')
    local other = game:createCard('闪')
    putInHand(players[2], { jink })
    -- 答一张不在手上的牌 ⇒ 不在选项里
    answerWith(game, { other })

    local ask = game:askCard(players[2], nil, { name = '闪' })

    lt.assertEquals('没拿到答复', nil, ask.card)
    lt.assertEquals('原因是「不在可选项里」', '答复不在可选项里', ask.err)
    lt.assertEquals('选项里只有手上那一张', 1, #assert(ask.options))
end)

lt.test('询问：`AskCard` 不要目标，答复多给会被拒收', function ()
    local game, players = newGame(3)
    local plain = game:createCard('闪')
    putInHand(players[1], { plain })
    game:on('卡牌-询问', function (ask)
        ask:answer { card = plain, targets = { players[2] } }
    end)

    local ask = game:askCard(players[1], '测试', { name = '闪' })

    lt.assertEquals('多给目标 ⇒ 没答复', nil, ask.card)
    lt.assertEquals('原因是「不该给目标」', '这次答复不该给目标', ask.err)
end)

lt.test('询问：条件按牌名筛，手牌里没有就不算选项', function ()
    local game, players = newGame(2)
    local other = game:createCard('杀')
    putInHand(players[2], { other })
    answerWith(game, { other })

    local ask = game:askCard(players[2], nil, { name = '闪' })

    lt.assertEquals('没有可选项', 0, #assert(ask.options))
    lt.assertEquals('答复被拒（不在选项里）', nil, ask.card)
    lt.assertEquals('原因是「不在可选项里」', '答复不在可选项里', ask.err)
end)


lt.test('询问：不给条件就不做限制', function ()
    local game, players = newGame(2)
    local anything = game:createCard('随便')
    answerWith(game, { anything })

    local ask = game:askCard(players[2], nil, nil)

    lt.assertEquals('照样收下答复', anything, ask.card)
    lt.assertEquals('不算失败', nil, ask.err)
end)

lt.test('询问：条件按区筛（名字在被问者身上解析）', function ()
    local game, players = newGame(2)
    local mine = game:createCard('闪')
    putInHand(players[1], { mine })
    players[1]:addZone('装备')
    assert(players[1]:getZone('装备')):put(game:createCard('杀'))
    answerWith(game, { mine })

    local ask     = game:askCard(players[1], nil, { zone = '手牌' })
    local options = assert(ask.options)

    lt.assertEquals('手牌区外的牌不算', 1, #options)
    lt.assertEquals('选项就是手牌里那张', mine, options[1].card)
    lt.assertEquals('答复照旧收下', mine, ask.card)
end)

lt.test('询问：条件的 zone 可以给区对象、也可以给好几个（其一）', function ()
    local game, players = newGame(2)
    putInHand(players[1], { game:createCard('闪') })
    players[1]:addZone('装备')
    local equip = assert(players[1]:getZone('装备'))
    equip:put(game:createCard('杀'))
    players[1]:addZone('判定')
    assert(players[1]:getZone('判定')):put(game:createCard('桃'))

    local only = game:askCard(players[1], nil, { zone = equip })
    lt.assertEquals('给区对象：只有那个区的牌', 1, #assert(only.options))
    lt.assertEquals('选项就是它', equip:peek(1), assert(only.options)[1].card)

    local many = game:askCard(players[1], nil, { zone = { equip, '判定' } })
    lt.assertEquals('给两个区：并集', 2, #assert(many.options))

    local none = game:askCard(players[1], nil, { zone = '没有这个区' })
    lt.assertEquals('区名解析不到 ⇒ 没有候选', 0, #assert(none.options))
end)

lt.test('询问：条件的 name 可以给好几个（满足其一）', function ()
    local game, players = newGame(2)
    local jink  = game:createCard('闪')
    local slash = game:createCard('杀')
    putInHand(players[1], { jink, slash, game:createCard('桃') })
    answerWith(game, { slash })

    local ask     = game:askCard(players[1], nil, { name = { '闪', '杀' } })
    local options = assert(ask.options)

    lt.assertEquals('符合的只有两张', 2, #options)
    lt.assertEquals('第一张是闪', jink, options[1].card)
    lt.assertEquals('第二张是杀', slash, options[2].card)
    lt.assertEquals('答复收下', slash, ask.card)
end)

lt.test('询问：条件的 card 给一批牌，与 zone 可以同时给（并集）', function ()
    local game, players = newGame(2)
    local inHand  = game:createCard('闪')
    local outside = game:createCard('杀')
    putInHand(players[1], { inHand })
    answerWith(game, { outside, outside })

    local only = game:askCard(players[1], nil, { card = outside })
    lt.assertEquals('给一批牌：只有它（手牌不算）', 1, #assert(only.options))
    lt.assertEquals('答复是这批里的就算数', outside, only.card)

    local both = game:askCard(players[1], nil, { card = outside, zone = '手牌' })
    lt.assertEquals('同时给：并集', 2, #assert(both.options))
end)
