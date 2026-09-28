-- 出牌阶段：问牌、用牌

---@type integer # 一个出牌阶段最多出这么多次（规则上可能有能无限用牌的技能，这里是终止条件）
local MAX_PLAY_COUNT = 1000

---@type AskUseCard.Condition # 手牌里那些能用的牌（选项带各自的可用目标）
local PLAY_PHASE_CONDITION = { zone = '手牌' }

---@param player Player
local function playPhase(player)
    for _ = 1, MAX_PLAY_COUNT do
        local ask = game:askUseCard(player, '出牌', PLAY_PHASE_CONDITION)
        if not ask.useCard then
            return
        end
    end
end

game:on('阶段-开始', function (phase)
    if phase.name == '出牌' then
        playPhase(phase.player)
    end
end)
