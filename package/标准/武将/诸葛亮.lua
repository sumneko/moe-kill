-- 【诸葛亮】（标准版）：蜀 · 男 · 体力上限 3

Hero '诸葛亮'
    : kingdom '蜀'
    : sex '男'
    : hp(3)
    : skills { '观星', '空城' }

-- 【观星】准备阶段开始时，你可以观看牌堆顶的 X 张牌，然后将任意数量的牌置于牌堆顶，将其余的牌置于牌堆底。（X 为存活角色数且至多为 5）

--- 分配：⚠️ 本批**服务器暂定** —— 「排列」询问类还没做，先按一个任意的占位来分（逆序置于牌堆顶），不代表任何策略；等那个询问类到位就换成玩家的答复
---@param shown Card[] # 观看的那些牌（原顺序）
---@return Card[] # 放顶的（第一张最靠顶）
---@return Card[] # 放底的
local function arrange(shown)
    ---@type Card[]
    local top = {}
    for i = #shown, 1, -1 do
        top[#top + 1] = shown[i]
    end
    return top, {}
end

Skill '观星'
    : event('阶段-开始', function (skill, phase)
        if phase.name ~= '准备' then
            return
        end
        skill:tryCast(function (cast)
            local deck  = assert(game:getZone('抽牌'))
            local x     = math.min(#game.desk.alivePlayers, 5)
            local seen  = deck:draw(x)
            -- 观看 = 摊在自己这次发动的临时区里：**先**把区藏好、**再**把牌搬进来（不留「大家都看得见」那一瞬）
            local shown = cast:getTempZone()
            shown:setVisible(skill.owner)
            game:moveCard(seen, shown)
            -- 看完全放回牌堆（顶 / 底两半合起来就是全部）—— 剩在临时区的会被默认收尾送进弃牌
            local top, bottom = arrange(shown:list())
            deck:placeTop(top)
            deck:placeBottom(bottom)
        end)
    end)

-- 【空城】锁定技，若你没有手牌，你不能被选择为【杀】或【决斗】的目标。
Skill '空城'
    : tags '锁定技'
    : event('卡牌-目标-能否指定', function (skill, plan)
        if skill.owner:getZone('手牌'):count() > 0 then
            return
        end
        local name = plan.card.name
        if name == '杀' or name == '决斗' then
            return '空城'
        end
    end)
