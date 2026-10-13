--- 线上形状的运行时校验：叶子用类型字符串（`?` 可选、`[]` 数组）、结构用表（默认必填、多一个字段也算不合）
--- 形状表照 `server/proto.d.lua` 的同名类写（那边是给人看的声明，这边是给机器查的表）

---@class Shape.API
moe.shape = {}

--- 一个形状：类型字符串（`'integer'` / `'integer[]?'` …）或嵌套的表
---@alias Shape string|table

--- 数组标记（`moe.shape.array(形状)`：这个位置是数组，元素照它）
local ARRAY = {}
--- 可选标记（`moe.shape.optional(形状)`：这个位置可以没有）
local OPTIONAL = {}

--- 这个位置是数组（元素照 `shape`）
---@param shape Shape
---@return table
function moe.shape.array(shape)
    return { [ARRAY] = shape }
end

--- 这个位置可以没有
---@param shape Shape
---@return table
function moe.shape.optional(shape)
    return { [OPTIONAL] = shape }
end

---@type table<string, fun(value: any): boolean>
local LEAVES = {
    integer = function (value) return math.type(value) == 'integer' end,
    number  = function (value) return type(value) == 'number' end,
    string  = function (value) return type(value) == 'string' end,
    boolean = function (value) return type(value) == 'boolean' end,
    table   = function (value) return type(value) == 'table' end,
    any     = function () return true end,
}

--- 值是什么类型（写给人看的）
---@param value any
---@return string
local function typeName(value)
    return math.type(value) or type(value)
end

--- 路径显示（顶层没有字段就写「值」）
---@param path string
---@return string
local function where(path)
    if path == '' then
        return '值'
    end
    return '「' .. path .. '」'
end

--- 是不是真列表（连续、从 1 开始；空表也算）
---@param value table
---@return boolean
local function isList(value)
    local count = 0
    for key in pairs(value) do
        if math.type(key) ~= 'integer' or key < 1 then
            return false
        end
        count = count + 1
    end
    return count == #value
end

--- 值合不合这个形状；不合给原因（带路径），合给空
---@param value any
---@param shape Shape
---@param path string # 已经点好的路径（顶层给空串）
---@return string?
local function mismatch(value, shape, path)
    if type(shape) == 'table' then
        local element = rawget(shape, ARRAY)
        local inner   = rawget(shape, OPTIONAL)
        if element ~= nil then
            if type(value) ~= 'table' or not isList(value) then
                return '{}应该是数组（现在是 {}）' % { where(path), typeName(value) }
            end
            for index, one in ipairs(value) do
                local why = mismatch(one, element, path .. '[' .. index .. ']')
                if why then
                    return why
                end
            end
            return nil
        end
        if inner ~= nil then
            if value == nil then
                return nil
            end
            return mismatch(value, inner, path)
        end
        if type(value) ~= 'table' then
            return '{}应该是表（现在是 {}）' % { where(path), typeName(value) }
        end
        for key, fieldShape in pairs(shape) do
            local why = mismatch(value[key], fieldShape, path == '' and key or path .. '.' .. key)
            if why then
                return why
            end
        end
        for key in pairs(value) do
            if shape[key] == nil then
                return '{}多了个字段' % { where(path == '' and tostring(key) or path .. '.' .. tostring(key)) }
            end
        end
        return nil
    end

    if type(shape) ~= 'string' then
        error('形状只能是类型字符串或表', 3)
    end

    local list     = false
    local optional = false
    local base     = shape
    if base:sub(-1) == '?' then
        optional = true
        base = base:sub(1, -2)
    end
    if base:sub(-2) == '[]' then
        list = true
        base = base:sub(1, -3)
    end
    local accepts = LEAVES[base]
    if not accepts then
        error('认不出的形状「{}」' % { shape }, 3)
    end

    if value == nil then
        if optional then
            return nil
        end
        return '{}不能没有' % { where(path) }
    end
    if list then
        if type(value) ~= 'table' or not isList(value) then
            return '{}应该是数组（现在是 {}）' % { where(path), typeName(value) }
        end
        for index, one in ipairs(value) do
            if not accepts(one) then
                return '{}应该是 {}（现在是 {}）' % { where(path .. '[' .. index .. ']'), base, typeName(one) }
            end
        end
        return nil
    end
    if not accepts(value) then
        return '{}应该是 {}（现在是 {}）' % { where(path), base, typeName(value) }
    end
    return nil
end

--- 值合不合这个形状；不合就给原因（带路径的中文短句），合就给空
---@param value any
---@param shape Shape
---@return string?
function moe.shape.problem(value, shape)
    return mismatch(value, shape, '')
end

return moe.shape
