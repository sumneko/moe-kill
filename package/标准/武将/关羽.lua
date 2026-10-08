-- 【关羽】（标准版）：蜀 · 男 · 体力上限 4

Hero '关羽'
    : kingdom '蜀'
    : sex '男'
    : hp(4)
    : skills { '武圣' }

-- 【武圣】你可以将一张红色牌当【杀】使用或打出。
Skill '武圣'
    : viewAs('杀', {
        condition = {
            color = '红',
            zone  = rule.ownZones,
        },
    })
