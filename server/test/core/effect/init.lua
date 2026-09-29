local lt = require 'test.ltest'

--- 测试用：把建实例时给的请求当作这次结算的结果交出去
---@class ProbeEffect : Effect
---@field request any # 这次用什么当结果
local ProbeEffect = Class 'ProbeEffect'

Extends('ProbeEffect', 'Effect')

---@param game Game
---@param request any
function ProbeEffect:__init(game, request)
    self.kind    = 'probe'
    self.request = request
end

function ProbeEffect:settle()
    return self.request
end

--- 测试用：这次结算当场不成立
---@class RejectEffect : Effect
local RejectEffect = Class 'RejectEffect'

Extends('RejectEffect', 'Effect')

---@param game Game
function RejectEffect:__init(game)
    self.kind = 'reject'
end

function RejectEffect:settle()
    self:cancel('不成立')
end

--- 测试用：结算里再嵌套一个内层效果（两边各要一块临时区）
---@class OuterEffect : Effect
local OuterEffect = Class 'OuterEffect'

Extends('OuterEffect', 'Effect')

---@param game Game
function OuterEffect:__init(game)
    self.kind = 'outer'
end

---@async
function OuterEffect:settle()
    self:getTempZone()
    local inner = New 'ProbeEffect' (self.game, nil)
    inner.kind = 'inner'
    inner:getTempZone()
    inner:apply():await()
end

--- 测试用：结算里先要一块临时区，再嵌一个内层效果（记下内层，供断言取区）
---@class ZoneProbeEffect : Effect
---@field inner? InnerProbeEffect # 结算里嵌的那个内层效果
local ZoneProbeEffect = Class 'ZoneProbeEffect'

Extends('ZoneProbeEffect', 'Effect')

---@param game Game
function ZoneProbeEffect:__init(game)
    self.kind = 'zoneProbe'
end

---@async
function ZoneProbeEffect:settle()
    self:getTempZone()
    local inner = New 'InnerProbeEffect' (self.game)
    inner:apply():await()
    self.inner = inner
end

--- 测试用：内层效果 —— 要一块自己的区，并把点名向外层借到的那块也记下来
---@class InnerProbeEffect : Effect
---@field own Zone # 自己那块
---@field borrowed? Zone # 点名向外层借到的那块（没有外层就是空）
local InnerProbeEffect = Class 'InnerProbeEffect'

Extends('InnerProbeEffect', 'Effect')

---@param game Game
function InnerProbeEffect:__init(game)
    self.kind = 'innerProbe'
end

---@async
function InnerProbeEffect:settle()
    self.own = self:getTempZone()
    local parent = self.parent
    if parent then
        self.borrowed = parent:getTempZone()
    end
end

---@param count integer
---@return Game
---@return Player[] # 按座位号升序
local function newGame(count)
    local random = moe.random.create(1)
    local game   = moe.game.create {
        seats   = count,
        random  = random,
        sources = { './package/*', lt.cardSource },
    }
    local desk   = game.desk
    local attributeSystem = game:getAttributeSystem()
    attributeSystem:define('体力', {
        min    = -999999,
        max    = 999999,
        simple = true,
    })
    ---@type Player[]
    local players = {}
    for i = 1, count do
        local player = moe.player.create(game, { attributes = attributeSystem:createInstance() })
        desk:sit(i, player)
        player:setAttr('体力', 4)
        players[i] = player
    end
    return game, players
end

