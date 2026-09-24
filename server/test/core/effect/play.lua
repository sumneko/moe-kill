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
    game.turnPlayer = players[1]
    local hand = players[1]:getZone('手牌')
    return game, players[1], players[2], hand
end

lt.test('使用：用一张牌并结算', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (target)
        return { game.desk:getPlayer(2) }
    end)
    : on('生效', function (cardEffect)
        cardEffect.user:setTag('顺序', (cardEffect.user:getTag('顺序') or '') .. '一')
    end)
    : on('生效', function (cardEffect)
        cardEffect.user:setTag('顺序', (cardEffect.user:getTag('顺序') or '') .. '二')
        cardEffect.user:setTag('目标', cardEffect.target)
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

    ---@param useCard UseCard
    local function onSettled(useCard)
        settledCard   = useCard.card
        settledTarget = useCard.targets[1]
    end
    game:on('卡牌-结算后', onSettled)

    game:useCard(user, card, { target })

    lt.assertEquals('两个生效回调按声明顺序执行', '一二', user:getTag('顺序'))
    lt.assertEquals('回调拿到了目标', target, user:getTag('目标'))
    lt.assertEquals('牌已经离开手牌', 0, hand:count())
    lt.assertEquals('收尾时机拿到这张牌', card, settledCard)
    lt.assertEquals('收尾时机也拿得到目标', target, settledTarget)
end)

lt.test('使用：生效钩子拿得到这次用牌', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (target)
        return { game.desk:getPlayer(2) }
    end)
    : on('生效', function (cardEffect, useCard)
        cardEffect.user:setTag('生效的用牌', useCard)
        cardEffect.user:setTag('临时区拿得到', useCard:getTempZone() ~= nil)
        cardEffect.user:setTag('生效自己建区', cardEffect:getTempZone() ~= useCard:getTempZone())
    end)
]])

    local game, user, target, hand = newGame()
    local card = game:createCard('测试杀')
    hand:put(card)

    local useCard = game:useCard(user, card, { target })

    lt.assertEquals('第二个参数就是这次用牌', useCard, user:getTag('生效的用牌'))
    lt.assertEquals('不用翻父子关系就能拿临时区', true, user:getTag('临时区拿得到'))
    lt.assertEquals('每个目标的生效自己建区（不借用牌那块）', true, user:getTag('生效自己建区'))
end)

lt.test('使用：自己的阶段里用一次就记一次账', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (target)
        return { game.desk:getPlayer(2) }
    end)
]])

    local game, user, target, hand = newGame()
    local card = game:createCard('测试杀')
    hand:put(card)

    local phase <close> = game:enterPhase(user, '出牌')

    lt.assertEquals('用之前是 0', 0, phase:getUseCount('测试杀'))

    lt.assertFailed('不能对自己用', game:useCard(user, card, { user }))
    lt.assertEquals('失败的使用不记账', 0, phase:getUseCount('测试杀'))

    game:useCard(user, card, { target })

    lt.assertEquals('用一次记一次', 1, phase:getUseCount('测试杀'))
    lt.assertEquals('别的牌名不受影响', 0, phase:getUseCount('闪'))
end)

lt.test('使用：阶段不是使用者的就不记账', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (target)
        return { game.desk:getPlayer(2) }
    end)
]])

    local game, user, target, hand = newGame()
    local card = game:createCard('测试杀')
    hand:put(card)

    local phase <close> = game:enterPhase(target, '出牌')   -- 阶段是 2 号位的

    game:useCard(user, card, { target })

    lt.assertEquals('不记在别人的阶段上', 0, phase:getUseCount('测试杀'))
end)

lt.test('使用：离开阶段之后用牌不记账', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (target)
        return { game.desk:getPlayer(2) }
    end)
]])

    local game, user, target, hand = newGame()
    local card = game:createCard('测试杀')
    hand:put(card)

    local phase = game:enterPhase(user, '出牌')
    Delete(phase)

    game:useCard(user, card, { target })

    lt.assertEquals('阶段已经离开，账还是 0', 0, phase:getUseCount('测试杀'))
