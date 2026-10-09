--- 玩家身上那张「内容侧自由数据」的袋子：写进去就同步、逐键定可见性
---@class Custom
---@field owner Player # 挂在谁身上（默认只有他自己看得见）
---@field raw table<string, any> # 真实数据
---@field proxy table<string, any> # 内容侧读写的那张表
---@field hook? fun(key: string, value: any) # 变更监听
---@field private visibles table<string, Visibility> # 逐键可见性（没设过 = 只有自己）
local M = Class 'Custom'

---@param owner Player
function M:__init(owner)
    self.owner    = owner
    self.raw      = {}
    self.visibles = {}
    self.proxy    = setmetatable({}, {
        __index = self.raw,
        __newindex = function (_, key, value)
            self.raw[key] = value
            if self.hook then
                self.hook(key, value)
            end
            self.owner:markDirty('custom')
        end,
    })
end

--- 定下某个键给谁看（不设过 = 只有自己看得见）
---@param key string
---@param options Visibility
function M:setVisible(key, options)
    self.visibles[key] = moe.visibility.normalize(options)
end

--- 这个键对某人可见吗（自己的数据永远看得见）
---@param key string
---@param player Player
---@return boolean
function M:isVisible(key, player)
    if player == self.owner then
        return true
    end
    local options = self.visibles[key]
    if not options then
        return false
    end
    return moe.visibility.isVisibleTo(options, player)
end

--- 这个人看得见的那些键（组装协议用）
---@param player Player
---@return table<string, any>
function M:allVisibles(player)
    local result = {}
    for key, value in pairs(self.raw) do
        if self:isVisible(key, player) then
            result[key] = value
        end
    end
    return result
end

---@class Custom.API
moe.custom = {}

---@param owner Player
---@return Custom
function moe.custom.create(owner)
    return New 'Custom' (owner)
end

return moe.custom
