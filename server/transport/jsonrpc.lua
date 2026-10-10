--- 解码后得到的四种形状之一（按字段区分：带 `method` = 请求 / 通知，带 `result` / `error` = 响应）
--- 形状本身声明在 `server/proto.d.lua`（`JSONRPC.*`）
---@alias Jsonrpc.Message JSONRPC.Request|JSONRPC.Notify|JSONRPC.Result|JSONRPC.Error

---@class Jsonrpc.API
local API = {}

API.PARSE_ERROR      = -32700
API.INVALID_REQUEST  = -32600
API.METHOD_NOT_FOUND = -32601
API.INVALID_PARAMS   = -32602
API.INTERNAL_ERROR   = -32603

--- 解一条消息（解不开就给空 + 原因）
---@param text string
---@return Jsonrpc.Message?
---@return string?
function API.decode(text)
    local ok, message = pcall(moe.json.decode, text)
    if not ok then
        return nil, tostring(message)
    end
    if type(message) ~= 'table' then
        return nil, '这不是一条消息'
    end
    ---@cast message Jsonrpc.Message
    return message
end

--- 编一次调用（不给 `id` 就是通知）
---@param id? integer|string
---@param method string
---@param params table
---@return string
function API.encodeCall(id, method, params)
    local message = {
        jsonrpc = '2.0',
        method  = method,
        params  = params,
    }
    if id ~= nil then
        message.id = id
    end
    return moe.json.encode(message)
end

--- 编一次成功响应（`result` 为空就编成 `null` —— 响应必须带 `result`）
---@param id integer|string
---@param result? any
---@return string
function API.encodeResult(id, result)
    return moe.json.encode {
        jsonrpc = '2.0',
        id      = id,
        result  = result == nil and moe.json.null or result,
    }
end

--- 编一次错误响应
---@param id? integer|string
---@param code integer
---@param message string
---@param data? any
---@return string
function API.encodeError(id, code, message, data)
    local errObj = { code = code, message = message }
    if data ~= nil then
        errObj.data = data
    end
    return moe.json.encode {
        jsonrpc = '2.0',
        id      = id == nil and moe.json.null or id,
        error   = errObj,
    }
end

moe.jsonrpc = API

return API
