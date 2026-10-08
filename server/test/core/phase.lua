local lt = require 'test.ltest'

---@return Game
---@return Player[]
local function newGame()
    local random = moe.random.create(1)
    local game   = moe.game.create { seats = 2, random = random, sources = { lt.emptySource } }
    local desk   = game.desk
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
    return game, players
end

lt.test('阶段：进入时触发阶段-开始，阶段实例就是事件上下文', function ()
    local game, players = newGame()
    ---@type Phase?
    local started = nil
    ---@type Phase?
    local ended = nil
    game:on('阶段-开始', function (phase)
        started = phase
    end)
    game:on('阶段-结束', function (phase)
        ended = phase
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

lt.test('阶段：阶段事件也发给当事人一份，别人收不到', function ()
    local game, players = newGame()
    ---@type string[]
    local mine = {}
    ---@type integer
    local others = 0
    players[1]:on('阶段-开始', function (phase) mine[#mine + 1] = '开始:' .. phase.name end)
    players[1]:on('阶段-结束', function (phase) mine[#mine + 1] = '结束:' .. phase.name end)
    players[2]:on('阶段-开始', function () others = others + 1 end)

    local phase = game:enterPhase(players[1], '出牌')
    Delete(phase)

    lt.assertEquals('当事人开始与结束都收到', '开始:出牌,结束:出牌', table.concat(mine, ','))
    lt.assertEquals('别人一次都没收到', 0, others)
end)

lt.test('阶段：先问全局、再发当事人', function ()
    local game, players = newGame()
    ---@type string[]
    local trace = {}
    game:on('阶段-开始', function () trace[#trace + 1] = '全局' end)
    players[1]:on('阶段-开始', function () trace[#trace + 1] = '当事人' end)

    local phase = game:enterPhase(players[1], '出牌')
    Delete(phase)

    lt.assertEquals('全局先、当事人后', '全局,当事人', table.concat(trace, ','))
end)

lt.test('阶段：「开始」（只通知）先于「生效」（业务），两份都发给当事人', function ()
    local game, players = newGame()
    ---@type string[]
    local trace = {}
    game:on('阶段-开始', function () trace[#trace + 1] = '全局开始' end)
    game:on('阶段-生效', function () trace[#trace + 1] = '全局生效' end)
    players[1]:on('阶段-开始', function () trace[#trace + 1] = '当事人开始' end)
    players[1]:on('阶段-生效', function () trace[#trace + 1] = '当事人生效' end)

    local phase = game:enterPhase(players[1], '摸牌')
    Delete(phase)

    lt.assertEquals('开始先、生效后；各自先全局后当事人',
        '全局开始,当事人开始,全局生效,当事人生效', table.concat(trace, ','))
end)

lt.test('阶段：bindGC 挂的东西随阶段离开放掉（发完「结束」再放）', function ()
    local game, players = newGame()
    ---@type string[]
    local trace = {}
    game:on('阶段-结束', function () trace[#trace + 1] = '结束' end)

    local phase = game:enterPhase(players[1], '摸牌')
    phase:bindGC(function () trace[#trace + 1] = '释放' end)
    lt.assertEquals('还在阶段里：没放', 0, #trace)

    Delete(phase)
    lt.assertEquals('先发「结束」、再放资源', '结束,释放', table.concat(trace, ','))
end)

lt.test('阶段：作用域结束（<close>）就离开', function ()
    local game, players = newGame()
    ---@type string[]
    local marks = {}
    game:on('阶段-开始', function (phase)
        marks[#marks+1] = '开始:' .. phase.name
    end)
    game:on('阶段-结束', function (phase)
        marks[#marks+1] = '结束:' .. phase.name
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

lt.test('阶段：用过次数的账按名字记', function ()
    local game, players = newGame()
    local phase = game:enterPhase(players[1], '出牌')

    lt.assertEquals('一开始没用过', 0, phase:getUseCount('杀'))

    phase:addUseCount('杀', 1)
    phase:addUseCount('杀', 1)
    lt.assertEquals('记两次就是 2', 2, phase:getUseCount('杀'))
    phase:addUseCount('杀', -1)
    lt.assertEquals('可以退回来', 1, phase:getUseCount('杀'))
    lt.assertEquals('别的名字不受影响', 0, phase:getUseCount('闪'))
end)

lt.test('阶段：打出次数的账与使用次数各记各的', function ()
    local game, players = newGame()
    local phase = game:enterPhase(players[1], '出牌')

    lt.assertEquals('一开始没打出过', 0, phase:getPlayCount('杀'))

    phase:addPlayCount('杀', 1)
    phase:addPlayCount('杀', 1)
    lt.assertEquals('记两次就是 2', 2, phase:getPlayCount('杀'))
    phase:addPlayCount('杀', -1)
    lt.assertEquals('可以退回来', 1, phase:getPlayCount('杀'))
    lt.assertEquals('别的名字不受影响', 0, phase:getPlayCount('闪'))
    lt.assertEquals('不混进使用次数的账', 0, phase:getUseCount('杀'))
end)

lt.test('阶段：玩家的 currentPhase 只给属于自己的当前阶段', function ()
    local game, players = newGame()

    lt.assertEquals('不在阶段里：空', nil, players[1]:currentPhase())

    local mine = game:enterPhase(players[1], '出牌')
    lt.assertEquals('自己的阶段：读得到', mine, players[1]:currentPhase())
    lt.assertEquals('别人读不到', nil, players[2]:currentPhase())

    Delete(mine)
    lt.assertEquals('离开后又是空', nil, players[1]:currentPhase())

    local other = game:enterPhase(players[2], '出牌')
    lt.assertEquals('别人的阶段：自己是空', nil, players[1]:currentPhase())
    lt.assertEquals('当事人才读得到', other, players[2]:currentPhase())
    Delete(other)
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
