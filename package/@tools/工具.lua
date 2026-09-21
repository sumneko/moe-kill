-- 内容侧的纯函数工具集：写在共享环境里（全局 util），所有规则包都能用
-- 只放纯函数 —— 有副作用的能力（读文件 / 定时器…）一律不给

local function filter(list, predicate)
    local result = {}
    for i = 1, #list do
        local value = list[i]
        if predicate(value) then
            result[#result + 1] = value
        end
    end
    return result
end

local function map(list, transform)
    local result = {}
    for i = 1, #list do
        result[i] = transform(list[i], i)
    end
    return result
end

local function contains(list, value)
    for i = 1, #list do
        if list[i] == value then
            return true
        end
    end
    return false
end

util = {
    filter   = filter,
    map      = map,
    contains = contains,
}
