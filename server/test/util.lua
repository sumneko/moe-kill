local lt = require 'test.ltest'

lt.test('工具：toList 把单个值与列表统一成列表', function ()
    local card  = lt.card('杀')
    local other = lt.card('闪')
    local list  = { card, other }
    ---@type Card[]
    local empty = {}

    local single = moe.util.toList(card)
    lt.assertEquals('单个值包成一张表', 1, #single)
    lt.assertEquals('包起来的就是那个值', card, single[1])

    lt.assertEquals('已经是列表就原样返回（同一个表）', list, moe.util.toList(list))
    lt.assertEquals('列表原样返回后长度不变', 2, #list)
    lt.assertEquals('空表也是空列表（原样返回）', empty, moe.util.toList(empty))
end)

lt.test('工具：isStrictList 认严格数组，不认空表与非数组', function ()
    local card = lt.card('杀')

    lt.assertEquals('严格数组', true, moe.util.isStrictList({ card }))
    lt.assertEquals('空表不算', false, moe.util.isStrictList({}))
    lt.assertEquals('类实例不算', false, moe.util.isStrictList(card))
    lt.assertEquals('中间缺项的也不算', false, moe.util.isStrictList({ [2] = card }))
end)
