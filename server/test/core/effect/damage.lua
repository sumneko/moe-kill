local lt = require 'test.ltest'

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
    game.turnPlayer = players[1]
    return game, players
end

lt.test('伤害：造成伤害后体力下降', function ()
    local game, players = newGame(2)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('目标掉 1 点体力', 3, players[2]:getAttr('体力'))
    lt.assertEquals('来源不受影响', 4, players[1]:getAttr('体力'))
end)

lt.test('伤害：体力可以降到负数', function ()
    local game, players = newGame(2)

    players[2]:setAttr('体力', 1)
    game:damage(players[1], players[2], 3)

    lt.assertEquals('1 被减 3 之后是 -2', -2, players[2]:getAttr('体力'))
end)

lt.test('伤害：连续伤害逐次减去', function ()
    local game, players = newGame(2)

    game:damage(players[1], players[2], 1)
    game:damage(players[1], players[2], 2)

    lt.assertEquals('两次伤害累计', 1, players[2]:getAttr('体力'))
end)

lt.test('伤害：没有订阅者时照常', function ()
    local game, players = newGame(2)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('照样掉血', 3, players[2]:getAttr('体力'))
end)

lt.test('伤害：建实例先不结算就不掉血', function ()
    local game, players = newGame(2)
    local damage = New 'Damage' (game, players[1], players[2], 2)

    lt.assertEquals('实例带来源', players[1], damage.from)
    lt.assertEquals('实例带目标', players[2], damage.to)
    lt.assertEquals('实例带点数', 2, damage.amount)
    lt.assertEquals('实例知道自己属于哪一局', game, damage.game)
    lt.assertEquals('还没结算，体力不变', 4, players[2]:getAttr('体力'))

    damage:apply():await()

    lt.assertEquals('结算之后才变化', 2, players[2]:getAttr('体力'))
end)

lt.test('伤害：便利入口与手写两步等价', function ()
    local game, players = newGame(3)

    game:damage(players[1], players[2], 2)
    local other = New 'Damage' (game, players[1], players[3], 2)
    other:apply():await()

    lt.assertEquals('两条路的结果一样', players[2]:getAttr('体力'), players[3]:getAttr('体力'))
    lt.assertEquals('结果确实是 2', 2, players[3]:getAttr('体力'))
end)

lt.test('伤害：结算期间在栈上', function ()
    local game, players = newGame(2)

    ---@type Damage?
    local damageSeen = nil
    ---@type Effect?
    local topSeen = nil

    game:on('伤害-结束', function (damage)
        damageSeen = damage
        topSeen    = game:getEffect()
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('触发时栈顶就是这次伤害', damageSeen, topSeen)
    lt.assertEquals('种类标识', 'damage', assert(damageSeen).kind)
    lt.assertEquals('记牌器留下了这一条', 1, #game:getEffects())
end)

lt.test('伤害：四个阶段各三份（全局 → 来源 → 目标）', function ()
    local game, players = newGame(2)

    ---@type string[]
    local seen = {}
    local function watch(stage)
        game:on('伤害-' .. stage, function ()
            seen[#seen + 1] = '全局-' .. stage
        end)
        players[1]:on('伤害-来源-' .. stage, function ()
            seen[#seen + 1] = '来源-' .. stage
        end)
        players[2]:on('伤害-目标-' .. stage, function ()
            seen[#seen + 1] = '目标-' .. stage
        end)
    end
    watch('开始')
    watch('生效前')
    watch('生效后')
    watch('结束')

    ---@type integer? # 发「生效前」时目标的体力（应当还没扣）
    local hpBefore = nil
    game:on('伤害-生效前', function (damage)
        hpBefore = damage.to:getAttr('体力')
    end)
    ---@type integer? # 发「生效后」时目标的体力（应当已经扣了）
    local hpAfter = nil
    game:on('伤害-生效后', function (damage)
        hpAfter = damage.to:getAttr('体力')
    end)

    game:damage(players[1], players[2], 1)

    local expected = '全局-开始,来源-开始,目标-开始,'
                  .. '全局-生效前,来源-生效前,目标-生效前,'
                  .. '全局-生效后,来源-生效后,目标-生效后,'
                  .. '全局-结束,来源-结束,目标-结束'
    lt.assertEquals('四个阶段按序、每阶段三份', expected, table.concat(seen, ','))
    lt.assertEquals('生效前还没扣血', 4, hpBefore)
    lt.assertEquals('生效后已经扣了', 3, hpAfter)
end)

lt.test('伤害：濒死夹在「生效前」与「生效后」之间', function ()
    local game, players = newGame(2)
    local victim = players[2]
    victim:setAttr('体力', 1)

    ---@type boolean? # 发「生效前」时还活着吗
    local aliveBefore = nil
    ---@type boolean? # 发「生效后」时还活着吗
    local aliveAfter = nil
    game:on('伤害-生效前', function ()
        aliveBefore = victim:isAlive()
    end)
    game:on('伤害-生效后', function ()
        aliveAfter = victim:isAlive()
    end)

    game:damage(players[1], victim, 3)

    lt.assertEquals('生效前还活着', true, aliveBefore)
    lt.assertEquals('濒死（判死）已经过去', false, aliveAfter)
end)

lt.test('伤害-开始：扣血之前就发，全局先来源后', function ()
    local game, players = newGame(2)

    ---@type string[]
    local seen = {}
    ---@type integer? # 发时机时目标的体力（应当还没扣）
    local hpWhenFired = nil

    game:on('伤害-开始', function (damage)
        seen[#seen + 1] = '全局'
        hpWhenFired = damage.to:getAttr('体力')
    end)
    players[1]:on('伤害-来源-开始', function ()
        seen[#seen + 1] = '来源'
    end)

    game:damage(players[1], players[2], 1)

    lt.assertEquals('全局先、来源后（两份都发了）', '全局,来源', table.concat(seen, ','))
    lt.assertEquals('发的时候还没扣血', 4, hpWhenFired)
    lt.assertEquals('结算完才扣', 3, players[2]:getAttr('体力'))
end)

lt.test('伤害-开始：无来源的伤害只发全局那份', function ()
    local game, players = newGame(2)

    local globalCount = 0
    local sourceCount = 0
    game:on('伤害-开始', function ()
        globalCount = globalCount + 1
    end)
    for _, player in ipairs(players) do
        player:on('伤害-来源-开始', function ()
            sourceCount = sourceCount + 1
        end)
    end

    game:damage(nil, players[2], 1)

    lt.assertEquals('全局那份照发', 1, globalCount)
    lt.assertEquals('没人收到来源那份', 0, sourceCount)
    lt.assertEquals('伤害照常', 3, players[2]:getAttr('体力'))
end)
