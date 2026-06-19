local lgi = require('lgi')

local GObject = lgi.require('GObject', '2.0')
local Process = require('astal.process')
local Time = require('astal.time')

---@alias AstalLua.Connectable GObject.Object | AstalLua.Variable<any> | { subscribe: function }

---@class AstalLua.Variable<T>: GObject.Object, {
--- value: T,
--- subscribe: fun(self, callback: fun(value: T)  ),
--- get: ( fun(self): T ),
--- set: ( fun(self, value: T) )}
---@field value any
---@field private priv table
---@field private _name "AstalLua.Variable"
---@field private _property table
---@overload fun(args: { value: any }): AstalLua.Variable
local Variable = GObject.Object:derive('AstalLua.Variable')

Variable._property.value =
    GObject.ParamSpecBoolean('value', 'value', 'dummy boolean property', false, { 'READWRITE' })

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
    return string.format('%s<%q>', self._name, self:get())
end

---@return any
function Variable:get()
    return self.value
end

---@param value any
function Variable:set(value)
    if self.value ~= value then
        self.value = value
    end
end

function Variable:is_polling()
    return self.priv.poll_cancel ~= nil
end

function Variable:start_poll()
    if self:is_polling() then
        return
    end

    if self.priv.poll_fn then
        self.priv.poll_cancel = Time.interval(self.priv.poll_interval, function()
            self:set(self.priv.poll_transform(self.priv.poll_fn(), self:get()))
        end)
    elseif self.priv.poll_exec then
        self.priv.poll_cancel = Time.interval(self.priv.poll_interval, function()
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
        self.priv.poll_cancel()
    end
    self.priv.poll_cancel = nil
end

---@param interval integer
---@param exec string | string[]
---@param transform? fun(next: any, prev: any): any
---@overload fun(self: AstalLua.Variable<`T`>, interval: integer, exec: fun(prev: any): any ): AstalLua.Variable<T>
function Variable:poll(interval, exec, transform)
    self:stop_poll()
    self.priv.poll_interval = interval
    self.priv.poll_transform = transform or function(next)
        return next
    end

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
        self.priv.watch:quit()
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

---@param gobject GObject.Object
---@param signal string
---@param callback fun(...): any
function Variable:observe(gobject, signal, callback)
    local id

    if string.sub(signal, 1, 8) == 'notify::' then
        local prop = string.gsub(signal, 'notify::', '')

        id = gobject.on_notify:connect(function()
            self:set(callback(gobject, gobject[prop]))
        end, prop, false)
    else
        id = gobject['on_' .. signal]:connect(function(...)
            self:set(callback(...))
        end)
    end

    self:on_dropped(function()
        GObject.signal_handler_disconnect(gobject, id)
    end)

    return self
end

---@param callback fun(value: T)
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
    for _, fn in ipairs(self.priv.droptbl) do
        fn(self)
    end
end

---@private
function Variable:emit_error(error)
    for _, fn in ipairs(self.priv.errtbl) do
        fn(self, error)
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
    self.priv.err_handler = true

    return self
end

---@generic T
---@param deps table<number, AstalLua.Variable<any> | AstalLua.Binding<any>>
---@param transform? fun(...): T
---@return AstalLua.Variable<T>
function Variable.derive(deps, transform)
    local bind = require('astal.binding')

    transform = transform or function(...)
        return { ... }
    end

    for i, var in ipairs(deps) do
        if Variable:is_type_of(var) then
            deps[i] = bind(var)
        end
    end

    local function update()
        local params = {}
        for i, binding in ipairs(deps) do
            params[i] = binding:get()
        end
        return transform(table.unpack(params, 1, #deps))
    end

    local var = Variable.new(update())

    local unsubs = {}

    for i, b in ipairs(deps) do
        unsubs[i] = b:subscribe(function()
            var:set(update())
        end)
    end

    var:on_dropped(function()
        for _, unsub in ipairs(unsubs) do
            unsub()
        end
    end)

    return var
end

---@private
function Variable:_init()
    self.priv.droptbl = {}
    self.priv.errtbl = {}
    self.priv.err_handler = false

    self:on_error(function(_, err)
        if not self.priv.err_handler then
            print(err)
        end
    end)

    self:on_dropped(function()
        self:stop_watch()
        self:stop_poll()
    end)
end

---@generic T
---@param value T
---@return AstalLua.Variable<T>
function Variable.new(value)
    return Variable { value = value }
end

return Variable
