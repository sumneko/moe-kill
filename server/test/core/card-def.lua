local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'card-def-probe'

---@param rel string
---@param content string
local function write(rel, content)
    local file = probeDir / rel
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), content)
    assert(ok, err)
end

---@return unknown # 配 <close> 用
local function useProbe()
    fs.remove_all(probeDir)
    fs.create_directories(probeDir)
    return moe.util.defer(function ()
        fs.remove_all(probeDir)
    end)
end

---@param source string # 探针包里的定义
---@return Game
---@return Player # 1 号位
local function newGame(source)
    write('探针/牌.lua', source)
    local game = moe.game.create {
        seats    = 2,
        random   = moe.random.create(1),
        sources  = { probeDir:string() .. '/*' },
        packages = { '探针' },
    }
    local desk = game.desk
    local attributeSystem = game:getAttributeSystem()
    attributeSystem:define('体力', {
        min    = -999999,
        max    = 999999,
        simple = true,
    })
    local player = moe.player.create(game, { attributes = attributeSystem:createInstance() })
    desk:sit(1, player)
    player:setAttr('体力', 4)
    return game, player
end

---@param game Game
---@param name string
---@return string # 分类列表拼成一行
local function kindsOf(game, name)
    return table.concat(assert(game:getCard(name)):getKinds(), ',')
end

lt.test('定义：分类一次给一张列表，重复调以后写的为准，取到的是快照', function ()
    local guard <close> = useProbe()
    local game = newGame([[
Card '甲'
    : kind { '锦囊', '延时锦囊', '锦囊' }
Card '乙'
    : kind '基本'
    : kind '装备'
]])

    lt.assertEquals('按列表顺序，重名只算一次', '锦囊,延时锦囊', kindsOf(game, '甲'))
    lt.assertEquals('重复调以后写的为准', '装备', kindsOf(game, '乙'))

    local def = assert(game:getCard('甲'))
    lt.assertEquals('isKind 正面', true, def:isKind('延时锦囊'))
    lt.assertEquals('isKind 反面', false, def:isKind('基本'))

    local snapshot = def:getKinds()
    snapshot[1] = '改过'
    lt.assertEquals('拿到的列表改不动定义', '锦囊,延时锦囊', kindsOf(game, '甲'))
end)

lt.test('定义：牌区声明与读、重复写后者覆盖、不声明就是空', function ()
    local guard <close> = useProbe()
    local game = newGame([[
Card '甲'
    : zone '手牌'
    : zone '装备'
Card '乙'
]])

    lt.assertEquals('重复写以后写的为准', '装备', assert(game:getCard('甲')):getZone())
    lt.assertEquals('不声明就是空', nil, assert(game:getCard('乙')):getZone())
end)

