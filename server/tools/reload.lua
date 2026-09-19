local originRequire = require

--热重载
--
--热重载相关的方法，详细请看 `演示/热重载`。
---@class Reload
---@overload fun(optional?: Reload.Optional): self
local M = Class 'Reload'

---@type table<string, boolean>
M.includedNameMap = {}

---@type string[]
M.includedNames = {}

---@alias Reload.beforeReloadCallback fun(reload: Reload, willReload: boolean)

---@private
---@type {name?: string, callback: Reload.beforeReloadCallback}[]
M.beforeReloadCallbacks = {}

---@alias Reload.afterReloadCallback fun(reload: Reload, hasReloaded: boolean)

---@private
---@type {name?: string, callback: Reload.afterReloadCallback}[]
M.afterReloadCallbacks = {}

---@class Reload.Optional
---@field list? string[] -- 要重载的模块列表
---@field filter? fun(name: string, reload: Reload): boolean -- 过滤函数

---@private
---@type Reload.Optional?
M.defaultReloadOptional = nil

---@param optional? Reload.Optional
function M:__init(optional)
    self.optional = optional

    ---@private
    ---@type table<string, any>
    self.validMap = optional and optional.list and moe.util.revertMap(optional.list) --[[@as table<string, any>]]

    ---@private
    self.filter = self.optional and self.optional.filter
end

-- 模块名是否会被重载
---@param name? string
---@return boolean
function M:isValidName(name)
    if not self.includedNameMap[name] then
        return false
    end
    if not self.validMap and not self.filter then
        return true
    end
    if self.validMap and self.validMap[name] then
        return true
    end
    if not self.filter then
        return false
    end
    local suc, result = xpcall(self.filter, log.error, name, self)
    if not suc then
        return false
    end
    return result
end

---@return string[] # 被重载的模块列表
function M:fire()
    ---@private
    M._reloading = true
    log.info('=========== reload start ===========')

    local beforeReloadCallbacksNoReload = {}
    local afterReloadCallbacksNoReload  = {}

    for _, data in ipairs(M.beforeReloadCallbacks) do
        local willReload = self:isValidName(data.name)
        if not willReload then
            beforeReloadCallbacksNoReload[#beforeReloadCallbacksNoReload+1] = data
        end
        xpcall(data.callback, log.error, self, willReload)
    end

    for _, data in ipairs(M.afterReloadCallbacks) do
        local willReload = self:isValidName(data.name)
        if not willReload then
            afterReloadCallbacksNoReload[#afterReloadCallbacksNoReload+1] = data
        end
    end

    M.beforeReloadCallbacks = beforeReloadCallbacksNoReload
    M.afterReloadCallbacks  = afterReloadCallbacksNoReload

    local needReload = {}
    for _, name in ipairs(M.includedNames) do
        if self:isValidName(name) then
            needReload[#needReload+1] = name
        end
    end
    log.info('reload modules: {}' % { table.concat(needReload, ', ') })

    for _, name in ipairs(needReload) do
        package.loaded[name] = nil
    end

    for _, name in ipairs(needReload) do
        pcall(M.include, name)
    end

    for _, data in ipairs(M.afterReloadCallbacks) do
        xpcall(data.callback, log.error, self, self:isValidName(data.name))
    end
    log.info('=========== reload finish ===========')
    M._reloading = false

    return needReload
end

---@private
M.modNameMap = {}

---@private
M.includeStack = {}

-- 把错误记进日志（带堆栈）后原样返回，让 `include` 能重新抛出它
---@param err any
---@return any
local function onLoadError(err)
    log.error(err)
    return err
end

-- 类似于 `require` ，但是会在重载时重新加载文件。
-- 加载文件出错时会记日志（带堆栈）并抛出错误。
---@param modname string
---@return any result
---@return string|unknown loaderdata
function M.include(modname)
    if not M.includedNameMap[modname] then
        M.includedNameMap[modname] = true
        M.includedNames[#M.includedNames+1] = modname
    end
    M.includeStack[#M.includeStack+1] = modname
    local suc, result, loaderdata = xpcall(originRequire, onLoadError, modname)
    M.includeStack[#M.includeStack] = nil
    if not suc then
        error(result, 0)
    end
    if loaderdata ~= nil then
        M.modNameMap[loaderdata] = modname
    end
    return result, loaderdata
end

---@param modname string
---@return unknown
---@return unknown loaderdata
function require(modname)
    if package.loaded[modname] ~= nil then
        return package.loaded[modname], nil
    end
    M.includeStack[#M.includeStack+1] = false
    local guard <close> = moe.util.defer(function ()
        M.includeStack[#M.includeStack] = nil
    end)
    local result, loaderdata = originRequire(modname)
    if loaderdata ~= nil then
        M.modNameMap[loaderdata] = modname
    end
    return result, loaderdata
end

---@param func function
---@return string?
function M.getIncludeName(func)
    if not debug or not debug.getinfo then
        return nil
    end
    local info = debug.getinfo(func, 'S')
    local source = info.source
    if source:sub(1, 1) ~= '@' then
        return nil
    end
    local modName = M.modNameMap[source:sub(2)]
    if not modName or not M.includedNameMap[modName] then
        return nil
    end
    return modName
end

---@return string?
function M.getCurrentIncludeName()
    return M.includeStack[#M.includeStack] or nil
end

-- 设置默认的重载选项
---@param optional? Reload.Optional
function M.setDefaultOptional(optional)
    M.defaultReloadOptional = optional
end

-- 进行重载
---@param optional? Reload.Optional
---@return string[] # 被重载的模块列表
function M.reload(optional)
    optional = optional or M.defaultReloadOptional
    local reload = New 'Reload' (optional)
    return reload:fire()
end

---是否正在重载
---@return boolean
function M.isReloading()
    return M._reloading == true
end

---@private
---@param getList fun(): {name?: string, callback: fun(...):...}[]
---@param data {name?: string, callback: fun(...):...}
function M.removeCallback(getList, data)
    local list = getList()
    for i = #list, 1, -1 do
        if list[i] == data then
            table.remove(list, i)
            return
        end
    end
end

---@private
---@generic T: fun(...):...
---@param getList fun(): {name?: string, callback: T}[]
---@param callback T
---@return fun()
function M.addCallback(getList, callback)
    local data = {
        name     = M.getCurrentIncludeName(),
        callback = callback,
    }
    local list = getList()
    list[#list+1] = data
    local disposed = false
    return function ()
        if disposed then
            return
        end
        disposed = true
        M.removeCallback(getList, data)
    end
end

-- 注册在重载之前的回调
---@param callback Reload.beforeReloadCallback
---@return fun()
function M.onBeforeReload(callback)
    return M.addCallback(function ()
        return M.beforeReloadCallbacks
    end, callback)
end

-- 注册在重载之后的回调
---@param callback Reload.afterReloadCallback
---@return fun()
function M.onAfterReload(callback)
    return M.addCallback(function ()
        return M.afterReloadCallbacks
    end, callback)
end

--立即执行回调函数，之后每当发生重载时，
--会再次执行这个回调函数。
---@generic R1, R2
---@param callback fun(trash: fun(obj: R2): R2): R1?
---@return R1
function M.recycle(callback)
    local trashList = {}
    local function trash(obj)
        trashList[#trashList+1] = obj
        return obj
    end
    M.onBeforeReload(function ()
        for _, obj in ipairs(trashList) do
            Delete(obj)
        end
        trashList = {}
    end)
    M.onAfterReload(function ()
        callback(trash)
    end)
    return callback(trash)
end

return M
