local INSIDERS = false

local function listExtensionDirs(tag)
    if INSIDERS then
        tag = tag .. '-insiders'
    end
    local isWindows = package.config:sub(1, 1) == '\\'
    local home = isWindows and os.getenv 'USERPROFILE' or os.getenv 'HOME'
    local dir = home .. '/.vscode' .. tag .. '/extensions'
    if isWindows then
        dir = dir:gsub('/', '\\')
    end
    local result = {}
    local command
    if isWindows then
        command = 'dir /B "' .. dir .. '" 2>nul'
    else
        command = 'ls -1 "' .. dir .. '" 2>/dev/null'
    end
    local pipe = io.popen(command, 'r')
    if not pipe then
        return result
    end
    for name in pipe:lines() do
        result[#result + 1] = dir .. (isWindows and '\\' or '/') .. name
    end
    pipe:close()
    return result
end

local function findDebugger()
    local candidates = {}
    for _, tag in ipairs { '', '-server' } do
        for _, dir in ipairs(listExtensionDirs(tag)) do
            local major, minor, patch = dir:match 'actboy168%.lua%-debug%-(%d+)%.(%d+)%.(%d+)'
            if major then
                local file = dir .. '/script/debugger.lua'
                local f = io.open(file, 'rb')
                if f then
                    f:close()
                    candidates[#candidates + 1] = {
                        version = tonumber(major) * 10000 + tonumber(minor) * 100 + tonumber(patch),
                        file    = file,
                    }
                end
            end
        end
    end
    table.sort(candidates, function (a, b)
        return a.version > b.version
    end)
    return candidates[1]
end

local candidate = findDebugger()
if not candidate then
    error 'Cant find `actboy168.lua-debug`'
end

local f = assert(io.open(candidate.file, 'rb'))
local source = f:read 'a'
f:close()

local chunk = assert(load(source, '@' .. candidate.file))

return chunk(candidate.file)
