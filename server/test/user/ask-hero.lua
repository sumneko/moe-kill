local lt      = require 'test.ltest'
local support = require 'test.user.support'

--- 替「他」答应答（注册一次，返回撤销函数；收尾写 `local _ <close> = reply(...)` 就行）
---@param answer fun(params: Proto.Request.Ask.Hero): Proto.Result.Ask.Hero?
---@return fun()
local function reply(answer)
    return moe.client.register('Ask.Hero', function (_, params)
        ---@cast params Proto.Request.Ask.Hero
        return answer(params)
    end)
end

---@async
lt.test('询问：要武将时问客户端，回包的名字转回 HeroDef', function ()
    local game, players = support.newPackageGame()
    local me = assert(players[1])

    local all = game:getHeroes()
    local first, second = assert(all[1]), assert(all[2])

    ---@type Proto.Request.Ask.Hero?
    local sent = nil
    local _ <close> = reply(function (params)
        sent = params
        return { heroes = { second.fullName } }
    end)

    local ask = moe.askHero.create {
        game      = game,
        to        = me,
        reason    = '选将',
        condition = { hero = { first, second } },
    }
    ask:apply():await()

    local params = assert(sent, '没问过客户端')
    lt.assertEquals('缘由原样带过去', '选将', params.reason)
    local names = assert(params.heroes, '该带上候选名单')
    lt.assertEquals('候选就两名', 2, #names)
    lt.assertEquals('第一个是他（全名）', first.fullName, names[1])
    lt.assertEquals('第二个也是（全名）', second.fullName, names[2])
    lt.assertEquals('个数区间带上了', 1, params.min)
    lt.assertEquals('区间上限同默认', 1, params.max)
    lt.assertEquals('可取消的请求带着号', true, params.cancelToken ~= nil)
    lt.assertEquals('这次成了', true, ask.success)
    lt.assertEquals('答复是它', second, ask.hero)
end)

---@async
lt.test('询问：不给条件就不列候选（名单缺省）', function ()
    local game, players = support.newPackageGame()
    local me = assert(players[1])

    local hero = assert(game:getHeroes()[1])
    ---@type Proto.Request.Ask.Hero?
    local sent = nil
    local _ <close> = reply(function (params)
        sent = params
        return { heroes = { hero.fullName } }
    end)

    local ask = moe.askHero.create {
        game   = game,
        to     = me,
        reason = '随便挑',
    }
    ask:apply():await()

    lt.assertEquals('没带候选名单', nil, assert(sent).heroes)
    lt.assertEquals('这次成了', true, ask.success)
    lt.assertEquals('答复是它', hero, ask.hero)
end)

---@async
lt.test('询问：武将名不认 ⇒ 这次不算成立', function ()
    local game, players = support.newPackageGame()
    local me = assert(players[1])

    local _ <close> = reply(function ()
        return { heroes = { '查无此人' } }
    end)

    local ask = moe.askHero.create {
        game      = game,
        to        = me,
        reason    = '选将',
        condition = { hero = { assert(game:getHeroes()[1]) } },
    }
    ask:apply():await()

    lt.assertEquals('这次没成', false, ask.success)
    lt.assertEquals('没选到武将', nil, ask.hero)
end)
