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
    return game, players
end

lt.test('回复：回复后体力上升', function ()
    local game, players = newGame(2)

    local heal = game:heal(players[2], 2)

    lt.assertEquals('种类标识', 'heal', heal.kind)
    lt.assertEquals('目标回 2 点', 6, players[2]:getAttr('体力'))
    lt.assertEquals('别人不受影响', 4, players[1]:getAttr('体力'))
    lt.assertEquals('入口返回已经结完的效果', nil, heal.err)
end)

lt.test('回复：建实例先不结算就不回血', function ()
    local game, players = newGame(2)
    local heal = New 'Heal' (game, players[2], 2)

    lt.assertEquals('实例带目标', players[2], heal.to)
    lt.assertEquals('实例带点数', 2, heal.amount)
    lt.assertEquals('还没结算，体力不变', 4, players[2]:getAttr('体力'))

    heal:apply():await()

    lt.assertEquals('结算之后才变化', 6, players[2]:getAttr('体力'))
end)

lt.test('回复：四个阶段各三份（全局 → 来源 → 目标）', function ()
    local game, players = newGame(3)
    local healer = players[1]

    ---@type string[]
    local seen = {}
    local function watch(stage)
        game:on('治疗-' .. stage, function ()
            seen[#seen + 1] = '全局-' .. stage
        end)
        healer:on('治疗-来源-' .. stage, function ()
            seen[#seen + 1] = '来源-' .. stage
        end)
        players[2]:on('治疗-目标-' .. stage, function ()
            seen[#seen + 1] = '目标-' .. stage
        end)
    end
    watch('开始')
    watch('生效前')
    watch('生效后')
    watch('结束')

    ---@type integer? # 发「生效前」时目标的体力（应当还没加）
    local hpBefore = nil
    game:on('治疗-生效前', function (heal)
        hpBefore = heal.to:getAttr('体力')
    end)

    local heal = game:heal(players[2], 2, healer)

    local expected = '全局-开始,来源-开始,目标-开始,'
                  .. '全局-生效前,来源-生效前,目标-生效前,'
                  .. '全局-生效后,来源-生效后,目标-生效后,'
                  .. '全局-结束,来源-结束,目标-结束'
    lt.assertEquals('四个阶段按序、每阶段三份', expected, table.concat(seen, ','))
    lt.assertEquals('生效前还没加体力', 4, hpBefore)
    lt.assertEquals('来源带上了', healer, heal.from)
    lt.assertEquals('加完是 6', 6, players[2]:getAttr('体力'))
end)

lt.test('回复：在「生效前」改 amount 就能改点数', function ()
    local game, players = newGame(2)

    game:on('治疗-生效前', function (heal)
        heal.amount = heal.amount + 1
    end)

    game:heal(players[2], 1)

    lt.assertEquals('1 点改成 2 点', 6, players[2]:getAttr('体力'))
end)

lt.test('回复：无来源时只发全局与目标两份', function ()
    local game, players = newGame(2)

    local sourceCount = 0
    players[1]:on('治疗-来源-生效前', function ()
        sourceCount = sourceCount + 1
    end)
    local globalCount = 0
    local targetCount = 0
    game:on('治疗-生效前', function ()
        globalCount = globalCount + 1
    end)
    players[2]:on('治疗-目标-生效前', function ()
        targetCount = targetCount + 1
    end)

    game:heal(players[2], 1)

    lt.assertEquals('全局照发', 1, globalCount)
    lt.assertEquals('目标照发', 1, targetCount)
    lt.assertEquals('没有来源就不发来源那份', 0, sourceCount)
end)
