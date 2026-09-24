-- 死亡奖惩（官方）：杀死反贼的角色摸三张牌；主公杀死忠臣，主公弃置其所有手牌与装备牌。

game:on('玩家-死亡', function (player)
    -- 死亡时机里那次濒死的账还在
    local dying  = game:getDying(player)
    local damage = dying and dying.damage
    local killer = damage and damage.from
    if not killer or killer == player then
        return
    end

    if player:getTag('身份') == '反贼' then
        game:draw(killer, 3)
        return
    end

    if player:getTag('身份') == '忠臣' and killer == game.desk:getPlayer(1) then
        local hand  = killer:getZone('手牌')
        local equip = killer:getZone('装备')
        ---@type Card[]
        local cards = {}
        if hand then
            table.move(hand:list(), 1, hand:count(), 1, cards)
        end
        if equip then
            table.move(equip:list(), 1, equip:count(), #cards + 1, cards)
        end
        if #cards > 0 then
            game:moveCard(cards, '弃牌')
        end
    end
end)