lt.test('定义：extends 抄分类、牌区与限额，基类的钩子跑在前面', function ()
    local guard <close> = useProbe()
    local game, player = newGame([[
Card '基'
    : kind '基本'
    : zone '手牌'
    : limit('出牌', 2)
    : on('进入区域', function ()
        local user = game.desk:getPlayer(1)
        user:setTag('顺序', (user:getTag('顺序') or '') .. '基')
    end)
Card '子'
    : extends '基'
    : limit('出牌', 5)
    : on('进入区域', function ()
        local user = game.desk:getPlayer(1)
        user:setTag('顺序', (user:getTag('顺序') or '') .. '子')
    end)
]])

    local def = assert(game:getCard('子'))

    lt.assertEquals('抄来了分类', true, def:isKind('基本'))
    lt.assertEquals('抄来了牌区', '手牌', def:getZone())
    lt.assertEquals('自己写的限额覆盖基类的', 5, def:getLimit('出牌'))

    local handlers = def:getHandlers('进入区域')
    lt.assertEquals('两个钩子都在', 2, #handlers)
    for _, handler in ipairs(handlers) do
        handler()
    end
    lt.assertEquals('基类的钩子先跑', '基子', player:getTag('顺序'))
end)

lt.test('定义：extends 是快照，抄完两边各管各的', function ()
    local guard <close> = useProbe()
    local game = newGame([[
Card '基'
    : kind '基本'
    : zone '手牌'
    : limit('出牌', 2)
Card '子'
    : extends '基'
]])

    local base = assert(game:getCard('基'))
    local def  = assert(game:getCard('子'))

    def:kind('测试')
    lt.assertEquals('改子定义不影响基类', false, base:isKind('测试'))

    base:kind('装备')
    base:zone('装备')
    base:limit('出牌', 9)

    lt.assertEquals('改基类的分类不影响已抄过的子定义', false, def:isKind('装备'))
    lt.assertEquals('改基类的牌区不影响已抄过的子定义', '手牌', def:getZone())
    lt.assertEquals('改基类的限额不影响已抄过的子定义', 2, def:getLimit('出牌'))
    lt.assertEquals('基类自己变了', '装备', base:getZone())
end)

lt.test('定义：多次 extends 依次合并', function ()
    local guard <close> = useProbe()
    local game = newGame([[
Card '甲'
    : kind '基本'
    : zone '手牌'
Card '乙'
    : kind '锦囊'
    : zone '装备'
Card '子'
    : extends '甲'
    : extends '乙'
]])

    local def = assert(game:getCard('子'))

    lt.assertEquals('分类以后一次为准（覆盖）', '锦囊', kindsOf(game, '子'))
    lt.assertEquals('牌区以后写的为准', '装备', def:getZone())
end)

lt.test('定义：extends 拄分类是覆盖，基类没分类就不动', function ()
    local guard <close> = useProbe()
    local game = newGame([[
Card '基'
    : kind '基本'
Card '素'
    : zone '手牌'
Card '子'
    : kind '装备'
    : extends '基'
Card '丙'
    : extends '基'
    : kind '锦囊'
Card '丁'
    : kind '装备'
    : extends '素'
]])

    lt.assertEquals('基类的分类覆盖自己写的', '基本', kindsOf(game, '子'))
    lt.assertEquals('extends 之后写的覆盖拄来的', '锦囊', kindsOf(game, '丙'))
    lt.assertEquals('基类没分类就不动自己的', '装备', kindsOf(game, '丁'))
end)

lt.test('定义：extends 支持限定名', function ()
    local guard <close> = useProbe()
    write('另一个/牌.lua', [[
Card '甲'
    : kind '基本'
]])
    write('探针/牌.lua', [[
Card '子'
    : extends '另一个.甲'
]])
    local game = moe.game.create {
        seats    = 2,
        random   = moe.random.create(1),
        sources  = { probeDir:string() .. '/*' },
        packages = { '另一个', '探针' },
    }
    local desk = game.desk

    lt.assertEquals('按限定名取到基类', true, assert(game:getCard('子')):isKind('基本'))
end)

lt.test('定义：找不到基类就报错', function ()
    local guard <close> = useProbe()

    local err = lt.assertError('继承不存在的定义', function ()
        newGame([[
Card '子'
    : extends '没有这个'
]])
    end) or ''

    lt.assertEquals('错误里点名那个名字', true, err:find('没有这个', 1, true) ~= nil)
end)

lt.test('定义：addKind 只往里加，重复的与已有分类不动', function ()
    local guard <close> = useProbe()
    local game = newGame([[
Card '甲'
    : kind '装备'
    : addKind '武器'
    : addKind { '装备', '武器', '坐骑' }
]])

    lt.assertEquals('已有的保留、新加的接在后面', '装备,武器,坐骑', kindsOf(game, '甲'))
    lt.assertEquals('加进来的也认', true, assert(game:getCard('甲')):isKind('坐骑'))
end)

lt.test('定义：addKind 接在 extends 之后用，基类分类不会丢', function ()
    local guard <close> = useProbe()
    local game = newGame([[
Card '基'
    : kind { '装备', '坐骑' }
Card '子'
    : extends '基'
    : addKind '进攻马'
]])

    lt.assertEquals('抄来的在后面加的仍留着', '装备,坐骑,进攻马', kindsOf(game, '子'))
end)

lt.test('定义：牌进玩家的牌区就发「进入区域」，给的是那个区', function ()
    local guard <close> = useProbe()
    local game, player = newGame([[
Card '甲'
    : on('进入区域', function (card, zone)
        local owner = assert(zone.owner, '发钩子的时候应该读得到归属者')
        owner:setTag('记录', (owner:getTag('记录') or '')
            .. card.name .. '@' .. tostring(zone == owner:getZone('武器')) .. ';')
    end)
]])

    local card = game:createCard('甲')
    local hand = assert(player:getZone('手牌'), '没有手牌区')
    hand:accept(card)
    lt.assertEquals('放手牌里发一次（不是武器子区）', '甲@false;', player:getTag('记录'))

    player:addZone('武器')
    assert(player:getZone('武器')):accept(card)
    lt.assertEquals('进武器子区时收到的就是那个区', '甲@false;甲@true;', player:getTag('记录'))
end)

lt.test('定义：公共区也发「进入区域」，定义跟着牌走', function ()
    local guard <close> = useProbe()
    local game, player = newGame([[
Card '甲'
    : on('进入区域', function (card, zone)
        local seat = game.desk.seats[1]
        seat:setTag('记录', (seat:getTag('记录') or '')
            .. tostring(zone.owner ~= nil) .. ';')
    end)
]])

    local discard = assert(game:getZone('弃牌'), '没有弃牌区')
    discard:accept(game:createCard('甲'))
    lt.assertEquals('公共区也发，只是没有归属者', 'false;', player:getTag('记录'))

    local loose = lt.zone()
    loose:accept(game:createCard('甲'))
    lt.assertEquals('别的局里也发，定义跟着牌走', 'false;false;', player:getTag('记录'))
end)

--- 一个钩子的源码（牌定义里用：game 是注入进去的）
---@param label string # 记录里写的短标签（离 / 进）
---@param event string # 钩子名（离开区域 / 进入区域）
---@return string
local function recordEvent(label, event)
    return [[
    : on(']] .. event .. [[', function (card, zone)
        local seat = game.desk.seats[1]
        seat:setTag('记录', (seat:getTag('记录') or '')
            .. ']] .. label .. [[' .. card.name .. ';')
    end)]]
end

lt.test('定义：一起收一批牌时，先发完所有「离开区域」再发所有「进入区域」', function ()
    local guard <close> = useProbe()
    local game, player = newGame('Card \'甲\'' .. recordEvent('离', '离开区域') .. recordEvent('进', '进入区域'))

    local seat   = player
    local from   = moe.zone.create(game)
    local to     = moe.zone.create(game)
    local first  = game:createCard('甲')
    local second = game:createCard('甲')
    from:accept(first)
    from:accept(second)

    seat:setTag('记录', nil)
    lt.assertEquals('一起收一批', true, to:accept({ first, second }))
    lt.assertEquals('先两条离开、再两条进入',
        '离甲;离甲;进甲;进甲;', seat:getTag('记录'))
end)

lt.test('定义：targets 声明目标数量的 min / max，重复调以后写的为准', function ()
    local guard <close> = useProbe()
    local game = newGame([[
Card '甲'
    : targets { min = 2, max = 4 }
    : targets { min = 0, max = 0 }
]])

    local min, max = assert(game:getCard('甲')):getTargetCount()
    lt.assertEquals('重复写以后写的为准（最少）', 0, min)
    lt.assertEquals('重复写以后写的为准（最多）', 0, max)
end)

lt.test('定义：不声明就是「最少 1、最多 1」', function ()
    local guard <close> = useProbe()
    local game = newGame([[Card '甲']])

    local min, max = assert(game:getCard('甲')):getTargetCount()
    lt.assertEquals('默认最少', 1, min)
    lt.assertEquals('默认最多', 1, max)
end)

lt.test('定义：extends 抄目标条件，自己写的覆盖基类', function ()
    local guard <close> = useProbe()
    local game = newGame([[
Card '基'
    : targets { min = 2, max = 3 }
Card '子'
    : extends '基'
Card '孙'
    : extends '基'
    : targets { min = 0, max = 0 }
]])

    local min, max = assert(game:getCard('子')):getTargetCount()
    lt.assertEquals('抄来最少', 2, min)
    lt.assertEquals('抄来最多', 3, max)

    local ownMin, ownMax = assert(game:getCard('孙')):getTargetCount()
    lt.assertEquals('自己写的覆盖基类的（最少）', 0, ownMin)
    lt.assertEquals('自己写的覆盖基类的（最多）', 0, ownMax)
end)

lt.test('定义：targets 多次调，filter 叠加、min / max 只覆盖写了的', function ()
    local guard <close> = useProbe()
    local game = newGame([[
Card '甲'
    : targets { min = 2, filter = function () return true end }
    : targets { max = 5, filter = function () return true end }
]])

    local condition = assert(assert(game:getCard('甲')).targetCondition)
    lt.assertEquals('没写的那半没动', 2, condition.min)
    lt.assertEquals('写了的那半覆盖', 5, condition.max)
    lt.assertEquals('filter 叠成两条', 2, #condition.filter)
end)

lt.test('定义：extends 抄 filter 是深拷贝，兄弟各叠各的', function ()
    local guard <close> = useProbe()
    local game = newGame([[
Card '基'
    : targets { filter = function () return true end }
Card '子甲'
    : extends '基'
    : targets { filter = function () return true end }
Card '子乙'
    : extends '基'
]])

    local base = assert(assert(game:getCard('基')).targetCondition)
    local first = assert(assert(game:getCard('子甲')).targetCondition)
    local second = assert(assert(game:getCard('子乙')).targetCondition)
    lt.assertEquals('基类自己一条', 1, #base.filter)
    lt.assertEquals('子甲叠上自己的一条', 2, #first.filter)
    lt.assertEquals('子乙不受子甲影响', 1, #second.filter)
end)

lt.test('定义：collect 跑全部回调，收齐非空返回值', function ()
    local guard <close> = useProbe()
    local game = newGame([[
Card '甲'
    : on('进入区域', function (card)
        return 1
    end)
    : on('进入区域', function (card) end)
    : on('进入区域', function (card)
        return 3
    end)
]])

    local def = assert(game:getCard('甲'))
    lt.assertEquals('空的没收，其余按注册顺序排开', '1,3', table.concat(def:collect('进入区域', {}), ','))
    lt.assertEquals('没人订阅的钩子给空列表', 0, #def:collect('没有这条', {}))
end)
