local lt = require 'test.ltest'

local DECK = { '甲', '乙', '丙', '丁', '戊', '己', '庚', '辛' }

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

---@param list Card[]
---@return string
local function labels(list)
    local names = {}
    for i = 1, #list do
        names[i] = tostring(list[i].name)
    end
    return table.concat(names, ',')
end

---@param zone Zone
---@return string
local function zoneLabels(zone)
    return labels(zone:list())
end

---@param seed integer
---@return string
local function shuffledLabels(seed)
    local zone = lt.orderedZone()
    fill(zone, DECK)
    zone:shuffle(moe.random.create(seed))
    return zoneLabels(zone)
end

lt.test('牌区：放入后计数与查看正确', function ()
    local zone  = lt.zone()
    local cards = fill(zone, { '甲', '乙', '丙' })

    lt.assertEquals('放入后计数', 3, zone:count())
    lt.assertEquals('顺序与放入一致', '甲,乙,丙', zoneLabels(zone))
    lt.assertEquals('查看第二张', cards[2], zone:peek(2))
end)

lt.test('牌区：列举返回副本，清空清掉全部', function ()
    local zone = lt.zone()
    fill(zone, { '甲', '乙' })

    local snapshot = zone:list()
    snapshot[1] = nil

    lt.assertEquals('修改副本不影响牌区', 2, zone:count())
    lt.assertEquals('再列举仍是原内容', '甲,乙', zoneLabels(zone))

    lt.assertEquals('清空返回被清掉的张数', 2, zone:clear())
    lt.assertEquals('清空后计数', 0, zone:count())
    lt.assertEquals('清空后列举为空', '', zoneLabels(zone))
end)

lt.test('牌区：空区 / 越界 / 序号非整数都给空', function ()
    local zone = lt.zone()

    lt.assertEquals('空区查看给空', nil, zone:peek(1))

    fill(zone, { '甲' })
    lt.assertEquals('越界查看给空（0 也不行）', nil, zone:peek(0))

    ---@type any
    local notInteger = 1.5
    lt.assertEquals('序号非整数也给空', nil, zone:peek(notInteger))

    lt.assertEquals('查看不动内容', '甲', zoneLabels(zone))
end)

lt.test('牌区：kind 只用来区分子类', function ()
    lt.assertEquals('基类的 kind', 'zone', lt.zone().kind)
    lt.assertEquals('有序子类的 kind', 'orderedZone', lt.orderedZone().kind)
end)

lt.test('牌区：禁用后不可放入清空，启用后恢复', function ()
    local zone = lt.zone()
    fill(zone, { '甲' })

    lt.assertEquals('初始为启用', true, zone:isEnabled())
    lt.assertEquals('禁用生效', true, zone:disable())
    lt.assertEquals('重复禁用无副作用', false, zone:disable())

    lt.assertEquals('禁用后放不进去', false, (zone:accept(lt.card('乙'))))
    lt.assertEquals('禁用后清不掉', 0, zone:clear())
    lt.assertEquals('禁用期间内容仍可读', '甲', zoneLabels(zone))

    lt.assertEquals('启用生效', true, zone:enable())
    lt.assertEquals('重复启用无副作用', false, zone:enable())

    lt.assertEquals('启用后恢复放入', true, zone:accept(lt.card('乙')))
    lt.assertEquals('确实放进去了', '甲,乙', zoneLabels(zone))
end)

lt.test('有序牌区：相同随机源洗出相同顺序', function ()
    lt.assertEquals('同种子同顺序', shuffledLabels(20260919), shuffledLabels(20260919))
    lt.assertNotEquals('异种子异顺序', shuffledLabels(20260919), shuffledLabels(20260920))
    lt.assertNotEquals('洗牌确实改变顺序', table.concat(DECK, ','), shuffledLabels(20260919))
end)

