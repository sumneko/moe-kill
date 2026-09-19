local withoutCheckNil = require 'tools.without-check-nil'

---@class Rule.Preparse
local M = {}

---@param source string
---@param chunkname string
---@param env table
---@return boolean ok
---@return string? err
function M.run(source, chunkname, env)
    local chunk, loadErr = load(source, chunkname, 't', env)
    if not chunk then
        return false, loadErr
    end
    withoutCheckNil.enable()
    local guard <close> = moe.util.defer(function ()
        withoutCheckNil.disable()
    end)
    local ok, runErr = pcall(chunk)
    if not ok then
        return false, tostring(runErr)
    end
    return true
end

return M
