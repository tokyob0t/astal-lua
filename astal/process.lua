local lgi = require('lgi')

---@type AstalIO
local AstalIO = lgi.require('AstalIO', '0.1')

local M = {}

M.Process = AstalIO.Process

---@param commandline string | string[]
---@param on_stdout? fun(out: string): nil
---@param on_stderr? fun(err: string): nil
---@return { kill: function } | nil proc
function M.subprocess(commandline, on_stdout, on_stderr)
    on_stdout = on_stdout or function(out)
        io.stdout:write(tostring(out) .. '\n')
    end

    on_stderr = on_stderr or function(err)
        io.stderr:write(tostring(err) .. '\n')
    end

    local proc, err

    if type(commandline) == 'table' then
        proc, err = AstalIO.Process.subprocessv(commandline)
    else
        proc, err = AstalIO.Process.subprocess(commandline)
    end

    if err ~= nil then
        return error(err)
    end

    proc.on_stdout = function(_, stdout)
        on_stdout(stdout)
    end
    proc.on_stderr = function(_, stderr)
        on_stderr(stderr)
    end
    return proc
end

---@param commandline string | string[]
---@return string, string
function M.exec(commandline)
    if type(commandline) == 'table' then
        return AstalIO.Process.execv(commandline)
    else
        return AstalIO.Process.exec(commandline)
    end
end

---@param commandline string | string[]
---@param callback? fun(out: string, err: string): nil
function M.exec_async(commandline, callback)
    callback = callback
        or function(out, err)
            if err ~= nil then
                io.stderr:write(tostring(out) .. '\n')
            else
                io.stdout:write(tostring(err) .. '\n')
            end
        end

    if type(commandline) == 'table' then
        AstalIO.Process.exec_asyncv(commandline, function(_, res)
            local out, err = AstalIO.Process.exec_asyncv_finish(res)
            callback(out, err)
        end)
    else
        AstalIO.Process.exec_async(commandline, function(_, res)
            local out, err = AstalIO.Process.exec_finish(res)
            callback(out, err)
        end)
    end
end

return M
