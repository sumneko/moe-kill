-- 延时锦囊：一张牌的一次结算（先判定、再把结果交给牌自己的「判定结果」钩子）
-- 判定阶段里逐张跑它，见「阶段/判定阶段.lua」

---@class 延时锦囊结算 : Effect
---@field player Player # 判定者（判定区的主人）
---@field card Card # 被结算的牌
---@field judge? Judge # 这次的判定（被无懈抵消时没有）
local 延时锦囊结算 = Class('延时锦囊结算', 'Effect')

---@param game Game
---@param player Player
---@param card Card
function 延时锦囊结算:__init(game, player, card)
    self.kind   = '延时锦囊结算'
    self.player = player
    self.card   = card
end

--- 结算这张牌：先判定，再把结果交给牌自己
---@async
function 延时锦囊结算:settle()
    self.judge = self.game:judge(self.player, self.card.name)
    local def = self.card:getDef()
    ---@cast def CardDef
    for _, handler in ipairs(def:getHandlers('判定结果')) do
        handler(self)
    end
end
