local lt = require 'test.ltest'

lt.test('牌：标识与牌名都由调用方给出', function ()
    local card = moe.card.create(lt.game(), '杀', 7)

    lt.assertEquals('标识就是给进来的号', 7, card:getId())
    lt.assertEquals('牌名就是给进来的那个值', '杀', card.name)

    local other = moe.card.create(lt.game(), '闪', 8)
    lt.assertEquals('两张牌各自用各自的号', false, card:getId() == other:getId())
end)

lt.test('牌：没给牌名建不出来', function ()
    lt.assertError('空牌名直接报错', function ()
        moe.card.create(lt.game(), '', 9)
    end)
end)

lt.test('牌：内核不解释牌名与牌面，只搬运内容给的取值', function ()
    local card = lt.card('杀')
    local keys = {}

    for key in pairs(card) do
        if type(key) == 'string' and key:sub(1, 2) ~= '__' then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    lt.assertEquals('没给牌面时的字段就是这三样', 'game,id,name', table.concat(keys, ','))

    ---@type any
    local raw = card
    lt.assertEquals('没有名称字段', nil, raw['名称'])
    lt.assertEquals('没有效果字段', nil, raw['效果'])
end)

lt.test('牌：花色与点数直接读字段', function ()
    local card = moe.card.create(lt.game(), '杀', 7, '黑桃', 9)

    lt.assertEquals('花色就是给进来的那个', '黑桃', card.suit)
    lt.assertEquals('点数就是给进来的那个', 9, card.point)

    local plain = moe.card.create(lt.game(), '闪', 8)
    lt.assertEquals('没给花色就是空', nil, plain.suit)
    lt.assertEquals('没给点数就是空', nil, plain.point)
end)
