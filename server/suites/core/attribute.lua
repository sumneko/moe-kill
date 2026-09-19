local lt = require 'suites.ltest'

---@return Core.AttributeSystem
local function createSystem()
    local system = moe.core.attribute.create()
    system:define('体力', { min = 0, max = 5 })
    system:define('攻击距离', { min = 1, max = 3 })
    return system
end

lt.test('属性：按调用方声明的名字读写', function ()
    local system = createSystem()
    local attrs  = system:createInstance()

    lt.assertEquals('初值为 0', 0, attrs:get('体力'))
    lt.assertEquals('上下限可读', 0, attrs:getMin('体力'))
    lt.assertEquals('上限可读', 5, attrs:getMax('体力'))

    attrs:set('体力', 3)
    lt.assertEquals('写入后读回', 3, attrs:get('体力'))

    attrs:add('体力', 1)
    lt.assertEquals('增加生效', 4, attrs:get('体力'))
    attrs:add('体力', -2)
    lt.assertEquals('减少生效', 2, attrs:get('体力'))

    lt.assertEquals('其它属性不受影响', 0, attrs:get('攻击距离'))
end)

lt.test('属性：内核不预设任何属性名', function ()
    local system = moe.core.attribute.create()
    local attrs  = system:createInstance()

    lt.assertError('未声明的名字读不到', function () attrs:get('体力') end)
    lt.assertError('未声明的名字写不了', function () attrs:set('体力', 1) end)
    lt.assertError('未声明的名字不能增减', function () attrs:add('体力', 1) end)
end)

lt.test('属性：写入与增减都受上下限约束', function ()
    local system = createSystem()
    local attrs  = system:createInstance()

    attrs:set('体力', 99)
    lt.assertEquals('写入不超过上限', 5, attrs:get('体力'))

    attrs:add('体力', -99)
    lt.assertEquals('减少不低于下限', 0, attrs:get('体力'))

    attrs:set('体力', -3)
    lt.assertEquals('写入不低于下限', 0, attrs:get('体力'))

    attrs:set('攻击距离', 100)
    lt.assertEquals('另一属性的上限同样生效', 3, attrs:get('攻击距离'))

    local fresh = system:createInstance()
    lt.assertEquals('从未写入过时读数为 0，下限只在写入时钳制', 0, fresh:get('攻击距离'))
end)

lt.test('属性：实例之间相互独立', function ()
    local system = createSystem()
    local first  = system:createInstance()
    local second = system:createInstance()

    first:set('体力', 4)
    lt.assertEquals('第一个实例已修改', 4, first:get('体力'))
    lt.assertEquals('第二个实例不受影响', 0, second:get('体力'))

    second:set('攻击距离', 2)
    lt.assertEquals('第二个实例已修改', 2, second:get('攻击距离'))
    lt.assertEquals('第一个实例仍未被写入', 0, first:get('攻击距离'))
end)

lt.test('属性：写入后就地分发通知', function ()
    local system = createSystem()
    local attrs  = system:createInstance()
    local seen   = {}

    local off = attrs:onChange('体力', function (_, newValue, oldValue)
        seen[#seen + 1] = '{} -> {}' % { oldValue, newValue }
    end)

    attrs:set('体力', 3)
    lt.assertEquals('写入后立即通知', 1, #seen)
    lt.assertEquals('通知带新旧取值', '0 -> 3', seen[1])

    attrs:set('体力', 3)
    lt.assertEquals('取值未变不重复通知', 1, #seen)

    attrs:add('体力', 2)
    lt.assertEquals('增减同样立即通知', 2, #seen)
    lt.assertEquals('第二次通知内容', '3 -> 5', seen[2])

    off()
    attrs:add('体力', -1)
    lt.assertEquals('取消订阅后不再通知', 2, #seen)
end)

lt.test('属性：订阅只关心被订阅的属性', function ()
    local system = createSystem()
    local attrs  = system:createInstance()
    local seen   = {}

    attrs:onChange('体力', function (_, newValue)
        seen[#seen + 1] = newValue
    end)

    attrs:set('攻击距离', 2)
    lt.assertEquals('其它属性变化不触发', 0, #seen)

    attrs:set('体力', 1)
    lt.assertEquals('被订阅属性变化触发', 1, #seen)
end)

lt.test('属性：回调里再修改也能继续分发', function ()
    local system = createSystem()
    local attrs  = system:createInstance()
    local seen   = {}

    attrs:onChange('体力', function (_, newValue)
        seen[#seen + 1] = newValue
        if newValue == 2 then
            attrs:add('体力', 1)
        end
    end)

    attrs:set('体力', 2)
    lt.assertEquals('嵌套修改同样被分发', 2, #seen)
    lt.assertEquals('第二次通知是新取值', 3, seen[2])
    lt.assertEquals('最终取值', 3, attrs:get('体力'))
end)

lt.test('属性：实例创建后不能新增定义', function ()
    local system = createSystem()
    system:createInstance()

    lt.assertError('新增定义失败', function ()
        system:define('怒气', { min = 0, max = 3 })
    end)

    local attrs = system:createInstance()
    lt.assertError('新名字仍然不可用', function () attrs:get('怒气') end)
end)

lt.test('属性：属性名必须是非空字符串', function ()
    local system = moe.core.attribute.create()

    ---@type any
    local notString = 1
    lt.assertError('名字不是字符串', function () system:define(notString) end)
    lt.assertError('名字为空串', function () system:define('') end)
end)
