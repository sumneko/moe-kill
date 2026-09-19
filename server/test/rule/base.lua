local fs      = require 'bee.filesystem'
local lt      = require 'test.ltest'
local support = require 'test.rule.support'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'overlay-probe'

---@param rel string
---@param content string
local function write(rel, content)
    local file = probeDir / rel
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), content)
    assert(ok, err)
end

---@return unknown # 配 <close> 用
local function useProbe()
    fs.remove_all(probeDir)
    fs.create_directories(probeDir)
    return moe.util.defer(function ()
        fs.remove_all(probeDir)
    end)
end

---@param 玩家 Core.Player
---@return Core.Attributes
local function 属性(玩家)
    return 玩家:getAttributes()
end

---@return integer # 当前牌表的总张数
local function 牌表总数()
    local 牌表 = assert(moe.rule:getValue('牌表'), '没有牌表')
    local 总数 = 0
    for _, 种类 in ipairs(牌表) do
        总数 = 总数 + 种类.张数
    end
    return 总数
end

lt.test('基础：规则数值后者覆盖前者', function ()
    local guard <close> = support.load { '基础' }
    lt.assertEquals('默认体力上限来自基础包', 4, moe.rule:getValue('体力上限'))

    local probe <close> = useProbe()
    write('覆盖/配置.lua', 'rule:setValues { 体力上限 = 6 }')
    moe.rule.setRoots { './package/*', probeDir:string() .. '/*' }
    moe.rule.load { '基础', '覆盖' }

    lt.assertEquals('后加载的包覆盖了先前的值', 6, moe.rule:getValue('体力上限'))
end)

lt.test('基础：清空重载后不保留', function ()
    local guard <close> = support.load { '基础' }
    lt.assertEquals('先设置过', 4, moe.rule:getValue('体力上限'))

    moe.rule.load { '标准' }

    lt.assertEquals('重载后不再保留', nil, moe.rule:getValue('体力上限'))
end)

lt.test('基础：未设置的名字读到不存在', function ()
    local guard <close> = support.load { '基础' }

    lt.assertEquals('读到不存在', nil, moe.rule:getValue('根本没有这个名字'))

    local 快照 = moe.rule:getValues()
    lt.assertEquals('取全部数值里能看到已设置的', 4, 快照['体力上限'])

    moe.rule:setValue('临时', 1)
    lt.assertEquals('快照不跟随后续修改', nil, 快照['临时'])
    lt.assertEquals('但规则数值里已经有了', 1, moe.rule:getValue('临时'))
end)

lt.test('基础：体力初值等于上限', function ()
    local guard <close> = support.load { '基础', '身份场', '标准' }

    local 局 = support.start(4)

    for i = 1, 4 do
        lt.assertEquals('第 {} 个玩家的体力等于上限' % { i }, 属性(局.玩家[i]):get('体力上限'), 属性(局.玩家[i]):get('体力'))
    end
end)

lt.test('基础：体力上限跟着覆盖后的规则数值', function ()
    local guard <close> = support.load { '基础', '身份场', '标准' }
    moe.rule:setValues { 体力上限 = 3 }

    local 局 = support.start(4)

    lt.assertEquals('用了覆盖后的上限', 3, 属性(局.玩家[2]):get('体力上限'))
    lt.assertEquals('体力也跟着走', 3, 属性(局.玩家[2]):get('体力'))
end)

lt.test('基础：按牌表建出牌堆', function ()
    local guard <close> = support.load { '基础', '身份场', '标准' }

    support.start(4)

    local 牌堆 = assert(moe.rule:getValue('牌堆'), '没有建出牌堆')
    lt.assertEquals('张数等于牌表总数', 牌表总数(), 牌堆:count())
    lt.assertEquals('每张牌都带牌名标签', '杀', 牌堆:list()[1]:getLabel())
end)

lt.test('基础：洗牌可复现', function ()
    local guard <close> = support.load { '基础', '身份场', '标准' }

    ---@return string[] # 当前牌堆上的牌名序列
    local function 牌名序列()
        ---@type string[]
        local 序列 = {}
        for i, 牌 in ipairs(moe.rule:getValue('牌堆'):list()) do
            序列[i] = 牌:getLabel()
        end
        return 序列
    end

    support.start(4, 20260919)
    local 第一次 = 牌名序列()

    support.start(4, 20260919)
    local 第二次 = 牌名序列()

    lt.assertEquals('两次张数一致', #第一次, #第二次)
    lt.assertEquals('同一 seed 洗出的顺序一致', table.concat(第一次, ','), table.concat(第二次, ','))
end)

lt.test('基础：牌堆里各种牌的张数与牌表一致', function ()
    local guard <close> = support.load { '基础', '身份场', '标准' }

    support.start(4)

    ---@type table<string, integer>
    local 计数 = {}
    for _, 牌 in ipairs(moe.rule:getValue('牌堆'):list()) do
        local 名 = 牌:getLabel()
        计数[名] = (计数[名] or 0) + 1
    end

    lt.assertEquals('杀 30 张', 30, 计数['杀'])
    lt.assertEquals('闪 15 张', 15, 计数['闪'])
    lt.assertEquals('桃 8 张', 8, 计数['桃'])
    lt.assertEquals('无懈可击 4 张', 4, 计数['无懈可击'])
    lt.assertEquals('万箭齐发 1 张', 1, 计数['万箭齐发'])
    lt.assertEquals('借刀杀人 2 张', 2, 计数['借刀杀人'])
end)

lt.test('基础：没有牌表时不建牌堆', function ()
    local guard <close> = support.load { '基础' }

    support.start(4)

    lt.assertEquals('没有牌表就不建出牌堆（回调报错被时机机制记录）', nil, moe.rule:getValue('牌堆'))
end)
