local lt = require 'test.ltest'
local fs = require 'bee.filesystem'

lt.test('日志目录与日志文件已建立', function ()
    lt.assertEquals('日志目录存在', true, fs.exists(moe.env.LOG_PATH))
    lt.assertEquals('日志文件存在', true, fs.exists(moe.env.LOG_FILE))
end)

lt.test('日志落盘并包含启动日志与本次标记', function ()
    moe.timer.update()
    local marker = 'MOE-KILL-SMOKE-{}' % { os.time() }
    log.info(marker)
    local content = moe.fsu.loadFile(moe.env.LOG_FILE:string()) or ''
    lt.assertEquals('包含启动日志', true, content:find('moe-kill startup', 1, true) ~= nil)
    lt.assertEquals('包含本次标记', true, content:find(marker, 1, true) ~= nil)
end)

lt.test('错误日志写入日志文件', function ()
    moe.timer.update()
    local marker = 'MOE-KILL-SMOKE-ERROR-{}' % { os.time() }
    log.error(marker)
    local content = moe.fsu.loadFile(moe.env.LOG_FILE:string()) or ''
    lt.assertEquals('包含错误标记', true, content:find(marker, 1, true) ~= nil)
    lt.assertEquals('标记为 error 级别', true, content:find('[error]', 1, true) ~= nil)
end)