end)

lt.test('使用：目标给单个或一张列表都行', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (target)
        return { game.desk:getPlayer(2) }
    end)
    : on('生效', function (cardEffect)
        cardEffect.user:setTag('目标', cardEffect.target)
    end)
]])

    local game, user, target, hand = newGame()
    local card = game:createCard('测试杀')
    hand:put(card)

    game:useCard(user, card, target)

    lt.assertEquals('单个目标照样结算', target, user:getTag('目标'))
end)

lt.test('使用：牌不在使用者手上时报错', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('生效', function (cardEffect)
        cardEffect.user:setTag('用了', true)
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
    : on('获取目标', function (target)
        return { game.desk:getPlayer(2) }
    end)
    : on('生效', function (cardEffect)
        cardEffect.user:setTag('用了', cardEffect.target)
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
    : on('使用', function (useCard)
        useCard.user:setTag('用了', useCard.targets[1])
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
    : on('获取目标', function (target)
        target.user:setTag('问过目标', true)
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
    : on('获取目标', function (target)
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
    : on('获取目标', function (target)
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
    : on('获取目标', function (target)
        return game.desk.players
    end)
    : on('获取目标', function (target)
        return { game.desk:getPlayer(2) }
    end)
    : on('生效', function (cardEffect)
        cardEffect.user:setTag('用了', true)
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
    : on('获取目标', function (target)
        return { game.desk:getPlayer(2) }
    end)
    : on('生效', function (cardEffect)
        cardEffect.user:setTag('父是根', game:getEffect() == cardEffect.parent)
        cardEffect.user:setTag('种类', cardEffect.kind)
        cardEffect.user:setTag('父是用牌', cardEffect.parent and cardEffect.parent.kind)
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
    : on('获取目标', function (target)
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
    : on('获取目标', function (target)
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
    : on('获取目标', function (target)
        return { game.desk:getPlayer(2) }
    end)
    : on('生效', function (cardEffect)
        game:damage(cardEffect.user, cardEffect.target, 1)
    end)
]])

    local game, user, target, hand = newGame()
    local card = game:createCard('测试杀')
    hand:put(card)

    ---@type Damage?
    local damageSeen = nil

    ---@param damage Damage
    local function onBefore(damage)
        damageSeen = damage
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
    local game = moe.game.create {
        seats    = count,
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
    for i = 1, count do
        local player = moe.player.create(game, { attributes = attributeSystem:createInstance() })
        desk:sit(i, player)
        player:setAttr('体力', 4)
        players[i] = player
    end
    game.turnPlayer = players[1]
    return game, players
end

lt.test('使用：逐目标生效，顺序按行动顺序', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (target)
        return game.desk.players
    end)
    : on('生效', function (cardEffect)
        local order = cardEffect.user:getTag('顺序') or ''
        cardEffect.user:setTag('顺序', order .. tostring(game.desk:getIndex(cardEffect.target)))
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

lt.test('使用：牌自己的「结算前」/「结算后」各跑一次，顺序对', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (target)
        return game.desk.players
    end)
    : on('结算前', function (useCard)
        local order = useCard.user:getTag('顺序') or ''
        useCard.user:setTag('顺序', order .. '结算前')
    end)
    : on('生效', function (cardEffect)
        local order = cardEffect.user:getTag('顺序') or ''
        cardEffect.user:setTag('顺序', order .. tostring(game.desk:getIndex(cardEffect.target)))
    end)
    : on('结算后', function (useCard)
        local order = useCard.user:getTag('顺序') or ''
        useCard.user:setTag('顺序', order .. '结算后')
    end)
]])

    local game, players = newWideGame(3)
    local card = game:createCard('测试杀')
    local user = players[1]
    local hand = assert(user:getZone('手牌'))
    hand:put(card)

    game:useCard(user, card, { players[2], players[3] })

    lt.assertEquals('结算前 → 逐个生效 → 结算后', '结算前23结算后', user:getTag('顺序'))
end)

lt.test('使用：起点是顺序锚点，不是使用者', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (target)
        return game.desk.players
    end)
    : on('生效', function (cardEffect)
        local order = cardEffect.user:getTag('顺序') or ''
        cardEffect.user:setTag('顺序', order .. tostring(game.desk:getIndex(cardEffect.target)))
    end)
]])

    local game, players = newWideGame(4)
    local card = game:createCard('测试杀')
    local user = players[3]
    local hand = assert(user:getZone('手牌'))
    hand:put(card)
    game.turnPlayer = players[1]

    game:useCard(user, card, { players[4], players[2] })

    lt.assertEquals('从锚点的下家起绕一圈', '24', user:getTag('顺序'))
end)

lt.test('使用：收尾时机在所有目标处理完之后，且只触发一次', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (target)
        return game.desk.players
    end)
    : on('生效', function (cardEffect)
        local order = cardEffect.user:getTag('顺序') or ''
        cardEffect.user:setTag('顺序', order .. '生效' .. tostring(game.desk:getIndex(cardEffect.target)))
    end)
]])

    local game, players = newWideGame(3)
    local card = game:createCard('测试杀')
    local user = players[1]
    local hand = assert(user:getZone('手牌'))
    hand:put(card)

    game:on('卡牌-结算后', function (useCard)
        ---@cast useCard UseCard
        local order = useCard.user:getTag('顺序') or ''
        useCard.user:setTag('顺序', order .. '收尾')
    end)

    game:useCard(user, card, { players[2], players[3] })

    lt.assertEquals('两个生效之后才收尾', '生效2生效3收尾', user:getTag('顺序'))
