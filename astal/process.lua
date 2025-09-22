local lgi = require('lgi')
local Gio = lgi.require('Gio')
local GLib = lgi.require('GLib')

---@generic F: function
---@param fn F
---@return F
local async = function(fn)
    return function(...)
        return lgi.Gio.Async.start(fn)(...)
    end
end

---@generic F: function
---@param fn F
---@return F
local await = function(fn)
    return function(...)
        return lgi.Gio.Async.call(fn)(...)
    end
end

---@class AstalLuaProcess
---@field private subprocess Gio.Subprocess
---@field private stdout_stream? Gio.DataInputStream
---@field private stderr_stream? Gio.DataInputStream
---@field private stdin_stream? Gio.DataOutputStream
local Process = {}

---@param command string | string[]
---@param mode 'r' | 'w' | 'rw'
---@return AstalLuaProcess
Process.new = function(command, mode)
    local argv

    if type(command) == 'string' then
        argv = GLib.shell_parse_argv(command) --- @diagnostic disable-line
    else
        argv = command
    end

    local p = setmetatable({ argv = argv, mode = mode }, { __index = Process })

    local flags

    if p.mode == 'rw' then
        flags = { 'STDOUT_PIPE', 'STDERR_PIPE', 'STDIN_PIPE' }
    elseif p.mode == 'r' then
        flags = { 'STDOUT_PIPE', 'STDERR_PIPE' }
    elseif p.mode == 'w' then
        flags = { 'STDIN_PIPE' }
    end

    p.subprocess = Gio.Subprocess({
        argv = p.argv,
        flags = flags,
    })

    return p
end

Process.async_lines = function(self)
    if not self.stdout_stream then
        self.stdout_stream = Gio.DataInputStream.new(self.subprocess:get_stdout_pipe())
    end

    return function()
        return self.stdout_stream:async_read_line()
    end
end

Process.lines = function(self)
    return await(self:async_lines())
end

---@param callback fun(line: string)
Process.lines_async = async(function(self, callback)
    for line in self:async_lines() do
        callback(line)
    end
end)

Process.async_errors = function(self)
    if not self.stderr_stream then
        self.stderr_stream = Gio.DataInputStream.new(self.subprocess:get_stderr_pipe())
    end

    return function()
        return self.stderr_stream:async_read_line()
    end
end

Process.errors = function(self)
    return await(self:async_errors())
end

---@param callback fun(err: string)
Process.errors_async = async(function(self, callback)
    for err in self:async_errors() do
        callback(err)
    end
end)

---@param self AstalLuaProcess
---@param ... integer | '*a' | '*l'
Process.async_read = function(self, ...) end --- ToDo

---@return boolean
Process.async_wait = function(self)
    return self.subprocess:async_wait()
end
---@return boolean
Process.wait = await(function(self)
    return self:async_wait()
end)

---@param self AstalLuaProcess
---@param callback fun(ok: boolean)
Process.wait_async = async(function(self, callback)
    callback(self:async_wait())
end)

function Process:quit()
    self.subprocess:force_exit()
end

local M = {}

--- Class that acts as io.popen using Gio.Subprocess as backend
M.Process = Process

---@param command string | string[]
---@param on_stdout? fun(out: string)
---@param on_stderr? fun(err: string)
M.subprocess = function(command, on_stdout, on_stderr)
    local p = Process.new(command, 'r')

    p:lines_async(on_stdout or function(out)
        io.stdout:write(('%s\n'):format(out))
    end)

    p:errors_async(on_stderr or function(err)
        io.stderr:write(('%s\n'):format(err))
    end)

    return p
end

---@param command string | string[]
M.async_exec = function(command)
    local p = Process.new(command, 'r')
    local ok = p:async_wait()
    local lines = {}

    if ok then
        for line in p:async_lines() do
            table.insert(lines, line)
        end

        return table.concat(lines, '\n')
    else
        for err in p:async_errors() do
            table.insert(lines, err)
        end

        return nil, table.concat(lines, '\n')
    end
end

---@param command string | string[]
---@return string?, string?
M.exec = await(function(command)
    return M.async_exec(command)
end)

---@param command string | string[]
---@param callback? fun(stdout: string?, stderr?: string)
M.exec_async = async(function(command, callback)
    local stdout, stderr = M.async_exec(command)
    if callback then
        callback(stdout, stderr)
    end
end)

return M
