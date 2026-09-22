local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

---@class Test.Reload.State
---@field version integer
---@field classRuns integer
---@field basicRuns integer
---@field plainRuns integer
---@field addedRuns integer
---@field moduleRuns integer
---@field afterHits integer
---@field seenDuringLoad boolean[]

---@type Test.Reload.State
local state = {
    version        = 1,
    classRuns      = 0,
    basicRuns      = 0,
    plainRuns      = 0,
    addedRuns      = 0,
    moduleRuns     = 0,
    afterHits      = 0,
    seenDuringLoad = {},
}

package.preload['test.reload.probe.added'] = function ()
    state.addedRuns = state.addedRuns + 1
    return {
        name = 'added',
        runs = state.addedRuns,
    }
end

package.preload['test.reload.probe.basic'] = function ()
    state.basicRuns = state.basicRuns + 1
    return {
        name = 'basic',
        runs = state.basicRuns,
    }
end

package.preload['test.reload.probe.plain'] = function ()
    state.plainRuns = state.plainRuns + 1
    return {
        name = 'plain',
        runs = state.plainRuns,
    }
end

package.preload['test.reload.probe.class'] = function ()
    state.classRuns = state.classRuns + 1
    local version = state.version
    ---@class Test.Reload.Probe.Class
    ---@field marker any
    local M = Class 'Test.Reload.Probe.Class'
    function M:__init(marker)
        self.marker = marker
    end
    function M:value()
        return version
    end
    return M
end

package.preload['test.reload.probe.broken'] = function ()
    error('探针模块故意报错')
end

package.preload['test.reload.probe.callback'] = function ()
    state.moduleRuns = state.moduleRuns + 1
    moe.reload.onAfterReload(function ()
        state.afterHits = state.afterHits + 1
    end)
    return true
end

