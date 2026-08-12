local lgi = require('lgi')
local GObject = lgi.require('GObject', '2.0')
local Gio = lgi.require('Gio', '2.0')

---@param default? any
local function constant(v, default)
    return require('astal.binding').new {
        get = function()
            if default and type(v) == 'nil' then
                return default
            end

            return v
        end,
        subscribe = function()
            return function() end ---@diagnostic disable-line
        end,
    }
end

---@param default? any
local function coerce(v, default)
    if require('astal.binding'):is_type_of(v) then
        return v
    end

    return constant(v, default)
end

---@class AstalLua.Binding<T>: {
--- value: T,
--- subscribe: fun(self, callback: fun(value: T) ),
--- get: (fun(self): T) }
---@field emitter AstalLua.Connectable
---@field property? string
---@field private transform_fn function
---@field private __index AstalLua.Binding
---@operator add(number | AstalLua.Binding): AstalLua.Binding<number>
---@operator sub(number | AstalLua.Binding): AstalLua.Binding<number>
---@operator mul(number | AstalLua.Binding): AstalLua.Binding<number>
---@operator div(number | AstalLua.Binding): AstalLua.Binding<number>
---@operator unm: AstalLua.Binding<number>
---@operator concat(string | AstalLua.Binding): AstalLua.Binding<string>
---@overload fun(emitter: AstalLua.Connectable<`T`>, property?: string): AstalLua.Binding<T>
local Binding = {}
Binding.__index = Binding
Binding.__type = 'Binding'

setmetatable(Binding, {
    __call = function(_, emmiter, property)
        return Binding.new(emmiter, property)
    end,
})

function Binding:is_type_of(instance)
    return type(instance) == 'table' and instance.__type == self.__type
end

---@generic T
---@param emitter AstalLua.Connectable<`T`>
---@param property string
---@return AstalLua.Binding<T>
function Binding.new(emitter, property)
    if not property then
        assert(emitter.get, 'can not get: Not a GObject or a Variable ' .. tostring(emitter))
        assert(
            emitter.subscribe,
            'can not subscribe: Not a GObject or a Variable ' .. tostring(emitter)
        )
    end

    return setmetatable({
        emitter = emitter,
        property = property,
        transform_fn = function(v)
            return v
        end,
    }, Binding)
end

---@protected
function Binding.__call(_, emitter, prop)
    return Binding.new(emitter, prop)
end

---@protected
function Binding:__tostring()
    local str = 'Binding<' .. tostring(self.emitter)
    if self.property then
        str = str .. ', ' .. self.property
    else
        str = str .. ', ' .. string.format('%q', tostring(self:get()))
    end
    return str .. '>'
end

---@protected
function Binding.__concat(b1, b2)
    local _b1 = coerce(b1, '')
    local _b2 = coerce(b2, '')

    return Binding.derive({ _b1, _b2 }, function(v1, v2)
        return v1 .. v2
    end)
end

---@protected
function Binding.__add(b1, b2)
    local _b1 = coerce(b1, 0)
    local _b2 = coerce(b2, 0)

    return Binding.derive({ _b1, _b2 }, function(v1, v2)
        return v1 + v2
    end)
end

---@protected
function Binding.__sub(b1, b2)
    local _b1 = coerce(b1, 0)
    local _b2 = coerce(b2, 0)

    return Binding.derive({ _b1, _b2 }, function(v1, v2)
        return v1 - v2
    end)
end

---@protected
function Binding.__mul(b1, b2)
    local _b1 = coerce(b1, 1)
    local _b2 = coerce(b2, 1)

    return Binding.derive({ _b1, _b2 }, function(v1, v2)
        return v1 * v2
    end)
end

---@protected
function Binding.__div(b1, b2)
    local _b1 = coerce(b1, 1)
    local _b2 = coerce(b2, 1)

    return Binding.derive({ _b1, _b2 }, function(v1, v2)
        return v1 / v2
    end)
end

