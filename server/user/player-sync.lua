--- 玩家数据下行：内核只说「谁的一类数据变了」，这里攒一下、按各人视角拼好再发

---@class PlayerSync.API
moe.playerSync = {}

--- 客户端接入了：把这一局的玩家数据账带起来（重复调无害）
---@param user User
---@return Game.PlayerSync
function moe.playerSync.attach(user)
    return user.game.playerSync
end

---@class Game: Class.Base
---@field package playerSync Game.PlayerSync # 这一局的玩家数据下行账本
local Game = Class 'Game'

---@param self Game
---@return Game.PlayerSync
---@return true
Game.__getter.playerSync = function (self)
    return New 'Game.PlayerSync' (self), true
end

--- 按局的账本挂在局上：`package` 可见性只给本文件看（内核不认识协议，就不写进 game.lua 了）
---@class Game.PlayerSync
---@field dirty? table<Player, table<Player.DirtyKind, true>> # 还没下发的脏玩家（下一笔调度统一发）
local S = Class 'Game.PlayerSync'

--- 组装一个玩家的基础信息
---@param player Player
---@return Proto.Player.Base
function moe.playerSync.toBase(player)
    return {
        id       = player.id,
        userName = player:getName() or '',
        seat     = player.game.desk:getIndex(player),
    }
end

---@param game Game
function S:__init(game)
    self.game = game

    game:on('玩家-数据变化', function (player, kind)
        self:markDirty(player, kind)
    end)
end

---@param player Player
---@param kind Player.DirtyKind
function S:markDirty(player, kind)
    local dirty = self.dirty
    if not dirty then
        dirty = {}
        self.dirty = dirty
        moe.await.wake(function ()
            self:flush()
        end)
    end
    local kinds = dirty[player]
    if not kinds then
        kinds = {}
        dirty[player] = kinds
    end
    kinds[kind] = true
end

--- 把攒着的脏玩家发下去（基础信息人人一份、custom 按各人视角裁）
function S:flush()
    local dirty = self.dirty
    if not dirty then
        return
    end
    self.dirty = nil

    ---@type Proto.Player.Base[]
    local baseList = {}
    for player, kinds in pairs(dirty) do
        if kinds.base then
            baseList[#baseList + 1] = moe.playerSync.toBase(player)
        end
    end

    for _, viewer in ipairs(self.game.desk.players) do
        local user = viewer.user
        if user then
            if #baseList > 0 then
                ---@type Proto.Notify.Player.Update
                local data = { players = baseList }
                user:notify('Player.Update', data)
            end
            ---@type Proto.Player.Custom[]
            local customList = {}
            for player, kinds in pairs(dirty) do
                if kinds.custom then
                    local visible = player.custom:allVisibles(viewer)
                    if next(visible) then
                        customList[#customList + 1] = { id = player.id, custom = visible }
                    end
                end
            end
            if #customList > 0 then
                ---@type Proto.Notify.Player.UpdateCustom
                local data = { players = customList }
                user:notify('Player.UpdateCustom', data)
            end
        end
    end
end
