local lt      = require 'test.ltest'
local support = require 'test.rule.support'

---@param player Moe.Player
---@return Moe.Attributes
local function attributes(player)
    return player:getAttributes()
end

---@param game Moe.Game
---@return integer # 当前牌表的总张数
local function totalCards(game)
    local cardTable = assert(game:getValue('牌表'), '没有牌表')
    local total = 0
    for _, entry in ipairs(cardTable) do
        total = total + entry.count
    end
    return total
end

---@param run Test.RuleSupport
---@return boolean
local function allHaveIdentity(run)
    for i = 1, #run.players do
        if type(run.players[i]:getTag('身份')) ~= 'string' then
            return false
        end
    end
    return true
end

lt.test('开局：8 人完整装配', function ()
    local run = support.start { packages = { '身份场', '标准' }, count = 8 }

    lt.assertEquals('八个人都在桌上', 8, #run.desk:getPlayers())
    lt.assertEquals('1 号位是主公', '主公', run.players[1]:getTag('身份'))
    lt.assertEquals('主公上限 6', 6, attributes(run.players[1]):get('体力上限'))
    lt.assertEquals('主公体力也是 6', 6, attributes(run.players[1]):get('体力'))
    lt.assertEquals('其他人上限 5', 5, attributes(run.players[8]):get('体力上限'))
    lt.assertEquals('牌堆建好了', true, run.game:getZone('抽牌堆') ~= nil)
    lt.assertEquals('牌堆张数等于牌表总张数', totalCards(run.game), assert(run.game:getZone('抽牌堆')):count())
    lt.assertEquals('每人都有身份', true, allHaveIdentity(run))
end)

lt.test('开局：同一 seed 两次开局的分配一致', function ()
    ---@return string[]
    local function identitySequence()
        local run = support.start { packages = { '身份场', '标准' }, count = 8, seed = 42 }
        ---@type string[]
        local result = {}
        for i = 1, 8 do
            result[i] = tostring(run.players[i]:getTag('身份'))
        end
        return result
    end

    lt.assertEquals('同一 seed 身份分配一致', table.concat(identitySequence(), ','), table.concat(identitySequence(), ','))
end)

lt.test('开局：换一个 seed 身份分配（通常）不同', function ()
    ---@param seed integer
    ---@return string
    local function identityString(seed)
        local run = support.start { packages = { '身份场', '标准' }, count = 8, seed = seed }
        ---@type string[]
        local result = {}
        for i = 2, 8 do
            result[i-1] = tostring(run.players[i]:getTag('身份'))
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
