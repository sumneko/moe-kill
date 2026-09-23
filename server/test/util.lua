local lt = require 'test.ltest'

lt.test('工具：toList 把单个值与列表统一成列表', function ()
    local card  = lt.card('杀')
    local other = lt.card('闪')
    local list  = { card, other }

    local single = assert(moe.util.toList(card), '单个值该包成一张表')
    lt.assertEquals('单个值包成一张表', 1, #single)
    lt.assertEquals('包起来的就是那个值', card, single[1])

    lt.assertEquals('已经是列表就原样返回（同一个表）', list, moe.util.toList(list))
    lt.assertEquals('列表原样返回后长度不变', 2, #list)

    lt.assertEquals('空表还是空列表', 0, #assert(moe.util.toList({})))
    lt.assertEquals('给 nil 还是 nil（可选参数保持「没给」）', nil, moe.util.toList(nil))
end)
