local lgi = require('lgi')

---@type GObject
local GObject = lgi.require('GObject', '2.0')
local Process = require('astal.process')
local Time = require('astal.time')

---@class AstalLuaVariable: GObject.Object
---@field value any
---@field private priv table
---@field private _name "AstalLuaVariable"
---@field private _attribute table
---@field private _property table
---@overload fun(args: { value: any }): AstalLuaVariable
local Variable = GObject.Object:derive('AstalLuaVariable')

Variable._property.value = GObject.ParamSpecBoolean(
    'value',
    'value',
    'dummy boolean property',
    false,
    { 'READABLE', 'WRITABLE' }
)

Variable._attribute.value = {
    set = function(self, value)
        self.priv.value = value
        self:notify('value')
    end,
    get = function(self)
        return self.priv.value
    end,
}

---@private
function Variable:_tostring()
    return string.format('%s<%s>', self._name, self:get())
end

function Variable:get()
    return self.value
end

function Variable:set(value)
    self.value = value
end

function Variable:is_polling()
    return self.priv.poll ~= nil
end

function Variable:start_poll()
    if self:is_polling() then
        return
    end

    if self.priv.poll_fn then
        self.priv.poll = Time.interval(self.priv.poll_interval, function()
            self:set(self.priv.poll_fn(self:get()))
        end)
    elseif self.priv.poll_exec then
        self.priv.poll = Time.interval(self.priv.poll_interval, function()
            Process.exec_async(self.priv.poll_exec, function(out, err)
                if err ~= nil then
                    return self:emit_error(err)
                else
                    self:set(self.priv.poll_transform(out, self:get()))
                end
            end)
        end)
    end
end

function Variable:stop_poll()
    if self:is_polling() then
        self.priv.poll:cancel()
    end
    self.priv.poll = nil
end

---@param interval number
---@param exec string | string[] | function
---@param transform? fun(next: any, prev: any): any
function Variable:poll(interval, exec, transform)
    transform = transform or function(next)
        return next
    end

    self:stop_poll()
    self.priv.poll_interval = interval
    self.priv.poll_transform = transform

    if type(exec) == 'function' then
        self.priv.poll_fn = exec
        self.priv.poll_exec = nil
    else
        self.priv.poll_exec = exec
        self.priv.poll_fn = nil
    end
    self:start_poll()
    return self
end

function Variable:is_watching()
    return self.priv.watch ~= nil
end

function Variable:start_watch()
    if self:is_watching() then
        return
    end

    self.priv.watch = Process.subprocess(self.priv.watch_exec, function(out)
        self:set(self.priv.watch_transform(out, self:get()))
    end, function(err)
        self:emit_error(err)
    end)
end

function Variable:stop_watch()
    if self:is_watching() then
        self.priv.watch:kill()
    end
    self.priv.watch = nil
end

---@param exec string | string[]
---@param transform? fun(next: any, prev: any): any
function Variable:watch(exec, transform)
    transform = transform or function(next)
        return next
    end

    self:stop_watch()
    self.priv.watch_exec = exec
    self.priv.watch_transform = transform
    self:start_watch()
    return self
end

-- ---@param object table
-- ---@param sigOrFn string
-- ---@param callback fun(...): any
-- ---@return Variable
-- ---@overload fun(self: Variable, object: { [1]: table, [2]: string }[], callback: fun(...): any): Variable
-- function Variable:observe(object, sigOrFn, callback)
--     local f
--     if type(sigOrFn) == 'function' then
--         f = sigOrFn
--     else
--         f = callback or function()
--             return self:get()
--         end
--     end

--     local set = function(...)
--         self:set(f(...))
--     end

--     local arr = {}

--     if type(sigOrFn) == 'string' then
--         table.insert(arr, { object, sigOrFn })
--     end

--     for _, tbl in ipairs(arr) do
--         local id
--         local obj, signal = tbl[1], tbl[2]

--         if string.sub(signal, 1, 8) == 'notify::' then
--             local prop = string.gsub(signal, 'notify::', '')
--             id = obj.on_notify:connect(function()
--                 set(obj, obj[prop])
--             end, prop, false)
--         else
--             id = obj['on_' .. signal]:connect(set)
--         end

--         self:on_dropped(function()
--             GObject.signal_handler_disconnect(obj, id)
--         end)
--     end

--     return self
-- end

---@param gobject GObject.Object
---@param signal string
---@param callback fun(...): any
function Variable:observe(gobject, signal, callback)
    local id

    local set = function(...)
        self:set(callback(...))
    end

    if string.sub(signal, 1, 8) == 'notify::' then
        local prop = string.gsub(signal, 'notify::', '')
        id = gobject.on_notify:connect(function()
            set(callback(gobject, gobject[prop]))
        end, prop, false)
    else
        id = gobject['on_' .. signal]:connect(set)
    end

    self:on_dropped(function()
        GObject.signal_handler_disconnect(gobject, id)
    end)

    return self
end

---@param callback fun(value: any)
---@return function
function Variable:subscribe(callback)
    local id = self.on_notify:connect(function()
        callback(self:get())
    end, 'value', false)

    return function()
        GObject.signal_handler_disconnect(self, id)
    end
end

function Variable:drop()
    self:emit_dropped()
    self.priv.droptbl = nil
    self.priv.errtbl = nil
end

---@private
function Variable:emit_dropped()
    for _, value in ipairs(self.priv.droptbl) do
        value(self)
    end
end

---@private
function Variable:emit_error(error)
    for _, value in ipairs(self.priv.errtbl) do
        value(self, error)
    end
end

---@param fn function
function Variable:on_dropped(fn)
    assert(fn, 'Callback not provided on on_dropped()')
    table.insert(self.priv.droptbl, fn)
    return self
end

---@param fn function
function Variable:on_error(fn)
    assert(fn, 'Callback not provided on on_dropped()')
    table.insert(self.priv.errtbl, fn)
    self.priv.err_handler = nil

    return self
end

---@private
function Variable:_init()
    self.priv.droptbl = {}
    self.priv.errtbl = {}

    self:on_error(function(_, err)
        if self.priv.err_handler then
            print(err)
        end
    end)

    self:on_dropped(function()
        self:stop_watch()
        self:stop_poll()
    end)
end

---@param value any
---@return AstalLuaVariable
function Variable.new(value)
    return Variable({ value = value })
end

return Variable
