---@class Phase
---@field name string # 阶段名（内容侧定的）
---@field player Player # 这个阶段属于谁
---@field private game Game
---@field private tags table<string, any>
---@field private useCounts table<string, integer> # 本阶段某名字用过的次数
---@field private limitDeltas table<string, integer> # 本阶段某名字的上限增减
local M = Class 'Phase'

---@param game Game
---@param player Player
---@param name string
function M:__init(game, player, name)
    self.game        = game
    self.player      = player
    self.name        = name
    self.tags        = {}
    self.useCounts   = {}
    self.limitDeltas = {}
end

---@param key string
---@param value any
function M:setTag(key, value)
    if type(key) ~= 'string' or key == '' then
        error('标签键必须是非空字符串', 2)
    end
    self.tags[key] = value
end

---@param key string
---@return any
function M:getTag(key)
    return self.tags[key]
end

---@param key string
function M:removeTag(key)
    self.tags[key] = nil
end

--- 改本阶段某名字用过的次数（正负都行）
---@param name string # 牌名 / 技能名（取值由你定）
---@param delta integer
function M:addUseCount(name, delta)
    self.useCounts[name] = (self.useCounts[name] or 0) + delta
end

--- 本阶段某名字用过的次数
---@param name string
---@return integer
function M:getUseCount(name)
    return self.useCounts[name] or 0
end

--- 改本阶段某名字的上限（+1 = 可以多用一次；+1000 = 事实上不限次数）
---@param name string
---@param delta integer
function M:addLimit(name, delta)
    self.limitDeltas[name] = (self.limitDeltas[name] or 0) + delta
end

--- 本阶段某名字的上限增减
---@param name string
---@return integer
function M:getLimitDelta(name)
    return self.limitDeltas[name] or 0
end

function M:__close()
    Delete(self)
end

function M:__del()
    self.game:leavePhase(self)
end

---@return string
function M:__tostring()
    return '阶段:{}' % { self.name }
end
