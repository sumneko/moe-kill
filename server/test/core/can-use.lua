local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'can-use-probe'

---@param rel string
---@param content string
local function write(rel, content)
    local file = probeDir / rel
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), content)
    assert(ok, err)
end

---@return unknown # 配 <close> 用
local function useProbe()
    fs.remove_all(probeDir)
    fs.create_directories(probeDir)
    return moe.util.defer(function ()
        fs.remove_all(probeDir)
    end)
end

---@class Test.CanUse
---@field game Game
---@field user Player # 1 号位（使用者）
---@field target Player # 2 号位（目标）
---@field hand Zone # 使用者的手牌区
---@field players Player[] # 所有座位

---@param cardSource string # 探针包里的牌定义
---@param seats? integer # 座位数（省略时 2）
---@return Test.CanUse
local function newGame(cardSource, seats)
    seats = seats or 2
    write('探针/牌.lua', cardSource)
    local game = moe.game.create {
        seats    = seats,
        random   = moe.random.create(1),
        sources  = { probeDir:string() .. '/*' },
        packages = { '探针' },
    }
    local desk = game.desk
    local attributeSystem = game:getAttributeSystem()
    attributeSystem:define('体力', {
        min    = -999999,
        max    = 999999,
        simple = true,
    })
    ---@type Player[]
    local players = {}
    for i = 1, seats do
        local player = moe.player.create(game, { attributes = attributeSystem:createInstance() })
        desk:sit(i, player)
        player:setAttr('体力', 4)
        players[i] = player
    end
    local hand = players[1]:getZone('手牌')
    return {
        game    = game,
        user    = players[1],
        target  = players[2],
        hand    = hand,
        players = players,
    }
end

local SIMPLE = [[
Card '测试杀'
    : on('获取目标', function (target)
        return { game.desk:getPlayer(2) }
    end)
]]

local ALL = [[
Card '测试杀'
    : on('获取目标', function (target)
        return game.desk.players
    end)
]]

local TWO = [[
Card '测试杀'
    : on('获取目标', function (target)
        return { game.desk:getPlayer(2), game.desk:getPlayer(3) }
    end)
]]

local LIMITED = [[
Card '测试杀'
    : limit('测试阶段', 1)
    : on('获取目标', function (target)
        return { game.desk:getPlayer(2) }
    end)
]]

local FROM_HAND = [[
Card '测试杀'
    : zone '手牌'
    : on('获取目标', function (target)
        return { game.desk:getPlayer(2) }
    end)
]]

local NO_SUCH_ZONE = [[
Card '测试杀'
    : zone '没有这个区'
    : on('获取目标', function (target)
        return { game.desk:getPlayer(2) }
    end)
]]

lt.test('校验：能用的牌给出合法目标', function ()
    local guard <close> = useProbe()
    local run = newGame(SIMPLE)
    local card = run.game:createCard('测试杀')
    run.hand:accept(card)

    local ok, reason, legal = run.game:canUse(run.user, card)

    lt.assertEquals('能用', true, ok)
    lt.assertEquals('没有原因', nil, reason)
    lt.assertEquals('给出合法目标', run.target, assert(legal)[1])
end)

lt.test('校验：没给目标时只判「能不能用」，给了目标就连目标一起判', function ()
    local guard <close> = useProbe()
    local run = newGame(SIMPLE)
    local card = run.game:createCard('测试杀')
    run.hand:accept(card)

    lt.assertEquals('目标给单个也行', true, (run.game:canUse(run.user, card, run.target)))
    lt.assertEquals('目标给列表也行', true, (run.game:canUse(run.user, card, { run.target })))
    lt.assertEquals('目标为空 ⇒ 用不了', false, (run.game:canUse(run.user, card, {})))
    lt.assertEquals('目标不合法 ⇒ 用不了', false, (run.game:canUse(run.user, card, { run.user })))
end)

lt.test('校验：没有内容定义 ⇒ 建牌时就报错', function ()
    local guard <close> = useProbe()
    local run = newGame(SIMPLE)

    lt.assertError('没有这张牌的内容定义', function ()
        run.game:createCard('没有这张牌')
    end)
end)

lt.test('校验：牌不在使用者手上 ⇒ 用不了', function ()
    local guard <close> = useProbe()
    local run = newGame(SIMPLE)
    local card = run.game:createCard('测试杀')

    local ok, reason = run.game:canUse(run.user, card)

    lt.assertEquals('用不了', false, ok)
    lt.assertEquals('原因是「手上没有」', '使用者手上没有这张牌', reason)
end)

