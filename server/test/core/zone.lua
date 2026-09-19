local lt = require 'test.ltest'

local DECK = { '甲', '乙', '丙', '丁', '戊', '己', '庚', '辛' }

---@param zone Moe.Zone
---@param source string[]
---@return Moe.Card[]
local function fill(zone, source)
    local cards = {}
    for i = 1, #source do
        cards[i] = moe.card.create(source[i])
        zone:put(cards[i])
    end
    return cards
end

---@param zone Moe.Zone
---@return string
local function zoneLabels(zone)
    local list  = zone:list()
    local names = {}
    for i = 1, #list do
        names[i] = tostring(list[i]:getLabel())
    end
    return table.concat(names, ',')
end

---@param seed integer
---@return string
local function shuffledLabels(seed)
    local zone = moe.orderedZone.create()
    fill(zone, DECK)
    zone:shuffle(moe.random.create(seed))
    return zoneLabels(zone)
end

lt.test('牌区：放入与取出后计数正确', function ()
    local zone  = moe.zone.create()
    local cards = fill(zone, { '甲', '乙', '丙' })

    lt.assertEquals('放入后计数', 3, zone:count())
    lt.assertEquals('顺序与放入一致', '甲,乙,丙', zoneLabels(zone))
    lt.assertEquals('查看第二张', cards[2], zone:peek(2))

    local taken = zone:take(2)
    lt.assertEquals('取出的是第二张', cards[2], taken)
    lt.assertEquals('取出后计数', 2, zone:count())
    lt.assertEquals('剩余顺序', '甲,丙', zoneLabels(zone))
end)

lt.test('牌区：列举返回副本，清空清掉全部', function ()
    local zone = moe.zone.create()
    fill(zone, { '甲', '乙' })

    local snapshot = zone:list()
    snapshot[1] = nil

    lt.assertEquals('修改副本不影响牌区', 2, zone:count())
    lt.assertEquals('再列举仍是原内容', '甲,乙', zoneLabels(zone))

    lt.assertEquals('清空返回被清掉的张数', 2, zone:clear())
    lt.assertEquals('清空后计数', 0, zone:count())
    lt.assertEquals('清空后列举为空', '', zoneLabels(zone))
end)

lt.test('牌区：空区取牌与越界取牌明确失败', function ()
    local zone = moe.zone.create()

    lt.assertError('空区取牌', function () zone:take(1) end)
    lt.assertError('空区查看', function () zone:peek(1) end)

    fill(zone, { '甲' })
    lt.assertError('越界取牌', function () zone:take(2) end)
    lt.assertError('越界查看', function () zone:peek(0) end)

    ---@type any
    local notInteger = 1.5
    lt.assertError('序号非整数', function () zone:take(notInteger) end)

    lt.assertEquals('失败后内容不变', '甲', zoneLabels(zone))
end)

lt.test('牌区：参数可设、可读、可改、可删', function ()
    local zone = moe.zone.create({ ['可见'] = true })

    lt.assertEquals('创建时传入的参数', true, zone:getParam('可见'))
    lt.assertEquals('未设置的参数为 nil', nil, zone:getParam('归属'))

    zone:setParam('归属', '玩家甲')
    lt.assertEquals('新增参数', '玩家甲', zone:getParam('归属'))

    zone:setParam('可见', false)
    lt.assertEquals('修改参数', false, zone:getParam('可见'))
    lt.assertEquals('其它参数不受影响', '玩家甲', zone:getParam('归属'))

    lt.assertEquals('删除已有参数', true, zone:removeParam('归属'))
    lt.assertEquals('删除后读回 nil', nil, zone:getParam('归属'))
    lt.assertEquals('删除不存在的参数', false, zone:removeParam('归属'))

    ---@type any
    local notString = 1
    lt.assertError('参数名必须是字符串', function () zone:setParam(notString, '值') end)
    lt.assertError('参数值不能为 nil', function () zone:setParam('可见', nil) end)
end)

lt.test('牌区：kind 只用来区分子类', function ()
    lt.assertEquals('基类的 kind', 'zone', moe.zone.create().kind)
    lt.assertEquals('有序子类的 kind', 'orderedZone', moe.orderedZone.create().kind)
end)

lt.test('牌区：禁用后不可放入取出，启用后恢复', function ()
    local zone = moe.zone.create()
    fill(zone, { '甲' })

    lt.assertEquals('初始为启用', true, zone:isEnabled())
    lt.assertEquals('禁用生效', true, zone:disable())
    lt.assertEquals('重复禁用无副作用', false, zone:disable())

    lt.assertError('禁用后放入失败', function () zone:put(moe.card.create('乙')) end)
    lt.assertError('禁用后取出失败', function () zone:take(1) end)
    lt.assertError('禁用后清空失败', function () zone:clear() end)
    lt.assertEquals('禁用期间内容仍可读', '甲', zoneLabels(zone))

    lt.assertEquals('启用生效', true, zone:enable())
    lt.assertEquals('重复启用无副作用', false, zone:enable())

    zone:put(moe.card.create('乙'))
    lt.assertEquals('启用后恢复放入', '甲,乙', zoneLabels(zone))
end)

lt.test('有序牌区：相同随机源洗出相同顺序', function ()
    lt.assertEquals('同种子同顺序', shuffledLabels(20260919), shuffledLabels(20260919))
    lt.assertNotEquals('异种子异顺序', shuffledLabels(20260919), shuffledLabels(20260920))
    lt.assertNotEquals('洗牌确实改变顺序', table.concat(DECK, ','), shuffledLabels(20260919))
end)

lt.test('有序牌区：依次取顶与洗牌后顺序一致', function ()
    local zone = moe.orderedZone.create()
    fill(zone, DECK)
    zone:shuffle(moe.random.create(7))

    local expected = zoneLabels(zone)
    local drawn    = {}
    while zone:count() > 0 do
        drawn[#drawn + 1] = tostring(zone:takeTop():getLabel())
    end

    lt.assertEquals('取顶顺序与洗牌后一致', expected, table.concat(drawn, ','))
    lt.assertEquals('取完后计数为 0', 0, zone:count())
    lt.assertError('取空后继续取顶失败', function () zone:takeTop() end)
end)

lt.test('无序牌区：取顶与洗牌明确失败', function ()
    local zone = moe.zone.create()
    fill(zone, DECK)

    lt.assertError('取顶失败', function () zone:takeTop() end)
    lt.assertError('洗牌失败', function () zone:shuffle(moe.random.create(1)) end)
    lt.assertEquals('失败后顺序不变', table.concat(DECK, ','), zoneLabels(zone))
end)

lt.test('有序牌区：洗牌必须传入随机源', function ()
    local zone = moe.orderedZone.create()
    fill(zone, DECK)

    ---@type any
    local notRandom = {}

    ---@type any
    local noRandom = nil

    lt.assertError('随机源类型不对', function () zone:shuffle(notRandom) end)
    lt.assertError('没有随机源', function () zone:shuffle(noRandom) end)
    lt.assertEquals('失败后顺序不变', table.concat(DECK, ','), zoneLabels(zone))
end)

lt.test('有序牌区：禁用后不能洗牌', function ()
    local zone = moe.orderedZone.create()
    fill(zone, DECK)
    zone:disable()

    lt.assertError('禁用后洗牌失败', function () zone:shuffle(moe.random.create(1)) end)
    lt.assertEquals('顺序未变', table.concat(DECK, ','), zoneLabels(zone))
end)
