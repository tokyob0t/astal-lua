local lgi = require('lgi')
local Gio = lgi.require('Gio')
---@type GLib
local GLib = lgi.require('GLib')

local M = {}

---@generic F: function
---@param fn F
---@return F
local async = function(fn)
    return function(...)
        return Gio.Async.start(fn)(...)
    end
end

---@generic F: function
---@param fn F
---@return F
local await = function(fn)
    return function(...)
        return Gio.Async.call(fn)(...)
    end
end

---@async
---@param path string
---@return string?
M.async_read_file = function(path)
    if not GLib.file_test(path, 'EXISTS') then
        return
    end

    local file = Gio.File.new_for_path(path)

    local info = assert(file:async_query_info('standard::size', 'NONE'))
    local stream = assert(file:async_read())

    local read_buffers = {}

    local remaining = info:get_size()

    while remaining > 0 do
        local buffer = assert(stream:async_read_bytes(remaining))
        table.insert(read_buffers, buffer.data)
        remaining = remaining - #buffer
    end

    stream:async_close()

    return table.concat(read_buffers)
end

---@param path string
---@param callback fun(contents: string?)
M.read_file_async = async(function(path, callback)
    callback(M.async_read_file(path))
end)

---@param path string
---@return string?
M.read_file = await(function(path)
    return M.async_read_file(path)
end)

---@async
---@param path string
---@param contents string
---@return boolean
M.async_write_file = function(path, contents)
    local file = Gio.File.new_for_path(path)
    local parent = GLib.path_get_dirname(path)
    local stream

    if not GLib.file_test(parent, 'IS_DIR') then
        Gio.File.new_for_path(parent):make_directory_with_parents()
    end

    if GLib.file_test(file:get_path(), 'EXISTS') then
        stream = file:async_replace(nil, false, 'REPLACE_DESTINATION')
    else
        stream = file:async_create('NONE')
    end

    local pos = 1

    while pos <= #contents do
        local wrote, err = stream:async_write_bytes(GLib.Bytes(contents:sub(pos)))
        assert(wrote >= 0, err)
        pos = pos + wrote
    end

    return stream:async_close()
end

---@param path string
---@param contents string
---@param callback? fun(ok: boolean)
M.write_file_async = async(function(path, contents, callback)
    local ok = M.async_write_file(path, contents)

    if callback then
        callback(ok)
    end
end)

---@param path string
---@param contents string
---@return boolean
M.write_file = await(function(path, contents)
    return M.async_write_file(path, contents)
end)

---@param path string
---@param recursive boolean
---@param callback fun(file: string, event: Gio.FileMonitorEvent)
---@overload fun(path: string, callback: fun(file: string, event: Gio.FileMonitorEvent)): Gio.FileMonitor
M.monitor_file = function(path, recursive, callback)
    if type(recursive) == 'function' then
        callback = recursive
        recursive = false
    end

    local file = Gio.File.new_for_path(path)

    ---@type Gio.FileMonitor
    local monitor = file:monitor({ 'WATCH_HARD_LINKS', 'WATCH_MOVES', 'WATCH_MOUNTS' })

    if callback then
        monitor.on_changed = function(_, _file, _, event_type)
            callback(_file:get_path(), event_type)
        end
    end

    if recursive and GLib.file_test(file:get_path(), 'IS_DIR') then
        local enum = file:enumerate_children('standard::*', 'NONE')

        local next_file = function()
            return enum:next_file()
        end

        for file_info in next_file do
            if file_info:get_file_type() == 'DIRECTORY' then
                local _path = file:get_child(file_info:get_name()):get_path()

                if _path then
                    local m = M.monitor_file(_path, recursive, callback)
                    monitor.on_notify.cancelled = function()
                        m:cancel()
                    end
                end
            end
        end
    end

    monitor.on_notify.cancelled = function()
        monitor:unref()
    end

    return monitor
end

return M
