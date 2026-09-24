-- 装备（官方通用口径）：装备区有四条槽位；装备牌的加成写进属性
-- 装备牌上的数据是**增量**（在默认值之上）：攻击范围在默认 1 之上加减、距离修正按 ±1 叠
-- 修正的撤销挂在牌上（牌一离开装备区就自动撤），所以没有「卸下」

game:setSlots('装备', { '武器', '防具', '进攻马', '防御马' })

-- 装上（玩家，牌）：按这张牌的数据加修正（撤销随牌离开装备区，见 D3b）
---@param player Player
---@param card Card
---@diagnostic disable-next-line: lowercase-global
function equip(player, card)
    local def   = assert(game:getCard(card:getLabel()))
    local attrs = player:getAttributes()
    local range = def:getValue('攻击范围')
    if range then
        card:bindZoneGC(attrs:addModifier('攻击范围', range))
    end
    local delta = def:getValue('距离修正')
    if delta and def:isKind('进攻马') then
        card:bindZoneGC(attrs:addModifier('进攻修正', delta))
    elseif delta then
        card:bindZoneGC(attrs:addModifier('防御修正', delta))
    end
end
