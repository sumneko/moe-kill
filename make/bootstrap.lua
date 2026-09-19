local fs          = require 'bee.filesystem'
local sys         = require 'bee.sys'
local strSub      = string.sub
local strGsub     = string.gsub
local tableConcat = table.concat
local tableUnpack = table.unpack
local getenv      = os.getenv

local sep = package.config:sub(1, 1)

local function toNative(path)
    return (strGsub(path, '/', sep))
end

local progdir = sys.exe_path():parent_path()
local root    = getenv 'MOE_KILL_ROOT'

if not root then
    local serverdir = progdir:parent_path()
    if not fs.exists(serverdir / 'core') then
        serverdir = progdir
    end
    root = serverdir:parent_path():string()
end

if root == '' then
    root = '.'
end

root = toNative(root)

local patterns = {
    'server/?.lua',
    'server/?/init.lua',
    'server/tools/?.lua',
    'server/tools/?/init.lua',
    '?.lua',
    '?/init.lua',
}

local paths = {}
for i = 1, #patterns do
    paths[i] = root .. sep .. toNative(patterns[i])
end
package.path = tableConcat(paths, ';')

package.searchers[2] = function (name)
    local filename, err = package.searchpath(name, package.path)
    if not filename then
        return err
    end
    local f = io.open(filename)
    if not f then
        return 'cannot open file:' .. filename
    end
    local buf = f:read 'a'
    f:close()
    local relative = strSub(filename, 1, #root) == root and strSub(filename, #root + 2) or filename
    local init, loadErr = load(buf, '@' .. relative)
    if not init then
        return loadErr
    end
    return init, filename
end

local main
local hasExpr = false

local i = 1
while arg[i] do
    local current = arg[i]
    if current == '-E' then
        i = i + 1
    elseif current == '-e' then
        local expr = arg[i + 1]
        assert(expr, "'-e' needs argument")
        assert(load(expr, '=(command line)'))()
        hasExpr = true
        i = i + 2
    elseif strSub(current, 1, 2) == '--' then
        break
    elseif strSub(current, 1, 1) ~= '-' then
        main = i
        break
    else
        i = i + 1
    end
end

if hasExpr and not main then
    return
end

local entry
if main then
    entry = fs.absolute(fs.path(arg[main])):string()
    local n = #arg
    for j = main, n - 1 do
        arg[j] = arg[j + 1]
    end
    arg[n] = nil
else
    entry = root .. sep .. toNative('server') .. sep .. 'main.lua'
end

arg[0] = entry

local file = assert(io.open(entry, 'rb'))
local source = file:read 'a'
file:close()

local chunk = assert(load(source, '@' .. entry, 't'))
chunk(tableUnpack(arg, 1, #arg))
