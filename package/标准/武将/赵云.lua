-- 【赵云】（标准版）：蜀 · 男 · 体力上限 4

Hero '赵云'
    : kingdom '蜀'
    : sex '男'
    : hp(4)
    : skills { '龙胆' }

-- 【龙胆】你可以将一张【杀】当【闪】使用或打出，或将一张【闪】当普通【杀】使用或打出。
Skill '龙胆'
    : viewAs('闪', { condition = { name = '杀', zone = '手牌' } })
    : viewAs('杀', { condition = { name = '闪', zone = '手牌' } })
