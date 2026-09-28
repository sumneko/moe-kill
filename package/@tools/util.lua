---@diagnostic disable-next-line: lowercase-global
util = {}

--- 拿一个 `<close>` 收尾对象：作用域一结束（正常、出错、提前 return 都算）就跑回调
---@param callback fun()
---@return table
function util.defer(callback)
    return setmetatable({ callback }, { __close = function (self) self[1]() end })
end
