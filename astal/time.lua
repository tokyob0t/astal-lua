local lgi = require('lgi')
local GLib = lgi.require('GLib')

local M = {}

---@param interval number
---@param fn function
---@return function
function M.interval(interval, fn)
    local id = GLib.timeout_add(GLib.PRIORITY_DEFAULT, interval, function()
        fn()
        return true
    end)

    return function()
        GLib.source_remove(id)
    end
end

---@param timeout number
---@param fn function
---@return function
function M.timeout(timeout, fn)
    local id = GLib.timeout_add(GLib.PRIORITY_DEFAULT, timeout, function()
        fn()
        return false
    end)

    return function()
        GLib.source_remove(id)
    end
end

---@param fn function
---@return function
function M.idle(fn)
    local id = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, function()
        fn()
        return false
    end)

    return function()
        GLib.source_remove(id)
    end
end

return M
