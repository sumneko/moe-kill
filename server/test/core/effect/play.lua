local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'play-probe'

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

---@return Game # 局（来源只有探针包）
---@return Player # 使用者（坐 1 号位）
---@return Player # 目标（坐 2 号位）
---@return Zone # 使用者的手牌区
local function newGame()
    local desk = moe.desk.create(2)
    local game = moe.game.create {
        desk     = desk,
        random   = moe.random.create(1),
        sources  = { probeDir:string() .. '/*' },
        packages = { '探针' },
    }
    local attributeSystem = game:getAttributeSystem()
    attributeSystem:define('体力', {
        min    = -999999,
        max    = 999999,
        simple = true,
    })
    ---@type Player[]
    local players = {}
    for i = 1, 2 do
        local player = moe.player.create { attributes = attributeSystem:createInstance() }
        desk:sit(i, player)
        player:setAttr('体力', 4)
        players[i] = player
    end
    local hand = moe.zone.create()
    players[1]:addZone('手牌', hand)
    return game, players[1], players[2], hand
end

lt.test('使用：用一张牌并结算', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (ctx)
        return { game.desk:getPlayer(2) }
    end)
    : on('生效', function (ctx)
        ctx.user:setTag('顺序', (ctx.user:getTag('顺序') or '') .. '一')
    end)
    : on('生效', function (ctx)
        ctx.user:setTag('顺序', (ctx.user:getTag('顺序') or '') .. '二')
        ctx.user:setTag('目标', ctx.target)
    end)
]])

    local game, user, target, hand = newGame()
    local card = game:createCard('测试杀')
    hand:put(card)

    lt.assertEquals('探针牌定义已装好', true, game:getCard('测试杀') ~= nil)

    ---@type Card?
    local settledCard = nil
    ---@type Player?
    local settledTarget = nil

    ---@param ctx UseCard
    local function onSettled(ctx)
        settledCard   = ctx.card
        settledTarget = ctx.targets[1]
    end
    game:on('卡牌-结算后', onSettled)

    game:useCard(user, card, { target })

    lt.assertEquals('两个生效回调按声明顺序执行', '一二', user:getTag('顺序'))
    lt.assertEquals('回调拿到了目标', target, user:getTag('目标'))
    lt.assertEquals('牌已经离开手牌', 0, hand:count())
    lt.assertEquals('收尾时机拿到这张牌', card, settledCard)
    lt.assertEquals('收尾时机也拿得到目标', target, settledTarget)
end)

lt.test('使用：牌不在使用者手上时报错', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('生效', function (ctx)
        ctx.user:setTag('用了', true)
    end)
]])

    local game, user, target, hand = newGame()
    local card = game:createCard('测试杀')

    lt.assertEquals('探针牌定义已装好', true, game:getCard('测试杀') ~= nil)

    lt.assertFailed('手上没有这张牌', game:useCard(user, card, { target }))

    lt.assertEquals('结算没跑', nil, user:getTag('用了'))
    lt.assertEquals('手牌还是空的', 0, hand:count())
end)

lt.test('使用：牌没有内容定义时报错', function ()
    local guard <close> = useProbe()
    write('探针/占位.lua', "Card '占位'")

    local game, user, target, hand = newGame()
    local card = game:createCard('没有这张牌')
    hand:put(card)

    lt.assertFailed('没有定义就用不了', game:useCard(user, card, { target }))

    lt.assertEquals('牌还留在手上', 1, hand:count())
end)

lt.test('使用：给出的目标必须是合法目标的子集', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (ctx)
        return { game.desk:getPlayer(2) }
    end)
    : on('生效', function (ctx)
        ctx.user:setTag('用了', ctx.target)
    end)
]])

    local game, user, _, hand = newGame()
    local card = game:createCard('测试杀')
    hand:put(card)

    lt.assertEquals('探针牌定义已装好', true, game:getCard('测试杀') ~= nil)

    lt.assertFailed('自己不在合法目标里', game:useCard(user, card, { user }))

    lt.assertEquals('牌还留在手上', 1, hand:count())
    lt.assertEquals('结算也没跑', nil, user:getTag('用了'))
end)

lt.test('使用：没声明「获取目标」的牌用不了', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('使用', function (ctx)
        ctx.user:setTag('用了', ctx.targets[1])
    end)
]])

    local game, user, target, hand = newGame()
    local card = game:createCard('测试杀')
    hand:put(card)

    lt.assertEquals('探针牌定义已装好', true, game:getCard('测试杀') ~= nil)

    lt.assertFailed('漏写钩子不等于谁都能打', game:useCard(user, card, { target }))

    lt.assertEquals('牌还留在手上', 1, hand:count())
    lt.assertEquals('结算也没跑', nil, user:getTag('用了'))
end)

