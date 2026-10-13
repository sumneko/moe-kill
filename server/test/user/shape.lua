local lt      = require 'test.ltest'
local support = require 'test.user.support'

---@async
lt.test('形状：请求参数不合 ⇒ 回「参数不对」，不进错误处理器', function ()
    local game, players, fronts = support.newPackageGame()
    local front = assert(fronts[1])

    -- 类型不对：`id` 照 proto 声明该是整数
    local result, err = front:request('Skill.ChangeAuto', { id = '甲', auto = true }):await()
    lt.assertEquals('没有结果', nil, result)
    lt.assertEquals('错误码说清是参数问题', moe.jsonrpc.INVALID_PARAMS, assert(err).code)
    lt.assertEquals('错在哪说清楚', '「id」应该是 integer（现在是 string）', err.message)

    -- 无参的方法多给字段也算不合
    local snap
    snap, err = front:request('Game.SnapShot', { extra = 1 }):await()
    lt.assertEquals('无参方法也没结果', nil, snap)
    lt.assertEquals('多了字段', '「extra」多了个字段', assert(err).message)
end)

---@async
lt.test('形状：回包该是数组却给了数字 ⇒ 当没答上（从前会抛）', function ()
    local game, players = support.newGame()
    local me = assert(players[1])

    local _ <close> = moe.client.register('Ask.Select', function ()
        return { player = 5 }
    end)

    local ask = moe.askPlayer.create {
        game      = game,
        to        = me,
        reason    = '乱答',
        condition = { min = 0, max = 1 },
    }
    ask:apply():await()

    lt.assertEquals('当成没答上', true, ask.success)
    lt.assertEquals('没有答复', nil, ask.player)
end)

---@async
lt.test('形状：回包数组里元素类型不对 ⇒ 整份作废', function ()
    local game, players = support.newGame()
    local me = assert(players[1])

    local _ <close> = moe.client.register('Ask.Select', function ()
        return { player = { '甲' } }
    end)

    local ask = moe.askPlayer.create {
        game      = game,
        to        = me,
        reason    = '乱答',
        condition = { min = 0, max = 1 },
    }
    ask:apply():await()

    lt.assertEquals('当成没答上', true, ask.success)
    lt.assertEquals('没有答复', nil, ask.player)
end)

---@async
lt.test('形状：回包多给了（超量）⇒ 内核拒收，原因说清', function ()
    local game, players = support.newGame()
    local me  = assert(players[1])
    local you = assert(players[2])

    local _ <close> = moe.client.register('Ask.Select', function ()
        return { player = { you.id, you.id, you.id } }
    end)

    local ask = moe.askPlayer.create {
        game      = game,
        to        = me,
        reason    = '乱答',
        condition = { min = 0, max = 1 },
    }
    ask:apply():await()

    lt.assertEquals('这次没成', false, ask.success)
    lt.assertEquals('原因里说清了', true, tostring(ask.err):match('至多') ~= nil)
end)

---@async
lt.test('形状：声明里没有的方法 ⇒ 不校验（不归协议管）', function ()
    local game, players, fronts = support.newPackageGame()
    local front = assert(fronts[1])

    local _ <close> = moe.client.register('测试/不管形状', function ()
        return { ok = true }
    end)

    local result, err = front:request('测试/不管形状', { 随便 = '什么' }):await()
    lt.assertEquals('照常回结果', true, assert(result).ok)
    lt.assertEquals('没被挡下', nil, err)
end)