---@protected
function Binding.__unm(b1)
    local _b1 = coerce(b1, 0)

    return _b1:as(function(v)
        return -v
    end)
end

---@protected
function Binding.__mod(b1, b2)
    local _b1 = coerce(b1, 0)
    local _b2 = coerce(b2, 1)

    return Binding.derive({ _b1, _b2 }, function(v1, v2)
        return v1 % v2
    end)
end

---@protected
function Binding.__pow(b1, b2)
    local _b1 = coerce(b1, 0)
    local _b2 = coerce(b2, 1)

    return Binding.derive({ _b1, _b2 }, function(v1, v2)
        return v1 ^ v2
    end)
end

---@protected
function Binding.__idiv(b1, b2)
    local _b1 = coerce(b1, 0)
    local _b2 = coerce(b2, 1)

    return Binding.derive({ _b1, _b2 }, function(v1, v2)
        return math.floor(v1 / v2)
    end)
end

---@return any
function Binding:get()
    local utils = require('astal._utils')

    if not self.property then
        return self.transform_fn(self.emitter:get())
    end

    local current = self.emitter

    for prop in self.property:gmatch('[^.]+') do
        if type(current) == 'nil' then
            return self.transform_fn()
        elseif Gio.Settings:is_type_of(current) then
            current = utils.decode_variant(current:get_value(prop))
        elseif GObject.Object:is_type_of(current) then
            current = current[prop]
        else
            error('can not get: Not a GObject at property ' .. prop .. ' ' .. tostring(current))
        end
    end

    return self.transform_fn(current)
end

---@generic T
---@param transform fun(value: any): T
---@return AstalLua.Binding<T>
function Binding:as(transform)
    local b = Binding.new(self.emitter, self.property)
    b.transform_fn = function(v)
        return transform(self.transform_fn(v))
    end
    return b
end

---@param callback fun(value: any)
---@return function
function Binding:subscribe(callback)
    if not self.property then
        return self.emitter:subscribe(function()
            callback(self:get())
        end)
    end

    if Gio.Settings:is_type_of(self.emitter) then
        local id = self.emitter.on_changed:connect(function(_, key)
            if key == self.property then
                callback(self:get())
            end
        end)

        return function()
            GObject.signal_handler_disconnect(self.emitter, id)
        end
    end

    local chain_unsubs = {}
    local properties = {}

    for part in self.property:gmatch('[^.]+') do
        table.insert(properties, part)
    end

    local function subscribe_level(start_idx)
        for i = start_idx, #chain_unsubs do
            if chain_unsubs[i] then
                chain_unsubs[i]()
                chain_unsubs[i] = nil
            end
        end

        local current = self.emitter

        for i = 1, start_idx - 1 do
            if current == nil then
                return
            end
            current = current[properties[i]]
        end

        for i = start_idx, #properties do
            if current == nil then
                break
            end

            local prop = properties[i]
            local is_last = (i == #properties)
            local obj = current

            local id = obj.on_notify:connect(function()
                if not is_last then
                    subscribe_level(i + 1)
                end
                callback(self:get())
            end, prop, false)

            chain_unsubs[i] = function()
                GObject.signal_handler_disconnect(obj, id)
            end

            if not is_last then
                current = current[prop]
            end
        end
    end

    subscribe_level(1)

    return function()
        for _, unsub in ipairs(chain_unsubs) do
            if unsub then
                unsub()
            end
        end
    end
end

function Binding.derive(deps, transform)
    return Binding.new {
        get = function()
            local values = {}

            for i, dep in ipairs(deps) do
                values[i] = dep:get()
            end

            return transform(table.unpack(values, 1, #deps))
        end,
        subscribe = function(self, callback)
            local unsubs = {}

            local function update()
                callback(self:get())
            end

            for i, dep in ipairs(deps) do
                unsubs[i] = dep:subscribe(update)
            end

            ---@diagnostic disable-next-line
            return function()
                for _, unsub in ipairs(unsubs) do
                    unsub()
                end
            end
        end,
    }
end

return Binding
