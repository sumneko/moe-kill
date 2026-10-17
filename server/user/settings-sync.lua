--- 玩家设置：上行一条改、下行一条推 —— 只有本人这一份，别人看不见

---@class SettingsSync.API
moe.settingsSync = {}

--- 设置袋台账：**同一个名字**共用一个（跨重开、跨断线重连都沿用；只在进程内，不落盘）
---@type table<string, table<string, boolean|number|string>>
moe.settingsSync._bags = moe.settingsSync._bags or {}

--- 组装一个人的设置（这一局声明的全部条目 + 他的当前值）
---@param user User
---@return Proto.Setting[]
function moe.settingsSync.toProto(user)
    ---@type Proto.Setting[]
    local list = {}
    for _, def in ipairs(user.game:listSettings()) do
        list[#list + 1] = {
            name     = def.name,
            value    = user:getSetting(def.name),
            default  = def.default,
            describe = def.describe,
        }
    end
    return list
end

--- 把全量设置推给本人
---@param user User
function moe.settingsSync.notify(user)
    ---@type Proto.Notify.Settings.Update
    local data = { settings = moe.settingsSync.toProto(user) }
    user:notify('Settings.Update', data)
end

moe.client.register('Settings.Change', function (client, params)
    ---@cast params Proto.Request.Settings.Change
    local user, _, err = moe.snapshot.requireUser(client)
    if not user then
        return nil, err
    end
    ---@type table<string, true>
    local known = {}
    for _, def in ipairs(user.game:listSettings()) do
        known[def.name] = true
    end
    ---@type table<string, boolean|number|string>
    local patch = {}
    for _, one in ipairs(params.settings) do
        if not known[one.name] then
            return nil, { code = moe.jsonrpc.INVALID_PARAMS, message = '没有这个设置：' .. one.name }
        end
        patch[one.name] = one.value
    end
    user:updateSettings(patch)
    moe.settingsSync.notify(user)
    ---@type Proto.Result.Settings.Change
    return { settings = moe.settingsSync.toProto(user) }
end)
