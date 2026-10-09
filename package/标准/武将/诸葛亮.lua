-- 【诸葛亮】（标准版）：蜀 · 男 · 体力上限 3

Hero '诸葛亮'
    : kingdom '蜀'
    : sex '男'
    : hp(3)
    : skills { '观星', '空城' }

-- 【观星】准备阶段开始时，你可以观看牌堆顶的 X 张牌，然后将任意数量的牌置于牌堆顶，将其余的牌置于牌堆底。（X 为存活角色数且至多为 5）

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
            -- 摊成面板：顶堆 / 底堆两行，归他自己摆（`moveable` = 允许把牌在两行之间挪）；不动就能直接确定
            local panel = createPanel('观星', skill.owner, { moveable = true, min = 0 })
                : row(shown:list(), '牌堆顶')
                : row({}, '牌堆底')
            game:askPanel(skill.owner, '观星', panel)
            -- 摆成什么样就照什么样放回：问没问成、答复到了哪一步，摆的事都记在面板上（剩在临时区的会被默认收尾送进弃牌）
            local rows = panel.cardsByRow
            deck:placeTop(rows[1])
            deck:placeBottom(rows[2])
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
