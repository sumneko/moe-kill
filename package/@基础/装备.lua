-- 装备（官方口径）：装备区分成子区 —— 武器区 / 防具区 / 进攻坐骑区 / 防御坐骑区
-- 四个子区由这里在「游戏-开始」建好（内核只认 `手牌` / `判定`）；一件装备进哪个子区由它的分类决定
-- 「一个子区只能有一张」也在这里（同子区已有牌 ⇒ 旧的先送弃牌堆）
-- 加成由牌自己的「被动」写进属性：进子区时启用、离开时由装备模板停用并撤销 —— 所以没有「卸下」
-- 想加子区（特殊坐骑 / 宝物…）的包往 rule.equipZones 里追加：加载期加完即可，子区名 = 那张牌的分类名

--- 装备子区名（= 装备的分类名；顺序就是找子区与列装备牌的顺序）—— `rule` 是装载器给的共享袋
---@type string[]
rule.equipZones = { '武器', '防具', '进攻马', '防御马' }

game:on('游戏-开始', function ()
    for _, player in ipairs(game.desk.players) do
        for _, name in ipairs(rule.equipZones) do
            player:addZone(name)
        end
    end
end)

---@class Player
local M = Class 'Player'

--- 这张装备该去的子区（分类认不出来就是空）
---@param card Card
---@return Zone?
function M:equipZoneOf(card)
    for _, name in ipairs(rule.equipZones) do
        if card:isKind(name) then
            return self:getZone(name)
        end
    end
end

--- 把这张装备放进它该去的子区（同子区已有牌 ⇒ 旧的先送弃牌堆；认不出分类就不放）
---@param card Card
function M:equipCard(card)
    local zone = self:equipZoneOf(card)
    if not zone then
        return
    end
    local old = zone:list()[1]
    if old and old ~= card then
        game:moveCard(old, '弃牌')
    end
    game:moveCard(card, zone)
end

---@type Card[]
M.equipCards = nil

---@param self Player
---@return Card[] # 他子区里的装备牌
M.__getter.equipCards = function (self)
    ---@type Card[]
    local cards = {}
    for _, name in ipairs(rule.equipZones) do
        local zone = self:getZone(name)
        if zone then
            table.mergeArray(cards, zone:list())
        end
    end
    return cards
end