lt.test('校验：没声明「获取目标」⇒ 用不了', function ()
    local guard <close> = useProbe()
    local run = newGame("Card '测试杀'")
    local card = run.game:createCard('测试杀')
    run.hand:accept(card)

    local ok, reason = run.game:canUse(run.user, card)

    lt.assertEquals('用不了', false, ok)
    lt.assertEquals('原因是「没声明获取目标」', '「探针.测试杀」没有声明「获取目标」，现在用不了', reason)
end)

lt.test('校验：本阶段用满额度 ⇒ 用不了，且不问内容侧', function ()
    local guard <close> = useProbe()
    local run = newGame(LIMITED)
    local card = run.game:createCard('测试杀')
    run.hand:accept(card)

    local asked = 0
    run.game:on('卡牌-能否使用', function ()
        asked = asked + 1
    end)

    local phase <close> = run.game:enterPhase(run.user, '测试阶段')

    lt.assertEquals('第一次能用', true, (run.game:canUse(run.user, card, run.target)))
    lt.assertEquals('内建通过后问了内容侧一次', 1, asked)

    phase:addUseCount('测试杀', 1)

    local ok, reason = run.game:canUse(run.user, card, run.target)
    lt.assertEquals('用满了就用不了', false, ok)
    lt.assertEquals('原因是「本阶段已经用过」', '本阶段已经用过「测试杀」了', reason)
    lt.assertEquals('内建不过就不问内容侧', 1, asked)

    phase:addLimit('测试杀', 1)
    lt.assertEquals('加了上限就又能用了', true, (run.game:canUse(run.user, card, run.target)))
    lt.assertEquals('又能用之后照样会问内容侧', 2, asked)
end)

lt.test('校验：阶段不属于使用者 ⇒ 不按次数拦', function ()
    local guard <close> = useProbe()
    local run = newGame(LIMITED)
    local card = run.game:createCard('测试杀')
    run.hand:accept(card)

    local phase <close> = run.game:enterPhase(run.target, '测试阶段')   -- 阶段是别人的
    phase:addUseCount('测试杀', 5)

    lt.assertEquals('别人的阶段里用多少都不拦', true, (run.game:canUse(run.user, card, run.target)))
    lt.assertEquals('也不记在别人的阶段上', 5, phase:getUseCount('测试杀'))
end)

lt.test('校验：不在任何阶段里 ⇒ 不按次数拦', function ()
    local guard <close> = useProbe()
    local run = newGame(LIMITED)
    local card = run.game:createCard('测试杀')
    run.hand:accept(card)

    lt.assertEquals('当前没有阶段', nil, run.game.phase)
    lt.assertEquals('阶段外不受次数限制', true, (run.game:canUse(run.user, card, run.target)))
end)

lt.test('校验：声明了牌区 ⇒ 必须从那个区里用', function ()
    local guard <close> = useProbe()
    local run = newGame(FROM_HAND)
    local card = run.game:createCard('测试杀')
    run.hand:accept(card)

    lt.assertEquals('在声明的手牌区里就能用', true, (run.game:canUse(run.user, card, run.target)))

    local other = moe.zone.create(run.game)
    run.user:addZone('别处', other)
    other:accept(assert(run.hand:peek(1)))

    local ok, reason = run.game:canUse(run.user, card, run.target)
    lt.assertEquals('挪到别的区就用不了', false, ok)
    lt.assertEquals('原因是「只能从那里用」', '「探针.测试杀」只能从「手牌」里用', reason)
end)

lt.test('校验：使用者没有声明里那个牌区 ⇒ 用不了', function ()
    local guard <close> = useProbe()
    local run = newGame(NO_SUCH_ZONE)
    local card = run.game:createCard('测试杀')
    run.hand:accept(card)

    local ok, reason = run.game:canUse(run.user, card, run.target)

    lt.assertEquals('用不了', false, ok)
    lt.assertEquals('原因点名那个区', '「探针.测试杀」只能从「没有这个区」里用', reason)
end)

lt.test('校验：没声明牌区 ⇒ 在使用者任一牌区里都能用', function ()
    local guard <close> = useProbe()
    local run = newGame(SIMPLE)
    local card = run.game:createCard('测试杀')
    local other = moe.zone.create(run.game)
    run.user:addZone('别处', other)
    other:accept(card)

    lt.assertEquals('别的区里照样能用', true, (run.game:canUse(run.user, card, run.target)))
end)