lt.test('使用：钩子没返回列表时用不了', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (ctx)
        ctx.user:setTag('问过目标', true)
    end)
]])

    local game, user, target, hand = newGame()
    local card = game:createCard('测试杀')
    hand:put(card)

    lt.assertFailed('拿不到列表就谁都不给用', game:useCard(user, card, { target }))

    lt.assertEquals('钩子确实跑过', true, user:getTag('问过目标'))
    lt.assertEquals('牌还留在手上', 1, hand:count())
end)

lt.test('使用：合法目标为空时用不了', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (ctx)
        return {}
    end)
]])

    local game, user, target, hand = newGame()
    local card = game:createCard('测试杀')
    hand:put(card)

    lt.assertFailed('没有合法目标就用不了', game:useCard(user, card, { target }))

    lt.assertEquals('牌还留在手上', 1, hand:count())
end)

lt.test('使用：给出的目标不能为空', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (ctx)
        return { game.desk:getPlayer(2) }
    end)
]])

    local game, user, _, hand = newGame()
    local card = game:createCard('测试杀')
    hand:put(card)

    lt.assertFailed('一个目标都不给就用不了', game:useCard(user, card, {}))

    lt.assertEquals('牌还留在手上', 1, hand:count())
end)

lt.test('使用：多个钩子取交集', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (ctx)
        return game.desk.players
    end)
    : on('获取目标', function (ctx)
        return { game.desk:getPlayer(2) }
    end)
    : on('生效', function (ctx)
        ctx.user:setTag('用了', true)
    end)
]])

    local game, user, target, hand = newGame()
    local card = game:createCard('测试杀')
    hand:put(card)

    lt.assertFailed('被前一个钩子收窄掉的目标用不了', game:useCard(user, card, { user }))
    lt.assertEquals('牌还留在手上', 1, hand:count())

    game:useCard(user, card, { target })

    lt.assertEquals('两个钩子都放行的目标能用', true, user:getTag('用了'))
    lt.assertEquals('牌用出去了', 0, hand:count())
end)

lt.test('使用：结算期间这次生效在栈上', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (ctx)
        return { game.desk:getPlayer(2) }
    end)
    : on('生效', function (ctx)
        ctx.user:setTag('父是根', game:getEffect() == ctx.parent)
        ctx.user:setTag('种类', ctx.kind)
        ctx.user:setTag('父是用牌', ctx.parent and ctx.parent.kind)
    end)
]])

    local game, user, target, hand = newGame()
    local card = game:createCard('测试杀')
    hand:put(card)

    lt.assertEquals('探针牌定义已装好', true, game:getCard('测试杀') ~= nil)

    game:useCard(user, card, { target })

    lt.assertEquals('生效不是根，根是这次用牌', true, user:getTag('父是根'))
    lt.assertEquals('种类标识', 'cardEffect', user:getTag('种类'))
    lt.assertEquals('生效的父是这次用牌', 'useCard', user:getTag('父是用牌'))
    lt.assertEquals('记牌器留下了这一条', 1, #game:getEffects())
end)

lt.test('使用：失败后栈恢复原状', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (ctx)
        return { game.desk:getPlayer(2) }
    end)
]])

    local game, user, _, hand = newGame()
    local card = game:createCard('测试杀')
    hand:put(card)

    lt.assertFailed('不能对自己用', game:useCard(user, card, { user }))

    lt.assertEquals('失败也记在记牌器上', 1, #game:getEffects())
end)

lt.test('使用：结算中抛错后栈恢复原状', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (ctx)
        return { game.desk:getPlayer(2) }
    end)
    : on('生效', function ()
        error('故意报错')
    end)
]])

    local game, user, target, hand = newGame()
    local card = game:createCard('测试杀')
    hand:put(card)

    lt.assertEquals('探针牌定义已装好', true, game:getCard('测试杀') ~= nil)

    local effect = game:useCard(user, card, { target })

    lt.assertEquals('钩子报错被隔离，用牌照常完成', 0, hand:count())
    lt.assertEquals('记牌器留下了这一条', 1, #game:getEffects())
    lt.assertEquals('用牌本身没失败', nil, effect.err)
end)

lt.test('使用：结算里造成的伤害认这次用牌为父', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (ctx)
        return { game.desk:getPlayer(2) }
    end)
    : on('生效', function (ctx)
        game:damage(ctx.user, ctx.target, 1)
    end)
]])

    local game, user, target, hand = newGame()
    local card = game:createCard('测试杀')
    hand:put(card)

    ---@type Damage?
    local damageSeen = nil

    ---@param ctx Damage
    local function onBefore(ctx)
        damageSeen = ctx
    end
    game:on('伤害-前', onBefore)

    game:useCard(user, card, { target })

    local damage = assert(damageSeen, '这次结算没造成伤害')
    local effect = assert(damage.parent, '伤害没有父效果')
    ---@cast effect CardEffect
    lt.assertEquals('伤害的父是这次生效', 'cardEffect', effect.kind)
    lt.assertEquals('生效的目标', target, effect.target)
    local parent = assert(effect.parent, '生效没有父效果')
    ---@cast parent UseCard
    lt.assertEquals('生效的父是这次用牌', 'useCard', parent.kind)
    lt.assertEquals('顺着父能拿到这张牌', card, parent.card)
    lt.assertEquals('顺着父能拿到使用者', user, parent.user)
    lt.assertEquals('伤害来源是使用者', user, damage.from)
    lt.assertEquals('父效果不等于伤害来源', true, parent ~= damage.from)
