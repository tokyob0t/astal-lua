local lgi = require('lgi')
---@type Gio
local Gio = lgi.require('Gio')

---@type GLib
local GLib = lgi.require('GLib')


-- stylua: ignore start
---@enum (key) AstalLua.UNIX_SIGNALS
local UNIX_SIGNALS = {
    SIGHUP = 1, SIGINT = 2, SIGQUIT = 3,
    SIGILL = 4, SIGTRAP = 5, SIGABRT = 6,
    SIGIOT = 6, SIGBUS = 7, SIGFPE = 8,
    SIGKILL = 9, SIGUSR1 = 10, SIGSEGV = 11,
    SIGUSR2 = 12, SIGPIPE = 13, SIGALRM = 14,
    SIGTERM = 15, SIGSTKFLT = 16, SIGCHLD = 17,
    SIGCLD = 17, SIGCONT = 18, SIGSTOP = 19,
    SIGTSTP = 20, SIGTTIN = 21, SIGTTOU = 22,
    SIGURG = 23, SIGXCPU = 24, SIGXFSZ = 25,
    SIGVTALRM = 26, SIGPROF = 27, SIGWINCH = 28,
    SIGIO = 29, SIGPOLL = 29, SIGPWR = 30,
    SIGSYS = 31,
}
-- stylua: ignore end

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

---@class AstalLua.Process
---@field private subprocess Gio.Subprocess
---@field private stdout_stream? Gio.DataInputStream
---@field private stderr_stream? Gio.DataInputStream
---@field private stdin_stream? Gio.DataOutputStream
local Process = {}

---@param command string | string[]
---@param mode 'r' | 'w' | 'rw'
---@return AstalLua.Process
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

    p.subprocess = Gio.Subprocess {
        argv = p.argv,
        flags = flags,
    }

    return p
end

function Process:lines_async(callback)
    if not self.stdout_stream then
        self.stdout_stream = Gio.DataInputStream.new(self.subprocess:get_stdout_pipe())
    end

    local iter = await(function()
        return self.stdout_stream:async_read_line()
    end)

    for err in iter do
        callback(err)
    end
end

---@param callback fun(err: string)
function Process:errors_async(callback)
    if not self.stderr_stream then
        self.stderr_stream = Gio.DataInputStream.new(self.subprocess:get_stderr_pipe())
    end

    local iter = await(function()
        return self.stderr_stream:async_read_line()
    end)

    for err in iter do
        callback(err)
    end
end

---@param callback fun(ok: boolean)
function Process:wait_async(callback)
    self.subprocess:wait_async(nil, function(_, task)
        callback(self.subprocess:wait_finish(task))
    end)
end

---@param signal AstalLua.UNIX_SIGNALS
function Process:signal(signal)
    self.subprocess:send_signal(UNIX_SIGNALS[signal])
end

function Process:quit()
    self:signal('SIGQUIT')
end

function Process:quit()
    self:signal('SIGKILL')
end

local M = {}

---Class that acts as io.popen using Gio.Subprocess as backend
---@deprecated
M.Process = Process

---@param command string | string[]
---@param on_stdout? fun(out: string)
---@param on_stderr? fun(err: string)
---@return Gio.Subprocess
M.subprocess = function(command, on_stdout, on_stderr)
    local argv = command

    if type(command) == 'string' then
        argv = GLib.shell_parse_argv(command) --- @diagnostic disable-line
    end

    local p = Gio.Subprocess {
        argv = argv,
        flags = { 'STDOUT_PIPE', 'STDERR_PIPE' },
    }

    local stderr_stream = Gio.DataInputStream.new(p:get_stderr_pipe())
    local stdout_stream = Gio.DataInputStream.new(p:get_stdout_pipe())

    on_stdout = on_stdout
        or function(out)
            io.stdout:write(string.format('%s\n', out))
        end

    on_stderr = on_stderr
        or function(err)
            io.stderr:write(string.format('%s\n', err))
        end

    ---@param stream Gio.DataInputStream
    local function read(stream)
        stream:read_line_async(GLib.PRIORITY_DEFAULT, nil, function(_, task)
            local out = stream:read_line_finish_utf8(task) ---@diagnostic disable-line

            if not out then
                return
            end

            if stream == stdout_stream then
                on_stdout(out)
            elseif stream == stderr_stream then
                on_stderr(out)
            end

            return read(stream)
        end)
    end

    read(stderr_stream)
    read(stdout_stream)

    return p
end

---@async
---@param command string | string[]
M.async_exec = function(command)
    local argv = command

    if type(command) == 'string' then
        argv = GLib.shell_parse_argv(command) --- @diagnostic disable-line
    end

    local p = Gio.Subprocess {
        argv = argv,
        flags = { 'STDOUT_PIPE', 'STDERR_PIPE' },
    }

    local stdout, stderr = p:async_communicate_utf8()

    if stderr ~= '' then
        return nil, stderr
    end

    return stdout
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
