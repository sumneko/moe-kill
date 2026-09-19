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

moe.card        = includeCore 'core.card'
moe.zone        = includeCore 'core.zone'
moe.orderedZone = includeCore 'core.ordered-zone'
moe.random      = includeCore 'core.random'
moe.attribute   = includeCore 'core.attribute'
moe.event       = includeCore 'core.event'
moe.rule        = includeCore 'core.rule'
moe.desk        = includeCore 'core.desk'
moe.player      = includeCore 'core.player'
moe.room        = includeCore 'core.room'

return moe
