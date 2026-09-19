local lt = require 'test.ltest'

---@class SmokeThing
---@field value integer
local SmokeThing = Class 'SmokeThing'

---@param value integer
function SmokeThing:__init(value)
    self.value = value
end

lt.test('类可声明与实例化', function ()
    local obj = New 'SmokeThing' (7)
    lt.assertEquals('构造参数写入字段', 7, obj.value)
end)

lt.test('可查询实例类型与有效性', function ()
    local obj = New 'SmokeThing' (1)
    lt.assertEquals('类型名', 'SmokeThing', Type(obj))
    lt.assertEquals('有效性', true, IsValid(obj))
    lt.assertEquals('非实例的类型为 nil', nil, Type(1))
end)

lt.test('销毁实例后不再有效', function ()
    local obj = New 'SmokeThing' (2)
    Delete(obj)
    lt.assertEquals('销毁后有效性', false, IsValid(obj))
end)
