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
    ---@type Player[]
    local players = {}
    for i = 1, 2 do
        local player = moe.player.create { attributes = attributeSystem:createInstance() }
        desk:sit(i, player)
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
    : on('使用', function (ctx)
        ctx.user:setTag('顺序', (ctx.user:getTag('顺序') or '') .. '一')
    end)
    : on('使用', function (ctx)
        ctx.user:setTag('顺序', (ctx.user:getTag('顺序') or '') .. '二')
        ctx.user:setTag('目标', ctx.targets[1])
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
    game.events:on('卡牌-结算后', onSettled)

    game:play(user, card, { target })

    lt.assertEquals('两个使用回调按声明顺序执行', '一二', user:getTag('顺序'))
    lt.assertEquals('回调拿到了目标', target, user:getTag('目标'))
    lt.assertEquals('牌已经离开手牌', 0, hand:count())
    lt.assertEquals('收尾时机拿到这张牌', card, settledCard)
    lt.assertEquals('收尾时机也拿得到目标', target, settledTarget)
end)

lt.test('使用：牌不在使用者手上时报错', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('使用', function (ctx)
        ctx.user:setTag('用了', true)
    end)
]])

    local game, user, target, hand = newGame()
    local card = game:createCard('测试杀')

    lt.assertEquals('探针牌定义已装好', true, game:getCard('测试杀') ~= nil)

    lt.assertError('手上没有这张牌', function ()
        game:play(user, card, { target })
    end)

    lt.assertEquals('结算没跑', nil, user:getTag('用了'))
    lt.assertEquals('手牌还是空的', 0, hand:count())
end)

lt.test('使用：牌没有内容定义时报错', function ()
    local guard <close> = useProbe()
    write('探针/占位.lua', "Card '占位'")

    local game, user, target, hand = newGame()
    local card = game:createCard('没有这张牌')
    hand:put(card)

    lt.assertError('没有定义就用不了', function ()
        game:play(user, card, { target })
    end)

    lt.assertEquals('牌还留在手上', 1, hand:count())
end)

lt.test('使用：给出的目标必须是合法目标的子集', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (ctx)
        return { game.desk:getPlayer(2) }
    end)
    : on('使用', function (ctx)
        ctx.user:setTag('用了', true)
    end)
]])

    local game, user, _, hand = newGame()
    local card = game:createCard('测试杀')
    hand:put(card)

    lt.assertEquals('探针牌定义已装好', true, game:getCard('测试杀') ~= nil)

    lt.assertError('自己不在合法目标里', function ()
        game:play(user, card, { user })
    end)

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

    lt.assertError('漏写钩子不等于谁都能打', function ()
        game:play(user, card, { target })
    end)

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

    lt.assertError('拿不到列表就谁都不给用', function ()
        game:play(user, card, { target })
    end)

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

    lt.assertError('没有合法目标就用不了', function ()
        game:play(user, card, { target })
    end)

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

    lt.assertError('一个目标都不给就用不了', function ()
        game:play(user, card, {})
    end)

    lt.assertEquals('牌还留在手上', 1, hand:count())
end)

lt.test('使用：多个钩子取交集', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (ctx)
        return game.desk:getPlayers()
    end)
    : on('获取目标', function (ctx)
        return { game.desk:getPlayer(2) }
    end)
    : on('使用', function (ctx)
        ctx.user:setTag('用了', true)
    end)
]])

    local game, user, target, hand = newGame()
    local card = game:createCard('测试杀')
    hand:put(card)

    lt.assertError('被前一个钩子收窄掉的目标用不了', function ()
        game:play(user, card, { user })
    end)
    lt.assertEquals('牌还留在手上', 1, hand:count())

    game:play(user, card, { target })

    lt.assertEquals('两个钩子都放行的目标能用', true, user:getTag('用了'))
    lt.assertEquals('牌用出去了', 0, hand:count())
end)

lt.test('使用：结算期间这次使用在栈上', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (ctx)
        return { game.desk:getPlayer(2) }
    end)
    : on('使用', function (ctx)
        ctx.user:setTag('栈顶是这次使用', game:getCurrentEffect() == ctx)
        ctx.user:setTag('种类', ctx.kind)
    end)
]])

    local game, user, target, hand = newGame()
    local card = game:createCard('测试杀')
    hand:put(card)

    lt.assertEquals('探针牌定义已装好', true, game:getCard('测试杀') ~= nil)

    game:play(user, card, { target })

    lt.assertEquals('结算期间栈顶就是这次使用', true, user:getTag('栈顶是这次使用'))
    lt.assertEquals('种类标识', 'useCard', user:getTag('种类'))
    lt.assertEquals('结算完栈空', 0, #game:getEffects())
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

    lt.assertError('不能对自己用', function ()
        game:play(user, card, { user })
    end)

    lt.assertEquals('栈上没有留下这次使用', 0, #game:getEffects())
end)

lt.test('使用：结算中抛错后栈恢复原状', function ()
    local guard <close> = useProbe()
    write('探针/牌.lua', [[
Card '测试杀'
    : on('获取目标', function (ctx)
        return { game.desk:getPlayer(2) }
    end)
    : on('使用', function ()
        error('故意报错')
    end)
]])

    local game, user, target, hand = newGame()
    local card = game:createCard('测试杀')
    hand:put(card)

    lt.assertEquals('探针牌定义已装好', true, game:getCard('测试杀') ~= nil)

    lt.assertError('结算里的错误会传出来', function ()
        game:play(user, card, { target })
    end)

    lt.assertEquals('栈上没有留下这次使用', 0, #game:getEffects())
end)
