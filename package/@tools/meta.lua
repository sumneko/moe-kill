---@meta

---@class 工具.工具集 # 给规则集用的纯函数工具集（不是 `moe.util` 本体；清单以 `package/@tools/工具.lua` 为准）
---@field filter fun(list: any[], predicate: fun(value: any): boolean): any[] # 泛型参数在 `@field` 里推不出来（LuaLS 不支持），先只给出名字与参数个数
---@field map fun(list: any[], transform: fun(value: any, index: integer): any): any[]
---@field contains fun(list: any[], value: any): boolean

---@type 工具.工具集
util = nil
