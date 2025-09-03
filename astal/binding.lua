local lgi = require('lgi')
local GObject = lgi.require('GObject', '2.0')

---@class AstalLuaBinding: table
---@field private emitter table | AstalLuaVariable | GObject.Object
---@field private property? string
---@field private transform_fn function
---@field private __index AstalLuaBinding
---@overload fun(emitter: GObject.Object, property: string): AstalLuaBinding
---@overload fun(emitter: AstalLuaVariable): AstalLuaBinding
---@overload fun(emitter: { subscribe: function, get: function }): AstalLuaBinding
local Binding = {}
Binding.__index = Binding ---@diagnostic disable-line
Binding.__type = 'Binding'

function Binding:is_type_of(object)
    return type(object) == 'table' and object.__type == self.__type
end

---@param emitter table | AstalLuaVariable | userdata
---@param property? string
function Binding.new(emitter, property)
    return setmetatable({
        emitter = emitter,
        property = property,
        transform_fn = function(v)
            return v
        end,
    }, Binding)
end

---@private
function Binding:__tostring()
    local str = 'Binding<' .. tostring(self.emitter)
    if self.property ~= nil then
        str = str .. ', ' .. self.property
    end
    return str .. '>'
end

---@return any
function Binding:get()
    if self.property ~= nil and GObject.Object:is_type_of(self.emitter) then
        return self.transform_fn(self.emitter[self.property])
    elseif type(self.emitter.get) == 'function' then
        return self.transform_fn(self.emitter:get())
    else
        error('can not get: Not a GObject or a Variable ' .. tostring(self))
    end
end

---@param transform fun(value: any): any
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
    if self.property ~= nil and GObject.Object:is_type_of(self.emitter) then
        local id = self.emitter.on_notify:connect(function()
            callback(self:get())
        end, self.property, false)
        return function()
            GObject.signal_handler_disconnect(self.emitter, id)
        end
    elseif type(self.emitter.subscribe) == 'function' then
        return self.emitter:subscribe(function()
            callback(self:get())
        end)
    else
        error('can not subscribe: Not a GObject or a Variable ' .. tostring(self))
    end
end

---@diagnostic disable-next-line
return setmetatable(Binding, {
    __call = function(_, emitter, prop)
        return Binding.new(emitter, prop)
    end,
})
