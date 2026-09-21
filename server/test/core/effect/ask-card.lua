local lt = require 'test.ltest'

---@param count integer
---@return Game
---@return Player[] # 按座位号升序
local function newGame(count)
    local desk   = moe.desk.create(count)
    local random = moe.random.create(1)
    local game   = moe.game.create { desk = desk, random = random }
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
        local player = moe.player.create { attributes = attributeSystem:createInstance() }
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
    game.events:on('卡牌-询问', function (ask)
        index = index + 1
        if index > #answers then
            error('脚本里没有更多牌了', 2)
        end
        ask:answer(answers[index])
    end)
end

lt.test('询问：一次往返', function ()
    local game, players = newGame(2)
    local jink = game:createCard('闪')
    answerWith(game, { jink })

    local ask = game:askCard(players[2], nil, { name = '闪' })

    lt.assertEquals('拿到应答方给出的牌', jink, ask.result)
end)

lt.test('询问：被问者与答复挂在询问上，父效果是发起它的那个', function ()
    local game, players = newGame(2)

    ---@type AskCard?
    local asked = nil
    game.events:on('卡牌-询问', function (ask)
        asked = ask
        ask:answer(game:createCard('闪'))
    end)

    game.events:on('伤害-前', function ()
        game:askCard(players[2], '测试', { name = '闪' })
    end)

    game:damage(players[1], players[2], 1)

    local ask = assert(asked, '应答方没被问到')
    lt.assertEquals('种类标识', 'askCard', ask.kind)
    lt.assertEquals('被问者', players[2], ask.to)
    lt.assertEquals('要什么牌', '闪', ask.question.name)
    lt.assertEquals('缘由也挂在询问上', '测试', ask.reason)
    lt.assertEquals('答复是这次询问的结果', true, ask.result ~= nil)
    lt.assertEquals('父效果是发起它的那次伤害', 'damage', assert(ask.parent).kind)
end)

lt.test('询问：同一结算里问多次互不串', function ()
    local game, players = newGame(3)
    local first  = game:createCard('闪')
    local second = game:createCard('闪')
    answerWith(game, { first, second })

    ---@type table<integer, Card>
    local answers = {}
    game.events:on('伤害-前', function ()
        answers[#answers + 1] = game:askCard(players[2], nil, { name = '闪' }).result
        answers[#answers + 1] = game:askCard(players[3], nil, { name = '闪' }).result
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('第一次拿到的牌', first, answers[1])
    lt.assertEquals('第二次拿到的牌', second, answers[2])
end)

lt.test('询问：没人应答时没有答复，也不算失败', function ()
    local game, players = newGame(2)
    lt.clearErrors()

    local ask = game:askCard(players[2], nil, { name = '闪' })

    lt.assertEquals('没有答复', nil, ask.result)
    lt.assertEquals('不算失败', nil, ask.err)
    lt.assertEquals('没有记下错误', 0, #lt.errors)
end)

lt.test('询问：重复应答不报错，先答的算数', function ()
    local game, players = newGame(2)
    local first  = game:createCard('闪')
    local second = game:createCard('闪')
    game.events:on('卡牌-询问', function (ask)
        ask:answer(first)
        ask:answer(second)
    end)
    lt.clearErrors()

    local ask = game:askCard(players[2], nil, { name = '闪' })
    lt.assertEquals('先答的算数', first, ask.result)
    lt.assertEquals('不算失败', nil, ask.err)
    lt.assertEquals('没有记下错误', 0, #lt.errors)
end)

---@async
lt.test('询问：应答方可以让出，稍后再答复', function ()
    local game, players = newGame(2)
    local jink = game:createCard('闪')
    game.events:on('卡牌-询问', function (ask)
        moe.await.sleep(0)
        ask:answer(jink)
    end)

    lt.assertEquals('答复照旧拿到', jink, game:askCard(players[2], nil, { name = '闪' }).result)
end)

lt.test('询问：被取消的询问以「没有答复」结束，结算其余部分照常', function ()
    local game, players = newGame(2)
    answerWith(game, { game:createCard('闪') })

    ---@type string[]
    local trace = {}
    game.events:on('即将生效', function (ctx)
        ---@cast ctx AskCard
        if ctx.kind == 'askCard' then
            ctx:remove()
        end
    end)
    game.events:on('伤害-前', function ()
        trace[#trace + 1] = '前'
        local card = game:askCard(players[2], nil, { name = '闪' }).result
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
    game.events:on('卡牌-答复', function (ctx)
        ---@cast ctx AskCard
        seen[#seen + 1] = ctx
        fired           = fired + 1
        atFire[fired]   = ctx.result
    end)

    game:askCard(players[2], nil, { name = '闪' })
    lt.assertEquals('没人应答就不触发', 0, #seen)

    local jink = game:createCard('闪')
    answerWith(game, { jink })
    local answered = game:askCard(players[2], nil, { name = '闪' })
    lt.assertEquals('有人应答触发了一次', 1, #seen)
    lt.assertEquals('上下文就是这次询问', answered, seen[1])
    lt.assertEquals('读到的答复', jink, seen[1].result)
    lt.assertEquals('答复时机里结果已经定下', jink, atFire[1])
end)

lt.test('答复：缘由是「打出」时基础规则把牌送进弃牌', function ()
    local game, players = newGame(2)
    local hand = assert(players[2]:getZone('手牌'))
    local jink = game:createCard('闪')
    hand:put(jink)
    answerWith(game, { jink })

    local ask = game:askCard(players[2], '打出', { name = '闪' })

    lt.assertEquals('答复拿到了', jink, ask.result)
    lt.assertEquals('答复的牌也挂在询问上', jink, ask.card)
    lt.assertEquals('牌离开了手', 0, hand:count())
    lt.assertEquals('牌最终进了弃牌', true, moe.util.arrayHas(assert(game:getZone('弃牌')):list(), jink))
    lt.assertEquals('处理只是路过', 0, assert(game:getZone('处理')):count())
end)

lt.test('答复：缘由不是「打出」时基础规则不接管', function ()
    local game, players = newGame(2)
    local hand = assert(players[2]:getZone('手牌'))
    local jink = game:createCard('闪')
    hand:put(jink)
    answerWith(game, { jink })

    game:askCard(players[2], '交出', { name = '闪' })

    lt.assertEquals('牌还在手上', 1, hand:count())
    lt.assertEquals('弃牌还是空的', 0, assert(game:getZone('弃牌')):count())
end)
