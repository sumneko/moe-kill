-- 【桃园结义】（标准版）
-- 出牌阶段，对所有角色使用。每名目标角色回复 1 点体力。

Card '桃园结义'
    : desc '出牌阶段，对所有角色使用。每名目标角色回复 1 点体力。'
    : hint '对所有角色使用，各回复 1 点体力'
    : extends '锦囊牌'
    : targets { max = 1000 }
    : on('生效', function (cardEffect)
        game:heal(cardEffect.target, 1)
    end)
