local lt = require 'test.ltest'

---@return Game
---@return Player[]
local function newGame()
    local desk   = moe.desk.create(2)
    local random = moe.random.create(1)
    local game   = moe.game.create { desk = desk, random = random }
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
    return game, players
end

lt.test('阶段：进入时触发阶段-开始，阶段实例就是事件上下文', function ()
    local game, players = newGame()
    ---@type Phase?
    local started = nil
    ---@type Phase?
    local ended = nil
    game:on('阶段-开始', function (ctx)
        started = ctx
    end)
    game:on('阶段-结束', function (ctx)
        ended = ctx
    end)

    local phase = game:enterPhase(players[1], '出牌')

    lt.assertEquals('事件上下文就是这个阶段', phase, started)
    lt.assertEquals('阶段名读得到', '出牌', assert(started).name)
    lt.assertEquals('属于谁读得到', players[1], assert(started).player)
    lt.assertEquals('当前阶段就是它', phase, game.phase)
    lt.assertEquals('还没结束', nil, ended)

    Delete(phase)

    lt.assertEquals('结束后事件也拿到了它', phase, ended)
end)

lt.test('阶段：作用域结束（<close>）就离开', function ()
    local game, players = newGame()
    ---@type string[]
    local marks = {}
    game:on('阶段-开始', function (ctx)
        marks[#marks+1] = '开始:' .. ctx.name
    end)
    game:on('阶段-结束', function (ctx)
        marks[#marks+1] = '结束:' .. ctx.name
    end)

    do
        local phase <close> = game:enterPhase(players[1], '出牌')
        lt.assertEquals('作用域里是当前阶段', phase, game.phase)
        lt.assertEquals('进来时触发一次', '开始:出牌', marks[1])
        lt.assertEquals('还没结束', 1, #marks)
    end

    lt.assertEquals('作用域结束就离开', '开始:出牌,结束:出牌', table.concat(marks, ','))
    lt.assertEquals('当前阶段空了', nil, game.phase)
end)

lt.test('阶段：可以嵌套，内层结束回到外层', function ()
    local game, players = newGame()
    local outer = game:enterPhase(players[1], '出牌')
    local inner = game:enterPhase(players[1], '额外出牌')

    lt.assertEquals('当前是内层', inner, game.phase)

    Delete(inner)
    lt.assertEquals('回到外层', outer, game.phase)

    Delete(outer)
    lt.assertEquals('都离开了', nil, game.phase)
end)

lt.test('阶段：不按嵌套顺序离开要报错', function ()
    local game, players = newGame()
    local outer = game:enterPhase(players[1], '出牌')
    local inner = game:enterPhase(players[1], '额外出牌')

    lt.assertError('先离开外层不行', function () Delete(outer) end)
    lt.assertEquals('当前阶段还是内层', inner, game.phase)

    Delete(inner)
    lt.assertEquals('内层离开后回到那个（已析构的）外层', outer, game.phase)
end)

lt.test('阶段：两本账都按名字记', function ()
    local game, players = newGame()
    local phase = game:enterPhase(players[1], '出牌')

    lt.assertEquals('一开始没用过', 0, phase:getUseCount('杀'))
    lt.assertEquals('一开始没有上限增减', 0, phase:getLimitDelta('杀'))

    phase:addUseCount('杀', 1)
    phase:addUseCount('杀', 1)
    lt.assertEquals('记两次就是 2', 2, phase:getUseCount('杀'))
    phase:addUseCount('杀', -1)
    lt.assertEquals('可以退回来', 1, phase:getUseCount('杀'))
    lt.assertEquals('别的名字不受影响', 0, phase:getUseCount('闪'))

    phase:addLimit('杀', 1)
    phase:addLimit('杀', 1000)
    lt.assertEquals('上限增减会累加', 1001, phase:getLimitDelta('杀'))
    lt.assertEquals('别的名字的上限没动', 0, phase:getLimitDelta('闪'))
end)

lt.test('阶段：标签袋与玩家同形状', function ()
    local game, players = newGame()
    local phase = game:enterPhase(players[1], '出牌')

    lt.assertEquals('没放过就是空', nil, phase:getTag('标记'))
    phase:setTag('标记', '甲')
    lt.assertEquals('读得到', '甲', phase:getTag('标记'))
    phase:removeTag('标记')
    lt.assertEquals('删掉就没了', nil, phase:getTag('标记'))
    lt.assertError('键不能为空', function ()
        phase:setTag('', 1)
    end)
end)

lt.test('阶段：重装规则内容不清阶段栈与账', function ()
    local game, players = newGame()
    local phase = game:enterPhase(players[1], '出牌')
    phase:addUseCount('杀', 1)

    game:resetContent()

    lt.assertEquals('还在这个阶段里', phase, game.phase)
    lt.assertEquals('账也还在', 1, phase:getUseCount('杀'))
end)
