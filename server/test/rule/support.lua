---@class Test.RuleSupport
---@field 玩家 Core.Player[]
---@field desk Core.Desk
---@field random Core.Random
local M = {}

---@return unknown # 配 <close> 用：把来源复位为默认
function M.usePackages()
    moe.rule.setRoots(moe.rule.DEFAULT_SOURCES)
    return moe.util.defer(function ()
        moe.rule.setRoots(moe.rule.DEFAULT_SOURCES)
    end)
end

---@param list string[]
---@return unknown # 配 <close> 用
function M.load(list)
    local guard = M.usePackages()
    moe.rule.load(list)
    return guard
end

---@param 人数 integer
---@param 种子? integer
---@return Test.RuleSupport
function M.start(人数, 种子)
    local 属性系统 = assert(moe.rule:getValue('属性系统'), '基础包没有提供属性系统')
    local desk     = moe.core.desk.create(人数)
    local random   = moe.core.random.create(种子 or 1)
    ---@type Core.Player[]
    local 玩家 = {}
    for i = 1, 人数 do
        local player = moe.core.player.create { attributes = 属性系统:createInstance() }
        desk:sit(i, player)
        玩家[i] = player
    end
    moe.rule:fire('游戏-开始', { desk = desk, random = random })
    return { 玩家 = 玩家, desk = desk, random = random }
end

return M