lt.test('有序牌区：依次取顶与洗牌后顺序一致', function ()
    local zone = lt.orderedZone()
    fill(zone, DECK)
    zone:shuffle(moe.random.create(7))

    local expected = zoneLabels(zone)
    local drawn    = {}
    while zone:count() > 0 do
        drawn[#drawn + 1] = tostring(assert(zone:draw(1)[1]).name)
    end

    lt.assertEquals('取顶顺序与洗牌后一致', expected, table.concat(drawn, ','))
    lt.assertEquals('取完后计数为 0', 0, zone:count())
    lt.assertEquals('取空后再取给空列表', 0, #zone:draw(1))
end)

lt.test('有序牌区：从顶取 n 张，不够就少给', function ()
    local zone = lt.orderedZone()
    fill(zone, { '甲', '乙', '丙' })

    local two = zone:draw(2)
    lt.assertEquals('取到 2 张', 2, #two)
    lt.assertEquals('取的是前两张', '甲,乙', labels(two))
    lt.assertEquals('区里剩 1 张', '丙', zoneLabels(zone))

    local rest = zone:draw(5)
    lt.assertEquals('再多要也只有 1 张', 1, #rest)
    lt.assertEquals('要不到不报错', '', zoneLabels(zone))

    lt.assertEquals('空区取到 0 张', 0, #zone:draw(1))
end)

lt.test('有序牌区：取空了会调不足回调，补到就接着取', function ()
    local zone  = lt.orderedZone()
    local stock = lt.zone()
    fill(stock, { '甲', '乙', '丙' })

    ---@type integer
    local times = 0
    zone:setShortageHandler(function (target)
        times = times + 1
        lt.assertEquals('回调收到的是这个区', zone, target)
        for _, card in ipairs(stock:list()) do
            zone:accept(card)
        end
    end)

    local cards = zone:draw(3)

    lt.assertEquals('只调了一次', 1, times)
    lt.assertEquals('取到 3 张', 3, #cards)
    lt.assertEquals('按补进来的顺序取', '甲,乙,丙', labels(cards))
end)

lt.test('有序牌区：回调补不到牌就少给', function ()
    local zone = lt.orderedZone()

    ---@type integer
    local times = 0
    zone:setShortageHandler(function ()
        times = times + 1
    end)

    local cards = zone:draw(2)

    lt.assertEquals('调了一次', 1, times)
    lt.assertEquals('一张都没取到', 0, #cards)
end)

lt.test('有序牌区：没挂回调时取空就少给', function ()
    local zone = lt.orderedZone()

    lt.assertEquals('要 3 张拿到 0 张', 0, #zone:draw(3))
end)

lt.test('有序牌区：洗牌必须传入随机源', function ()
    local zone = lt.orderedZone()
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
    local zone = lt.orderedZone()
    fill(zone, DECK)
    zone:disable()

    lt.assertEquals('禁用后洗不了', false, zone:shuffle(moe.random.create(1)))
    lt.assertEquals('顺序未变', table.concat(DECK, ','), zoneLabels(zone))
end)

lt.test('牌区：默认对所有人可见，设成暗区后只有持有者看得见', function ()
    local game   = moe.game.create { seats = 2, random = moe.random.create(1) }
    local system = moe.attribute.create()
    local mine   = moe.player.create(game, { attributes = system:createInstance() })
    local other  = moe.player.create(game, { attributes = system:createInstance() })

    local open = moe.zone.create(game)
    lt.assertEquals('默认对所有人可见', true, open:isVisibleTo(other))

    local hand = mine:getZone('手牌')
    hand:setVisible(false)

    lt.assertEquals('持有者自己看得见', true, hand:isVisibleTo(mine))
    lt.assertEquals('别人看不见', false, hand:isVisibleTo(other))

    local nobody = moe.zone.create(game)
    nobody:setVisible(false)
    lt.assertEquals('没有归属的暗区：谁都看不见', false, nobody:isVisibleTo(mine))
end)

---@return Game # 换下来的牌要有个地方去（槽位区的弃牌堆）
local function newGame()
    return moe.game.create { seats = 2, random = moe.random.create(1) }
end

--- 把牌放进某个槽位（`accept` 自己会占槽）
---@param zone SlotZone
---@param slot string
---@param card Card
local function putInSlot(zone, slot, card)
    zone:accept(card, slot)
end

lt.test('槽位区：放进空槽、同槽换新时旧牌进弃牌堆', function ()
    local game = newGame()
    local zone = moe.slotZone.create(game):setSlots({ '武器', '防具' })
    local slot = assert(game:getZone('弃牌'), '局上有弃牌区')

    lt.assertEquals('kind 只用来区分子类', 'slotZone', zone.kind)
    lt.assertEquals('声明的槽位按顺序', '武器,防具', table.concat(zone.slots, ','))
    lt.assertEquals('空槽读不到', nil, zone:getSlot('武器'))

    local old = lt.card('甲')
    putInSlot(zone, '武器', old)
    lt.assertEquals('放进去就读得到', old, zone:getSlot('武器'))
    lt.assertEquals('牌记着自己在哪个区', zone, old:getZone())
    lt.assertEquals('另一个槽还是空的', nil, zone:getSlot('防具'))

    local new = lt.card('乙')
    putInSlot(zone, '武器', new)
    lt.assertEquals('槽里换成新的', new, zone:getSlot('武器'))
    lt.assertEquals('一个槽始终只有一张（装备区也只有这一张）', 1, zone:count())
    lt.assertEquals('旧的进了弃牌堆', old, slot:list()[1])
    lt.assertEquals('旧的不再属于这个区', slot, old:getZone())
end)

lt.test('槽位区：从别的区搬进来 —— 给槽位名的那次挪牌', function ()
    local game  = newGame()
    local zone  = moe.slotZone.create(game):setSlots({ '武器' })
    local other = moe.zone.create(game)
    local card  = lt.card('甲')
    other:accept(card)

    local moveCard = game:moveCardWithSlot(card, zone, '武器')

    lt.assertEquals('这次挪牌没失败', nil, moveCard.err)
    lt.assertEquals('源区空了', 0, other:count())
    lt.assertEquals('牌进了槽', card, zone:getSlot('武器'))
    lt.assertEquals('牌在本区里', zone, card:getZone())
end)

lt.test('槽位区：没占槽的牌进不来', function ()
    local game  = newGame()
    local zone  = moe.slotZone.create(game):setSlots({ '武器' })
    local other = moe.zone.create(game)
    local card  = lt.card('甲')
    other:accept(card)

    local ok, why = zone:accept(card)
    lt.assertEquals('没给槽位名就进不去（牌还在原区）', false, ok)
    lt.assertEquals('而且说出原因', '槽位区必须指名收进哪个槽位', why)
    lt.assertEquals('没归属的直接放进去也进不去', false, (zone:accept(lt.card('乙'))))
    lt.assertEquals('区里什么都没进', 0, zone:count())
    lt.assertEquals('牌还在原处', other, card:getZone())
end)

lt.test('槽位区：牌被别的路径取走后槽位就地失效', function ()
    local game = newGame()
    local zone = moe.slotZone.create(game):setSlots({ '武器' })
    local card = lt.card('甲')
    putInSlot(zone, '武器', card)

    zone:clear()

    lt.assertEquals('槽位读不到那张牌了', nil, zone:getSlot('武器'))

    local again = lt.card('乙')
    putInSlot(zone, '武器', again)
    lt.assertEquals('空出来的槽能重新放', again, zone:getSlot('武器'))
    lt.assertEquals('区里就那一张', 1, zone:count())
    lt.assertEquals('这次没有旧牌要弃（牌早就走了）', 0, assert(game:getZone('弃牌')):count())
end)

lt.test('槽位区：清空后槽位全空', function ()
    local game = newGame()
    local zone = moe.slotZone.create(game):setSlots({ '武器', '防具' })
    putInSlot(zone, '武器', lt.card('甲'))
    putInSlot(zone, '防具', lt.card('乙'))

    lt.assertEquals('清空返回张数', 2, zone:clear())

    lt.assertEquals('武器槽空了', nil, zone:getSlot('武器'))
    lt.assertEquals('防具槽空了', nil, zone:getSlot('防具'))
    lt.assertEquals('清空的牌没有自动进弃牌堆（归内容侧）', 0,
        assert(game:getZone('弃牌')):count())
end)

lt.test('槽位区：弃牌堆被禁用时，换槽整次都不做', function ()
    local game  = newGame()
    local zone  = moe.slotZone.create(game):setSlots({ '武器' })
    local old   = lt.card('甲')
    putInSlot(zone, '武器', old)

    assert(game:getZone('弃牌')):disable()

    local new = lt.card('乙')
    local ok, why = zone:accept(new, '武器')
    lt.assertEquals('换不进去', false, ok)
    lt.assertEquals('而且说出原因', '弃牌堆被禁用了，换下来的牌没地方去', why)
    lt.assertEquals('旧牌还在槽里', old, zone:getSlot('武器'))
    lt.assertEquals('新牌没有归属', nil, new:getZone())
end)

lt.test('槽位区：未声明的槽位名 —— 收不下、读也给「没有」', function ()
    local game = newGame()
    local zone = moe.slotZone.create(game):setSlots({ '武器' })

    local ok, why = zone:accept(lt.card('甲'), '防具')
    lt.assertEquals('收不下（拒绝，不抛）', false, ok)
    lt.assertEquals('而且说出是哪个槽位', '这个牌区没有「防具」这个槽位', why)
    lt.assertEquals('读不到', nil, zone:getSlot('防具'))
    lt.assertEquals('拒绝后什么都没放进去', 0, zone:count())

    local bare = moe.slotZone.create(game)
    lt.assertEquals('不声明就没有槽位', 0, #bare.slots)
    lt.assertEquals('没有槽位也收不下', false, (bare:accept(lt.card('甲'), '武器')))
end)
