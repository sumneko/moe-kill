-- 【雌雄双股剑】（标准版）
-- 当你使用【杀】指定一名异性角色为目标后，你可以令其选择一项：弃置一张手牌，或令你摸一张牌。
-- 攻击范围 2

Card '雌雄双股剑'
    : extends '武器牌'
    : value('攻击范围', 2)
    : on('被动', function (card, zone, host)
        local owner = zone.owner
        if not owner then
            return
        end
        host:bindGC(owner:on('卡牌-来源-指定目标后', function (useCard, target)
            if useCard.card.name ~= '杀' then
                return
            end
            -- 没有性别的角色不能判断异性（官方）：两边都得知道、且不同才发动
            local mine   = owner.sex
            local theirs = target.sex
            if not mine or not theirs or mine == theirs then
                return
            end
            -- 不答 = 取消 = 不发动（`.choice` 为空）—— 否定项不必当选项传
            if game:askChoice(owner, '雌雄双股剑', { '发动' }).choice ~= '发动' then
                return
            end
            -- 给牌 = 弃置它；给不出（没牌 / 不答 / 答错）由 askCard 归一成空 ⇒ 令你摸一张
            local given = game:askCard(target, '雌雄双股剑', { zone = '手牌', min = 0, max = 1 }).card
            card:cast(function ()
                if given then
                    game:moveCard(given, '弃牌')
                else
                    owner:draw(1)
                end
            end)
        end))
    end)
