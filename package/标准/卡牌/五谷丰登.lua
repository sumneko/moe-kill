-- 【五谷丰登】（标准版）
-- 出牌阶段，对所有角色使用。你亮出牌堆顶等同于目标角色数的牌，然后每名目标角色获得其中一张；
-- 使用结算结束后，将其中剩余的牌置入弃牌堆。

Card '五谷丰登'
    : extends '锦囊牌'
    : targets { max = 1000 }
    : on('使用', function (useCard)
        -- 处理区里还有这张锦囊自己 ⇒ 面板只摆「亮出的」那些（`drawCards` 给出实际抽到的牌）
        local revealed = game:drawCards(useCard.user, #useCard.targets, useCard:getTempZone())
        -- 亮出的牌摊成一行，这块面板归这次使用所有（`bindGC` = 这次结算收尾时跟它一起放掉）
        local panel = createPanel('五谷丰登', true, { min = 1, max = 1, cancelable = false })
            : row(revealed)
        useCard:bindGC(panel)
        useCard:setTag('panel', panel)
    end)
    : on('生效', function (cardEffect, useCard)
        ---@type Panel
        local panel = useCard:getTag('panel')
        local card = game:askPanel(cardEffect.target, '五谷丰登', panel).card
        if not card then
            -- 没答上（超时之类）照样得「获得其中一张」：替他拿第一张还没被拿走的
            for _, one in ipairs(panel:cards()) do
                if not panel:isDisabled(one) then
                    card = one
                    break
                end
            end
        end
        if not card then
            return
        end
        -- 拿走 = 禁用（牌仍留在面板上，标上是谁拿的；之后谁都选不到它）
        panel:disableCard(card)
        panel:addMark(card, '${hero:{name}}' % { name = cardEffect.target:getName() })
        game:moveCard(card, cardEffect.target:getZone('手牌'))
    end)
