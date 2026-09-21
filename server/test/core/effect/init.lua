local lt = require 'test.ltest'

---@class ProbeEffect : Effect # 测试用：把建实例时给的请求当作这次结算的结果交出去
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

---@param count integer
---@return Game
---@return Player[] # 按座位号升序
local function newGame(count)
    local desk   = moe.desk.create(count)
    local random = moe.random.create(1)
    local game   = moe.game.create { desk = desk, random = random }
    local attributeSystem = game:getAttributeSystem()
    attributeSystem:define('体力', {
        min    = -999999,
        max    = 999999,
        simple = true,
    })
    ---@type Player[]
    local players = {}
    for i = 1, count do
        local player = moe.player.create { attributes = attributeSystem:createInstance() }
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

lt.test('效果：结算期间是根，结束就清掉', function ()
    local game, players = newGame(2)

    ---@type string[]
    local trace = {}

    game:on('伤害-前', function (ctx)
        trace[#trace + 1] = '前 {}' % { tostring(game:getEffect() == ctx) }
    end)
    game:on('伤害-后', function (ctx)
        trace[#trace + 1] = '后 {}' % { tostring(game:getEffect() == ctx) }
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

    game:on('伤害-前', function (ctx)
        ---@cast ctx Damage
        trace[#trace + 1] = '进入 {} 层 {}' % { ctx.deep, ctx.to == players[2] and '外层' or '内层' }
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

    game:on('伤害-前', function (ctx)
        ---@cast ctx Effect
        if not nested then
            nested    = true
            outerSeen = ctx
            game:damage(players[2], players[3], 1)
        else
            innerSeen  = ctx
            parentSeen = ctx.parent
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

    game:on('伤害-前', function (ctx)
        ---@cast ctx Effect
        topSeen = ctx
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('父效果是不存在', nil, assert(topSeen).parent)
    lt.assertEquals('记牌器留下了这一条', 1, #game:getEffects())
end)

lt.test('效果：沿父效果能还原整条结算链', function ()
    local game, players = newGame(4)

    ---@type Effect[] # 按进入顺序
    local entered = {}

    game:on('伤害-前', function (ctx)
        ---@cast ctx Effect
        entered[#entered + 1] = ctx
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

lt.test('效果：嵌套过深被拒绝', function ()
    local game, players = newGame(2)

    ---@type integer
    local depth = 0

    game:on('伤害-前', function ()
        depth = depth + 1
        if depth < 200 then
            game:damage(players[1], players[2], 0)
        end
    end)

    game:damage(players[1], players[2], 0)

    lt.assertEquals('第 101 层发动不了，就停在这一层', 100, depth)
    lt.assertEquals('只记根，内层不单独记', 1, #game:getEffects())
end)

lt.test('效果：即将生效的订阅者能取消这一次生效', function ()
    local game, players = newGame(2)

    ---@type string[]
    local trace = {}

    game:on('即将生效', function (ctx)
        trace[#trace + 1] = '{} {}' % { ctx.kind, game:getEffect() == ctx }
        ---@cast ctx Effect
        ctx:remove()
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
    game:on('即将生效', function (ctx)
        ---@cast ctx Damage
        if ctx.amount == 2 then
            ctx:remove()
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

    game:on('即将生效', function (ctx)
        ---@cast ctx Effect
        ctx:remove()
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

    game:on('即将生效', function (ctx)
        ---@cast ctx Effect
        ctx:remove()
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
