local lt = require 'test.ltest'

---@param count integer
---@return Game
---@return Player[] # 按座位号升序
local function newGame(count)
    local random = moe.random.create(1)
    local game   = moe.game.create { seats = count, random = random, sources = { lt.emptySource } }
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
        return players[3]
    end)

    local ask = game:askPlayer(players[1], '测试', { player = candidates })

    lt.assertEquals('种类标识', 'askPlayer', ask.kind)
    lt.assertEquals('被问者', players[1], ask.to)
    lt.assertEquals('缘由', '测试', ask.reason)
    local fromAnswerer = assert(asked, '应答方没被问到')
    lt.assertEquals('应答方拿到的就是这一条询问', ask, fromAnswerer)
    lt.assertEquals('候选名单挂在询问上', candidates, fromAnswerer.options)
    lt.assertEquals('答复成为结果', players[3], ask.player)
end)

lt.test('询问：第一个表态的胜出，后面的订阅者不再调', function ()
    local game, players = newGame(3)
    local ask = moe.askPlayer.create {
        game      = game,
        to        = players[1],
        reason    = '测试',
        condition = { player = { players[2], players[3] } },
    }

    game:on('决策-询问', function (payload)
        ---@cast payload AskPlayer
        return players[3]
    end)
    game:on('决策-询问', function ()
        error('后面的订阅者不该被调', 2)
    end)
    lt.clearErrors()

    ask:apply():await()

    lt.assertEquals('先表态的算数', players[3], ask.player)
    lt.assertEquals('后面的订阅者没被调', 0, #lt.errors)
end)

lt.test('询问：答复不在候选里 ⇒ 拒收，原因记在 `.err`', function ()
    local game, players = newGame(3)

    game:on('决策-询问', function (ask)
        ---@cast ask AskPlayer
        return players[3] -- 候选里只有 2 号位
    end)

    local ask = game:askPlayer(players[1], '测试', { player = { players[2] } })

    lt.assertEquals('没拿到答复', nil, ask.player)
    lt.assertEquals('原因是「不在可选项里」（文案与别的询问统一）', '答复的目标不在可选项里', ask.err)
    lt.assertEquals('候选里就那一个', 1, #assert(ask.options))
end)

lt.test('询问：没人应答时没有答复，也不算失败', function ()
    local game, players = newGame(3)
    lt.clearErrors()

    local ask = game:askPlayer(players[1], '测试', { player = { players[2] } })

    lt.assertEquals('没有答复', nil, ask.player)
    lt.assertEquals('不算失败', nil, ask.err)
    lt.assertEquals('没有记下错误', 0, #lt.errors)
end)

lt.test('询问：不给条件就不做限制', function ()
    local game, players = newGame(3)

    game:on('决策-询问', function (ask)
        ---@cast ask AskPlayer
        return players[3]
    end)

    local ask = game:askPlayer(players[1], '测试', nil)

    lt.assertEquals('照样收下答复', players[3], ask.player)
    lt.assertEquals('没有候选名单', nil, ask.options)
    lt.assertEquals('不算失败', nil, ask.err)
end)

lt.test('询问：min / max 摆好个数区间，一次可以选好几名', function ()
    local game, players = newGame(4)
    local candidates = { players[2], players[3], players[4] }

    game:on('决策-询问', function (ask)
        ---@cast ask AskPlayer
        return { players[3], players[4] }
    end)

    local ask = game:askPlayer(players[1], '测试', { player = candidates, min = 1, max = 2 })

    lt.assertEquals('两名都收下（列表）', 2, #ask.players)
    lt.assertEquals('列表里就是那两名', players[3], ask.players[1])
    lt.assertEquals('第一个读法照旧', players[3], ask.player)
    lt.assertEquals('不算失败', nil, ask.err)
end)

lt.test('询问：min 给 0 就能一个都不选（没答复也是空表）', function ()
    local game, players = newGame(3)
    lt.clearErrors()

    local ask = game:askPlayer(players[1], '测试', {
        player = { players[2], players[3] },
        min    = 0,
        max    = 2,
    })

    lt.assertEquals('空表', 0, #ask.players)
    lt.assertEquals('第一个是空', nil, ask.player)
    lt.assertEquals('不算失败', nil, ask.err)
    lt.assertEquals('没记下错误', 0, #lt.errors)
end)

lt.test('询问：答复超上限 / 重复都拒收', function ()
    local game, players = newGame(4)
    local candidates = { players[2], players[3], players[4] }

    ---@type Player[]
    local answer = { players[2], players[3], players[4] }
    game:on('决策-询问', function (ask)
        ---@cast ask AskPlayer
        return answer
    end)

    local tooMany = game:askPlayer(players[1], '测试', { player = candidates, min = 1, max = 2 })
    lt.assertEquals('超过上限就没收下', 0, #tooMany.players)
    lt.assertEquals('原因是「至多指定 2 个目标」', '至多指定 2 个目标', tooMany.err)

    answer = { players[3], players[3] }
    local repeated = game:askPlayer(players[1], '测试', { player = candidates, min = 1, max = 3 })
    lt.assertEquals('重复的没收下', 0, #repeated.players)
    lt.assertEquals('原因是「答复的目标重复了」', '答复的目标重复了', repeated.err)
end)

lt.test('询问：默认正好一名（给两名就拒收）', function ()
    local game, players = newGame(3)

    game:on('决策-询问', function (ask)
        ---@cast ask AskPlayer
        return { players[2], players[3] }
    end)

    local ask = game:askPlayer(players[1], '测试', { player = { players[2], players[3] } })

    lt.assertEquals('没拿到答复', nil, ask.player)
    lt.assertEquals('原因是「至多指定 1 个目标」', '至多指定 1 个目标', ask.err)
end)

lt.test('询问：max 省略就取 min（min 给 0 时连一个都不能给）', function ()
    local game, players = newGame(3)

    game:on('决策-询问', function (ask)
        ---@cast ask AskPlayer
        return players[2]
    end)

    local ask = game:askPlayer(players[1], '测试', { player = { players[2], players[3] }, min = 0 })

    lt.assertEquals('给了一名反而超了', nil, ask.player)
    lt.assertEquals('原因是「至多指定 0 个目标」', '至多指定 0 个目标', ask.err)
end)

lt.test('询问：第一个返回答复的胜出，后面的订阅者不再调', function ()
    local game, players = newGame(3)

    game:on('决策-询问', function (ask)
        ---@cast ask AskPlayer
        return players[2]
    end)
    game:on('决策-询问', function ()
        error('后面的订阅者不该被调', 2)
    end)
    lt.clearErrors()

    local ask = game:askPlayer(players[1], '测试', { player = { players[2], players[3] } })

    lt.assertEquals('先答的算数', players[2], ask.player)
    lt.assertEquals('后面的订阅者没被调', 0, #lt.errors)
end)

---@async
lt.test('询问：应答方可以让出，稍后再答复', function ()
    local game, players = newGame(3)

    game:on('决策-询问', function (ask)
        ---@cast ask AskPlayer
        moe.await.sleep(0)
        return players[3]
    end)

    lt.assertEquals('答复照旧拿到', players[3],
        game:askPlayer(players[1], '测试', { player = { players[3] } }).player)
end)

lt.test('询问：被问者与父效果挂在询问上', function ()
    local game, players = newGame(3)

    ---@type AskPlayer?
    local asked = nil
    game:on('决策-询问', function (ask)
        ---@cast ask AskPlayer
        asked = ask
        return players[2]
    end)

    game:on('效果-能否生效', function (effect)
        if effect.kind == 'damage' then
            game:askPlayer(players[1], '测试', { player = { players[2] } })
        end
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
        return players[2]
    end)

    local ask = game:askPlayer(players[1], '测试', { player = { players[2] } })

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

    game:askPlayer(players[1], '测试', { player = { players[2] } })
    lt.assertEquals('没人应答就不触发', 0, #seen)

    game:on('决策-询问', function (ask)
        ---@cast ask AskPlayer
        return players[2]
    end)
    local answered = game:askPlayer(players[1], '测试', { player = { players[2] } })
    lt.assertEquals('有人应答触发了一次', 1, #seen)
    lt.assertEquals('上下文就是这次询问', answered, seen[1])
    lt.assertEquals('答复时机里结果已经定下', players[2], seen[1].player)
end)

lt.test('询问：条件给 true 就是不做限制', function ()
    local game, players = newGame(3)

    game:on('决策-询问', function (ask)
        ---@cast ask AskPlayer
        return players[3]
    end)

    local ask = game:askPlayer(players[1], '测试', { player = true })

    lt.assertEquals('没有候选名单（= 不限）', nil, ask.options)
    lt.assertEquals('照样收下答复', players[3], ask.player)
    lt.assertEquals('不算失败', nil, ask.err)
end)

lt.test('询问：条件给谓词就在存活角色里筛候选', function ()
    local game, players = newGame(3)

    ---@type Player[]?
    local options = nil
    game:on('决策-询问', function (ask)
        ---@cast ask AskPlayer
        options = ask.options
        return players[3]
    end)

    local ask = game:askPlayer(players[1], '测试', {
        player = function (player)
            return player ~= players[1]
        end,
    })

    local list = assert(options, '应答方没拿到候选')
    lt.assertEquals('存活角色里筛出两名', 2, #list)
    lt.assertEquals('第一候选是 2 号位', players[2], list[1])
    lt.assertEquals('名单外的答复照旧拒收', players[3], ask.player)
end)
