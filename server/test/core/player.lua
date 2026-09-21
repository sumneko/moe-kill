local lt = require 'test.ltest'

---@return AttributeSystem
local function newSystem()
    return moe.attribute.create()
end

lt.test('玩家：持有属性实例', function ()
    local system = newSystem()
    system:define('体力上限', { min = 0 })
    local a = moe.player.create { attributes = system:createInstance() }
    local b = moe.player.create { attributes = system:createInstance() }

    a:getAttributes():set('体力上限', 4)
    b:getAttributes():set('体力上限', 3)

    lt.assertEquals('自己的属性读得到', 4, a:getAttributes():get('体力上限'))
    lt.assertEquals('别人的属性不受影响', 3, b:getAttributes():get('体力上限'))
end)

lt.test('玩家：牌区可增删', function ()
    local system = newSystem()
    local player = moe.player.create { attributes = system:createInstance() }

    local undo = player:addZone('手牌区')
    player:addZone('装备区')

    lt.assertEquals('两个牌区都在', 2, #player:getZones())
    lt.assertEquals('按加入顺序', player:getZone('手牌区'), player:getZones()[1])
    lt.assertEquals('按名字查得到', true, player:getZone('装备区') ~= nil)

    undo()
    undo()
    lt.assertEquals('撤销后只剩一个', 1, #player:getZones())
    lt.assertEquals('被撤销的查不到了', nil, player:getZone('手牌区'))
    lt.assertEquals('另一个不受影响', true, player:getZone('装备区') ~= nil)
end)

lt.test('玩家：同名牌区报错', function ()
    local system = newSystem()
    local player = moe.player.create { attributes = system:createInstance() }
    player:addZone('手牌区')

    lt.assertError('重复名字报错', function ()
        player:addZone('手牌区')
    end)
end)

lt.test('玩家：属性读写代理', function ()
    local system = newSystem()
    system:define('体力上限', { min = 0 })
    local player = moe.player.create { attributes = system:createInstance() }

    player:setAttr('体力上限', 4)
    lt.assertEquals('setAttr 写进去', 4, player:getAttr('体力上限'))

    player:addAttr('体力上限', -1)
    lt.assertEquals('addAttr 做增减', 3, player:getAttr('体力上限'))
    lt.assertEquals('与 getAttributes 是同一份数据', 3, player:getAttributes():get('体力上限'))
end)

lt.test('玩家：标签原样存取', function ()
    local system = newSystem()
    local player = moe.player.create { attributes = system:createInstance() }

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
    local player = moe.player.create { attributes = system:createInstance() }

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
    local desk = moe.desk.create(count)
    ---@type Player[]
    local players = {}
    for i = 1, count do
        local system = newSystem()
        local player = moe.player.create { attributes = system:createInstance() }
        desk:sit(i, player)
        players[i] = player
    end
    return moe.game.create { desk = desk, random = moe.random.create(1) }, players
end

lt.test('玩家：默认活着，死亡时触发时机', function ()
    local game, players = newGame(2)
    local dead         = players[1]

    lt.assertEquals('默认活着', true, dead:isAlive())

    ---@type Player?
    local seen = nil
    ---@type integer
    local times = 0
    game:on('玩家-死亡', function (ctx)
        seen  = ctx
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
    local player = moe.player.create { attributes = system:createInstance() }

    player:setAlive(false)

    lt.assertEquals('照常改状态', false, player:isAlive())
end)
