local lt      = require 'test.ltest'
local support = require 'test.rule.support'

---@param 玩家 Core.Player
---@return Core.Attributes
local function 属性(玩家)
    return 玩家:getAttributes()
end

---@return integer # 当前牌表的总张数
local function 牌表总数()
    local 牌表 = assert(moe.rule:getValue('牌表'), '没有牌表')
    local 总数 = 0
    for _, 种类 in ipairs(牌表) do
        总数 = 总数 + 种类.张数
    end
    return 总数
end

---@param 局 Test.RuleSupport
---@return boolean
local function 身份齐全(局)
    for i = 1, #局.玩家 do
        if type(局.玩家[i]:getTag('身份')) ~= 'string' then
            return false
        end
    end
    return true
end

lt.test('开局：8 人完整装配', function ()
    local guard <close> = support.load { '基础', '身份场', '标准' }

    local 局 = support.start(8)

    lt.assertEquals('八个人都在桌上', 8, #局.desk:getPlayers())
    lt.assertEquals('1 号位是主公', '主公', 局.玩家[1]:getTag('身份'))
    lt.assertEquals('主公上限 5', 5, 属性(局.玩家[1]):get('体力上限'))
    lt.assertEquals('主公体力也是 5', 5, 属性(局.玩家[1]):get('体力'))
    lt.assertEquals('其他人上限 4', 4, 属性(局.玩家[8]):get('体力上限'))
    lt.assertEquals('牌堆建好了', true, moe.rule:getValue('牌堆') ~= nil)
    lt.assertEquals('牌堆张数等于牌表总张数', 牌表总数(), moe.rule:getValue('牌堆'):count())
    lt.assertEquals('每人都有身份', true, 身份齐全(局))
end)

lt.test('开局：同一 seed 两次开局的分配一致', function ()
    local guard <close> = support.load { '基础', '身份场', '标准' }

    ---@return string[]
    local function 身份序列()
        local 局 = support.start(8, 42)
        ---@type string[]
        local 序列 = {}
        for i = 1, 8 do
            序列[i] = tostring(局.玩家[i]:getTag('身份'))
        end
        return 序列
    end

    lt.assertEquals('同一 seed 身份分配一致', table.concat(身份序列(), ','), table.concat(身份序列(), ','))
end)

lt.test('开局：换一个 seed 身份分配（通常）不同', function ()
    local guard <close> = support.load { '基础', '身份场', '标准' }

    ---@param 种子 integer
    ---@return string
    local function 身份串(种子)
        local 局 = support.start(8, 种子)
        ---@type string[]
        local 序列 = {}
        for i = 2, 8 do
            序列[i-1] = tostring(局.玩家[i]:getTag('身份'))
        end
        return table.concat(序列, ',')
    end

    local 不同 = false
    for 种子 = 1, 20 do
        if 身份串(种子) ~= 身份串(0) then
            不同 = true
            break
        end
    end

    lt.assertEquals('换 seed 能换出不同的分配', true, 不同)
end)
