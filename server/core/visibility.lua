--- 可见性：`true` = 所有人、`false` = 无人、一名或一批角色 = 只有他们、谓词 = 逐人现算
---@alias Visibility boolean|Player|Player[]|fun(player: Player): boolean

---@class Visibility.API
moe.visibility = {}

--- 单值包成一批，其余原样
---@param value Visibility
---@return Visibility
function moe.visibility.normalize(value)
    if type(value) == 'boolean' or type(value) == 'function' then
        return value
    end
    return moe.util.toList(value)
end

--- 这份可见性对某人是否可见
---@param value Visibility
---@param viewer Player
---@return boolean
function moe.visibility.isVisibleTo(value, viewer)
    if type(value) == 'boolean' then
        return value
    end
    if type(value) == 'function' then
        return value(viewer) and true or false
    end
    for _, player in ipairs(value) do
        if player == viewer then
            return true
        end
    end
    return false
end
