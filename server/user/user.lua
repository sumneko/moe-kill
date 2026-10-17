--- 一个座位的控制者（真实玩家 / 电脑 / 测试夹具）：内核的询问优先问他，他不表态才回落全局时机
--- 每个方法收这次询问的实例，返回与内核同一形状的答复；返回空 = 不表态
---@class User : Class.Base
---@field player? Player # 他控制的座位（`Player:setUser` 维护）
---@field client? Client # 他走的那条连接（只有真实玩家会给）
---@field cardView? CardSync.View # 他看得见的那份牌（默认没有 —— 要收卡牌下行的子类自己挂）
---@field private localSettings? table<string, boolean|number|string> # 没名字的夹具就地存（有名字的走按名字的台账）
local M = Class 'User'

---@param game Game
---@param client? Client # 真实玩家那条连接
function M:__init(game, client)
    self.game   = game
    self.client = client
end

--- 客户端接入了：把这一局的下行账都带起来（外壳在接入时调；重复调无害）
function M:attach()
    moe.cardSync.attach(self)
    moe.playerSync.attach(self)
    moe.skillSync.attach(self)
    moe.panelSync.attach(self)
    moe.flowSync.attach(self)
end

--- 设置袋（跟着**名字**走：重开一局、断线重连都沿用；没名字的夹具就地存）
---@return table<string, boolean|number|string>
function M:settingsBag()
    local name = self.player and self.player:getName()
    if not name then
        local localSettings = self.localSettings
        if not localSettings then
            localSettings = {}
            self.localSettings = localSettings
        end
        return localSettings
    end
    local bags = moe.settingsSync._bags
    local bag = bags[name]
    if not bag then
        bag = {}
        bags[name] = bag
    end
    return bag
end

--- 一项设置（改过的就用改过的，否则取这一局声明的默认值）
---@param name string
---@return boolean|number|string|nil
function M:getSetting(name)
    local value = self:settingsBag()[name]
    if value ~= nil then
        return value
    end
    return self.game:getSettingDefault(name)
end

--- 改一批设置（只改带上的键）
---@param patch table<string, boolean|number|string>
function M:updateSettings(patch)
    local bag = self:settingsBag()
    for name, value in pairs(patch) do
        bag[name] = value
    end
end

---@param method string
---@param params table
function M:notify(method, params)
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

--- 要一次行动（能用的牌与能发动的技能一起摆）
---@param ask AskUse
---@return AskUseCard.Answer|AskUseSkill.Answer?
function M:askUse(ask)
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

--- 有牌搬动了（当场发的动画预通知；默认什么都不做）
---@param moves Zone.Move[]
function M:moveCards(moves)
end

--- 搬走的那几张旧号作废（当场发；默认什么都不做）
---@param moves Zone.Move[]
function M:removeCards(moves)
end

--- 搬到的那几张建号落位（当场发；默认什么都不做）
---@param moves Zone.Move[]
function M:createCards(moves)
end

---@param cards Card[]
function M:updateCards(cards)
end

return M
