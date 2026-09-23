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

---@param cardSource string # 探针包里的牌定义
---@return Test.CanUse
local function newGame(cardSource)
    write('探针/牌.lua', cardSource)
    local game = moe.game.create {
        seats    = 2,
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
    for i = 1, 2 do
        local player = moe.player.create(game, { attributes = attributeSystem:createInstance() })
        desk:sit(i, player)
        player:setAttr('体力', 4)
        players[i] = player
    end
    local hand = moe.zone.create()
    players[1]:addZone('手牌', hand)
    return {
        game   = game,
        user   = players[1],
        target = players[2],
        hand   = hand,
    }
end

local SIMPLE = [[
Card '测试杀'
    : on('获取目标', function (ctx)
        return { game.desk:getPlayer(2) }
    end)
]]

local LIMITED = [[
Card '测试杀'
    : limit('测试阶段', 1)
    : on('获取目标', function (ctx)
        return { game.desk:getPlayer(2) }
    end)
]]

local FROM_HAND = [[
Card '测试杀'
    : zone '手牌'
    : on('获取目标', function (ctx)
        return { game.desk:getPlayer(2) }
    end)
]]

local NO_SUCH_ZONE = [[
Card '测试杀'
    : zone '没有这个区'
    : on('获取目标', function (ctx)
        return { game.desk:getPlayer(2) }
    end)
]]

lt.test('校验：能用的牌给出合法目标', function ()
    local guard <close> = useProbe()
    local run = newGame(SIMPLE)
    local card = run.game:createCard('测试杀')
    run.hand:put(card)

    local ok, reason, legal = run.game:canUse(run.user, card)

    lt.assertEquals('能用', true, ok)
    lt.assertEquals('没有原因', nil, reason)
    lt.assertEquals('给出合法目标', run.target, assert(legal)[1])
end)

lt.test('校验：没给目标时只判「能不能用」，给了目标就连目标一起判', function ()
    local guard <close> = useProbe()
    local run = newGame(SIMPLE)
    local card = run.game:createCard('测试杀')
    run.hand:put(card)

    lt.assertEquals('目标给单个也行', true, (run.game:canUse(run.user, card, run.target)))
    lt.assertEquals('目标给列表也行', true, (run.game:canUse(run.user, card, { run.target })))
    lt.assertEquals('目标为空 ⇒ 用不了', false, (run.game:canUse(run.user, card, {})))
    lt.assertEquals('目标不合法 ⇒ 用不了', false, (run.game:canUse(run.user, card, { run.user })))
end)

lt.test('校验：牌没牌名 ⇒ 用不了', function ()
    local guard <close> = useProbe()
    local run = newGame(SIMPLE)
    -- 局上造的牌必须给牌名，这里直接造一张没牌名的
    local card = lt.card()
    run.hand:put(card)

    local ok, reason = run.game:canUse(run.user, card)

    lt.assertEquals('用不了', false, ok)
    lt.assertEquals('原因是「没有牌名」', '这张牌没有牌名，查不到内容定义', reason)
end)

lt.test('校验：没有内容定义 ⇒ 用不了', function ()
    local guard <close> = useProbe()
    local run = newGame(SIMPLE)
    local card = run.game:createCard('没有这张牌')
    run.hand:put(card)

    local ok, reason = run.game:canUse(run.user, card)

    lt.assertEquals('用不了', false, ok)
    lt.assertEquals('原因里有牌名', '没有叫「没有这张牌」的内容定义', reason)
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
    run.hand:put(card)

    local ok, reason = run.game:canUse(run.user, card)

    lt.assertEquals('用不了', false, ok)
    lt.assertEquals('原因是「没声明获取目标」', '「探针.测试杀」没有声明「获取目标」，现在用不了', reason)
end)

lt.test('校验：本阶段用满额度 ⇒ 用不了，且不问内容侧', function ()
    local guard <close> = useProbe()
    local run = newGame(LIMITED)
    local card = run.game:createCard('测试杀')
    run.hand:put(card)

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
    run.hand:put(card)

    local phase <close> = run.game:enterPhase(run.target, '测试阶段')   -- 阶段是别人的
    phase:addUseCount('测试杀', 5)

    lt.assertEquals('别人的阶段里用多少都不拦', true, (run.game:canUse(run.user, card, run.target)))
    lt.assertEquals('也不记在别人的阶段上', 5, phase:getUseCount('测试杀'))
end)

lt.test('校验：不在任何阶段里 ⇒ 不按次数拦', function ()
    local guard <close> = useProbe()
    local run = newGame(LIMITED)
    local card = run.game:createCard('测试杀')
    run.hand:put(card)

    lt.assertEquals('当前没有阶段', nil, run.game.phase)
    lt.assertEquals('阶段外不受次数限制', true, (run.game:canUse(run.user, card, run.target)))
end)

lt.test('校验：声明了牌区 ⇒ 必须从那个区里用', function ()
    local guard <close> = useProbe()
    local run = newGame(FROM_HAND)
    local card = run.game:createCard('测试杀')
    run.hand:put(card)

    lt.assertEquals('在声明的手牌区里就能用', true, (run.game:canUse(run.user, card, run.target)))

    local other = moe.zone.create()
    run.user:addZone('装备', other)
    other:put(run.hand:take(1))

    local ok, reason = run.game:canUse(run.user, card, run.target)
    lt.assertEquals('挪到别的区就用不了', false, ok)
    lt.assertEquals('原因是「只能从那里用」', '「探针.测试杀」只能从「手牌」里用', reason)
end)

lt.test('校验：使用者没有声明里那个牌区 ⇒ 用不了', function ()
    local guard <close> = useProbe()
    local run = newGame(NO_SUCH_ZONE)
    local card = run.game:createCard('测试杀')
    run.hand:put(card)

    local ok, reason = run.game:canUse(run.user, card, run.target)

    lt.assertEquals('用不了', false, ok)
    lt.assertEquals('原因点名那个区', '「探针.测试杀」只能从「没有这个区」里用', reason)
end)

lt.test('校验：没声明牌区 ⇒ 在使用者任一牌区里都能用', function ()
    local guard <close> = useProbe()
    local run = newGame(SIMPLE)
    local card = run.game:createCard('测试杀')
    local other = moe.zone.create()
    run.user:addZone('装备', other)
    other:put(card)

    lt.assertEquals('别的区里照样能用', true, (run.game:canUse(run.user, card, run.target)))
end)

lt.test('校验：「获取目标」没返回列表 ⇒ 用不了', function ()
    local guard <close> = useProbe()
    local run = newGame([[
Card '测试杀'
    : on('获取目标', function (ctx)
        ctx.user:setTag('问过', true)
    end)
]])
    local card = run.game:createCard('测试杀')
    run.hand:put(card)

    local ok, reason = run.game:canUse(run.user, card)

    lt.assertEquals('用不了', false, ok)
    lt.assertEquals('原因是「必须返回列表」', '「探针.测试杀」的「获取目标」必须返回合法目标列表', reason)
    lt.assertEquals('钩子确实跑过', true, run.user:getTag('问过'))
end)

lt.test('校验：合法目标为空 ⇒ 用不了', function ()
    local guard <close> = useProbe()
    local run = newGame([[
Card '测试杀'
    : on('获取目标', function (ctx)
        return {}
    end)
]])
    local card = run.game:createCard('测试杀')
    run.hand:put(card)

    local ok, reason = run.game:canUse(run.user, card)

    lt.assertEquals('用不了', false, ok)
    lt.assertEquals('原因是「没有合法目标」', '「探针.测试杀」现在没有合法目标', reason)
end)

lt.test('校验：多个「获取目标」取交集', function ()
    local guard <close> = useProbe()
    local run = newGame([[
Card '测试杀'
    : on('获取目标', function (ctx)
        return game.desk.players
    end)
    : on('获取目标', function (ctx)
        return { game.desk:getPlayer(2) }
    end)
]])
    local card = run.game:createCard('测试杀')
    run.hand:put(card)

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
    run.hand:put(card)

    ---@type Card[] # 条目看到的那些牌
    local seen = {}
    run.game:on('卡牌-能否使用', function (ctx)
        seen[#seen + 1] = ctx.card
        if ctx.card == card then
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
    run.hand:put(card)
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
    run.hand:put(card)

    local ok = run.game:canUse(run.user, card, { run.target })

    lt.assertEquals('能用', true, ok)
    lt.assertEquals('记牌器还是空的', 0, #run.game:getEffects())
    lt.assertEquals('牌还在手上', 1, run.hand:count())
end)
