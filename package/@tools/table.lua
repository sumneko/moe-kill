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

---@generic T
---@param list T[]
---@param value T
---@return T[] # 去掉这个值的所有出现（不改原表）
function table.without(list, value)
    local result = {}
    for i = 1, #list do
        if list[i] ~= value then
            result[#result + 1] = list[i]
        end
    end
    return result
end

---@generic T
---@param list T[] # 接在这个列表后面（会被改动）
---@param ... T[]
---@return T[]
function table.mergeArray(list, ...)
    local lists = { ... }
    for _, another in ipairs(lists) do
        table.move(another, 1, #another, #list + 1, list)
    end
    return list
end

---@generic T: table
---@param source T
---@return T # 浅拷贝（改它不影响原表）
function table.copy(source)
    local result = {}
    for key, value in pairs(source) do
        result[key] = value
    end
    return result
end
