local args = table.pack(...)
local src, dst = args[1], args[2]
assert(src and dst, 'usage: apply.lua <src_dir> <dst_dir> [patch ...]')

local patches = table.pack(select(3, ...))
local isWindows = package.config:sub(1, 1) == '\\'

if isWindows then
    os.execute(('if exist "%s" rmdir /s /q "%s"'):format(dst, dst))
    os.execute(('mkdir "%s"'):format(dst))
    os.execute(('xcopy /e /i /y /q "%s" "%s"'):format(src, dst))
else
    os.execute(('rm -rf "%s"'):format(dst))
    os.execute(('mkdir -p "%s"'):format(dst))
    os.execute(('cp -r "%s/." "%s/"'):format(src, dst))
end

local dstStr = dst:gsub('\\', '/')

local function normalizeLF(path, index)
    local input = assert(io.open(path, 'rb'))
    local content = input:read 'a'
    input:close()
    if not content:find('\r\n', 1, true) then
        return path
    end
    local tmp = ('%s.%d.patch'):format(dst, index)
    local output = assert(io.open(tmp, 'wb'))
    output:write((content:gsub('\r\n', '\n')))
    output:close()
    return tmp
end

for i = 1, patches.n do
    local patch = normalizeLF(patches[i], i)
    local ok = os.execute(('git apply --directory="%s" "%s"'):format(dstStr, patch))
    assert(ok, 'git apply failed for ' .. patches[i])
end

print('apply_lua_patch: OK')
