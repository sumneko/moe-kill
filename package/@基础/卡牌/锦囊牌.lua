-- 锦囊牌模板：继承它就有「锦囊 / 非延时锦囊」分类、且只能从手牌里用（使用）
Card '锦囊牌'
    : kind { '锦囊', '非延时锦囊' }
    : zone '手牌'

-- 延时锦囊模板：把分类换成「锦囊 / 延时锦囊」；使用结算里把牌放进目标的判定区
-- 判定区里已经有同名牌的目标不能再选（判定区不能有同名牌）

---@param target Player
---@param name string
---@return boolean # 他的判定区里有没有叫这个名字的牌
local function hasSameName(target, name)
    for _, card in ipairs(target:getZone('判定'):list()) do
        if card.name == name then
            return true
        end
    end
    return false
end

Card '延时锦囊牌'
    : extends '锦囊牌'
    : kind { '锦囊', '延时锦囊' }
    : on('获取目标', function (plan)
        return table.filter(game.desk.players, function (target)
            return not hasSameName(target, plan.card.name)
        end)
    end)
    : on('生效', function (cardEffect)
        game:moveCard(cardEffect.card, cardEffect.target:getZone('判定'))
    end)
