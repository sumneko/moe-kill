local lt = require 'test.ltest'

--- 造一对对接好、都起了读循环的客户端
---@return Client # 前端侧
---@return Client # 后端侧
local function connect()
    local a, b = moe.link.pair()
    local front = moe.client.create(a)
    local back  = moe.client.create(b)
    front:start()
    back:start()
    return front, back
end

--- 搭一个两人局：每人坐好、都接了客户端并接入下行
---@return Game
---@return Player[]
---@return Client[] # 后端侧（前端那半由用例自己收／答）
local function newGame()
    local game = moe.game.create {
        seats   = 2,
        random  = moe.random.create(1),
        sources = { lt.cardSource },
    }
    ---@type Player[]
    local players = {}
    ---@type Client[]
    local backs = {}
    for i = 1, 2 do
        local player = moe.player.create(game, { attributes = game:getAttributeSystem():createInstance() })
        local _, back = connect()
        game.desk:sit(i, player)
        player:setUser(New 'ClientUser' (game, back))
        assert(player.user):attach()
        players[i] = player
        backs[i]   = back
    end
    return game, players, backs
end

--- 替「他」答应答（注册一次，返回撤销函数）
---@param answer fun(params: Proto.Request.Ask.Player): Proto.Result.Ask.Player?
---@return fun()
local function reply(answer)
    return moe.client.register('Ask.Player', function (_, params)
        ---@cast params Proto.Request.Ask.Player
        return answer(params)
    end)
end

---@async
lt.test('询问：要角色时问客户端，回包的 id 转回 Player', function ()
    local game, players = newGame()
    local me  = assert(players[1])
    local you = assert(players[2])

    local undo = reply(function (params)
        lt.assertEquals('缘由原样带过去', '突袭', params.reason)
        lt.assertEquals('候选就一个', 1, #params.players)
        lt.assertEquals('候选是他', you.id, params.players[1])
        lt.assertEquals('个数区间带上了', 1, params.min)
        lt.assertEquals('区间上限同默认', 1, params.max)
        lt.assertEquals('可取消请求要有号', true, params.cancelid ~= nil)
        return { players = { you.id } }
    end)

    local ask = moe.askPlayer.create {
        game      = game,
        to        = me,
        reason    = '突袭',
        condition = { player = you },
    }
    ask:apply():await()

    lt.assertEquals('这次成了', true, ask.success)
    lt.assertEquals('答复是他', you, ask.player)
    undo()
end)

---@async
lt.test('询问：不限候选时把存活角色都列出来', function ()
    local game, players = newGame()
    local me = assert(players[1])

    local seen = 0
    local undo = reply(function (params)
        seen = #params.players
        return { players = {} }
    end)

    local ask = moe.askPlayer.create {
        game   = game,
        to     = me,
        reason = '随便挑',
        condition = { min = 0, max = 1 },
    }
    ask:apply():await()

    lt.assertEquals('存活的两个都列出来了', 2, seen)
    lt.assertEquals('一个都不选也是合法答复', true, ask.success)
    lt.assertEquals('没选人', nil, ask.player)
    undo()
end)

---@async
lt.test('询问：回包里的 id 不认就得报错（原因只进日志）', function ()
    local game, players = newGame()
    local me = assert(players[1])

    local undo = reply(function ()
        return { players = { 9999 } }
    end)

    local ask = moe.askPlayer.create {
        game   = game,
        to     = me,
        reason = '乱答',
        condition = { min = 0, max = 1 },
    }
    ask:apply():await()

    lt.assertEquals('这次没成', false, ask.success)
    lt.assertEquals('原因里说清楚了', true, tostring(ask.err):match('不在这一局里') ~= nil)
    undo()
end)
