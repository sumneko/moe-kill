local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'judge-bare'

---@return unknown # 配 <close> 用
local function useBareSources()
    fs.create_directories(probeDir)
    return moe.util.defer(function ()
        fs.remove_all(probeDir)
    end)
end

--- 一个不装任何内容包的局（连默认包也不装）：内核的机制在这里是「光杆」
---@param count integer
---@return Game
---@return Player[] # 按座位号升序
local function newBareGame(count)
    local random = moe.random.create(1)
    local game   = moe.game.create {
        seats   = count,
        random  = random,
        sources = { probeDir:string() .. '/*' },
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

lt.test('判定：当场结算，上下文里是判定者与缘由', function ()
    local bare <close> = useBareSources()
    local game, players = newBareGame(2)

    ---@type Judge?
    local seen = nil
    ---@type string[]
    local trace = {}
    game:on('判定-亮牌', function (judge)
        seen = judge
        trace[#trace + 1] = '亮牌'
    end)
    game:on('判定-前', function ()
        trace[#trace + 1] = '前'
    end)
    game:on('判定-后', function ()
        trace[#trace + 1] = '后'
    end)

    local judge = game:judge(players[2], '测试')

    lt.assertEquals('种类标识', 'judge', judge.kind)
    lt.assertEquals('上下文里是那个判定的人', players[2], judge.player)
    lt.assertEquals('缘由原样带着', '测试', judge.reason)
    lt.assertEquals('三个时机按次序发一遍', '亮牌,前,后', table.concat(trace, ','))
    lt.assertEquals('每个时机都是同一次结算', judge, assert(seen))
    lt.assertEquals('没人亮牌就是空', nil, judge.card)
    lt.assertEquals('没换过牌', 0, #judge.replaced)
    lt.assertEquals('不是失败', nil, judge.err)
end)

lt.test('判定：亮牌之后可以换牌，被换下的按顺序记着', function ()
    local bare <close> = useBareSources()
    local game, players = newBareGame(2)
    local first  = lt.card('甲')
    local second = lt.card('乙')
    local third  = lt.card('丙')

    game:on('判定-亮牌', function (judge)
        judge.card = first
    end)
    game:on('判定-前', function (judge)
        judge:replace(second)
        judge:replace(third)
    end)

    local judge = game:judge(players[1])

    lt.assertEquals('判的是最后换上的那张', third, judge.card)
    lt.assertEquals('被换下的按顺序记着', 2, #judge.replaced)
    lt.assertEquals('先后被换下的是第一张', first, judge.replaced[1])
    lt.assertEquals('再被换下的是第二张', second, judge.replaced[2])
end)

lt.test('判定：嵌在别的结算里也用自己的临时区', function ()
    local bare <close> = useBareSources()
    local game, players = newBareGame(2)
    ---@type Damage?
    local damage = nil
    ---@type Judge?
    local judge = nil

    game:on('伤害-前', function (payload)
        ---@cast payload Damage
        damage = payload
        payload:getTempZone()
        judge = game:judge(players[2], '测试')
    end)

    game:damage(players[1], players[2], 1)

    local outer = assert(damage, '伤害没起')
    local inner = assert(judge, '判定没起')
    lt.assertEquals('没要过区就没有', nil, inner.tempZone)
    lt.assertEquals('判定要区时自己建，不借外层那块', true, inner:getTempZone() ~= outer:getTempZone())
    lt.assertEquals('那块区记在判定自己身上', true, inner.tempZone ~= nil)
end)

lt.test('判定：换牌只能在「判定-前」里做', function ()
    local bare <close> = useBareSources()
    local game, players = newBareGame(2)
    local card = lt.card('甲')

    ---@type string?
    local brightErr = nil
    ---@type string?
    local afterErr = nil
    game:on('判定-亮牌', function (judge)
        brightErr = lt.assertError('亮牌时换牌', function () judge:replace(card) end)
    end)
    game:on('判定-后', function (judge)
        afterErr = lt.assertError('结算后换牌', function () judge:replace(card) end)
    end)

    local judge = game:judge(players[1])
    local noJudgeErr = lt.assertError('没起判定时换牌', function () judge:replace(card) end)

    lt.assertEquals('亮牌时不能换', true, brightErr ~= nil)
    lt.assertEquals('结果定了也不能换', true, afterErr ~= nil)
    lt.assertEquals('没起判定也不能换', true, noJudgeErr ~= nil)
    lt.assertEquals('一次都没换成', nil, judge.card)
    lt.assertEquals('账上也没有', 0, #judge.replaced)
end)

lt.test('判定：没有订阅者时照常结完', function ()
    local bare <close> = useBareSources()
    local game, players = newBareGame(1)

    local judge = game:judge(players[1])

    lt.assertEquals('返回这次判定', 'judge', judge.kind)
    lt.assertEquals('没人亮牌就是空', nil, judge.card)
    lt.assertEquals('也不是失败', nil, judge.err)
end)
