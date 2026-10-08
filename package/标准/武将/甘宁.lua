-- 【甘宁】（标准版）：吴 · 男 · 体力上限 4

Hero '甘宁'
    : kingdom '吴'
    : sex '男'
    : hp(4)
    : skills { '奇袭' }

-- 【奇袭】你可以将一张黑色牌当【过河拆桥】使用。
Skill '奇袭'
    : viewAs('过河拆桥', {
        color = '黑',
        zone  = table.mergeArray({ '手牌' }, rule.equipZones),
    })
