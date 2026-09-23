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
    self:reject('不成立')
end

--- 测试用：结算里再嵌套一个内层效果
---@class OuterEffect : Effect
local OuterEffect = Class 'OuterEffect'

Extends('OuterEffect', 'Effect')

---@param game Game
function OuterEffect:__init(game)
    self.kind = 'outer'
end

---@async
function OuterEffect:settle()
    local inner = New 'ProbeEffect' (self.game, nil)
    inner.kind = 'inner'
    inner:apply():await()
end

---@param count integer
---@return Game
---@return Player[] # 按座位号升序
local function newGame(count)
    local random = moe.random.create(1)
    local game   = moe.game.create { seats = count, random = random }
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

lt.test('效果：结算期间是根，结束就清掉', function ()
    local game, players = newGame(2)

    ---@type string[]
    local trace = {}

    game:on('伤害-前', function (damage)
        trace[#trace + 1] = '前 {}' % { tostring(game:getEffect() == damage) }
    end)
    game:on('伤害-后', function (damage)
        trace[#trace + 1] = '后 {}' % { tostring(game:getEffect() == damage) }
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('两个时机都看到这次伤害是根', '前 true,后 true', table.concat(trace, ','))
    lt.assertEquals('记牌器留下了这一条', 1, #game:getEffects())
end)

lt.test('效果：嵌套结算会压深，结束后回到外层', function ()
    local game, players = newGame(3)

    ---@type string[]
    local trace = {}
    ---@type boolean
    local nested = false

    game:on('伤害-前', function (damage)
        ---@cast damage Damage
        trace[#trace + 1] = '进入 {} 层 {}' % { damage.deep, damage.to == players[2] and '外层' or '内层' }
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

    game:on('伤害-前', function (damage)
        ---@cast damage Effect
        if not nested then
            nested    = true
            outerSeen = damage
            game:damage(players[2], players[3], 1)
        else
            innerSeen  = damage
            parentSeen = damage.parent
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

    game:on('伤害-前', function (damage)
        ---@cast damage Effect
        topSeen = damage
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('父效果是不存在', nil, assert(topSeen).parent)
    lt.assertEquals('记牌器留下了这一条', 1, #game:getEffects())
end)

lt.test('效果：沿父效果能还原整条结算链', function ()
    local game, players = newGame(4)

    ---@type Effect[] # 按进入顺序
    local entered = {}

    game:on('伤害-前', function (damage)
        ---@cast damage Effect
        entered[#entered + 1] = damage
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
    local damage = moe.damage.create {
        game   = game,
        from   = players[1],
        to     = players[2],
        amount = 1,
    }
    damage.settle = function ()
        error('故意报错')
    end
    lt.clearErrors()

    damage:apply()

    lt.assertEquals('失败记在效果上', true, damage.err ~= nil)
    lt.assertEquals('错误被收到', 1, #lt.errors)
    lt.assertEquals('记牌器留下了这一条', 1, #game:getEffects())
    lt.assertEquals('体力没变（错误发生在改体力之前）', 4, players[2]:getAttr('体力'))
    lt.assertEquals('错误信息里带出错位置', true, tostring(damage.err):match(':%d+:') ~= nil)
end)

lt.test('效果：即将生效的订阅者能取消这一次生效', function ()
    local game, players = newGame(2)

    ---@type string[]
    local trace = {}

    game:on('即将生效', function (effect)
        trace[#trace + 1] = '{} {}' % { effect.kind, game:getEffect() == effect }
        ---@cast effect Effect
        effect:remove()
        trace[#trace + 1] = '取消之后这一行不该执行'
    end)
    game:on('即将生效', function ()
        trace[#trace + 1] = '后面的订阅者也不该执行'
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('订阅者拿到的是这个效果，且此刻它是根', 'damage true', table.concat(trace, ','))
    lt.assertEquals('被取消 ⇒ 没有造成伤害', 4, players[2]:getAttr('体力'))
    lt.assertEquals('被取消也记在记牌器上', 1, #game:getEffects())
end)

lt.test('效果：取消只作用于这一个效果，外层照常结算完', function ()
    local game, players = newGame(3)

    ---@type boolean
    local outerDone = false
    ---@type boolean
    local nested = false

    game:on('伤害-前', function ()
        if not nested then
            nested = true
            game:damage(players[2], players[3], 2)
            outerDone = true
        end
    end)
    game:on('即将生效', function (effect)
        ---@cast effect Damage
        if effect.amount == 2 then
            effect:remove()
        end
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('内层被取消 ⇒ 内层目标没掉血', 4, players[3]:getAttr('体力'))
    lt.assertEquals('外层照常走完', true, outerDone)
    lt.assertEquals('外层目标照常掉血', 3, players[2]:getAttr('体力'))
    lt.assertEquals('被取消也记在记牌器上', 1, #game:getEffects())
end)

lt.test('效果：被取消后它自己的结算不再执行', function ()
    local game, players = newGame(2)

    ---@type string[]
    local trace = {}

    game:on('即将生效', function (effect)
        ---@cast effect Effect
        effect:remove()
    end)

    local damage = moe.damage.create { game = game, from = players[1], to = players[2], amount = 1 }
    local settle = damage.settle
    damage.settle = function (self)
        settle(self)
        trace[#trace + 1] = '结算跑完了'
    end

    damage:apply()

    lt.assertEquals('结算整个没跑', 0, #trace)
    lt.assertEquals('体力没变', 4, players[2]:getAttr('体力'))
end)

lt.test('效果：不在结算中或已经结束的效果不能取消', function ()
    local game, players = newGame(2)
    local fresh = moe.damage.create { game = game, from = players[1], to = players[2], amount = 1 }
    local damage = game:damage(players[1], players[2], 1)
    lt.clearErrors()

    local before = #game:getEffects()

    fresh:remove()

    lt.assertEquals('还没开始结算 ⇒ 取消是空操作', before, #game:getEffects())

    damage:remove()

    lt.assertEquals('已经结束 ⇒ 取消是空操作', nil, damage.err)
    lt.assertEquals('正常结算照常掉血', 3, players[2]:getAttr('体力'))
    lt.assertEquals('没有产生错误', 0, #lt.errors)
end)

lt.test('效果：失败记在 err 上，不抛', function ()
    local game = newGame(1)
    local probe = New 'ProbeEffect' (game, {})
    probe.settle = function ()
        error('故意报错', 0)
    end
    lt.clearErrors()

    lt.assertEquals('apply 不抛，返回它自己', probe, probe:apply())
    lt.assertEquals('错误记在效果上', true, probe.err ~= nil)
    lt.assertEquals('错误被收到', 1, #lt.errors)
    lt.assertEquals('再等也不抛', probe, probe:await())
    lt.assertEquals('错误不会被清掉', true, probe.err ~= nil)
end)

lt.test('效果：结算体给出的值就是这次结算的结果', function ()
    local game, players = newGame(2)

    local probe = New 'ProbeEffect' (game, '答案')
    probe:apply()

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

lt.test('效果：自动失败交给任务的错误处理器，取消不交', function ()
    local game, players = newGame(2)

    local damage = moe.damage.create { game = game, from = players[1], to = players[2], amount = 1 }
    damage.settle = function ()
        error('故意报错', 0)
    end
    lt.clearErrors()

    damage:apply()

    lt.assertEquals('失败记在效果上', true, damage.err ~= nil)
    lt.assertEquals('处理器收到一次', 1, #lt.errors)
    lt.assertEquals('收到的是这个失败', true, tostring(lt.errors[1]):find('故意报错', 1, true) ~= nil)

    game:on('即将生效', function (effect)
        ---@cast effect Effect
        effect:remove()
    end)
    game:damage(players[1], players[2], 1)

    lt.assertEquals('取消不算失败，不交给处理器', 1, #lt.errors)
    lt.assertEquals('被取消 ⇒ 没有造成伤害', 4, players[2]:getAttr('体力'))
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

lt.test('效果：临时处理区按需建，且每个效果各自一块', function ()
    local game = newGame(1)

    local one = New 'ProbeEffect' (game, nil)
    lt.assertEquals('没问过就没有临时区', nil, one.tempZone)

    local zone = one:getTempZone()
    lt.assertEquals('问两次拿到同一块', zone, one:getTempZone())
    lt.assertEquals('就是普通牌区', 'zone', zone.kind)

    local other = New 'ProbeEffect' (game, nil)
    lt.assertEquals('另一个效果是另一块', true, other:getTempZone() ~= zone)
end)

lt.test('效果：结完时收尾一次', function ()
    local game = newGame(1)
    ---@type Effect[]
    local finished = {}
    game:on('效果-收尾', function (effect)
        finished[#finished+1] = effect
    end)

    local probe = New 'ProbeEffect' (game, nil)
    probe:apply()

    lt.assertEquals('只收一次', 1, #finished)
    lt.assertEquals('收的就是它', probe, finished[1])
end)

lt.test('效果：不成立也收尾', function ()
    local game = newGame(1)
    local finished = 0
    game:on('效果-收尾', function () finished = finished + 1 end)

    local reject = New 'RejectEffect' (game)
    reject:apply()

    lt.assertEquals('这次结算不成立', '不成立', reject.err)
    lt.assertEquals('照样收尾', 1, finished)
end)

lt.test('效果：取消也收尾（牌不能留在已经死掉的效果里）', function ()
    local game = newGame(1)
    local finished = 0
    game:on('效果-收尾', function () finished = finished + 1 end)
    game:on('即将生效', function (effect)
        ---@cast effect Effect
        effect:remove()
    end)

    New 'ProbeEffect' (game, nil):apply()

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

lt.test('效果：收尾只发信号，临时区里的牌不会自己跑掉', function ()
    local game = newGame(1)
    local probe = New 'ProbeEffect' (game, nil)
    local zone = probe:getTempZone()
    local card = game:createCard('测试牌')
    game:moveCard(card, zone)

    probe:apply()

    lt.assertEquals('牌还在临时区里', 1, zone:count())
    lt.assertEquals('位置就是这块临时区', zone, card:getZone())
end)
