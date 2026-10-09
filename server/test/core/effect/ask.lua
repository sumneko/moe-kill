local lt = require 'test.ltest'

---@param count integer
---@return Game
---@return Player[] # 按座位号升序
local function newGame(count)
    local random = moe.random.create(1)
    local game   = moe.game.create {
        seats   = count,
        random  = random,
        sources = { lt.cardSource },
    }
    local desk   = game.desk
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
        players[i] = player
    end
    return game, players
end

lt.test('决策询问：一次往返', function ()
    local game, players = newGame(2)
    local hand = players[1]:getZone('手牌')
    local card = game:createCard('杀')
    hand:accept(card)

    ---@type Ask?
    local asked = nil
    game:on('决策-询问', function (ask)
        ---@cast ask Ask
        asked = ask
        return { card = card, targets = {} }
    end)

    local ask = game:ask(players[1], '出牌', { hand = { card } })

    lt.assertEquals('种类标识', 'ask', ask.kind)
    lt.assertEquals('被问者', players[1], ask.to)
    lt.assertEquals('缘由', '出牌', ask.reason)
    local fromAnswerer = assert(asked, '应答方没被问到')
    lt.assertEquals('应答方拿到的就是这一条询问', ask, fromAnswerer)
    lt.assertEquals('问题原样带到应答方', card, fromAnswerer.question.hand[1])
    lt.assertEquals('答复成为结果', card, ask.reply.card)
end)

lt.test('决策询问：第一个表态的胜出，后面的订阅者不再调', function ()
    local game, players = newGame(1)
    local ask = moe.ask.create {
        game     = game,
        to       = players[1],
        reason   = '测试',
        question = {},
    }

    game:on('决策-询问', function (payload)
        ---@cast payload Ask
        return '正经答复'
    end)
    game:on('决策-询问', function ()
        error('后面的订阅者不该被调', 2)
    end)
    lt.clearErrors()

    ask:apply():await()

    lt.assertEquals('先表态的算数', '正经答复', ask.reply)
    lt.assertEquals('后面的订阅者没被调', 0, #lt.errors)
end)

lt.test('决策询问：没人应答 = 取消（记成失败）', function ()
    local game, players = newGame(2)
    lt.clearErrors()

    local ask = game:ask(players[1], '出牌', { hand = {} })

    lt.assertEquals('答复为空', nil, ask.reply)
    lt.assertEquals('取消记在 .err 上', '取消', ask.err)
    lt.assertEquals('也没成立', false, ask.success)
    lt.assertEquals('取消不是故障，不进错误处理器', 0, #lt.errors)
end)

lt.test('决策询问：有答复才触发「决策-答复」', function ()
    local game, players = newGame(2)
    local fired = 0

    game:on('决策-答复', function (ask)
        fired = fired + 1
        lt.assertEquals('时机里读得到答复', true, ask.reply ~= nil)
    end)

    game:ask(players[1], '出牌', {})
    lt.assertEquals('没答上时不触发', 0, fired)

    game:on('决策-询问', function (ask)
        return '出牌'
    end)
    local ask = game:ask(players[1], '出牌', {})
    lt.assertEquals('有答复就触发一次', 1, fired)
    lt.assertEquals('答复挂在询问上', '出牌', ask.reply)
end)

lt.test('决策询问：第一个返回答复的胜出，后面的订阅者不再调', function ()
    local game, players = newGame(2)

    game:on('决策-询问', function (ask)
        return '第一次'
    end)
    game:on('决策-询问', function ()
        error('后面的订阅者不该被调', 2)
    end)
    lt.clearErrors()

    local ask = game:ask(players[1], '出牌', {})
    lt.assertEquals('结果仍是第一次给的', '第一次', ask.reply)
    lt.assertEquals('后面的订阅者没被调', 0, #lt.errors)
end)

lt.test('决策询问：自己不动任何状态', function ()
    local game, players = newGame(2)
    local hand = players[1]:getZone('手牌')
    local card = game:createCard('杀')
    hand:accept(card)

    game:on('决策-询问', function (ask)
        ---@cast ask Ask
        return { cards = { card } }
    end)

    local ask = game:ask(players[1], '弃牌', {})
    lt.assertEquals('牌还在原处', 1, hand:count())
    lt.assertEquals('答复原样交给发起方', card, ask.reply.cards[1])
end)

lt.test('决策询问：被阻止 ⇒ 没有答复', function ()
    local game, players = newGame(2)
    local fired = 0

    game:on('决策-答复', function ()
        fired = fired + 1
    end)
    game:on('效果-能否生效', function (effect)
        if effect.kind == 'ask' then
            return '不让这次询问生效'
        end
    end)

    local ask = game:ask(players[1], '出牌', {})

    lt.assertEquals('没有答复', nil, ask.reply)
    lt.assertEquals('原因记在 err 上', '不让这次询问生效', ask.err)
    lt.assertEquals('被阻止不触发答复时机', 0, fired)
end)
