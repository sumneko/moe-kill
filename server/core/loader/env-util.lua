---@class Loader.EnvUtil # 注入给规则集的**收窄工具集**：只有纯函数，不是内核工具库本体（清单以本文件为准）
---@field filter fun(list: any[], predicate: fun(value: any): boolean): any[] # 泛型参数在 `@field` 里推不出来（LuaLS 不支持），先只给出名字与参数个数
---@field map fun(list: any[], transform: fun(value: any, index: integer): any): any[]
---@field contains fun(list: any[], value: any): boolean
local M = {}

---@generic V
---@param list V[]
---@param predicate fun(value: V): boolean
---@return V[] # 满足条件的那些元素（新表，不动入参）
function M.filter(list, predicate)
    local result = {}
    for i = 1, #list do
        local value = list[i]
        if predicate(value) then
            result[#result+1] = value
        end
    end
    return result
end

M.map      = moe.util.map
M.contains = moe.util.arrayHas

return M
