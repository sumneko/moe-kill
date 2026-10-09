--- 一个座位的控制者（真实玩家 / 电脑 / 测试夹具）：内核的询问优先问他，他不表态才回落全局时机
--- 每个方法收这次询问的实例，返回与内核同一形状的答复；返回空 = 不表态
---@class User : Class.Base
local M = Class 'User'

--- 要一个决策
---@param ask Ask
---@return any
function M:ask(ask)
end

--- 要一个选项
---@param ask AskChoice
---@return string?
function M:askChoice(ask)
end

--- 要一名角色（给一批也行）
---@param ask AskPlayer
---@return Player|Player[]?
function M:askPlayer(ask)
end

--- 要一张牌
---@param ask AskCard
---@return AskCard.Answer?
function M:askCard(ask)
end

--- 要一批牌，并指定给谁
---@param ask AskCardWithTarget
---@return AskCard.Answer?
function M:askCardWithTarget(ask)
end

--- 要一次「使用」
---@param ask AskUseCard
---@return AskUseCard.Answer?
function M:askUseCard(ask)
end

--- 要一次「对一张牌的使用」
---@param ask AskUseCardToCard
---@return AskCard.Answer?
function M:askUseCardToCard(ask)
end

--- 要一张打出的牌
---@param ask AskPlayCard
---@return AskCard.Answer?
function M:askPlayCard(ask)
end

--- 要发动哪个技能
---@param ask AskUseSkill
---@return AskUseSkill.Answer?
function M:askUseSkill(ask)
end

--- 要一名武将（给一批也行）
---@param ask AskHero
---@return HeroDef|HeroDef[]?
function M:askHero(ask)
end

--- 面板上的一次回复
---@param ask AskPanel
---@return AskPanel.Change?
function M:askPanel(ask)
end

--- 玩家数据变了（`base?` / `custom?`，内核已经按视角组装好；默认什么都不做）
---@param data Proto.Update
function M:update(data)
end

return M
