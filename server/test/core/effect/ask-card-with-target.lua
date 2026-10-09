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
    local desk = game.desk
    ---@type Player[]
    local players = {}
    for i = 1, count do
        local player = moe.player.create(game, { attributes = game:getAttributeSystem():createInstance() })
        desk:sit(i, player)
        players[i] = player
    end
    return game, players
end

---@param player Player
---@param cards Card[]
local function putInHand(player, cards)
    assert(player:getZone('手牌')):accept(cards)
end

lt.test('给出：一次往返（答复 = 牌 + 目标，候选与区间摆在条件里）', function ()
    local game, players = newGame(3)
    local slash = game:createCard('杀')
    local jink  = game:createCard('闪')
    putInHand(players[1], { slash, jink })

    ---@type AskCardWithTarget?
    local asked = nil
    game:on('卡牌-询问', function (ask)
        ---@cast ask AskCardWithTarget
        asked = ask
        return { card = { slash, jink }, targets = players[2] }
    end)

    local ask = game:askCardWithTarget(players[1], '测试', {
        card = {
            zone = '手牌',
            min  = 1,
            max  = 2,
        },
        target = {
            player = { players[2], players[3] },
        },
    })

    lt.assertEquals('种类标识', 'askCardWithTarget', ask.kind)
    lt.assertEquals('被问者', players[1], ask.to)
    lt.assertEquals('缘由', '测试', ask.reason)
    local fromAnswerer = assert(asked, '应答方没被问到')
    lt.assertEquals('应答方拿到的就是这一条询问', ask, fromAnswerer)
    lt.assertEquals('候选名单归一成列表', 2, #assert(assert(ask.targetCondition).players))
    lt.assertEquals('答复里的两张牌都收下', 2, #ask.cards)
    lt.assertEquals('目标读得到（一张列表）', 1, #ask.targets)
    lt.assertEquals('列表里就是那个目标', players[2], ask.targets[1])
    lt.assertEquals('第一个目标读法', players[2], ask.target)
    lt.assertEquals('不算失败', nil, ask.err)
end)

lt.test('给出：条件构造时归一（候选单值 → 列表、个数补默认）', function ()
    local game, players = newGame(3)
    putInHand(players[1], { game:createCard('杀') })

    local ask = game:askCardWithTarget(players[1], '测试', {
        target = { player = players[2] },
    })

    local condition = assert(ask.targetCondition)
    local list      = assert(condition.players)
    lt.assertEquals('单值归一成列表', 1, #list)
    lt.assertEquals('列表里就是他', players[2], list[1])
    lt.assertEquals('默认至少一个目标', 1, condition.min)
    lt.assertEquals('默认至多同最少', 1, condition.max)

    local exact = game:askCardWithTarget(players[1], '测试', { target = { min = 2 } })
    local bare  = assert(exact.targetCondition)
    lt.assertEquals('只写 min ⇒ 上限也是它', '2,2', bare.min .. ',' .. bare.max)

    local many  = game:askCardWithTarget(players[1], '测试', {
        target = { player = { players[2], players[3] }, min = 2, max = 3 },
    })
    local named = assert(many.targetCondition)
    lt.assertEquals('显式区间读得到', '2,3', named.min .. ',' .. named.max)
end)

lt.test('给出：候选写谓词时在存活角色里筛，写 `true` 就是不限制', function ()
    local game, players = newGame(3)
    local slash = game:createCard('杀')
    putInHand(players[1], { slash })
    game:on('卡牌-询问', function ()
        return { card = slash, targets = players[3] }
    end)

    local ask = game:askCardWithTarget(players[1], '测试', {
        target = {
            player = function (player)
                return player ~= players[2]
            end,
        },
    })

    local list = assert(assert(ask.targetCondition).players)
    lt.assertEquals('存活角色里筛出两个', 2, #list)
    lt.assertEquals('2 号位被筛掉', players[1], list[1])
    lt.assertEquals('3 号位留下', players[3], list[2])
    lt.assertEquals('筛出来的名单照样收下答复', players[3], ask.target)

    local loose = game:askCardWithTarget(players[1], '测试', {
        target = { player = true },
    })
    lt.assertEquals('`true` = 不做限制', nil, assert(loose.targetCondition).players)
end)

lt.test('给出：答复不给目标 ⇒ 拒收', function ()
    local game, players = newGame(2)
    local slash = game:createCard('杀')
    putInHand(players[1], { slash })
    game:on('卡牌-询问', function ()
        return { card = slash }
    end)

    local ask = game:askCardWithTarget(players[1], '测试', { card = { zone = '手牌' } })

    lt.assertEquals('没拿到答复', nil, ask.target)
    lt.assertEquals('目标为空表', 0, #ask.targets)
    lt.assertEquals('原因', '这次答复要给出目标', ask.err)
end)

lt.test('给出：目标不在候选里 ⇒ 拒收', function ()
    local game, players = newGame(3)
    local slash = game:createCard('杀')
    putInHand(players[1], { slash })
    game:on('卡牌-询问', function ()
        return { card = slash, targets = players[3] } -- 候选里只有 2 号位
    end)

    local ask = game:askCardWithTarget(players[1], '测试', {
        card   = { zone = '手牌' },
        target = { player = { players[2] } },
    })

    lt.assertEquals('没拿到答复', nil, ask.target)
    lt.assertEquals('原因', '答复的目标不在可选项里', ask.err)
end)

lt.test('给出：目标重复 ⇒ 拒收', function ()
    local game, players = newGame(3)
    local slash = game:createCard('杀')
    putInHand(players[1], { slash })
    game:on('卡牌-询问', function ()
        return { card = slash, targets = { players[2], players[2] } }
    end)

    local ask = game:askCardWithTarget(players[1], '测试', {
        card   = { zone = '手牌' },
        target = { max = 2 },
    })

    lt.assertEquals('没拿到答复', nil, ask.target)
    lt.assertEquals('原因', '答复的目标重复了', ask.err)
end)

lt.test('给出：目标个数不在区间 ⇒ 拒收', function ()
    local game, players = newGame(4)
    local slash = game:createCard('杀')
    putInHand(players[1], { slash })
    game:on('卡牌-询问', function ()
        return { card = slash, targets = { players[2], players[3] } }
    end)

    local tooFew = game:askCardWithTarget(players[1], '测试', {
        card   = { zone = '手牌' },
        target = { min = 3 },
    })
    lt.assertEquals('不够 ⇒ 拒收', '至少要指定 3 个目标', tooFew.err)

    local tooMany = game:askCardWithTarget(players[1], '测试', {
        card   = { zone = '手牌' },
        target = { min = 1 },
    })
    lt.assertEquals('超了 ⇒ 拒收', '至多指定 1 个目标', tooMany.err)
end)

lt.test('给出：不给候选名单就不限制目标；个数那半的 `min` 为 0 时也可以不给', function ()
    local game, players = newGame(3)
    local slash = game:createCard('杀')
    putInHand(players[1], { slash })

    local index = 0
    game:on('卡牌-询问', function ()
        index = index + 1
        if index == 1 then
            return { card = slash, targets = players[3] }
        end
        return { card = slash }
    end)

    local ask = game:askCardWithTarget(players[1], '测试', { card = { zone = '手牌' } })
    lt.assertEquals('没有名单照样收下答复', players[3], ask.target)

    local loose = game:askCardWithTarget(players[1], '测试', {
        card   = { zone = '手牌' },
        target = { min = 0 },
    })
    lt.assertEquals('允许不给 ⇒ 也收下', nil, loose.target)
    lt.assertEquals('目标为空表', 0, #loose.targets)
    lt.assertEquals('不算失败', nil, loose.err)
end)

lt.test('给出：允许取消时，没人应答就是空答复、不算失败', function ()
    local game, players = newGame(2)
    putInHand(players[1], { game:createCard('杀') })
    lt.clearErrors()

    local ask = game:askCardWithTarget(players[1], '测试', {
        card   = { zone = '手牌' },
        target = { player = { players[2] } },
    })

    lt.assertEquals('没有答复', nil, ask.target)
    lt.assertEquals('不算失败', nil, ask.err)
    lt.assertEquals('没有记下错误', 0, #lt.errors)
end)
