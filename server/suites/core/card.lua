local lt = require 'suites.ltest'

lt.test('牌：每个实例有唯一标识', function ()
    local first  = moe.core.card.create('杀')
    local second = moe.core.card.create('杀')
    local marks  = {}

    for i = 1, 100 do
        local card = moe.core.card.create()
        lt.assertNotEquals('标识不与既有的重复', first:getId(), card:getId())
        lt.assertEquals('标识未被用过', nil, marks[card:getId()])
        marks[card:getId()] = true
    end

    lt.assertNotEquals('标签相同的两张牌可区分', first:getId(), second:getId())
end)

lt.test('牌：标签由调用方给出且可修改', function ()
    local plain = moe.core.card.create()
    lt.assertEquals('默认没有标签', nil, plain:getLabel())

    local card = moe.core.card.create('杀')
    lt.assertEquals('创建时给出标签', '杀', card:getLabel())

    card:setLabel('闪')
    lt.assertEquals('标签可修改', '闪', card:getLabel())
    lt.assertEquals('标识不随标签变化', card:getId(), card:getId())
end)

lt.test('牌：内核不预设任何牌的定义', function ()
    local card = moe.core.card.create('杀')
    local keys = {}

    for key in pairs(card) do
        if type(key) == 'string' and key:sub(1, 2) ~= '__' then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    lt.assertEquals('只有标识与标签两类字段', 'id,label', table.concat(keys, ','))

    ---@type any
    local raw = card
    lt.assertEquals('没有名称字段', nil, raw['名称'])
    lt.assertEquals('没有花色字段', nil, raw['花色'])
    lt.assertEquals('没有点数字段', nil, raw['点数'])
    lt.assertEquals('没有效果字段', nil, raw['效果'])
end)