lt.test('效果：没有结算时没有根', function ()
    local game = newGame(1)

    lt.assertEquals('没有正在结算的', nil, game:getEffect())
    lt.assertEquals('还没有发起过结算', 0, #game:getEffects())
end)

lt.test('效果：可以挂标签袋（内容侧存这次结算的临时数据）', function ()
    local game, players = newGame(2)

    local effect = game:damage(players[1], players[2], 1)
    effect:setTag('缘由', '测试')

    lt.assertEquals('读得回来', '测试', effect:getTag('缘由'))

    effect:removeTag('缘由')
    lt.assertEquals('移除后读到不存在', nil, effect:getTag('缘由'))

    lt.assertError('空键报错', function ()
        effect:setTag('', 1)
    end)
end)

lt.test('效果：嵌套太深的那一层以「取消」收尾，不算失败也不报错', function ()
    local game = newGame(1)
    lt.clearErrors()

    ---@type Effect? # 撞上限的那一层
    local over = nil

    -- 手工把外层「垫」得很深：它里起的那一层就超限了（不跟具体上限绑死，也不必真造几百层）
    local outer = New 'ProbeEffect' (game, '外层')
    outer.deep = 100000
    outer.settle = function (self)
        over = New 'ProbeEffect' (self.game, '太深了')
        over:apply():await()
        return '外层照常结完'
    end
    outer:apply():await()

    local deep = assert(over, '没有起出更深的层')
    lt.assertEquals('以「取消」收尾', moe.task.CANCELED, deep.err)
    lt.assertEquals('没有结果', nil, deep.result)
    lt.assertEquals('不算失败（没进错误处理器）', 0, #lt.errors)
    lt.assertEquals('外层照常结完', '外层照常结完', outer.result)
    lt.assertEquals('只记根，内层不单独记', 1, #game:getEffects())
end)

lt.test('效果：越限的那一层不发收尾（收尾里起结算也不会自激）', function ()
    local game = newGame(1)
    local finished = 0
    game:on('效果-收尾', function (effect)
        finished = finished + 1
        if effect.parent then
            return
        end
        New 'ProbeEffect' (game, nil):apply()
    end)

    local probe = New 'ProbeEffect' (game, nil)
    probe.deep = 100000
    probe:apply():await()

    lt.assertEquals('下面那层被拒 ⇒ 没有第二次收尾', 1, finished)
end)

lt.test('效果：一个结算挂的子结算到上限就不再结算', function ()
    local game = newGame(1)
    local settled = 0
    local outer = New 'ProbeEffect' (game, nil)
    outer.settle = function ()
        for _ = 1, 5000 do
            local child = New 'ProbeEffect' (game, nil)
            child.settle = function ()
                settled = settled + 1
            end
            child:apply():await()
            if child.err == moe.task.CANCELED then
                return '撞上限了'
            end
        end
        return '没撞上限'
    end

    outer:apply():await()

    lt.assertEquals('父的账上记的等于结算过的', #outer.childs, settled)
    lt.assertEquals('撞上限后不再结算', true, settled > 0 and settled < 5000)
    lt.assertEquals('外层照常结完', '撞上限了', outer.result)
end)

lt.test('效果：结算期间是根，结束就清掉', function ()
    local game, players = newGame(2)

    ---@type string[]
    local trace = {}

    game:on('效果-能否生效', function (effect)
        if effect.kind == 'damage' then
            trace[#trace + 1] = '发起时是根 {}' % { tostring(game:getEffect() == effect) }
        end
    end)
    game:on('伤害-结束', function (damage)
        trace[#trace + 1] = '结束时是根 {}' % { tostring(game:getEffect() == damage) }
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('发起与结束时它都是最近发起的根', '发起时是根 true,结束时是根 true', table.concat(trace, ','))
    lt.assertEquals('记牌器留下了这一条', 1, #game:getEffects())
end)

lt.test('效果：嵌套结算会压深，结束后回到外层', function ()
    local game, players = newGame(3)

    ---@type string[]
    local trace = {}
    ---@type boolean
    local nested = false

    game:on('效果-能否生效', function (effect)
        if effect.kind ~= 'damage' then
            return
        end
        ---@cast effect Damage
        trace[#trace + 1] = '进入 {} 层 {}' % { effect.deep, effect.to == players[2] and '外层' or '内层' }
        if not nested then
            nested = true
            game:damage(players[2], players[3], 1)
        end
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('外层先进、内层后进', '进入 1 层 外层,进入 2 层 内层', table.concat(trace, ','))
    lt.assertEquals('外层目标掉血', 3, players[2]:getAttr('体力'))
    lt.assertEquals('内层目标掉血', 3, players[3]:getAttr('体力'))
    lt.assertEquals('只记根，内层不单独记', 1, #game:getEffects())
end)

lt.test('效果：内层的父是外层，根效果没有父', function ()
    local game, players = newGame(3)

    ---@type Effect?
    local outerSeen = nil
    ---@type Effect?
    local innerSeen = nil
    ---@type Effect?
    local parentSeen = nil
    ---@type boolean
    local nested = false

    game:on('效果-能否生效', function (effect)
        if effect.kind ~= 'damage' then
            return
        end
        if not nested then
            nested    = true
            outerSeen = effect
            game:damage(players[2], players[3], 1)
        else
            innerSeen  = effect
            parentSeen = effect.parent
        end
    end)

    game:damage(players[1], players[2], 1)

    local outer = assert(outerSeen, '外层没被记下来')
    local inner = assert(innerSeen, '内层没被记下来')
    lt.assertEquals('内层的父是外层', true, parentSeen == outer)
    lt.assertEquals('内层自己认的是外层', true, inner.parent == outer)
    lt.assertEquals('两者不是同一个', true, inner ~= outer)
    lt.assertEquals('外层的父不存在', nil, outer.parent)
    lt.assertEquals('记牌器留下了这一条', 1, #game:getEffects())
end)

lt.test('效果：根效果的父不存在，也不报错', function ()
    local game, players = newGame(2)

    ---@type Effect?
    local topSeen = nil

    game:on('效果-能否生效', function (effect)
        if effect.kind == 'damage' then
            topSeen = effect
        end
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('父效果是不存在', nil, assert(topSeen).parent)
    lt.assertEquals('记牌器留下了这一条', 1, #game:getEffects())
end)

lt.test('效果：沿父效果能还原整条结算链', function ()
    local game, players = newGame(4)

    ---@type Effect[] # 按进入顺序
    local entered = {}

    game:on('效果-能否生效', function (effect)
        if effect.kind ~= 'damage' then
            return
        end
        entered[#entered + 1] = effect
        if #entered < 3 then
            game:damage(players[1], players[#entered + 2], 1)
        end
    end)

    game:damage(players[1], players[2], 1)

    ---@type string[]
    local chain = {}
    ---@type Effect?
    local node = entered[#entered]
    while node do
        chain[#chain + 1] = node.kind
        node = node.parent
    end

    lt.assertEquals('三层结算', 3, #entered)
    lt.assertEquals('最深那层的父是中间那层', true, entered[3].parent == entered[2])
    lt.assertEquals('中间那层的父是根', true, entered[2].parent == entered[1])
    lt.assertEquals('根的父不存在', nil, entered[1].parent)
    lt.assertEquals('从里往上走到根', 'damage,damage,damage', table.concat(chain, ','))
end)

lt.test('效果：结算中抛错也退栈', function ()
    local game, players = newGame(2)
    local damage = New 'Damage' (game, players[1], players[2], 1)
    damage.settle = function ()
        error('故意报错')
    end
    lt.clearErrors()

    damage:apply():await()

    lt.assertEquals('失败记在效果上', true, damage.err ~= nil)
    lt.assertEquals('错误被收到', 1, #lt.errors)
    lt.assertEquals('记牌器留下了这一条', 1, #game:getEffects())
    lt.assertEquals('体力没变（错误发生在改体力之前）', 4, players[2]:getAttr('体力'))
    lt.assertEquals('错误信息里带出错位置', true, tostring(damage.err):match(':%d+:') ~= nil)
end)

lt.test('效果：订阅者在「能否生效」里返回原因 ⇒ 这一次生效不结算', function ()
    local game, players = newGame(2)
    lt.clearErrors()

    ---@type string[]
    local trace = {}

    game:on('效果-能否生效', function (effect)
        trace[#trace + 1] = '{} {}' % { effect.kind, game:getEffect() == effect }
        return '我不让它生效'
    end)
    game:on('效果-能否生效', function ()
        trace[#trace + 1] = '第一个松了口就不该轮到我'
    end)

    local damage = game:damage(players[1], players[2], 1)

    lt.assertEquals('订阅者拿到的是这个效果，且此刻它是根；第一个给了原因就快速返回', 'damage true',
        table.concat(trace, ','))
    lt.assertEquals('被阻止 ⇒ 没有结果', nil, damage.result)
    lt.assertEquals('原因记在 err 上', '我不让它生效', damage.err)
    lt.assertEquals('被阻止 ⇒ 不算成立', false, damage.success)
    lt.assertEquals('被阻止 ⇒ 没有造成伤害', 4, players[2]:getAttr('体力'))
    lt.assertEquals('被阻止也记在记牌器上', 1, #game:getEffects())
    lt.assertEquals('阻止不算失败，不交给错误处理器', 0, #lt.errors)
end)

lt.test('效果：订阅者只返回 false ⇒ 归一成一句通用原因', function ()
    local game, players = newGame(2)

    game:on('效果-能否生效', function ()
        return false
    end)

    local damage = game:damage(players[1], players[2], 1)

    lt.assertEquals('没有结果', nil, damage.result)
    lt.assertEquals('原因', '这次生效被阻止', damage.err)
    lt.assertEquals('没有造成伤害', 4, players[2]:getAttr('体力'))
end)

lt.test('效果：阻止只作用于这一个效果，外层照常结算完', function ()
    local game, players = newGame(3)

    ---@type boolean
    local outerDone = false
    ---@type boolean
    local nested = false

    game:on('效果-能否生效', function (effect)
        if effect.kind ~= 'damage' or nested then
            return
        end
        nested = true
        game:damage(players[2], players[3], 2)
        outerDone = true
    end)
    game:on('效果-能否生效', function (effect)
        ---@cast effect Damage
        if effect.amount == 2 then
            return '不让这一下生效'
        end
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('内层被阻止 ⇒ 内层目标没掉血', 4, players[3]:getAttr('体力'))
    lt.assertEquals('外层照常走完', true, outerDone)
    lt.assertEquals('外层目标照常掉血', 3, players[2]:getAttr('体力'))
    lt.assertEquals('被阻止也记在记牌器上', 1, #game:getEffects())
end)

lt.test('效果：被阻止后它自己的结算不再执行', function ()
    local game, players = newGame(2)

    ---@type string[]
    local trace = {}

    game:on('效果-能否生效', function ()
        return '拦下'
    end)

    local damage = New 'Damage' (game, players[1], players[2], 1)
    local settle = damage.settle
    damage.settle = function (self)
        settle(self)
        trace[#trace + 1] = '结算跑完了'
    end

    damage:apply():await()

    lt.assertEquals('结算整个没跑', 0, #trace)
    lt.assertEquals('体力没变', 4, players[2]:getAttr('体力'))
end)

lt.test('效果：失败记在 err 上，不抛', function ()
    local game = newGame(1)
    local probe = New 'ProbeEffect' (game, {})
    probe.settle = function ()
        error('故意报错', 0)
    end
    lt.clearErrors()

    lt.assertEquals('apply 不抛，返回它自己', probe, probe:apply():await())
    lt.assertEquals('错误记在效果上', true, probe.err ~= nil)
    lt.assertEquals('错误被收到', 1, #lt.errors)
    lt.assertEquals('再等也不抛', probe, probe:await())
    lt.assertEquals('错误不会被清掉', true, probe.err ~= nil)
end)

lt.test('效果：成败读 .success，它就是「没成立的原因为空」', function ()
    local game, players = newGame(2)

    local damage = game:damage(players[1], players[2], 1)
    lt.assertEquals('结算完 = 成立', true, damage.success)

    lt.clearErrors()
    local probe = New 'ProbeEffect' (game, {})
    probe.settle = function ()
        error('故意报错', 0)
    end
    probe:apply():await()

    lt.assertEquals('出错 = 不成立', false, probe.success)
end)

lt.test('效果：结算体给出的值就是这次结算的结果', function ()
    local game, players = newGame(2)

    local probe = New 'ProbeEffect' (game, '答案')
    probe:apply():await()

    lt.assertEquals('读 settle 的返回值', '答案', probe.result)

    local damage = game:damage(players[1], players[2], 1)
    lt.assertEquals('结算体不返回值 ⇒ 没有结果', nil, damage.result)
end)

lt.test('效果：入口返回已经结完的效果', function ()
    local game, players = newGame(2)

    local damage = game:damage(players[1], players[2], 1)

    lt.assertEquals('入口返回这次伤害', 'damage', damage.kind)
    lt.assertEquals('拿到的是同一个效果', damage, damage:await())
    lt.assertEquals('已经结完（体力掉了）', 3, players[2]:getAttr('体力'))
    lt.assertEquals('没有失败', nil, damage.err)
end)

lt.test('效果：自动失败交给任务的错误处理器，阻止不交', function ()
    local game, players = newGame(2)

    local damage = New 'Damage' (game, players[1], players[2], 1)
    damage.settle = function ()
        error('故意报错', 0)
    end
    lt.clearErrors()

    damage:apply():await()

    lt.assertEquals('失败记在效果上', true, damage.err ~= nil)
    lt.assertEquals('处理器收到一次', 1, #lt.errors)
    lt.assertEquals('收到的是这个失败', true, tostring(lt.errors[1]):find('故意报错', 1, true) ~= nil)

    game:on('效果-能否生效', function ()
        return '不让你生效'
    end)
    game:damage(players[1], players[2], 1)

    lt.assertEquals('阻止不算失败，不交给处理器', 1, #lt.errors)
    lt.assertEquals('被阻止 ⇒ 没有造成伤害', 4, players[2]:getAttr('体力'))
end)

---@async
lt.test('任务：到点没结完以超时失败', function ()
    local task = moe.task.create()
    task:setTimeout(0.01)
    lt.clearErrors()

    local result, err = task:await()

    lt.assertEquals('没有结果', nil, result)
    lt.assertEquals('失败原因是超时', 'timeout', err)
    lt.assertEquals('超时不算报错，不交给处理器', 0, #lt.errors)
end)

lt.test('效果：临时处理区按需建，顶层效果各自一块', function ()
    local game = newGame(1)

    local one = New 'ProbeEffect' (game, nil)
    lt.assertEquals('没问过就没有临时区', nil, one.tempZone)

    local zone = one:getTempZone()
    lt.assertEquals('问两次拿到同一块', zone, one:getTempZone())
    lt.assertEquals('就是普通牌区', 'zone', zone.kind)

    local other = New 'ProbeEffect' (game, nil)
    lt.assertEquals('另一个效果是另一块', true, other:getTempZone() ~= zone)
end)

lt.test('效果：内层效果要区就自己一块，不向外层取', function ()
    local game = newGame(1)
    local outer = New 'ZoneProbeEffect' (game)
    outer:apply():await()

    local inner = assert(outer.inner, '内层没跑')
    local zone  = assert(outer.tempZone, '外层没建区')
    lt.assertEquals('内层要到自己一块', inner.own, inner.tempZone)
    lt.assertEquals('不是外层那块', true, inner.own ~= zone)
    lt.assertEquals('外层那块还是外层的', zone, outer.tempZone)
end)

lt.test('效果：点名向外层借区，借到的就是外层那块', function ()
    local game = newGame(1)
    local outer = New 'ZoneProbeEffect' (game)
    outer:apply():await()

    local inner = assert(outer.inner, '内层没跑')
    lt.assertEquals('借到的就是外层那块', assert(outer.tempZone, '外层没建区'), inner.borrowed)
end)

lt.test('效果：没要过区的效果也发收尾', function ()
    local game = newGame(1)
    local finished = 0
    game:on('效果-收尾', function () finished = finished + 1 end)

    local probe = New 'ProbeEffect' (game, nil)
    probe:apply():await()

    lt.assertEquals('没要过区也发一次', 1, finished)
    lt.assertEquals('发的时候自己没区', nil, probe.tempZone)
end)

lt.test('效果：结完时收尾一次', function ()
    local game = newGame(1)
    ---@type Effect[]
    local finished = {}
    game:on('效果-收尾', function (effect)
        finished[#finished+1] = effect
    end)

    local probe = New 'ProbeEffect' (game, nil)
    probe:getTempZone()
    probe:apply():await()

    lt.assertEquals('只收一次', 1, #finished)
    lt.assertEquals('收的就是它', probe, finished[1])
end)

lt.test('效果：不成立也收尾', function ()
    local game = newGame(1)
    local finished = 0
    game:on('效果-收尾', function () finished = finished + 1 end)

    local reject = New 'RejectEffect' (game)
    reject:getTempZone()
    reject:apply():await()

    lt.assertEquals('这次结算不成立', '不成立', reject.err)
    lt.assertEquals('照样收尾', 1, finished)
end)

lt.test('效果：被阻止也收尾（牌不能留在已经死掉的效果里）', function ()
    local game = newGame(1)
    local finished = 0
    game:on('效果-收尾', function () finished = finished + 1 end)
    game:on('效果-能否生效', function ()
        return '不让它生效'
    end)

    local probe = New 'ProbeEffect' (game, nil)
    probe:getTempZone()
    probe:apply():await()

    lt.assertEquals('取消也要收尾', 1, finished)
end)

lt.test('效果：内层效果先收尾，外层后收尾', function ()
    local game = newGame(1)
    ---@type string[]
    local order = {}
    game:on('效果-收尾', function (effect)
        order[#order+1] = effect.kind
    end)

    New 'OuterEffect' (game):apply():await()

    lt.assertEquals('内层先收尾', 'inner', order[1])
    lt.assertEquals('外层后收尾', 'outer', order[2])
    lt.assertEquals('一共两次', 2, #order)
end)

lt.test('效果：收尾时临时区剩下的牌进弃牌堆', function ()
    local game = newGame(1)
    local discard = game:getZone('弃牌')
    local probe = New 'ProbeEffect' (game, nil)
    local zone = probe:getTempZone()
    local card = game:createCard('测试牌')
    game:moveCard(card, zone)

    probe:apply():await()

    lt.assertEquals('临时区空了', 0, zone:count())
    lt.assertEquals('牌进了弃牌堆', discard, card:getZone())
end)

lt.test('效果：内容侧在收尾里先搬走的牌，内核不再动它', function ()
    local game = newGame(1)
    local discard = game:getZone('弃牌')
    local probe = New 'ProbeEffect' (game, nil)
    local zone = probe:getTempZone()
    local kept = game:createCard('留下的牌')
    local left = game:createCard('剩下的牌')
    game:moveCard(kept, zone)
    game:moveCard(left, zone)

    local stash = lt.zone()
    game:on('效果-收尾', function (effect)
        -- 订阅方要按载荷过滤：收尾里起的结算自己也会收尾，不筛就会自激
        if effect ~= probe then
            return
        end
        game:moveCard(kept, stash)
    end)

    probe:apply():await()

    lt.assertEquals('被搬走的落在内容侧给的地方', stash, kept:getZone())
    lt.assertEquals('没被搬走的进弃牌堆', discard, left:getZone())
end)

lt.test('效果：三段式按 全局 → 来源 → 目标 依次问', function ()
    local game, players = newGame(2)
    ---@type string[]
    local trace = {}

    game:on('效果-能否生效', function () trace[#trace + 1] = '全局' end)
    players[1]:on('效果-来源-能否生效', function () trace[#trace + 1] = '来源' end)
    players[2]:on('效果-目标-能否生效', function () trace[#trace + 1] = '目标' end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('三段都问到、按序', '全局,来源,目标', table.concat(trace, ','))
    lt.assertEquals('没人拦 ⇒ 照常结算', 3, players[2]:getAttr('体力'))
end)

lt.test('效果：全局拦下后不再问来源与目标', function ()
    local game, players = newGame(2)
    ---@type string[]
    local trace = {}

    game:on('效果-能否生效', function ()
        trace[#trace + 1] = '全局'
        return '全局拦下'
    end)
    players[1]:on('效果-来源-能否生效', function () trace[#trace + 1] = '来源' end)
    players[2]:on('效果-目标-能否生效', function () trace[#trace + 1] = '目标' end)

    local damage = game:damage(players[1], players[2], 1)

    lt.assertEquals('到全局为止', '全局', table.concat(trace, ','))
    lt.assertEquals('原因就是那一句', '全局拦下', damage.err)
    lt.assertEquals('没有掉血', 4, players[2]:getAttr('体力'))
end)

lt.test('效果：来源拦下后不再问目标', function ()
    local game, players = newGame(2)
    ---@type string[]
    local trace = {}

    game:on('效果-能否生效', function () trace[#trace + 1] = '全局' end)
    players[1]:on('效果-来源-能否生效', function ()
        trace[#trace + 1] = '来源'
        return '来源不让'
    end)
    players[2]:on('效果-目标-能否生效', function () trace[#trace + 1] = '目标' end)

    local damage = game:damage(players[1], players[2], 1)

    lt.assertEquals('到来源为止', '全局,来源', table.concat(trace, ','))
    lt.assertEquals('原因', '来源不让', damage.err)
    lt.assertEquals('没有掉血', 4, players[2]:getAttr('体力'))
end)

lt.test('效果：目标段只问承受者，不相干的玩家不被唤醒', function ()
    local game, players = newGame(3)
    ---@type integer
    local bothered = 0

    players[3]:on('效果-目标-能否生效', function () bothered = bothered + 1 end)
    players[2]:on('效果-目标-能否生效', function () return '目标不让' end)

    local damage = game:damage(players[1], players[2], 1)

    lt.assertEquals('不相干的玩家一次都没被问', 0, bothered)
    lt.assertEquals('拦下了', '目标不让', damage.err)
    lt.assertEquals('没有掉血', 4, players[2]:getAttr('体力'))
end)

lt.test('效果：目标段只给 false ⇒ 照样拦下（不被 or 链跳过）', function ()
    local game, players = newGame(2)
    players[2]:on('效果-目标-能否生效', function () return false end)

    local damage = game:damage(players[1], players[2], 1)

    lt.assertEquals('归一成通用原因', '这次生效被阻止', damage.err)
    lt.assertEquals('没有掉血', 4, players[2]:getAttr('体力'))
end)

lt.test('效果：没有来源就跳过来源段', function ()
    local game, players = newGame(2)
    ---@type string[]
    local trace = {}

    game:on('效果-能否生效', function () trace[#trace + 1] = '全局' end)
    players[2]:on('效果-来源-能否生效', function () trace[#trace + 1] = '来源（不该被问）' end)
    players[2]:on('效果-目标-能否生效', function () trace[#trace + 1] = '目标' end)

    game:damage(nil, players[2], 1)

    lt.assertEquals('无来源伤害：只问全局与目标', '全局,目标', table.concat(trace, ','))
end)

lt.test('效果：与玩家无关的效果只问全局段', function ()
    local game, players = newGame(2)
    ---@type string[]
    local trace = {}

    game:on('效果-能否生效', function (effect) trace[#trace + 1] = effect.kind end)
    players[1]:on('效果-来源-能否生效', function () trace[#trace + 1] = '来源' end)
    players[2]:on('效果-目标-能否生效', function () trace[#trace + 1] = '目标' end)

    New 'ProbeEffect' (game, '结果'):apply():await()

    lt.assertEquals('没有来源也没有目标的两段', 'probe', table.concat(trace, ','))
end)

lt.test('效果：用牌与生效的 from / to 指对人', function ()
    local game, players = newGame(2)
    local card    = game:createCard('杀')
    local useCard = New 'UseCard' (game, players[1], card, { players[2] })

    lt.assertEquals('用牌的 from 是使用者', players[1], useCard.from)

    local effect = New 'CardEffect' (game, card, players[2], useCard)
    lt.assertEquals('生效的 from 是使用者', players[1], effect.from)
    lt.assertEquals('生效的 to 是承受者', players[2], effect.to)

    local judged = New 'CardEffect' (game, card, players[2])
    lt.assertEquals('判定阶段形态没有 from', nil, judged.from)
    lt.assertEquals('判定阶段 to 照旧指判定者', players[2], judged.to)
end)
