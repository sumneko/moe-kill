local lt = require 'test.ltest'

---@param count integer
---@return Game
---@return Player[] # 按座位号升序
local function newGame(count)
    local desk   = moe.desk.create(count)
    local random = moe.random.create(1)
    local game   = moe.game.create { desk = desk, random = random }
    game:createZone('弃牌堆')
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

---@param answers any[]
---@return fun(ask: Ask): any
local function scripted(answers)
    local index = 0
    return function ()
        index = index + 1
        if index > #answers then
            error('脚本里没有更多答案了', 2)
        end
        return answers[index]
    end
end

lt.test('询问：一次往返', function ()
    local game, players = newGame(2)
    game.answerer = scripted { '好' }

    local answer = game:ask(players[2], { name = '闪' })

    lt.assertEquals('拿到回答者给的答案', '好', answer)
end)

lt.test('询问：答案与被问者挂在询问自己身上，父效果是发起它的那个', function ()
    local game, players = newGame(2)

    ---@type Ask?
    local asked = nil
    game.answerer = function (ask)
        asked = ask
        return true
    end

    game.events:on('伤害-前', function ()
        game:ask(players[2], { name = '闪' })
    end)

    game:damage(players[1], players[2], 1)

    local ask = assert(asked, '回答者没被问到')
    lt.assertEquals('种类标识', 'ask', ask.kind)
    lt.assertEquals('答案存在询问上', true, ask.answer)
    lt.assertEquals('被问者', players[2], ask.to)
    lt.assertEquals('问的是什么', '闪', ask.question.name)
    lt.assertEquals('父效果是发起它的那次伤害', 'damage', assert(ask.parent).kind)
end)

lt.test('询问：同一结算里问多次互不串', function ()
    local game, players = newGame(3)
    game.answerer = scripted { '第一次', '第二次' }

    ---@type any[]
    local answers = {}
    game.events:on('伤害-前', function ()
        answers[#answers + 1] = game:ask(players[2], '问一次')
        answers[#answers + 1] = game:ask(players[3], '再问一次')
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('两次各拿各的', '第一次,第二次', table.concat(answers, ','))
end)

lt.test('询问：没有回答者时明确失败', function ()
    local game, players = newGame(2)

    lt.assertError('问不了', function ()
        game:ask(players[2], { name = '闪' })
    end)
end)

lt.test('询问：回答者拿不出答案时明确失败', function ()
    local game, players = newGame(2)
    game.answerer = function ()
        return nil
    end

    lt.assertError('拿不出答案', function ()
        game:ask(players[2], { name = '闪' })
    end)
end)

lt.test('询问：被取消的询问以「没有答案」结束，结算其余部分照常', function ()
    local game, players = newGame(2)
    game.answerer = scripted { '不该被问到' }

    ---@type string[]
    local trace = {}
    game.events:on('即将生效', function (ctx)
        ---@cast ctx Ask
        if ctx.kind == 'ask' then
            ctx:remove()
        end
    end)
    game.events:on('伤害-前', function ()
        trace[#trace + 1] = '前'
        local answer = game:ask(players[2], { name = '闪' })
        trace[#trace + 1] = '答案 {}' % { tostring(answer) }
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('询问没答上，伤害照常结算', '前,答案 nil', table.concat(trace, ','))
    lt.assertEquals('目标掉了血', 3, players[2]:getAttr('体力'))
end)

lt.test('打出：把牌取出、触发收尾时机，且不产生牌自身的效果', function ()
    local game, players = newGame(2)
    local hand = assert(players[1]:getZone('手牌'))
    local jink = game:createCard('闪')
    hand:put(jink)

    ---@type string[]
    local trace = {}
    game.events:on('卡牌-打出后', function (ctx)
        trace[#trace + 1] = '{} {}' % { ctx.player == players[1], ctx.card == jink }
    end)
    game.events:on('卡牌-结算后', function ()
        trace[#trace + 1] = '不该有用牌结算'
    end)

    game:respond(players[1], jink)

    lt.assertEquals('收尾时机拿到打出的牌', 'true true', table.concat(trace, ','))
    lt.assertEquals('牌离开了手牌', 0, hand:count())
end)

lt.test('打出：牌不在手上时明确失败', function ()
    local game, players = newGame(2)
    local jink = game:createCard('闪')

    lt.assertError('手上没有这张牌', function ()
        game:respond(players[1], jink)
    end)
end)
