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
Card '杀'
Card '桃'
Card '随便'
Card '测试牌'
    : targets {
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

---@param game Game
---@param answers Card[] # 按顺序给出的牌
local function answerWith(game, answers)
    local index = 0
    game:on('卡牌-询问', function (ask)
        index = index + 1
        if index > #answers then
            error('脚本里没有更多牌了', 2)
        end
        return { card = answers[index] }
    end)
end

---@param player Player
---@param cards Card[] # 摆进这个玩家的手牌（选项是内核从牌区里按条件算出来的）
local function putInHand(player, cards)
    local hand = assert(player:getZone('手牌'), '这个玩家没有手牌区')
    for _, card in ipairs(cards) do
        hand:accept(card)
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

lt.test('询问：条件构造时归一化（列表 + 默认张数）', function ()
    local game, players = newGame(2)
    local jink = game:createCard('闪')
    putInHand(players[2], { jink })

    local ask = game:askCard(players[2], nil, { name = '闪' })

    local condition = assert(ask.condition)
    local names = assert(condition.names)
    lt.assertEquals('牌名归一成列表', 1, #names)
    lt.assertEquals('列表里就是给的那个名字', '闪', names[1])
    lt.assertEquals('张数补上默认', '1,1', condition.min .. ',' .. condition.max)
    lt.assertEquals('旧的单数名不再留着', nil, rawget(condition, 'name'))

    local loose = game:askCard(players[2], nil)
    lt.assertEquals('没给条件就是不限制（也不归一）', nil, loose.condition)
end)

lt.test('询问：条件里的区名构造时解析成区对象（解析不到的丢掉）', function ()
    local game, players = newGame(2)
    putInHand(players[2], { game:createCard('闪') })

    local ask = game:askCard(players[2], nil, { zone = { '手牌', '没有这个区' } })

    local zones = assert(assert(ask.condition).zones)
    lt.assertEquals('解析到的留下、解析不到的丢掉', 1, #zones)
    lt.assertEquals('留下的是被问者的手牌区', players[2]:getZone('手牌'), zones[1])

    local none = game:askCard(players[2], nil, { zone = '没有这个区' })
    lt.assertEquals('全解析不到 ⇒ 空表', 0, #assert(assert(none.condition).zones))
end)

lt.test('询问：第一个表态的胜出，后面的订阅者不再调', function ()
    local game, players = newGame(2)
    local early = game:createCard('闪')
    local late  = game:createCard('杀')
    putInHand(players[2], { early, late })

    local ask = moe.askCard.create {
        game      = game,
        to        = players[2],
        reason    = '测试',
        condition = { name = { '闪', '杀' } },
    }
    game:on('卡牌-询问', function ()
        return { card = early }
    end)
    answerWith(game, {})
    lt.clearErrors()

    ask:apply():await()

    lt.assertEquals('先表态的算数', early, ask.card)
    lt.assertEquals('后面的订阅者没被调（脚本没报「没有更多牌」）', 0, #lt.errors)
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
        return { card = jink }
    end)

    game:on('效果-能否生效', function (effect)
        if effect.kind == 'damage' then
            game:askCard(players[2], '测试', { name = '闪' })
        end
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
    game:on('效果-能否生效', function (effect)
        if effect.kind ~= 'damage' then
            return
        end
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
    lt.assertEquals('cards 是空表', 0, #ask.cards)
    lt.assertEquals('不算失败', nil, ask.err)
    lt.assertEquals('没有记下错误', 0, #lt.errors)
end)

lt.test('询问：第一个返回答复的胜出，后面的订阅者不再调', function ()
    local game, players = newGame(2)
    local first  = game:createCard('闪')
    local second = game:createCard('闪')
    putInHand(players[2], { first, second })
    game:on('卡牌-询问', function ()
        return { card = first }
    end)
    game:on('卡牌-询问', function ()
        error('后面的订阅者不该被调', 2)
    end)
    lt.clearErrors()

    local ask = game:askCard(players[2], nil, { name = '闪' })
    lt.assertEquals('先答的算数', first, ask.card)
    lt.assertEquals('后面的订阅者没被调', 0, #lt.errors)
end)

---@async
lt.test('询问：应答方可以让出，稍后再答复', function ()
    local game, players = newGame(2)
    local jink = game:createCard('闪')
    putInHand(players[2], { jink })
    game:on('卡牌-询问', function (ask)
        moe.await.sleep(0)
        return { card = jink }
    end)

    lt.assertEquals('答复照旧拿到', jink, game:askCard(players[2], nil, { name = '闪' }).card)
end)

lt.test('询问：被阻止的询问以「没有答复」结束，结算其余部分照常', function ()
    local game, players = newGame(2)
    local jink = game:createCard('闪')
    putInHand(players[2], { jink })
    answerWith(game, { jink })

    ---@type string[]
    local trace = {}
    game:on('效果-能否生效', function (effect)
        ---@cast effect AskCard
        if effect.kind == 'askCard' then
            return '不让这次询问生效'
        end
    end)
    game:on('效果-能否生效', function (effect)
        if effect.kind ~= 'damage' then
            return
        end
        trace[#trace + 1] = '前'
        local card = game:askCard(players[2], nil, { name = '闪' }).card
        trace[#trace + 1] = '答复 {}' % { tostring(card) }
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('询问没答上，伤害照常结算', '前,答复 nil', table.concat(trace, ','))
    lt.assertEquals('目标掉了血', 3, players[2]:getAttr('体力'))
end)

lt.test('询问：张数区间 2、2 收两张，`.cards` 是全部、`.card` 是第一张', function ()
    local game, players = newGame(2)
    local first  = game:createCard('闪')
    local second = game:createCard('杀')
    local third  = game:createCard('桃')
    putInHand(players[1], { first, second, third })
    game:on('卡牌-询问', function (ask)
        return { card = { second, first } }
    end)

    local ask = game:askCard(players[1], '测试', { name = { '闪', '杀', '桃' }, min = 2 })

    lt.assertEquals('两张都收下', 2, #ask.cards)
    lt.assertEquals('按答复的顺序（第一张）', second, ask.cards[1])
    lt.assertEquals('按答复的顺序（第二张）', first, ask.cards[2])
    lt.assertEquals('card 就是第一张', second, ask.card)
    lt.assertEquals('不算失败', nil, ask.err)
end)

lt.test('询问：张数不在区间就拒收（默认只收一张）', function ()
    local game, players = newGame(2)
    local first  = game:createCard('闪')
    local second = game:createCard('闪')
    putInHand(players[1], { first, second })
    game:on('卡牌-询问', function (ask)
        return { card = { first, second } }
    end)

    local ask = game:askCard(players[1], '测试', { name = '闪' })

    lt.assertEquals('两张被拒', nil, ask.card)
    lt.assertEquals('原因', '至多给 1 张牌', ask.err)
end)

lt.test('询问：只写 min ⇒ 至多同最少（要正好那么多张）', function ()
    local game, players = newGame(2)
    local first  = game:createCard('闪')
    local second = game:createCard('闪')
    local third  = game:createCard('闪')
    putInHand(players[1], { first, second, third })

    ---@type Card[]
    local answer = { first, second }
    game:on('卡牌-询问', function ()
        return { card = answer }
    end)

    local ask = game:askCard(players[1], '测试', { name = '闪', min = 2 })
    lt.assertEquals('正好两张：过', nil, ask.err)
    lt.assertEquals('收到了两张', 2, #ask.cards)

    answer = { first }
    local few = game:askCard(players[1], '测试', { name = '闪', min = 2 })
    lt.assertEquals('只给一张：拒收', '至少要给 2 张牌', few.err)

    answer = { first, second, third }
    local many = game:askCard(players[1], '测试', { name = '闪', min = 2 })
    lt.assertEquals('给三张也被拒（上限就是 min）', '至多给 2 张牌', many.err)
end)

lt.test('询问：min 0 ⇒ 不给也算答复（空表）', function ()
    local game, players = newGame(2)
    local jink = game:createCard('闪')
    putInHand(players[2], { jink })
    game:on('卡牌-询问', function (ask)
        return { card = {} }
    end)

    local ask = game:askCard(players[2], '测试', { name = '闪', min = 0, max = 1 })

    lt.assertEquals('没有牌', nil, ask.card)
    lt.assertEquals('cards 是空表', 0, #ask.cards)
    lt.assertEquals('不算失败', nil, ask.err)
end)

lt.test('询问：重复给同一张牌 ⇒ 拒收', function ()
    local game, players = newGame(2)
    local jink = game:createCard('闪')
    putInHand(players[2], { jink })
    game:on('卡牌-询问', function (ask)
        return { card = { jink, jink } }
    end)

    local ask = game:askCard(players[2], '测试', { name = '闪', min = 1, max = 2 })

    lt.assertEquals('没拿到答复', nil, ask.card)
    lt.assertEquals('原因', '答复的牌重复了', ask.err)
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
    hand:accept(jink)
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

lt.test('询问：答复是空表 ⇒ 一样拒收（连牌都没给）', function ()
    local game, players = newGame(2)
    local jink = game:createCard('闪')
    putInHand(players[2], { jink })
    game:on('卡牌-询问', function (ask)
        return {}
    end)

    local ask = game:askCard(players[2], '测试', { name = '闪' })

    lt.assertEquals('没拿到答复', nil, ask.card)
    lt.assertEquals('原因是「至少要给 1 张牌」', '至少要给 1 张牌', ask.err)
end)

lt.test('询问：`AskCard` 不要目标，答复多给会被拒收', function ()
    local game, players = newGame(3)
    local plain = game:createCard('闪')
    putInHand(players[1], { plain })
    game:on('卡牌-询问', function (ask)
        return { card = plain, targets = { players[2] } }
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
    players[1]:getZone('判定'):accept(game:createCard('杀'))
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
    local judge = players[1]:getZone('判定')
    judge:accept(game:createCard('杀'))
    game:getZone('弃牌'):accept(game:createCard('桃'))

    local only = game:askCard(players[1], nil, { zone = judge })
    lt.assertEquals('给区对象：只有那个区的牌', 1, #assert(only.options))
    lt.assertEquals('选项就是它', judge:peek(1), assert(only.options)[1].card)

    local many = game:askCard(players[1], nil, { zone = { judge, '弃牌' } })
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

lt.test('询问：条件按花色筛', function ()
    local game, players = newGame(2)
    local heart = game:createCard('闪', '红桃', 2)
    local spade = game:createCard('闪', '黑桃', 2)
    putInHand(players[1], { heart, spade })
    answerWith(game, { heart })

    local ask = game:askCard(players[1], nil, { suit = '红桃' })
    lt.assertEquals('只留下红桃那张', 1, #assert(ask.options))
    lt.assertEquals('就是它', heart, assert(ask.options)[1].card)
end)

lt.test('询问：条件按点数筛（可以给好几个）', function ()
    local game, players = newGame(2)
    local two   = game:createCard('闪', '红桃', 2)
    local three = game:createCard('闪', '黑桃', 3)
    putInHand(players[1], { two, three })
    answerWith(game, { three })

    local ask = game:askCard(players[1], nil, { point = { 3, 4 } })
    lt.assertEquals('只剩 3 点那张', 1, #assert(ask.options))
    lt.assertEquals('就是它', three, assert(ask.options)[1].card)
end)

lt.test('询问：条件按颜色筛（颜色按花色算出来）', function ()
    local game, players = newGame(2)
    local diamond = game:createCard('闪', '方块', 2)
    local club    = game:createCard('闪', '梅花', 2)
    local blank   = game:createCard('闪')
    putInHand(players[1], { diamond, club, blank })
    answerWith(game, { diamond })

    local ask = game:askCard(players[1], nil, { color = '红' })
    lt.assertEquals('只留下方块那张（没花色的不算）', 1, #assert(ask.options))
    lt.assertEquals('就是它', diamond, assert(ask.options)[1].card)
end)

lt.test('询问：牌面筛选与牌名叠加（都要满足）', function ()
    local game, players = newGame(2)
    local heartJink  = game:createCard('闪', '红桃', 2)
    local heartPeach = game:createCard('桃', '红桃', 3)
    local spadeJink  = game:createCard('闪', '黑桃', 4)
    putInHand(players[1], { heartJink, heartPeach, spadeJink })
    answerWith(game, { heartJink })

    local ask = game:askCard(players[1], nil, { name = '闪', color = '红' })
    lt.assertEquals('只剩红桃闪', 1, #assert(ask.options))
    lt.assertEquals('就是它', heartJink, assert(ask.options)[1].card)
end)
