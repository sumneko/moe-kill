-- 死亡奖惩（官方）：杀死反贼的角色摸三张牌；主公杀死忠臣，主公弃置其所有手牌与装备牌。

game:on('玩家-死亡', function (player)
    -- 死亡时机里那次濒死的账还在
    local dying  = player.dying
    local damage = dying and dying.damage
    local killer = damage and damage.from
    if not killer or killer == player then
        return
    end

    if player.identity == '反贼' then
        killer:draw(3)
        return
    end

    if player.identity == '忠臣' and killer == game.desk:getPlayer(1) then
        local hand  = killer:getZone('手牌')
        local equip = killer.equipCards
        ---@type Card[]
        local cards = {}
        if hand then
            table.move(hand:list(), 1, hand:count(), 1, cards)
        end
        table.move(equip, 1, #equip, #cards + 1, cards)
        if #cards > 0 then
            game:moveCard(cards, '弃牌')
        end
    end
end)
