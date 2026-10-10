--- 技能下行：技能总是可见，一次调度把攒下的变化广播给所有人

---@class SkillSync.API
moe.skillSync = {}

--- 客户端接入了：把这一局的技能账带起来（重复调无害）
---@param user User
---@return Game.SkillSync
function moe.skillSync.attach(user)
    return user.game.skillSync
end

---@class Game: Class.Base
---@field package skillSync Game.SkillSync # 这一局的技能下行账本
local Game = Class 'Game'

---@param self Game
---@return Game.SkillSync
---@return true
Game.__getter.skillSync = function (self)
    return New 'Game.SkillSync' (self), true
end

--- 按局的账本挂在局上：`package` 可见性只给本文件看（内核不认识协议，就不写进 game.lua 了）
---@class Game.SkillSync
---@field dirty? table<Skill, Skill.DirtyKind> # 还没下发的脏技能（一个技能只记最后一种变化）
local S = Class 'Game.SkillSync'

--- 一个技能的协议形状
---@param skill Skill
---@return Proto.Skill
function moe.skillSync.toProto(skill)
    return {
        name     = skill.name,
        id       = skill.id,
        player   = skill.owner.id,
        auto     = skill.auto,
        tag      = skill.def:getTags(),
        disabled = skill.disabled,
    }
end

--- 按协议号找某个人的技能（找不到给空）
---@param player Player
---@param id integer
---@return Skill?
local function skillOf(player, id)
    for _, skill in ipairs(player:getSkills()) do
        if skill.id == id then
            return skill
        end
    end
end

---@param game Game
function S:__init(game)
    self.game = game

    game:on('技能-数据变化', function (skill, kind)
        self:markDirty(skill, kind)
    end)
end

---@param skill Skill
---@param kind Skill.DirtyKind
function S:markDirty(skill, kind)
    local dirty = self.dirty
    if not dirty then
        dirty = {}
        self.dirty = dirty
        moe.await.wake(function ()
            self:flush()
        end)
    end
    dirty[skill] = kind
end

--- 把攒着的脏技能广播下去（技能总是可见 ⇒ 不分视角，也不裁字段）
function S:flush()
    local dirty = self.dirty
    if not dirty then
        return
    end
    self.dirty = nil

    for _, player in ipairs(self.game.desk.players) do
        local user = player.user
        if user then
            for skill, kind in pairs(dirty) do
                if kind == 'removed' then
                    ---@type Proto.Notify.Skill.Remove
                    local data = { id = skill.id }
                    user:notify('Skill.Remove', data)
                else
                    ---@type Proto.Notify.skill.Update
                    local data = { skill = moe.skillSync.toProto(skill) }
                    user:notify('Skill.Update', data)
                end
            end
        end
    end
end

moe.client.register('Skill.ChangeAuto', function (client, params)
    ---@cast params Proto.Request.Skill.ChangeAuto
    local game  = assert(moe.snapshot._game, '还没开局')
    local user  = assert(moe.snapshot.userOf(game, client), '这条连接还没入座')
    local skill = assert(skillOf(assert(user.player), params.id), '这不是他的技能')
    skill:setAuto(params.auto)
    ---@type Proto.Result.Skill.ChangeAuto
    return { auto = skill.auto }
end)
