---@class Test.RuleSupport
---@field players Core.Player[]
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

---@param count integer
---@param seed? integer
---@return Test.RuleSupport
function M.start(count, seed)
    local attributeSystem = assert(moe.rule:getValue('属性系统'), '基础包没有提供属性系统')
    local desk            = moe.core.desk.create(count)
    local random          = moe.core.random.create(seed or 1)
    ---@type Core.Player[]
    local players = {}
    for i = 1, count do
        local player = moe.core.player.create { attributes = attributeSystem:createInstance() }
        desk:sit(i, player)
        players[i] = player
    end
    moe.rule:fire('游戏-开始', { desk = desk, random = random })
    return { players = players, desk = desk, random = random }
end

return M
