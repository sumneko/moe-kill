---@class Core
---@field card Core.Card
---@field zone Core.Zone
---@field orderedZone Core.OrderedZone
---@field random Core.Random
local M = {}

M.card        = require 'core.card'
M.zone        = require 'core.zone'
M.orderedZone = require 'core.ordered-zone'
M.random      = require 'core.random'

return M
