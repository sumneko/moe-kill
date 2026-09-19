local lt = require 'test.ltest'
local fs = require 'bee.filesystem'

local dir = moe.env.ROOT_PATH / 'tmp'
local path = dir / 'test-async-io.txt'

---@async
lt.test('异步写入后可读回相同内容', function ()
    fs.create_directories(dir)

    local content = 'moe-kill 异步文件读写\n第二行\n'
    moe.asyncIO.writeFile(path, content)
    local readBack = moe.asyncIO.readFile(path)

    lt.assertEquals('内容一致', content, readBack)
    fs.remove(path)
end)

---@async
lt.test('读取不存在的文件以错误交回', function ()
    ---@async
    local function read()
        return moe.asyncIO.readFile(dir / 'test-async-io-not-exists.txt')
    end

    local ok, err = xpcall(read, tostring)

    lt.assertEquals('以错误失败', false, ok)
    lt.assertEquals('错误信息可读', true, tostring(err):find('不存在') ~= nil)
end)

---@async
lt.test('文件操作期间循环继续推进', function ()
    local before = test.loopTicks

    moe.asyncIO.writeFile(path, 'spin-check')
    local readBack = moe.asyncIO.readFile(path)

    lt.assertEquals('读回内容有效', 'spin-check', readBack)
    lt.assertEquals('等待期间循环仍在推进', true, test.loopTicks > before)
    fs.remove(path)
end)
