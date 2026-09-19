---@class Test.RuleSupport
---@field players Core.Player[]
---@field desk Core.Desk
---@field random Core.Random
---@field room Core.Room
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
    local attributeSystem = assert(moe.rule:getAttributeSystem(), '基础包没有提供属性系统')
    local desk            = moe.core.desk.create(count)
    local random          = moe.core.random.create(seed or 1)
    ---@type Core.Player[]
    local players = {}
    for i = 1, count do
        local player = moe.core.player.create { attributes = attributeSystem:createInstance() }
        desk:sit(i, player)
        players[i] = player
    end
    local room = moe.core.room.create { desk = desk, random = random }
    moe.rule:fire('游戏-开始', { desk = desk, random = random, room = room })
    return { players = players, desk = desk, random = random, room = room }
end

return M