end)

lt.test('使用：牌出手前触发一次时机，早于第一个生效', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (target)
        return { game.desk:getPlayer(2) }
    end)
    : on('生效', function (cardEffect)
        local order = cardEffect.user:getTag('顺序') or ''
        cardEffect.user:setTag('顺序', order .. '生效')
    end)
]])

    local game, user, target, hand = newGame()
    local card = game:createCard('测试杀')
    hand:put(card)

    ---@type (Card?)[]
    local seen = {}
    game:on('卡牌-结算前', function (useCard)
        ---@cast useCard UseCard
        seen[#seen + 1] = useCard.card
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
    : on('获取目标', function (target)
        return game.desk.players
    end)
    : on('生效', function (cardEffect)
        local order = cardEffect.user:getTag('顺序') or ''
        cardEffect.user:setTag('顺序', order .. tostring(game.desk:getIndex(cardEffect.target)))
    end)
]])

    local game, players = newWideGame(3)
    local card = game:createCard('测试杀')
    local user = players[1]
    local hand = assert(user:getZone('手牌'))
    hand:put(card)

    local blocked = players[2]
    game:on('效果-能否生效', function (cardEffect)
        ---@cast cardEffect CardEffect
        if cardEffect.kind == 'cardEffect' and cardEffect.target == blocked then
            return '不让这一次生效'
        end
    end)

    game:useCard(user, card, { players[2], players[3] })

    lt.assertEquals('被阻止的那个没生效，其余的照常', '3', user:getTag('顺序'))
    lt.assertEquals('记牌器留下了这一条', 1, #game:getEffects())
end)

lt.test('使用：声明了 noTarget 就不需要目标', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '无目标牌'
    : noTarget()
    : on('生效', function (cardEffect)
        cardEffect.user:setTag('生效过', true)
    end)
]])

    local game, user, target, hand = newGame()
    local card = game:createCard('无目标牌')
    hand:put(card)

    local ok, reason, legal = game:canUse(user, card)
    lt.assertEquals('不用给目标就能用', true, ok)
    lt.assertEquals('没有原因', nil, reason)
    lt.assertEquals('不给出合法目标（本来就没有）', nil, legal)

    local noTargets = game:useCard(user, card, {})
    lt.assertEquals('零目标也用出去了', nil, noTargets.err)
    lt.assertEquals('牌离开手牌', 0, hand:count())

    lt.assertFailed('给了目标反而不成立', game:useCard(user, card, { target }))
