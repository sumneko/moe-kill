local lt = require 'test.ltest'

---@param zone Zone
---@param source string[]
---@return Card[]
local function fill(zone, source)
    local cards = {}
    for i = 1, #source do
        cards[i] = moe.card.create(source[i])
        zone:put(cards[i])
    end
    return cards
end

---@param zone Zone
---@return string
local function zoneLabels(zone)
    local list  = zone:list()
    local names = {}
    for i = 1, #list do
        names[i] = tostring(list[i]:getLabel())
    end
    return table.concat(names, ',')
end

lt.test('移动：跨区移动改变两边的计数与顺序', function ()
    local from  = moe.zone.create()
    local to    = moe.zone.create()
    local cards = fill(from, { '甲', '乙', '丙' })
    fill(to, { '一', '二' })

    local moved = from:move(cards[2], to, -1)

    lt.assertEquals('返回被移动的牌', cards[2], moved)
    lt.assertEquals('源区少了一张', 2, from:count())
    lt.assertEquals('源区剩余顺序', '甲,丙', zoneLabels(from))
    lt.assertEquals('目标区多了一张并落在底部', '一,二,乙', zoneLabels(to))
end)

lt.test('移动：位置 1 是顶、-1 与省略是底', function ()
    local from  = moe.zone.create()
    local to    = moe.zone.create()
    local cards = fill(from, { '甲', '乙', '丙' })
    fill(to, { '一', '二' })

    from:move(cards[1], to, 1)
    lt.assertEquals('1 = 顶部', '甲,一,二', zoneLabels(to))

    from:move(cards[2], to, -1)
    lt.assertEquals('-1 = 底部', '甲,一,二,乙', zoneLabels(to))

    from:move(cards[3], to)
    lt.assertEquals('省略位置视同底部', '甲,一,二,乙,丙', zoneLabels(to))
end)

lt.test('移动：其它下标按从顶部数或从底部数解释', function ()
    local from  = moe.zone.create()
    local to    = moe.zone.create()
    local cards = fill(from, { '甲', '乙', '丙', '丁' })
    fill(to, { '一', '二', '三' })

    from:move(cards[1], to, 2)
    lt.assertEquals('2 = 插到第二位', '一,甲,二,三', zoneLabels(to))

    from:move(cards[2], to, -2)
    lt.assertEquals('-2 = 插到倒数第二位', '一,甲,二,乙,三', zoneLabels(to))
end)

lt.test('移动：同一牌区内移动就是重排', function ()
    local zone  = moe.zone.create()
    local cards = fill(zone, { '甲', '乙', '丙' })

    zone:move(cards[3], zone, 1)
    lt.assertEquals('移到顶部', '丙,甲,乙', zoneLabels(zone))
    lt.assertEquals('数量不变', 3, zone:count())

    zone:move(cards[3], zone)
    lt.assertEquals('移到底部', '甲,乙,丙', zoneLabels(zone))
    lt.assertEquals('数量仍不变', 3, zone:count())
end)

lt.test('移动：牌不在源区时报错且两边不变', function ()
    local from    = moe.zone.create()
    local to      = moe.zone.create()
    local stranger = moe.card.create('丙')
    fill(from, { '甲', '乙' })
    fill(to, { '一' })

    lt.assertError('源区没有这张牌', function () from:move(stranger, to, 1) end)
    lt.assertEquals('源区不变', '甲,乙', zoneLabels(from))
    lt.assertEquals('目标区不变', '一', zoneLabels(to))
end)

lt.test('移动：任一端被禁用都失败', function ()
    local from  = moe.zone.create()
    local to    = moe.zone.create()
    local cards = fill(from, { '甲' })
    fill(to, { '一' })

    from:disable()
    lt.assertError('源区禁用', function () from:move(cards[1], to, 1) end)
    lt.assertEquals('禁用时的源区不变', '甲', zoneLabels(from))

    from:enable()
    to:disable()
    lt.assertError('目标区禁用', function () from:move(cards[1], to, 1) end)
    lt.assertEquals('禁用时的源区不变（二）', '甲', zoneLabels(from))
    lt.assertEquals('禁用时的目标区不变', '一', zoneLabels(to))
end)

lt.test('移动：位置越界或不是整数时报错', function ()
    local from  = moe.zone.create()
    local to    = moe.zone.create()
    local cards = fill(from, { '甲' })

    lt.assertError('位置 0', function () from:move(cards[1], to, 0) end)
    lt.assertError('位置超出顶部范围', function () from:move(cards[1], to, 2) end)
    lt.assertError('位置超出底部范围', function () from:move(cards[1], to, -2) end)

    ---@type any
    local notInteger = 1.5
    lt.assertError('位置不是整数', function () from:move(cards[1], to, notInteger) end)

    lt.assertEquals('一直没动过', '甲', zoneLabels(from))
    lt.assertEquals('目标区一直为空', 0, to:count())
end)

lt.test('归属：放进牌区就记得住自己在哪里', function ()
    local zone = moe.zone.create()
    local card = moe.card.create('甲')

    lt.assertEquals('一开始不属于任何牌区', nil, card:getZone())

    zone:put(card)
    lt.assertEquals('放进后记得住', zone, card:getZone())

    zone:take(1)
    lt.assertEquals('取出来后不再属于任何牌区', nil, card:getZone())
end)

lt.test('归属：移动后跟着到目标区', function ()
    local from = moe.zone.create()
    local to   = moe.zone.create()
    local card = moe.card.create('甲')
    from:put(card)

    from:move(card, to)

    lt.assertEquals('归属改成目标区', to, card:getZone())
    lt.assertEquals('目标区拿得到它', card, to:peek(to:count()))
end)

lt.test('归属：清空后不再属于任何牌区', function ()
    local zone  = moe.zone.create()
    local cards = fill(zone, { '甲', '乙' })

    lt.assertEquals('清掉两张', 2, zone:clear())
    lt.assertEquals('第一张没有归属了', nil, cards[1]:getZone())
    lt.assertEquals('第二张没有归属了', nil, cards[2]:getZone())
end)

lt.test('归属：已经在牌区里的牌不能再放一次', function ()
    local first  = moe.zone.create()
    local second = moe.zone.create()
    local card   = moe.card.create('甲')
    first:put(card)

    lt.assertError('不能再放进别的区', function () second:put(card) end)
    lt.assertEquals('别的区仍然是空的', 0, second:count())
    lt.assertEquals('归属没变', first, card:getZone())

    lt.assertError('在同一个区里也不能再放一次', function () first:put(card) end)
    lt.assertEquals('同一个区里没有重复', 1, first:count())
end)

lt.test('移动：手牌放进有序牌区顶部后即可被取顶', function ()
    local pile  = moe.orderedZone.create()
    local hand  = moe.zone.create()
    local pileCards = fill(pile, { '甲', '乙', '丙' })
    local handCards = fill(hand, { '闪' })

    hand:move(handCards[1], pile, 1)

    lt.assertEquals('牌堆顶是刚移入的牌', '闪', pile:peek(1):getLabel())
    lt.assertEquals('牌堆容量增加', 4, pile:count())
    lt.assertEquals('手牌清空', 0, hand:count())
    lt.assertEquals('取顶拿到的就是它', '闪', pile:takeTop():getLabel())
    lt.assertEquals('取顶后剩余顺序不变', '甲,乙,丙', zoneLabels(pile))
    lt.assertNotEquals('原来的牌都还在', nil, pileCards[1])
end)
