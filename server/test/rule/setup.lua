local lt      = require 'test.ltest'
local support = require 'test.rule.support'

---@param player Core.Player
---@return Core.Attributes
local function attributes(player)
    return player:getAttributes()
end

---@return integer # 当前牌表的总张数
local function totalCards()
    local cardTable = assert(moe.rule:getValue('牌表'), '没有牌表')
    local total = 0
    for _, entry in ipairs(cardTable) do
        total = total + entry.count
    end
    return total
end

---@param game Test.RuleSupport
---@return boolean
local function allHaveIdentity(game)
    for i = 1, #game.players do
        if type(game.players[i]:getTag('身份')) ~= 'string' then
            return false
        end
    end
    return true
end

lt.test('开局：8 人完整装配', function ()
    local guard <close> = support.load { '身份场', '标准' }

    local game = support.start(8)

    lt.assertEquals('八个人都在桌上', 8, #game.desk:getPlayers())
    lt.assertEquals('1 号位是主公', '主公', game.players[1]:getTag('身份'))
    lt.assertEquals('主公上限 5', 5, attributes(game.players[1]):get('体力上限'))
    lt.assertEquals('主公体力也是 5', 5, attributes(game.players[1]):get('体力'))
    lt.assertEquals('其他人上限 4', 4, attributes(game.players[8]):get('体力上限'))
    lt.assertEquals('牌堆建好了', true, game.room:getZone('抽牌堆') ~= nil)
    lt.assertEquals('牌堆张数等于牌表总张数', totalCards(), assert(game.room:getZone('抽牌堆')):count())
    lt.assertEquals('每人都有身份', true, allHaveIdentity(game))
end)

lt.test('开局：同一 seed 两次开局的分配一致', function ()
    local guard <close> = support.load { '身份场', '标准' }

    ---@return string[]
    local function identitySequence()
        local game = support.start(8, 42)
        ---@type string[]
        local result = {}
        for i = 1, 8 do
            result[i] = tostring(game.players[i]:getTag('身份'))
        end
        return result
    end

    lt.assertEquals('同一 seed 身份分配一致', table.concat(identitySequence(), ','), table.concat(identitySequence(), ','))
end)

lt.test('开局：换一个 seed 身份分配（通常）不同', function ()
    local guard <close> = support.load { '身份场', '标准' }

    ---@param seed integer
    ---@return string
    local function identityString(seed)
        local game = support.start(8, seed)
        ---@type string[]
        local result = {}
        for i = 2, 8 do
            result[i-1] = tostring(game.players[i]:getTag('身份'))
        end
        return table.concat(result, ',')
    end

    local differs = false
    for seed = 1, 20 do
        if identityString(seed) ~= identityString(0) then
            differs = true
            break
        end
    end

    lt.assertEquals('换 seed 能换出不同的分配', true, differs)
end)