end)

lt.test('使用：无目标牌给目标时给出的原因', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '无目标牌'
    : noTarget()
]])

    local game, user, target, hand = newGame()
    local card = game:createCard('无目标牌')
    hand:put(card)

    local ok, reason = game:canUse(user, card, { target })
    lt.assertEquals('给了目标就不成立', false, ok)
    lt.assertEquals('原因点明不需要目标', '「探针.无目标牌」不需要指定目标', reason)
    lt.assertEquals('牌没被拿走', 1, hand:count())
end)

lt.test('使用：没声明 noTarget 的牌照旧要求非空目标', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '有目标牌'
    : on('获取目标', function (target)
        return { game.desk:getPlayer(2) }
    end)
]])

    local game, user, _, hand = newGame()
    local card = game:createCard('有目标牌')
    hand:put(card)

    lt.assertFailed('fail-closed：不给目标就用不了', game:useCard(user, card, {}))
    lt.assertEquals('牌还留在手上', 1, hand:count())
end)

lt.test('使用：零目标也跑完两个时机与收尾', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '无目标牌'
    : noTarget()
    : on('结算前', function (useCard)
        useCard.user:setTag('顺序', (useCard.user:getTag('顺序') or '') .. '结算前')
    end)
    : on('结算后', function (useCard)
        useCard.user:setTag('顺序', (useCard.user:getTag('顺序') or '') .. '结算后')
    end)
]])

    local game, user, _, hand = newGame()
    local card = game:createCard('无目标牌')
    hand:put(card)

    ---@type string[]
    local events = {}
    game:on('卡牌-结算前', function () events[#events + 1] = '卡牌-结算前' end)
    game:on('卡牌-结算后', function () events[#events + 1] = '卡牌-结算后' end)

    local useCard = game:useCard(user, card, {})

    lt.assertEquals('牌自己的两个时机都跑了', '结算前结算后', user:getTag('顺序'))
    lt.assertEquals('用牌级两个时机也跑了', '卡牌-结算前,卡牌-结算后', table.concat(events, ','))
    lt.assertEquals('这次用牌没有目标', 0, #useCard.targets)
    lt.assertEquals('牌离开手牌', 0, hand:count())
    -- 探针环境里没有 @基础（来源只指探针目录）⇒ 没人把牌安置进临时区，收尾也就无牌可收
    lt.assertEquals('没被安置（安置是 @基础/使用.lua 的事）', nil, card:getZone())
end)

lt.test('定义：数据袋读得回来，重复写以后写的为准', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '有数据的牌'
    : value('攻击范围', 3)
    : value('攻击范围', 4)
    : value('花色名', '红桃')
]])

    local game = select(1, newGame())
    local def  = assert(game:getCard('有数据的牌'))

    lt.assertEquals('后写的覆盖前面的', 4, def:getValue('攻击范围'))
    lt.assertEquals('别的名字各存各的', '红桃', def:getValue('花色名'))
    lt.assertEquals('没声明过的是「不存在」', nil, def:getValue('没有这条'))
end)

lt.test('定义：基类的数据被抄过来，抄完就脱钩', function ()
    local guard <close> = useProbe()
    write('探针/基类.lua', "Card '基类牌' : value('攻击范围', 2) : value('距离修正', -1)")
    write('探针/子类.lua', "Card '子类牌' : extends '基类牌' : value('攻击范围', 5)")

    local game    = select(1, newGame())
    local base    = assert(game:getCard('基类牌'))
    local derived = assert(game:getCard('子类牌'))

    lt.assertEquals('基类的数据抄到了子类', -1, derived:getValue('距离修正'))
    lt.assertEquals('子类自己的数据覆盖基类的', 5, derived:getValue('攻击范围'))
    lt.assertEquals('基类不受影响', 2, base:getValue('攻击范围'))

    derived:value('新加的一条', true)
    lt.assertEquals('抄完就脱钩：子类后加的不会跑到基类', nil, base:getValue('新加的一条'))
end)
