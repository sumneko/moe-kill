local lt = require 'test.ltest'

---@param zone Zone
---@param source string[]
---@return Card[]
local function fill(zone, source)
    local cards = {}
    for i = 1, #source do
        cards[i] = lt.card(source[i])
        zone:accept(cards[i])
    end
    return cards
end

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

lt.test('收牌：跨区收进来时两边的计数与顺序都对', function ()
    local from  = lt.zone()
    local to    = lt.zone()
    local cards = fill(from, { '甲', '乙', '丙' })
    fill(to, { '一', '二' })

    lt.assertEquals('返回是否成功', true, to:accept(cards[2]))
    lt.assertEquals('源区少了一张', 2, from:count())
    lt.assertEquals('源区剩余顺序', '甲,丙', zoneLabels(from))
    lt.assertEquals('目标区多了一张并落在底部', '一,二,乙', zoneLabels(to))
end)

lt.test('归属：放进牌区就记得住自己在哪里', function ()
    local zone = lt.zone()
    local card = lt.card('甲')

    lt.assertEquals('一开始不属于任何牌区', nil, card:getZone())

    zone:accept(card)
    lt.assertEquals('放进后记得住', zone, card:getZone())

    zone:clear()
    lt.assertEquals('清空后不再属于任何牌区', nil, card:getZone())
end)

lt.test('归属：换区后跟着到目标区', function ()
    local from = lt.zone()
    local to   = lt.zone()
    local card = lt.card('甲')
    from:accept(card)

    to:accept(card)

    lt.assertEquals('归属改成目标区', to, card:getZone())
    lt.assertEquals('源区不再有它', 0, from:count())
    lt.assertEquals('目标区拿得到它', card, to:peek(to:count()))
end)

lt.test('归属：清空后不再属于任何牌区', function ()
    local zone  = lt.zone()
    local cards = fill(zone, { '甲', '乙' })

    lt.assertEquals('清掉两张', 2, zone:clear())
    lt.assertEquals('第一张没有归属了', nil, cards[1]:getZone())
    lt.assertEquals('第二张没有归属了', nil, cards[2]:getZone())
end)

lt.test('随区容器：牌离开牌区时撤销挂在它上面的东西', function ()
    local from = lt.zone()
    local to   = lt.zone()
    local card = lt.card('甲')
    from:accept(card)

    ---@type integer
    local times = 0
    card:withZone(function () times = times + 1 end)

    to:accept(card)
    lt.assertEquals('换区就跑了一次', 1, times)

    to:clear()
    lt.assertEquals('清空不会重复跑（容器已经扔掉）', 1, times)

    to:accept(card)
    to:clear()
    lt.assertEquals('清空也算离开区', 1, times)
end)

lt.test('随区容器：没挂过东西的牌不建容器（懒建）', function ()
    local zone = lt.zone()
    local card = lt.card('甲')
    zone:accept(card)

    ---@diagnostic disable-next-line: invisible
    lt.assertEquals('没挂过就没有容器', nil, card.zoneGCHost)

    card:withZone(function () end)
    ---@diagnostic disable-next-line: invisible
    lt.assertEquals('挂过一次才有容器', true, card.zoneGCHost ~= nil)
end)

lt.test('归属：牌在别的区也能直接收过来（跨区搬运）', function ()
    local first  = lt.zone()
    local second = lt.zone()
    local card   = lt.card('甲')
    first:accept(card)

    lt.assertEquals('收下了', true, second:accept(card))
    lt.assertEquals('源区空了', 0, first:count())
    lt.assertEquals('进了目标区', 1, second:count())
    lt.assertEquals('归属跟着走', second, card:getZone())

    lt.assertEquals('在同一个区里再收一次也算收下（移到末尾）', true, second:accept(card))
    lt.assertEquals('同一个区里没有重复', 1, second:count())
end)

lt.test('收牌：一批牌一起收进来，从哪个区来都行', function ()
    local first  = lt.zone()
    local second = lt.zone()
    local to     = lt.zone()
    local a      = lt.card('甲')
    local b      = lt.card('乙')
    first:accept(a)
    second:accept(b)

    lt.assertEquals('返回是否成功', true, to:accept({ a, b }))
    lt.assertEquals('两个源区都空了', 0, first:count() + second:count())
    lt.assertEquals('目标区按给的顺序收', '甲,乙', zoneLabels(to))
    lt.assertEquals('归属跟着走', to, a:getZone())
    lt.assertEquals('归属跟着走（二）', to, b:getZone())

    local ok, why = to:accept(lt.card('丙'), '武器')
    lt.assertEquals('不是槽位区却给了槽位名 ⇒ 失败', false, ok)
    lt.assertEquals('而且说出原因', '这个牌区不是槽位区', why)
    lt.assertEquals('失败时什么都不改', 2, to:count())
end)

lt.test('收牌：被禁用的区收不下，也不动牌', function ()
    local from = lt.zone()
    local to   = lt.zone()
    local card = lt.card('甲')
    from:accept(card)
    to:disable()

    local ok, why = to:accept(card)
    lt.assertEquals('禁用区收不下', false, ok)
    lt.assertEquals('而且说出原因', '这个牌区被禁用了', why)
    lt.assertEquals('源区没少牌', 1, from:count())
    lt.assertEquals('归属没变', from, card:getZone())
end)

lt.test('收牌：收进有序牌区是追加到底部，取顶拿到的还是原来那张', function ()
    local pile  = lt.orderedZone()
    local hand  = lt.zone()
    local pileCards = fill(pile, { '甲', '乙', '丙' })
    local handCards = fill(hand, { '闪' })

    lt.assertEquals('收下', true, pile:accept(handCards[1]))

    lt.assertEquals('牌堆顶没变', '甲', assert(pile:peek(1)).name)
    lt.assertEquals('牌堆容量增加', 4, pile:count())
    lt.assertEquals('手牌清空', 0, hand:count())
    lt.assertEquals('刚收进来的在底部', '闪', assert(pile:peek(4)).name)
    lt.assertEquals('取顶拿到的还是原来那张', '甲', assert(pile:draw(1)[1]).name)
    lt.assertEquals('取顶后剩余顺序不变', '乙,丙,闪', zoneLabels(pile))
    lt.assertNotEquals('原来的牌都还在', nil, pileCards[3])
end)
