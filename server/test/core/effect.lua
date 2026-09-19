local lt = require 'test.ltest'

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

lt.test('效果：空栈时查不到当前效果', function ()
    local game = newGame(1)

    lt.assertEquals('没有正在结算的', nil, game:getCurrentEffect())
    lt.assertEquals('栈是空的', 0, #game:getEffects())
end)

lt.test('效果：结算期间在栈上，结束就退栈', function ()
    local game, players = newGame(2)

    ---@type string[]
    local trace = {}

    game.events:on('伤害-前', function ()
        trace[#trace + 1] = '前 {} {}' % { assert(game:getCurrentEffect()).kind, #game:getEffects() }
    end)
    game.events:on('伤害-后', function ()
        trace[#trace + 1] = '后 {} {}' % { assert(game:getCurrentEffect()).kind, #game:getEffects() }
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('两个时机都在栈上看到这次伤害', '前 damage 1,后 damage 1', table.concat(trace, ','))
    lt.assertEquals('结算完栈空', 0, #game:getEffects())
    lt.assertEquals('查不到当前效果', nil, game:getCurrentEffect())
end)

lt.test('效果：嵌套结算会压深，结束后回到外层', function ()
    local game, players = newGame(3)

    ---@type string[]
    local trace = {}
    ---@type boolean
    local nested = false

    game.events:on('伤害-前', function ()
        local current = assert(game:getCurrentEffect())
        ---@cast current Damage
        trace[#trace + 1] = '进入 {} 层 {}' % { #game:getEffects(), current.to == players[2] and '外层' or '内层' }
        if not nested then
            nested = true
            game:damage(players[2], players[3], 1)
        end
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('外层先进、内层后进', '进入 1 层 外层,进入 2 层 内层', table.concat(trace, ','))
    lt.assertEquals('外层目标掉血', 3, players[2]:getAttr('体力'))
    lt.assertEquals('内层目标掉血', 3, players[3]:getAttr('体力'))
    lt.assertEquals('结算完栈空', 0, #game:getEffects())
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

    game.events:on('伤害-前', function ()
        local current = assert(game:getCurrentEffect())
        if not nested then
            nested    = true
            outerSeen = current
            game:damage(players[2], players[3], 1)
        else
            innerSeen  = current
            parentSeen = current.parent
        end
    end)

    game:damage(players[1], players[2], 1)

    local outer = assert(outerSeen, '外层没被记下来')
    local inner = assert(innerSeen, '内层没被记下来')
    lt.assertEquals('内层的父是外层', true, parentSeen == outer)
    lt.assertEquals('内层自己认的是外层', true, inner.parent == outer)
    lt.assertEquals('两者不是同一个', true, inner ~= outer)
    lt.assertEquals('外层的父不存在', nil, outer.parent)
    lt.assertEquals('结算完栈空', 0, #game:getEffects())
end)

lt.test('效果：根效果的父不存在，也不报错', function ()
    local game, players = newGame(2)

    ---@type Effect?
    local topSeen = nil

    game.events:on('伤害-前', function ()
        topSeen = game:getCurrentEffect()
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('父效果是不存在', nil, assert(topSeen).parent)
end)

lt.test('效果：沿父效果能还原整条结算链', function ()
    local game, players = newGame(4)

    ---@type Effect[] # 按进入顺序
    local entered = {}

    game.events:on('伤害-前', function ()
        entered[#entered + 1] = assert(game:getCurrentEffect())
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

    local message = assert(lt.assertError('错误照常向外传播', function ()
        damage:apply()
    end))

    lt.assertEquals('栈上没有留下这一帧', 0, #game:getEffects())
    lt.assertEquals('体力没变（错误发生在改体力之前）', 4, players[2]:getAttr('体力'))
    lt.assertEquals('错误信息里带出错位置', true, message:find('effect.lua:', 1, true) ~= nil)
end)

lt.test('效果：取到的是快照', function ()
    local game, players = newGame(2)

    ---@type Effect[]?
    local snapshot = nil

    game.events:on('伤害-前', function ()
        snapshot = game:getEffects()
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('当时栈深 1', 1, snapshot and #snapshot)
    lt.assertEquals('之后栈空了', 0, #game:getEffects())
    lt.assertEquals('快照还是当时的样子', 1, snapshot and #snapshot)
end)

lt.test('效果：顺序是栈底到栈顶', function ()
    local game, players = newGame(3)

    ---@type Effect[]?
    local snapshot = nil
    ---@type Effect?
    local topSeen = nil
    ---@type Effect?
    local currentSeen = nil
    ---@type boolean
    local nested = false

    game.events:on('伤害-前', function ()
        currentSeen = game:getCurrentEffect()
        if not nested then
            nested = true
            game:damage(players[2], players[3], 1)
        else
            snapshot = game:getEffects()
            topSeen = game:getCurrentEffect()
        end
    end)

    game:damage(players[1], players[2], 1)

    ---@type Effect[]
    local list = assert(snapshot)
    lt.assertEquals('内外都在栈上', 2, #list)
    lt.assertEquals('最后一个就是当前正在结算的', true, topSeen == list[2])
    lt.assertEquals('最前面那个是最外层', true, list[1] ~= currentSeen)
    lt.assertEquals('结算完栈空', 0, #game:getEffects())
end)

lt.test('效果：压栈返回的撤销函数精确且幂等', function ()
    local game, players = newGame(2)
    local outer = moe.damage.create { game = game, from = players[1], to = players[2], amount = 1 }
    local inner = moe.damage.create { game = game, from = players[1], to = players[2], amount = 1 }

    local popOuter = game:pushEffect(outer)
    local popInner = game:pushEffect(inner)

    lt.assertEquals('栈深 2', 2, #game:getEffects())
    lt.assertEquals('栈顶是内层', inner, game:getCurrentEffect())

    lt.assertError('乱序退栈被拒绝', popOuter)
    lt.assertEquals('栈没被弄乱', inner, game:getCurrentEffect())

    popInner()
    lt.assertEquals('弹出内层后栈顶是外层', outer, game:getCurrentEffect())

    popInner()
    lt.assertEquals('重复撤销安全（栈没变）', outer, game:getCurrentEffect())

    popOuter()
    lt.assertEquals('栈空', 0, #game:getEffects())

    popOuter()
    lt.assertEquals('再撤销一次也安全', 0, #game:getEffects())
end)

lt.test('效果：压栈有深度上限', function ()
    local game, players = newGame(2)
    local effect = moe.damage.create { game = game, from = players[1], to = players[2], amount = 1 }

    ---@type function[]
    local disposers = {}
    for _ = 1, 100 do
        disposers[#disposers + 1] = game:pushEffect(effect)
    end

    lt.assertError('第 101 层被拒绝', function ()
        game:pushEffect(effect)
    end)
    lt.assertEquals('已有的 100 层不受影响', 100, #game:getEffects())

    for i = #disposers, 1, -1 do
        disposers[i]()
    end
    lt.assertEquals('退干净', 0, #game:getEffects())
end)

lt.test('效果：即将生效的订阅者能取消这一次生效', function ()
    local game, players = newGame(2)

    ---@type string[]
    local trace = {}

    game.events:on('即将生效', function (ctx)
        trace[#trace + 1] = '{} {}' % { ctx.kind, game:getCurrentEffect() == ctx }
        ---@cast ctx Effect
        ctx:remove()
        trace[#trace + 1] = '取消之后这一行不该执行'
    end)
    game.events:on('即将生效', function ()
        trace[#trace + 1] = '后面的订阅者也不该执行'
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('订阅者拿到的是这个效果，且此刻它在栈顶', 'damage true', table.concat(trace, ','))
    lt.assertEquals('被取消 ⇒ 没有造成伤害', 4, players[2]:getAttr('体力'))
    lt.assertEquals('栈恢复原状', 0, #game:getEffects())
end)

lt.test('效果：取消只作用于这一个效果，外层照常结算完', function ()
    local game, players = newGame(3)

    ---@type boolean
    local outerDone = false
    ---@type boolean
    local nested = false

    game.events:on('伤害-前', function ()
        if not nested then
            nested = true
            game:damage(players[2], players[3], 2)
            outerDone = true
        end
    end)
    game.events:on('即将生效', function (ctx)
        ---@cast ctx Damage
        if ctx.amount == 2 then
            ctx:remove()
        end
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('内层被取消 ⇒ 内层目标没掉血', 4, players[3]:getAttr('体力'))
    lt.assertEquals('外层照常走完', true, outerDone)
    lt.assertEquals('外层目标照常掉血', 3, players[2]:getAttr('体力'))
    lt.assertEquals('栈恢复原状', 0, #game:getEffects())
end)

lt.test('效果：被取消后它自己的结算不再执行', function ()
    local game, players = newGame(2)

    ---@type string[]
    local trace = {}

    game.events:on('即将生效', function (ctx)
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
    local damage = moe.damage.create { game = game, from = players[1], to = players[2], amount = 1 }

    lt.assertError('还没开始结算', function ()
        damage:remove()
    end)

    damage:apply()

    lt.assertError('已经结算完毕', function ()
        damage:remove()
    end)
    lt.assertEquals('正常结算照常掉血', 3, players[2]:getAttr('体力'))
end)