end)

---@param count integer
---@return Game # 局（来源只有探针包）
---@return Player[] # 按座位号升序
local function newWideGame(count)
    local desk = moe.desk.create(count)
    local game = moe.game.create {
        desk     = desk,
        random   = moe.random.create(1),
        sources  = { probeDir:string() .. '/*' },
        packages = { '探针' },
    }
    local attributeSystem = game:getAttributeSystem()
    attributeSystem:define('体力', {
        min    = -999999,
        max    = 999999,
        simple = true,
    })
    ---@type Player[]
    local players = {}
    for i = 1, count do
        local player = moe.player.create { attributes = attributeSystem:createInstance() }
        desk:sit(i, player)
        player:setAttr('体力', 4)
        player:addZone('手牌')
        players[i] = player
    end
    return game, players
end

lt.test('使用：逐目标生效，顺序按行动顺序', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (ctx)
        return game.desk.players
    end)
    : on('生效', function (ctx)
        local order = ctx.user:getTag('顺序') or ''
        ctx.user:setTag('顺序', order .. tostring(game.desk:getIndex(ctx.target)))
    end)
]])

    local game, players = newWideGame(4)
    local card = game:createCard('测试杀')
    local user = players[1]
    local hand = assert(user:getZone('手牌'))
    hand:put(card)

    game:useCard(user, card, { players[4], players[2], players[3] })

    lt.assertEquals('从使用者的下家开始绕一圈', '234', user:getTag('顺序'))
end)

lt.test('使用：收尾时机在所有目标处理完之后，且只触发一次', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (ctx)
        return game.desk.players
    end)
    : on('生效', function (ctx)
        local order = ctx.user:getTag('顺序') or ''
        ctx.user:setTag('顺序', order .. '生效' .. tostring(game.desk:getIndex(ctx.target)))
    end)
]])

    local game, players = newWideGame(3)
    local card = game:createCard('测试杀')
    local user = players[1]
    local hand = assert(user:getZone('手牌'))
    hand:put(card)

    game:on('卡牌-结算后', function (ctx)
        ---@cast ctx UseCard
        local order = ctx.user:getTag('顺序') or ''
        ctx.user:setTag('顺序', order .. '收尾')
    end)

    game:useCard(user, card, { players[2], players[3] })

    lt.assertEquals('两个生效之后才收尾', '生效2生效3收尾', user:getTag('顺序'))
end)

lt.test('使用：牌出手前触发一次时机，早于第一个生效', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (ctx)
        return { game.desk:getPlayer(2) }
    end)
    : on('生效', function (ctx)
        local order = ctx.user:getTag('顺序') or ''
        ctx.user:setTag('顺序', order .. '生效')
    end)
]])

    local game, user, target, hand = newGame()
    local card = game:createCard('测试杀')
    hand:put(card)

    ---@type (Card?)[]
    local seen = {}
    game:on('卡牌-结算前', function (ctx)
        ---@cast ctx UseCard
        seen[#seen + 1] = ctx.card
        user:setTag('顺序', (user:getTag('顺序') or '') .. '取出')
        user:setTag('取出时还在手上吗', hand:count())
    end)
    game:on('卡牌-结算后', function ()
        user:setTag('顺序', (user:getTag('顺序') or '') .. '收尾')
    end)

    game:useCard(user, card, { target })

    lt.assertEquals('时机拿到这张牌', card, seen[1])
    lt.assertEquals('只触发一次', 1, #seen)
    lt.assertEquals('此刻牌已经离开手牌，可以被内容侧安置', 0, user:getTag('取出时还在手上吗'))
    lt.assertEquals('顺序：取出 → 生效 → 收尾', '取出生效收尾', user:getTag('顺序'))
end)

lt.test('使用：每个目标的生效可以被单独取消', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (ctx)
        return game.desk.players
    end)
    : on('生效', function (ctx)
        local order = ctx.user:getTag('顺序') or ''
        ctx.user:setTag('顺序', order .. tostring(game.desk:getIndex(ctx.target)))
    end)
]])

    local game, players = newWideGame(3)
    local card = game:createCard('测试杀')
    local user = players[1]
    local hand = assert(user:getZone('手牌'))
    hand:put(card)

    local blocked = players[2]
    game:on('即将生效', function (ctx)
        ---@cast ctx CardEffect
        if ctx.kind == 'cardEffect' and ctx.target == blocked then
            ctx:remove()
        end
    end)

    game:useCard(user, card, { players[2], players[3] })

    lt.assertEquals('被取消的那个没生效，其余的照常', '3', user:getTag('顺序'))
    lt.assertEquals('记牌器留下了这一条', 1, #game:getEffects())
end)
