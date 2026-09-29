local lt = require 'test.ltest'

---@return AttributeSystem
local function newSystem()
    return moe.attribute.create()
end

---@param system AttributeSystem
---@return Player
local function newPlayer(system)
    local game = moe.game.create { seats = 1, random = moe.random.create(1) }
    return moe.player.create(game, { attributes = system:createInstance() })
end

lt.test('玩家：持有属性实例', function ()
    local system = newSystem()
    system:define('体力上限', { min = 0 })
    local a = newPlayer(system)
    local b = newPlayer(system)

    a:getAttributes():set('体力上限', 4)
    b:getAttributes():set('体力上限', 3)

    lt.assertEquals('自己的属性读得到', 4, a:getAttributes():get('体力上限'))
    lt.assertEquals('别人的属性不受影响', 3, b:getAttributes():get('体力上限'))
end)

lt.test('玩家：内核建好手牌 / 装备 / 判定三个区', function ()
    local player = newPlayer(newSystem())

    lt.assertEquals('三个区都在', 3, #player:getZones())
    lt.assertEquals('手牌区', true, player:getZone('手牌') ~= nil)
    lt.assertEquals('装备区', true, player:getZone('装备') ~= nil)
    lt.assertEquals('判定区', true, player:getZone('判定') ~= nil)
    lt.assertEquals('手牌区按加入顺序在前', player:getZone('手牌'), player:getZones()[1])

    local other = newPlayer(newSystem())
    player:getZone('手牌'):setVisible(false)
    lt.assertEquals('归属记在持有者身上', false, player:getZone('手牌'):isVisibleTo(other))
end)

lt.test('玩家：装备区是槽位区，槽位由内容侧在游戏开始时设置', function ()
    local system = newSystem()
    local game   = moe.game.create { seats = 1, random = moe.random.create(1) }
    local player = moe.player.create(game, { attributes = system:createInstance() })

    lt.assertEquals('装备区是槽位区', 'slotZone', player:getZone('装备').kind)
    lt.assertEquals('内核建出来时没有槽位（等内容侧在游戏开始时设）', 0,
        #player:getZone('装备').slots)
    lt.assertEquals('判定区是有序区（结算顺序 = 进入顺序，后入先出）', 'orderedZone', player:getZone('判定').kind)
end)

lt.test('玩家：牌区可增删', function ()
    local system = newSystem()
    local player = newPlayer(system)

    local undo = player:addZone('手牌区')
    player:addZone('装备区')

    lt.assertEquals('两个自建牌区都在', 5, #player:getZones())
    lt.assertEquals('按加入顺序排在后面', player:getZone('手牌区'), player:getZones()[4])
    lt.assertEquals('按名字查得到', true, player:getZone('装备区') ~= nil)

    undo()
    undo()
    lt.assertEquals('撤销后少一个', 4, #player:getZones())
    lt.assertEquals('被撤销的查不到了', nil, player:getZone('手牌区'))
    lt.assertEquals('另一个不受影响', true, player:getZone('装备区') ~= nil)
end)

lt.test('玩家：同名牌区报错', function ()
    local system = newSystem()
    local player = newPlayer(system)
    player:addZone('手牌区')

    lt.assertError('重复名字报错', function ()
        player:addZone('手牌区')
    end)
end)

lt.test('玩家：内核建过的名字不能再建', function ()
    local player = newPlayer(newSystem())

    lt.assertError('手牌区不能再建', function ()
        player:addZone('手牌')
    end)
end)

lt.test('玩家：属性读写代理', function ()
    local system = newSystem()
    system:define('体力上限', { min = 0 })
    local player = newPlayer(system)

    player:setAttr('体力上限', 4)
    lt.assertEquals('setAttr 写进去', 4, player:getAttr('体力上限'))

    player:addAttr('体力上限', -1)
    lt.assertEquals('addAttr 做增减', 3, player:getAttr('体力上限'))
    lt.assertEquals('与 getAttributes 是同一份数据', 3, player:getAttributes():get('体力上限'))
end)

lt.test('玩家：addAttr 返回的撤销函数只减掉自己那条', function ()
    local system = newSystem()
    system:define('体力上限', { min = 0 })
    local player = newPlayer(system)
    player:setAttr('体力上限', 4)

    local undo  = player:addAttr('体力上限', 2)
    local other = player:addAttr('体力上限', 1)
    lt.assertEquals('两条加成都在', 7, player:getAttr('体力上限'))

    undo()
    lt.assertEquals('撤掉的那条只减 2', 5, player:getAttr('体力上限'))

    undo()
    lt.assertEquals('再撤一次不变（幂等）', 5, player:getAttr('体力上限'))

    other()
    lt.assertEquals('撤完回到原值', 4, player:getAttr('体力上限'))
end)

lt.test('玩家：标签原样存取', function ()
    local system = newSystem()
    local player = newPlayer(system)

    player:setTag('身份', '主公')
    lt.assertEquals('读到的就是写入的', '主公', player:getTag('身份'))
    lt.assertEquals('标签可以放非字符串', true, (function ()
        player:setTag('某表', { 1, 2 })
        return type(player:getTag('某表')) == 'table'
    end)())
    lt.assertEquals('没写过的标签读到不存在', nil, player:getTag('没写过'))

    player:removeTag('身份')
    lt.assertEquals('移除后读到不存在', nil, player:getTag('身份'))
end)

lt.test('玩家：参与行动由存活派生', function ()
    local system = newSystem()
    local player = newPlayer(system)

    lt.assertEquals('默认参与行动', true, player.acting)

    player:setAlive(false)
    lt.assertEquals('阵亡后不再参与', false, player.acting)

    player:setAlive(true)
    lt.assertEquals('复活后又参与', true, player.acting)
end)

---@param count integer
---@return Game # 一个装着这些玩家的局（座位号 = 参数顺序）
---@return Player[]
local function newGame(count)
    local game = moe.game.create { seats = count, random = moe.random.create(1) }
    local desk = game.desk
    ---@type Player[]
    local players = {}
    for i = 1, count do
        local system = newSystem()
        local player = moe.player.create(game, { attributes = system:createInstance() })
        desk:sit(i, player)
        players[i] = player
    end
    return game, players
end

lt.test('玩家：默认活着，死亡时触发时机', function ()
    local game, players = newGame(2)
    local dead         = players[1]

    lt.assertEquals('默认活着', true, dead:isAlive())

    ---@type Player?
    local seen = nil
    ---@type integer
    local times = 0
    game:on('玩家-死亡', function (player)
        seen  = player
        times = times + 1
    end)

    dead:setAlive(false)

    lt.assertEquals('状态变了', false, dead:isAlive())
    lt.assertEquals('时机收到的就是死者', dead, seen)
    lt.assertEquals('只触发一次', 1, times)
    lt.assertEquals('别人不受影响', true, players[2]:isAlive())

    dead:setAlive(false)
    lt.assertEquals('重复置死不再触发', 1, times)

    dead:setAlive(true)
    lt.assertEquals('可以复活', true, dead:isAlive())

    dead:setAlive(false)
    lt.assertEquals('再死一次会再触发', 2, times)
end)

lt.test('玩家：没上桌的玩家也能置存活状态', function ()
    local system = newSystem()
    local player = newPlayer(system)

    player:setAlive(false)

    lt.assertEquals('照常改状态', false, player:isAlive())
end)

lt.test('玩家：自己的时机表与别人互不干扰', function ()
    local a = newPlayer(newSystem())
    local b = newPlayer(newSystem())

    ---@type string[]
    local log = {}
    a:on('测试-时机', function () log[#log + 1] = 'a' end)
    b:on('测试-时机', function () log[#log + 1] = 'b' end)

    a:fire('测试-时机')
    lt.assertEquals('只触发自己名下的订阅', 'a', table.concat(log, ','))

    b:fire('测试-时机')
    lt.assertEquals('各问各的', 'a,b', table.concat(log, ','))
end)

lt.test('玩家：注册顺序即执行顺序，撤销只影响那一次', function ()
    local player = newPlayer(newSystem())
    ---@type integer[]
    local log = {}
    player:on('甲', function () log[#log + 1] = 1 end)
    local undo = player:on('甲', function () log[#log + 1] = 2 end)
    player:on('甲', function () log[#log + 1] = 3 end)

    player:fire('甲')
    lt.assertEquals('按注册顺序执行', '1,2,3', table.concat(log, ','))

    undo()
    undo()
    log = {}
    player:fire('甲')
    lt.assertEquals('撤销的是那一次注册，重复撤销安全', '1,3', table.concat(log, ','))
end)

lt.test('玩家：疑问式看返回值，修正式收全部', function ()
    local player = newPlayer(newSystem())
    player:on('问', function () end)
    player:on('问', function () return '原因' end)
    player:on('问', function () return '不该轮到我' end)
    lt.assertEquals('第一个明确返回值即结论（快速返回）', '原因', player:fire('问'))

    player:on('修正', function () return 1 end)
    player:on('修正', function () return 2 end)
    lt.assertEquals('收集所有返回值', '1,2', table.concat(player:collect('修正'), ','))
end)

lt.test('玩家：时机名必须是非空字符串', function ()
    local player = newPlayer(newSystem())

    lt.assertError('空串订阅报错', function ()
        player:on('', function () end)
    end)
    lt.assertError('空串触发报错', function ()
        player:fire('')
    end)
end)
