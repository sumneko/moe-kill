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

lt.test('询问：一次往返（候选名单摆在询问上）', function ()
    local game, players = newGame(3)
    local candidates    = { players[2], players[3] }

    ---@type AskPlayer?
    local asked = nil
    game:on('决策-询问', function (ask)
        ---@cast ask AskPlayer
        asked = ask
        ask:answer(players[3])
    end)

    local ask = game:askPlayer(players[1], '测试', { players = candidates })

    lt.assertEquals('种类标识', 'askPlayer', ask.kind)
    lt.assertEquals('被问者', players[1], ask.to)
    lt.assertEquals('缘由', '测试', ask.reason)
    local fromAnswerer = assert(asked, '应答方没被问到')
    lt.assertEquals('应答方拿到的就是这一条询问', ask, fromAnswerer)
    lt.assertEquals('候选名单挂在询问上', candidates, fromAnswerer.options)
    lt.assertEquals('答复成为结果', players[3], ask.player)
end)

lt.test('询问：答复不在候选里 ⇒ 拒收，原因记在 `.err`', function ()
    local game, players = newGame(3)

    game:on('决策-询问', function (ask)
        ---@cast ask AskPlayer
        ask:answer(players[3]) -- 候选里只有 2 号位
    end)

    local ask = game:askPlayer(players[1], '测试', { players = { players[2] } })

    lt.assertEquals('没拿到答复', nil, ask.player)
    lt.assertEquals('原因是「不在可选角色里」', '答复不在可选角色里', ask.err)
    lt.assertEquals('候选里就那一个', 1, #assert(ask.options))
end)

lt.test('询问：没人应答时没有答复，也不算失败', function ()
    local game, players = newGame(3)
    lt.clearErrors()

    local ask = game:askPlayer(players[1], '测试', { players = { players[2] } })

    lt.assertEquals('没有答复', nil, ask.player)
    lt.assertEquals('不算失败', nil, ask.err)
    lt.assertEquals('没有记下错误', 0, #lt.errors)
end)

lt.test('询问：不给条件就不做限制', function ()
    local game, players = newGame(3)

    game:on('决策-询问', function (ask)
        ---@cast ask AskPlayer
        ask:answer(players[3])
    end)

    local ask = game:askPlayer(players[1], '测试', nil)

    lt.assertEquals('照样收下答复', players[3], ask.player)
    lt.assertEquals('没有候选名单', nil, ask.options)
    lt.assertEquals('不算失败', nil, ask.err)
end)

lt.test('询问：重复应答不报错，先答的算数', function ()
    local game, players = newGame(3)

    game:on('决策-询问', function (ask)
        ---@cast ask AskPlayer
        ask:answer(players[2])
        ask:answer(players[3])
    end)
    lt.clearErrors()

    local ask = game:askPlayer(players[1], '测试', { players = { players[2], players[3] } })

    lt.assertEquals('先答的算数', players[2], ask.player)
    lt.assertEquals('不算失败', nil, ask.err)
    lt.assertEquals('没有记下错误', 0, #lt.errors)
end)

---@async
lt.test('询问：应答方可以让出，稍后再答复', function ()
    local game, players = newGame(3)

    game:on('决策-询问', function (ask)
        ---@cast ask AskPlayer
        moe.await.sleep(0)
        ask:answer(players[3])
    end)

    lt.assertEquals('答复照旧拿到', players[3],
        game:askPlayer(players[1], '测试', { players = { players[3] } }).player)
end)

lt.test('询问：被问者与父效果挂在询问上', function ()
    local game, players = newGame(3)

    ---@type AskPlayer?
    local asked = nil
    game:on('决策-询问', function (ask)
        ---@cast ask AskPlayer
        asked = ask
        ask:answer(players[2])
    end)

    game:on('伤害-前', function ()
        game:askPlayer(players[1], '测试', { players = { players[2] } })
    end)

    game:damage(players[1], players[3], 1)

    local ask = assert(asked, '应答方没被问到')
    lt.assertEquals('被问者', players[1], ask.to)
    lt.assertEquals('答复里有角色', players[2], ask.player)
    lt.assertEquals('父效果是发起它的那次伤害', 'damage', assert(ask.parent).kind)
end)

lt.test('询问：被阻止的询问以「没有答复」结束，结算其余部分照常', function ()
    local game, players = newGame(3)

    game:on('效果-能否生效', function (effect)
        if effect.kind == 'askPlayer' then
            return '不让这次询问生效'
        end
    end)
    game:on('决策-询问', function (ask)
        ---@cast ask AskPlayer
        ask:answer(players[2])
    end)

    local ask = game:askPlayer(players[1], '测试', { players = { players[2] } })

    lt.assertEquals('没有答复', nil, ask.player)
    lt.assertEquals('原因是那条阻止', '不让这次询问生效', ask.err)
end)

lt.test('答复：有答复才触发答复时机，上下文是这次询问', function ()
    local game, players = newGame(3)

    ---@type AskPlayer[]
    local seen = {}
    game:on('决策-答复', function (ask)
        ---@cast ask AskPlayer
        seen[#seen + 1] = ask
    end)

    game:askPlayer(players[1], '测试', { players = { players[2] } })
    lt.assertEquals('没人应答就不触发', 0, #seen)

    game:on('决策-询问', function (ask)
        ---@cast ask AskPlayer
        ask:answer(players[2])
    end)
    local answered = game:askPlayer(players[1], '测试', { players = { players[2] } })
    lt.assertEquals('有人应答触发了一次', 1, #seen)
    lt.assertEquals('上下文就是这次询问', answered, seen[1])
    lt.assertEquals('答复时机里结果已经定下', players[2], seen[1].player)
end)
