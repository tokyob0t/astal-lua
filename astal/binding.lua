local lgi = require('lgi')
local GObject = lgi.require('GObject', '2.0')

---@class AstalLuaBinding: table
---@field emitter table | GObject.Object
---@field property? string
---@field transform_fn function
---@field private __index AstalLuaBinding
---@overload fun(emitter: table | userdata, property?: string): AstalLuaBinding
local Binding = {}
Binding.__index = Binding ---@diagnostic disable-line

---@param emitter table | Variable | userdata
---@param property? string
function Binding.new(emitter, property)
    local Variable = require('astal.variable')

    if Variable:is_type_of(emitter) then
        property = 'value'
    end

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
        error('can not get: Not a GObject or a Variable ' .. self)
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

return setmetatable(Binding, {
    __call = function(_, emitter, prop)
        return Binding.new(emitter, prop)
    end,
})
