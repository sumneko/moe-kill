local fs = require 'bee.filesystem'

---@class Rule.Vfs
---@field private files table<string, string>
---@field private dirs table<string, true>
---@field private defaults table<string, true>
local M = Class 'Rule.Vfs'

function M:__init()
    self.files    = {}
    self.dirs     = {}
    self.defaults = {}
end

---@param path string
---@return string
function M.normalize(path)
    ---@type string[]
    local parts = {}
    for segment in path:gmatch '[^/\\]+' do
        if segment == '.' then
        elseif segment == '..' then
            if #parts == 0 then
                error('逻辑路径越出规则集根：{}' % { path }, 2)
            end
            parts[#parts] = nil
        else
            parts[#parts+1] = segment
        end
    end
    return table.concat(parts, '/')
end

---@param dir bee.fspath
---@param logical string
---@private
function M:index(dir, logical)
    self.dirs[logical] = true
    for entry in fs.pairs(dir) do
        local child = logical .. '/' .. entry:filename():string()
        if fs.is_directory(entry) then
            self:index(entry, child)
        elseif fs.is_regular_file(entry) then
            self.files[child] = entry:string()
        end
    end
end

---@param pattern string
---@param base bee.fspath
---@return { name: string, dir: bee.fspath }[]
local function expandSource(pattern, base)
    local normalized = fs.path(pattern):lexically_normal():string()
    local star       = normalized:find('*', 1, true)
    if star then
        if star ~= #normalized or star == 1 or normalized:sub(star - 1, star - 1) ~= '/' then
            error('规则集来源写法非法：{}（* 只能作为结尾的 /*）' % { pattern }, 3)
        end
        local container = base / fs.path(normalized:sub(1, star - 2))
        if not fs.is_directory(container) then
            error('规则集来源不存在：{}' % { pattern }, 3)
        end
        ---@type { name: string, dir: bee.fspath }[]
        local sources = {}
        for entry in fs.pairs(container) do
            local name = entry:filename():string()
            if name:sub(1, 1) ~= '.' and fs.is_directory(entry) then
                sources[#sources+1] = { name = name, dir = entry }
            end
        end
        table.sort(sources, function (a, b)
            return a.name < b.name
        end)
        return sources
    end

    local dir = base / fs.path(normalized)
    if not fs.is_directory(dir) then
        error('规则集来源不存在：{}' % { pattern }, 3)
    end
    local name = dir:filename():string()
    if name == '' then
        error('规则集来源必须是目录：{}' % { pattern }, 3)
    end
    return { { name = name, dir = dir } }
end

---@param name string
---@return string # 逻辑名（去掉默认加载标记）
---@return boolean # 是否带默认加载标记
local function splitDefault(name)
    if name:sub(1, 1) ~= '@' then
        return name, false
    end
    local rest = name:sub(2)
    if rest == '' then
        error('来源目录名只有一个 "@"：默认加载标记后面必须还有名字', 3)
    end
    return rest, true
end

---@param sources string[]
---@param base string|bee.fspath
---@return Rule.Vfs
function M.create(sources, base)
    if type(sources) ~= 'table' then
        error('规则集来源必须是字符串列表', 2)
    end
    local root = fs.absolute(fs.path(base))
    local self = New 'Rule.Vfs' ()
    for _, pattern in ipairs(sources) do
        if type(pattern) ~= 'string' or pattern == '' then
            error('规则集来源必须是非空字符串', 2)
        end
        for _, source in ipairs(expandSource(pattern, root)) do
            local logical, isDefault = splitDefault(source.name)
            self:index(source.dir, logical)
            if isDefault then
                self.defaults[logical] = true
            end
        end
    end
    return self
end

---@return string[] # 默认加载的包（逻辑名，按名字升序）
function M:getDefaultPackages()
    ---@type string[]
    local list = {}
    for name in pairs(self.defaults) do
        list[#list+1] = name
    end
    table.sort(list)
    return list
end

---@param logical string
---@return boolean
function M:exists(logical)
    return self.files[logical] ~= nil or self.dirs[logical] == true
end

---@param logical string
---@return boolean
function M:isFile(logical)
    return self.files[logical] ~= nil
end

---@param logical string
---@return boolean
function M:isDirectory(logical)
    return self.dirs[logical] == true
end

---@param logical string
---@return string? # 物理路径
function M:resolve(logical)
    return self.files[logical]
end

---@param logical string
---@return string? source
---@return string? err
function M:read(logical)
    local physical = self.files[logical]
    if not physical then
        return nil, '逻辑路径不是文件：' .. logical
    end
    return moe.util.loadFile(physical)
end

---@param logicalDir string
---@return string[] # 递归列出的 .lua 文件（逻辑路径，按路径排序）
function M:listFiles(logicalDir)
    local prefix = logicalDir .. '/'
    ---@type string[]
    local list = {}
    for logical in pairs(self.files) do
        if logical:sub(-4) == '.lua' and logical:sub(1, #prefix) == prefix then
            list[#list+1] = logical
        end
    end
    table.sort(list)
    return list
end

return M