lt.test('校验：「获取目标」没返回列表 ⇒ 用不了', function ()
    local guard <close> = useProbe()
    local run = newGame([[
Card '测试杀'
    : on('获取目标', function (target)
        target.user:setTag('问过', true)
    end)
]])
    local card = run.game:createCard('测试杀')
    run.hand:accept(card)

    local ok, reason = run.game:canUse(run.user, card)

    lt.assertEquals('用不了', false, ok)
    lt.assertEquals('原因是「必须返回列表」', '「探针.测试杀」的「获取目标」必须返回合法目标列表', reason)
    lt.assertEquals('钩子确实跑过', true, run.user:getTag('问过'))
end)

lt.test('校验：合法目标为空 ⇒ 用不了', function ()
    local guard <close> = useProbe()
    local run = newGame([[
Card '测试杀'
    : on('获取目标', function (target)
        return {}
    end)
]])
    local card = run.game:createCard('测试杀')
    run.hand:accept(card)

    local ok, reason = run.game:canUse(run.user, card)

    lt.assertEquals('用不了', false, ok)
    lt.assertEquals('原因是「没有合法目标」', '「探针.测试杀」现在没有合法目标', reason)
end)

lt.test('校验：多个「获取目标」取交集', function ()
    local guard <close> = useProbe()
    local run = newGame([[
Card '测试杀'
    : on('获取目标', function (target)
        return game.desk.players
    end)
    : on('获取目标', function (target)
        return { game.desk:getPlayer(2) }
    end)
]])
    local card = run.game:createCard('测试杀')
    run.hand:accept(card)

    local ok, _, legal = run.game:canUse(run.user, card)
    local list = assert(legal)

    lt.assertEquals('能用', true, ok)
    lt.assertEquals('只剩交集里的那个', 1, #list)
    lt.assertEquals('交集里是 2 号位', run.target, list[1])
end)

lt.test('校验：内容侧条目可以否决（返回值就是原因）', function ()
    local guard <close> = useProbe()
    local run = newGame(SIMPLE)
    local card = run.game:createCard('测试杀')
    run.hand:accept(card)

    ---@type Card[] # 条目看到的那些牌
    local seen = {}
    run.game:on('卡牌-能否使用', function (check)
        seen[#seen + 1] = check.card
        if check.card == card then
            return '这张现在不许用'
        end
    end)

    local ok, reason = run.game:canUse(run.user, card)

    lt.assertEquals('被否决', false, ok)
    lt.assertEquals('返回值就是原因', '这张现在不许用', reason)
    lt.assertEquals('条目看到了要用的牌', card, seen[1])
end)

lt.test('校验：条目只返回 false 时给一句通用原因', function ()
    local guard <close> = useProbe()
    local run = newGame(SIMPLE)
    local card = run.game:createCard('测试杀')
    run.hand:accept(card)
    run.game:on('卡牌-能否使用', function ()
        return false
    end)

    local ok, reason = run.game:canUse(run.user, card)

    lt.assertEquals('被否决', false, ok)
    lt.assertEquals('原因是通用的一句', '这张牌现在不能使用', reason)
end)

lt.test('校验：跑校验不进记牌器、也不改状态', function ()
    local guard <close> = useProbe()
    local run = newGame(SIMPLE)
    local card = run.game:createCard('测试杀')
    run.hand:accept(card)

    local ok = run.game:canUse(run.user, card, { run.target })

    lt.assertEquals('能用', true, ok)
    lt.assertEquals('记牌器还是空的', 0, #run.game:getEffects())
    lt.assertEquals('牌还在手上', 1, run.hand:count())
end)

lt.test('校验：默认「最少 1、最多 1」', function ()
    local guard <close> = useProbe()
    local run = newGame(ALL, 3)
    local card = run.game:createCard('测试杀')
    run.hand:accept(card)

    lt.assertEquals('指定一名能用', true, (run.game:canUse(run.user, card, run.players[2])))

    local ok, reason = run.game:canUse(run.user, card, { run.players[2], run.players[3] })
    lt.assertEquals('指定两名就用不了了', false, ok)
    lt.assertEquals('原因是「至多指定 1 个目标」', '「探针.测试杀」至多指定 1 个目标', reason)
end)

lt.test('校验：声明「最少 1、最多 2」后，数量按区间判', function ()
    local guard <close> = useProbe()
    local run = newGame([[
Card '测试杀'
    : targetCount(1, 2)
    : on('获取目标', function (target)
        return game.desk.players
    end)
]], 3)
    local card = run.game:createCard('测试杀')
    run.hand:accept(card)

    lt.assertEquals('一名能用', true, (run.game:canUse(run.user, card, { run.players[2] })))
    lt.assertEquals('两名也能用', true, (run.game:canUse(run.user, card, { run.players[2], run.players[3] })))

    local ok, reason = run.game:canUse(run.user, card, {})
    lt.assertEquals('一个都不给就用不了了', false, ok)
    lt.assertEquals('原因是「至少要指定 1 个目标」', '「探针.测试杀」至少要指定 1 个目标', reason)

    local over, overReason = run.game:canUse(run.user, card, { run.players[2], run.players[3], run.user })
    lt.assertEquals('三个也用不了了', false, over)
    lt.assertEquals('原因是「至多指定 2 个目标」', '「探针.测试杀」至多指定 2 个目标', overReason)
end)

lt.test('校验：「最少 0、最多 0」谁都不指定，给目标反而不行', function ()
    local guard <close> = useProbe()
    local run = newGame([[
Card '无目标牌'
    : targetCount(0, 0)
]])
    local card = run.game:createCard('无目标牌')
    run.hand:accept(card)

    lt.assertEquals('不传目标能用（也不用声明「获取目标」）', true, (run.game:canUse(run.user, card)))
    lt.assertEquals('传空表也能用（调用方习惯给空表）', true, (run.game:canUse(run.user, card, {})))
    lt.assertEquals('也不给出合法目标', nil, (select(3, run.game:canUse(run.user, card))))

    local ok, reason = run.game:canUse(run.user, card, { run.target })
    lt.assertEquals('给目标反而不行', false, ok)
    lt.assertEquals('原因是「不需要指定目标」', '「探针.无目标牌」不需要指定目标', reason)
end)

lt.test('校验：目标数修正放宽与收紧，上限跟合法目标数取较小值', function ()
    local guard <close> = useProbe()
    local run = newGame(TWO, 3)
    local card = run.game:createCard('测试杀')
    run.hand:accept(card)

    local extra = 0
    run.game:on('卡牌-目标数修正', function (check)
        return extra
    end)

    local ok, reason = run.game:canUse(run.user, card, { run.players[2], run.players[3] })
    lt.assertEquals('没放宽时两名被拒', false, ok)
    lt.assertEquals('原因就是默认上限 1', '「探针.测试杀」至多指定 1 个目标', reason)

    extra = 1
    lt.assertEquals('放宽 1 个：两名就能用了', true,
        (run.game:canUse(run.user, card, { run.players[2], run.players[3] })))

    extra = 5
    local over, overReason = run.game:canUse(run.user, card, { run.players[2], run.players[3], run.user })
    lt.assertEquals('放宽再多也超不过合法目标数（「获取目标」只给得出两名）', false, over)
    lt.assertEquals('上限就是合法目标数 2', '「探针.测试杀」至多指定 2 个目标', overReason)

    extra = -1
    local tight, tightReason = run.game:canUse(run.user, card, { run.players[2] })
    lt.assertEquals('收紧 1 个：连一名都不让指定', false, tight)
    lt.assertEquals('上限收到 0', '「探针.测试杀」至多指定 0 个目标', tightReason)
end)

lt.test('校验：没给目标就不问「目标数修正」', function ()
    local guard <close> = useProbe()
    local run = newGame(ALL, 3)
    local card = run.game:createCard('测试杀')
    run.hand:accept(card)

    local asked = 0
    run.game:on('卡牌-目标数修正', function ()
        asked = asked + 1
    end)

    lt.assertEquals('没给目标时照常能用', true, (run.game:canUse(run.user, card)))
    lt.assertEquals('也就没问修正', 0, asked)

    run.game:canUse(run.user, card, { run.players[2] })
    lt.assertEquals('给了目标就问一次', 1, asked)
end)

lt.test('校验：多个来源的目标数修正叠加', function ()
    local guard <close> = useProbe()
    local run = newGame(ALL, 3)
    local card = run.game:createCard('测试杀')
    run.hand:accept(card)

    run.game:on('卡牌-目标数修正', function () return 1 end)
    run.game:on('卡牌-目标数修正', function () return 1 end)

    lt.assertEquals('两个 +1 叠成 +2：两名能用', true,
        (run.game:canUse(run.user, card, { run.players[2], run.players[3] })))
end)
