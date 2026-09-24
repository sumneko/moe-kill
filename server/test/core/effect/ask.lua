local lt = require 'test.ltest'

---@param count integer
---@return Game
---@return Player[] # 按座位号升序
local function newGame(count)
    local random = moe.random.create(1)
    local game   = moe.game.create { seats = count, random = random }
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
    hand:put(card)

    ---@type Ask?
    local asked = nil
    game:on('决策-询问', function (ask)
        ---@cast ask Ask
        asked = ask
        ask:answer { card = card, targets = {} }
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

lt.test('决策询问：没人应答不算失败', function ()
    local game, players = newGame(2)

    local ask = game:ask(players[1], '出牌', { hand = {} })

    lt.assertEquals('答复为空', nil, ask.reply)
    lt.assertEquals('不算失败', nil, ask.err)
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
        ask:answer('出牌')
    end)
    local ask = game:ask(players[1], '出牌', {})
    lt.assertEquals('有答复就触发一次', 1, fired)
    lt.assertEquals('答复挂在询问上', '出牌', ask.reply)
end)

lt.test('决策询问：重复应答先给出的算数', function ()
    local game, players = newGame(2)

    game:on('决策-询问', function (ask)
        ask:answer('第一次')
        ask:answer('第二次')
    end)

    local ask = game:ask(players[1], '出牌', {})
    lt.assertEquals('结果仍是第一次给的', '第一次', ask.reply)
end)

lt.test('决策询问：自己不动任何状态', function ()
    local game, players = newGame(2)
    local hand = players[1]:getZone('手牌')
    local card = game:createCard('杀')
    hand:put(card)

    game:on('决策-询问', function (ask)
        ---@cast ask Ask
        ask:answer { cards = { card } }
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
