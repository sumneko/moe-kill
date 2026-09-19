---@class Core
---@field card Core.Card
---@field zone Core.Zone
---@field orderedZone Core.OrderedZone
---@field random Core.Random
---@field attribute Core.AttributeSystem
---@field event Core.Event
---@field desk Core.Desk
---@field player Core.Player
moe.core = moe.core or {}

---@private
---@param name string
---@return any
local function includeCore(name)
    local mod, err = include(name)
    if not mod then
        error(('内核模块 {} 加载失败：{}' % { name, err }), 0)
    end
    return mod
end

moe.core.card        = includeCore 'core.card'
moe.core.zone        = includeCore 'core.zone'
moe.core.orderedZone = includeCore 'core.ordered-zone'
moe.core.random      = includeCore 'core.random'
moe.core.attribute   = includeCore 'core.attribute'
moe.core.event       = includeCore 'core.event'
moe.core.desk        = includeCore 'core.desk'
moe.core.player      = includeCore 'core.player'

return moe.core
