local lt = require 'suites.ltest'

lt.test('可选链：字段与索引短路', function ()
    local nested = { b = { c = 42 } }
    local absent
    local list = { 10, 20 }

    lt.assertEquals('链式取值', 42, nested?.b?.c)
    lt.assertEquals('混合链', 42, nested?.b.c)
    lt.assertEquals('nil 短路', nil, absent?.b?.c)
    lt.assertEquals('索引访问', 20, list?[2])
    lt.assertEquals('索引短路', nil, absent?[1])
end)

lt.test('可选链：方法与函数调用', function ()
    local counter = { name = 'x', calls = 0 }
    function counter:greet()
        self.calls = self.calls + 1
        return self.name
    end

    local fn = function ()
        return 'ok'
    end
    local absent

    lt.assertEquals('方法调用', 'x', counter?:greet())
    lt.assertEquals('调用计数', 1, counter.calls)
    lt.assertEquals('方法短路', nil, absent?:greet())
    lt.assertEquals('函数调用', 'ok', fn?())
    lt.assertEquals('函数短路', nil, absent?())
end)

lt.test('可选链：方法调用保留多返回值', function ()
    local counter = {}
    function counter:many()
        return 1, 2
    end

    local first = counter?:many()
    local m1, m2 = counter?:many()

    lt.assertEquals('取第一个', 1, first)
    lt.assertEquals('多返回值第一项', 1, m1)
    lt.assertEquals('多返回值第二项', 2, m2)
end)

lt.test('可选链：短路时不求值后续链节', function ()
    local absent
    local evaluated = false
    local function effect()
        evaluated = true
        return { value = 1 }
    end

    lt.assertEquals('短路返回 nil', nil, absent?.x?.y)
    lt.assertEquals('后续未求值', false, evaluated)
    lt.assertEquals('非短路时求值', 1, effect()?.value)
    lt.assertEquals('确实求值了', true, evaluated)
end)
