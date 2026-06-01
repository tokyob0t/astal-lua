if not table.unpack then
    table.unpack = unpack
end

local GLib = require('lgi').GLib

---@param name string
---@param fn fun(done: function)
return function(name, fn)
    local start = GLib.get_monotonic_time()

    fn(function(...)
        print(('% -20s %.3f ms'):format(name, (GLib.get_monotonic_time() - start) / 1000))
    end)
end
