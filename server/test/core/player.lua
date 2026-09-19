local lt = require 'test.ltest'

---@return Core.AttributeSystem
local function newSystem()
    return moe.core.attribute.create()
end

lt.test('玩家：持有属性实例', function ()
    local system = newSystem()
    system:define('体力上限', { min = 0 })
    local a = moe.core.player.create { attributes = system:createInstance() }
    local b = moe.core.player.create { attributes = system:createInstance() }

    a:getAttributes():set('体力上限', 4)
    b:getAttributes():set('体力上限', 3)

    lt.assertEquals('自己的属性读得到', 4, a:getAttributes():get('体力上限'))
    lt.assertEquals('别人的属性不受影响', 3, b:getAttributes():get('体力上限'))
end)

lt.test('玩家：牌区可增删', function ()
    local system = newSystem()
    local player = moe.core.player.create { attributes = system:createInstance() }

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
    local player = moe.core.player.create { attributes = system:createInstance() }
    player:addZone('手牌区')

    lt.assertError('重复名字报错', function ()
        player:addZone('手牌区')
    end)
end)

lt.test('玩家：标签原样存取', function ()
    local system = newSystem()
    local player = moe.core.player.create { attributes = system:createInstance() }

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

lt.test('玩家：参与行动标记', function ()
    local system = newSystem()
    local player = moe.core.player.create { attributes = system:createInstance() }

    lt.assertEquals('默认参与行动', true, player:isActing())
    player:setActing(false)
    lt.assertEquals('可以清掉', false, player:isActing())
    player:setActing(true)
    lt.assertEquals('可以再置位', true, player:isActing())
end)
