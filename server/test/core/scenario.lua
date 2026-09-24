local lt = require 'test.ltest'

---@param zone Zone
---@return string
local function zoneLabels(zone)
    local list  = zone:list()
    local names = {}
    for i = 1, #list do
        names[i] = tostring(list[i].name)
    end
    return table.concat(names, ',')
end

lt.test('场景：调用方自己组合出「发牌」', function ()
    local pile = lt.orderedZone()
    local hand = lt.zone()

    for i = 1, 10 do
        pile:put(lt.card('第{}张' % { i }))
    end
    pile:shuffle(moe.random.create(20260919))

    local top3 = {}
    for i = 1, 3 do
        local card = pile:takeTop()
        top3[i] = tostring(card.name)
        hand:put(card)
    end

    lt.assertEquals('抽牌少三张', 7, pile:count())
    lt.assertEquals('手牌三张', 3, hand:count())
    lt.assertEquals('发到手里的就是取顶的那三张', table.concat(top3, ','), zoneLabels(hand))
end)

lt.test('场景：用移动一次把牌送进牌区', function ()
    local pile  = lt.orderedZone()
    local hand  = lt.zone()
    local cards = {}

    for i = 1, 5 do
        cards[i] = lt.card('第{}张' % { i })
        pile:put(cards[i])
    end

    pile:move(cards[3], hand, 1)

    lt.assertEquals('抽牌少一张', 4, pile:count())
    lt.assertEquals('手牌区多一张且在顶部', '第3张', zoneLabels(hand))
end)

lt.test('场景：属性名与取值全由调用方决定', function ()
    local system = moe.attribute.create()
    system:define('体力', { min = 0, max = 4 })
    system:define('手牌上限', { min = 0, max = 20 })

    local attrs = system:createInstance()
    attrs:set('体力', 3)
    attrs:set('手牌上限', 6)

    lt.assertEquals('自定义属性可读写', 3, attrs:get('体力'))
    lt.assertEquals('上限随声明生效', 4, attrs:getMax('体力'))
    lt.assertEquals('另一个自定义属性独立', 6, attrs:get('手牌上限'))
    lt.assertError('内核没有预设的名字', function () attrs:get('魔力') end)
end)
