---@generic T
---@param list T[]
---@param predicate fun(value: T): boolean
---@return T[]
function table.filter(list, predicate)
    local result = {}
    for i = 1, #list do
        local value = list[i]
        if predicate(value) then
            result[#result + 1] = value
        end
    end
    return result
end

---@generic T, U
---@param list T[]
---@param transform fun(value: T, index: integer): U
---@return U[]
function table.map(list, transform)
    local result = {}
    for i = 1, #list do
        result[i] = transform(list[i], i)
    end
    return result
end

---@generic T
---@param list T[]
---@param value T
---@return boolean
function table.contains(list, value)
    for i = 1, #list do
        if list[i] == value then
            return true
        end
    end
    return false
end