package.preload['test.reload.probe.isreloading'] = function ()
    state.seenDuringLoad[#state.seenDuringLoad + 1] = moe.reload.isReloading()
    return true
end

lt.test('重载：登记过的模块会被重新执行', function ()
    include 'test.reload.probe.basic'
    lt.assertEquals('首次加载执行一次', 1, state.basicRuns)

    local reloaded = moe.reload.reload()

    lt.assertEquals('重载后重新执行', 2, state.basicRuns)
    lt.assertEquals('重载名单包含该模块', true, moe.util.arrayHas(reloaded, 'test.reload.probe.basic'))
end)

lt.test('重载：未登记的模块不受影响', function ()
    require 'test.reload.probe.plain'
    lt.assertEquals('普通加载执行一次', 1, state.plainRuns)

    local reloaded = moe.reload.reload()

    lt.assertEquals('重载后不再执行', 1, state.plainRuns)
    lt.assertEquals('重载名单不包含该模块', false, moe.util.arrayHas(reloaded, 'test.reload.probe.plain'))
end)

lt.test('重载：加载失败的模块以明确失败暴露', function ()
    lt.expectErrors(1)
    local modName = 'test.reload.probe.broken'
    local guard <close> = moe.util.defer(function ()
        for i, name in ipairs(moe.reload.includedNames) do
            if name == modName then
                table.remove(moe.reload.includedNames, i)
                break
            end
        end
        moe.reload.includedNameMap[modName] = nil
    end)

    local err = lt.assertError('加载失败会抛出', function ()
        include(modName)
    end) or ''

    lt.assertEquals('失败信息带上了出处', true, err:find('探针模块故意报错', 1, true) ~= nil)
end)

lt.test('重载：默认范围只含登记过的模块', function ()
    local toolsClass = package.loaded['tools.class']
    local reloaded = moe.reload.reload()

    for _, name in ipairs(reloaded) do
        lt.assertEquals('基础设施不在重载名单里', nil, name:match '^tools%.')
    end
    lt.assertEquals('内核模块在重载名单里', true, moe.util.arrayHas(reloaded, 'core.card'))
    lt.assertEquals('基础设施模块未被重新执行', toolsClass, package.loaded['tools.class'])
end)

lt.test('重载：局跨重载照常可用', function ()
    local desk   = moe.desk.create(4)
    local random = moe.random.create(1)
    local game   = moe.game.create { desk = desk, random = random, packages = { '标准' } }

    local cardTable = game:getValue('牌表')

    local reloaded = moe.reload.reload()

    lt.assertEquals('装载器在重载名单里', true, moe.util.arrayHas(reloaded, 'core.loader'))
    lt.assertEquals('局也在重载名单里', true, moe.util.arrayHas(reloaded, 'core.game'))
    lt.assertEquals('局仍然带着自己的桌子', desk, game.desk)
    lt.assertEquals('规则数值照旧', cardTable, game:getValue('牌表'))
    lt.assertEquals('包元信息照旧可取', true, game:getPackageMeta('标准') ~= nil)
end)

lt.test('重载：新增模块无需额外配置即进入范围', function ()
    local mod = include 'test.reload.probe.added'
    lt.assertEquals('首次加载执行一次', 1, state.addedRuns)
    lt.assertEquals('加载结果可用', 'added', mod.name)

    local reloaded = moe.reload.reload()

    lt.assertEquals('重新执行', 2, state.addedRuns)
    lt.assertEquals('无需配置即在重载名单里', true, moe.util.arrayHas(reloaded, 'test.reload.probe.added'))
end)

lt.test('重载：回调的顺序与告知内容', function ()
    ---@type string[]
    local trace = {}
    local undoBefore = moe.reload.onBeforeReload(function (reload, willReload)
        trace[#trace + 1] = 'before:{}' % { tostring(willReload) }
    end)
    local undoAfter = moe.reload.onAfterReload(function (reload, hasReloaded)
        trace[#trace + 1] = 'after:{}' % { tostring(hasReloaded) }
    end)
    local guard <close> = moe.util.defer(function ()
        undoBefore()
        undoAfter()
    end)

    moe.reload.reload()

    lt.assertEquals('重载前回调先触发', 'before:false', trace[1])
    lt.assertEquals('重载后回调后触发', 'after:false', trace[#trace])
    lt.assertEquals('两者各触发一次', 2, #trace)
end)

lt.test('重载：回调可撤销', function ()
    local hits = 0
    local undo = moe.reload.onAfterReload(function ()
        hits = hits + 1
    end)

    moe.reload.reload()
    lt.assertEquals('撤销前触发', 1, hits)

    undo()
    undo()
    moe.reload.reload()
    lt.assertEquals('撤销后不再触发', 1, hits)
end)

lt.test('重载：单个回调报错不影响其余', function ()
    lt.expectErrors(1)
    local undoBroken = moe.reload.onAfterReload(function ()
        error('回调故意报错')
    end)
    local reached = false
    local undoOK = moe.reload.onAfterReload(function ()
        reached = true
    end)
    local guard <close> = moe.util.defer(function ()
        undoBroken()
        undoOK()
    end)

    local reloaded = moe.reload.reload()

    lt.assertEquals('重载整体仍然完成', true, #reloaded > 0)
    lt.assertEquals('其余回调仍被调用', true, reached)
end)

lt.test('重载：重载期间可被识别', function ()
    ---@type boolean[]
    local inCallback = {}
    local undo = moe.reload.onAfterReload(function ()
        inCallback[#inCallback + 1] = moe.reload.isReloading()
    end)
    local guard <close> = moe.util.defer(undo)

    lt.assertEquals('平时不是重载中', false, moe.reload.isReloading())

    include 'test.reload.probe.isreloading'
    lt.assertEquals('首次加载时不是重载中', false, state.seenDuringLoad[#state.seenDuringLoad])

    moe.reload.reload()
    lt.assertEquals('回调里标记为重载中', true, inCallback[#inCallback])
    lt.assertEquals('重载中加载模块也标记为重载中', true, state.seenDuringLoad[#state.seenDuringLoad])
    lt.assertEquals('重载结束后恢复', false, moe.reload.isReloading())
end)

lt.test('重载：模块被重载时它的回调自动注销', function ()
    include 'test.reload.probe.callback'
    local baseline = state.afterHits

    moe.reload.reload()
    moe.reload.reload()
    moe.reload.reload()

    lt.assertEquals('三次重载只触发三次（不累积）', baseline + 3, state.afterHits)
end)

lt.test('重载：已存在的实例立即使用新代码', function ()
    include 'test.reload.probe.class'
    local instance = New 'Test.Reload.Probe.Class' ('标记')

    lt.assertEquals('初始方法体', 1, instance:value())

    state.version = 2
    moe.reload.reload()

    lt.assertEquals('同一个实例调用到新方法体', 2, instance:value())
    lt.assertEquals('自有字段保留', '标记', instance.marker)
    lt.assertEquals('类型不变', 'Test.Reload.Probe.Class', Type(instance))
    lt.assertEquals('实例仍然有效', true, IsValid(instance))
end)

lt.test('重载：局上的号源跨重载接着走', function ()
    local game   = moe.game.create { desk = moe.desk.create(4), random = moe.random.create(1) }
    local before = game:nextId()
    local reloaded = moe.reload.reload()
    local after  = game:nextId()

    lt.assertEquals('内核模块在重载名单里', true, moe.util.arrayHas(reloaded, 'core.card'))
    lt.assertEquals('号继续增长', true, after > before)
    lt.assertNotEquals('号不与重载前重复', before, after)
end)

lt.test('重载：recycle 立即执行、重载后重跑并回收旧对象', function ()
    local runs  = 0
    ---@type Card[]
    local trash = {}

    local function rebuild(trashFn)
        runs = runs + 1
        trash[#trash + 1] = trashFn(lt.card())
        return runs
    end

    lt.assertEquals('立即执行一次', 1, moe.reload.recycle(rebuild))

    local old = trash[1]
    lt.assertEquals('回收前对象有效', true, IsValid(old))

    moe.reload.reload()

    lt.assertEquals('重载后重跑', 2, runs)
    lt.assertEquals('旧对象已被回收', false, IsValid(old))
    lt.assertEquals('新对象有效', true, IsValid(trash[#trash]))
end)

lt.test('重载：改磁盘文件后重载生效', function ()
    local modName = 'reload_tmp_probe'
    local dir     = moe.env.ROOT_PATH / 'tmp' / 'reload-probe'
    local file    = dir / (modName .. '.lua')
    local oldPath = package.path
    local guard <close> = moe.util.defer(function ()
        package.path = oldPath
        package.loaded[modName] = nil
        fs.remove_all(dir)
    end)

    fs.create_directories(dir)
    package.path = package.path .. ';' .. dir:string() .. '/?.lua'

    local ok, err = moe.util.saveFile(file:string(), 'return { version = 1 }\n')
    lt.assertEquals('写入初始文件', true, ok)
    lt.assertEquals('写入无错误', nil, err)

    local first = include(modName)
    lt.assertEquals('首次加载读到文件内容', 1, first.version)

    moe.util.saveFile(file:string(), 'return { version = 2, changed = true }\n')
    local reloaded = moe.reload.reload()

    lt.assertEquals('重载名单包含该模块', true, moe.util.arrayHas(reloaded, modName))
    lt.assertEquals('重载后读到新内容', 2, require(modName).version)
    lt.assertEquals('改动过的字段生效', true, require(modName).changed)
end)
