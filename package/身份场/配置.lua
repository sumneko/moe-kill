-- 身份场的规则数值：选将备选数与人数 → 身份配置（别的包可以覆盖）
-- 选将时给几个人备选（主公是「全部君主 + 这么多张其他」，其余人就是这么多张）
rule.heroCandidateCount = 5

-- 人数 → 每个身份几个人（4~8 人局）
rule.identityConfig = {
    [4] = {
        { identity = '主公', count = 1 },
        { identity = '忠臣', count = 1 },
        { identity = '反贼', count = 1 },
        { identity = '内奸', count = 1 },
    },
    [5] = {
        { identity = '主公', count = 1 },
        { identity = '忠臣', count = 1 },
        { identity = '反贼', count = 2 },
        { identity = '内奸', count = 1 },
    },
    [6] = {
        { identity = '主公', count = 1 },
        { identity = '忠臣', count = 1 },
        { identity = '反贼', count = 3 },
        { identity = '内奸', count = 1 },
    },
    [7] = {
        { identity = '主公', count = 1 },
        { identity = '忠臣', count = 2 },
        { identity = '反贼', count = 3 },
        { identity = '内奸', count = 1 },
    },
    [8] = {
        { identity = '主公', count = 1 },
        { identity = '忠臣', count = 2 },
        { identity = '反贼', count = 4 },
        { identity = '内奸', count = 1 },
    },
}
