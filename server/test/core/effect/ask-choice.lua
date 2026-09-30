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
        player:setAttr('体力', 4)
        players[i] = player
    end
    return game, players
end

lt.test('询问：一次往返（选项摆在询问上，读 `.choice`）', function ()
    local game, players = newGame(3)
    local options = { '甲', '乙', '丙' }

    ---@type AskChoice?
    local asked = nil
    game:on('决策-询问', function (ask)
        ---@cast ask AskChoice
        asked = ask
        return '乙'
    end)

    local ask = game:askChoice(players[1], '测试', options)

    lt.assertEquals('种类标识', 'askChoice', ask.kind)
    lt.assertEquals('被问者', players[1], ask.to)
    lt.assertEquals('缘由', '测试', ask.reason)
    local fromAnswerer = assert(asked, '应答方没被问到')
    lt.assertEquals('应答方拿到的就是这一条询问', ask, fromAnswerer)
    lt.assertEquals('选项原样挂在询问上', options, fromAnswerer.options)
    lt.assertEquals('答复成为结果', '乙', ask.choice)
end)

lt.test('询问：第一个表态的胜出，后面的订阅者不再调', function ()
    local game, players = newGame(2)
    local ask = moe.askChoice.create {
        game    = game,
        to      = players[1],
        reason  = '测试',
        options = { '甲', '乙' },
    }

    game:on('决策-询问', function (payload)
        ---@cast payload AskChoice
        return '乙'
    end)
    game:on('决策-询问', function ()
        error('后面的订阅者不该被调', 2)
    end)
    lt.clearErrors()

    ask:apply():await()

    lt.assertEquals('先表态的算数', '乙', ask.choice)
    lt.assertEquals('后面的订阅者没被调', 0, #lt.errors)
end)

lt.test('询问：答复不在选项里 ⇒ 拒收，原因记在 `.err`', function ()
    local game, players = newGame(2)

    game:on('决策-询问', function (ask)
        ---@cast ask AskChoice
        return '丁' -- 选项里没有这个
    end)

    local ask = game:askChoice(players[1], '测试', { '甲', '乙' })

    lt.assertEquals('没拿到答复', nil, ask.choice)
    lt.assertEquals('原因是「不在可选项里」', '答复不在可选项里', ask.err)
    lt.assertEquals('选项就是那两个', 2, #ask.options)
end)

lt.test('询问：没人应答时没有选择，也不算失败', function ()
    local game, players = newGame(2)
    lt.clearErrors()

    local ask = game:askChoice(players[1], '测试', { '甲', '乙' })

    lt.assertEquals('没有选择', nil, ask.choice)
    lt.assertEquals('不算失败', nil, ask.err)
    lt.assertEquals('没有记下错误', 0, #lt.errors)
end)

lt.test('询问：答复 nil 等同没答（取消不算失败）', function ()
    local game, players = newGame(2)
    lt.clearErrors()

    game:on('决策-询问', function (ask)
        ---@cast ask AskChoice
        return nil
    end)

    local ask = game:askChoice(players[1], '测试', { '发动' })

    lt.assertEquals('取消 ⇒ 没有选择', nil, ask.choice)
    lt.assertEquals('不算失败', nil, ask.err)
    lt.assertEquals('没有记下错误', 0, #lt.errors)
end)

lt.test('询问：第一个返回答复的胜出，后面的订阅者不再调', function ()
    local game, players = newGame(2)

    game:on('决策-询问', function (ask)
        ---@cast ask AskChoice
        return '甲'
    end)
    game:on('决策-询问', function ()
        error('后面的订阅者不该被调', 2)
    end)
    lt.clearErrors()

    local ask = game:askChoice(players[1], '测试', { '甲', '乙' })

    lt.assertEquals('先答的算数', '甲', ask.choice)
    lt.assertEquals('后面的订阅者没被调', 0, #lt.errors)
end)
