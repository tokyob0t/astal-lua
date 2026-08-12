local lgi = require('lgi')
local GObject = lgi.require('GObject')
local Gtk = lgi.require('Gtk')

local utils = require('astal._utils')

local no_implicit_destroy = {}
local types = setmetatable({}, { __mode = 'k' })

Gtk.Widget._attribute.type = {
    set = function(self, _type)
        types[self] = _type
    end,
    get = function(self)
        return types[self]
    end,
}

Gtk.Widget._attribute.action_group = {
    set = function(self, v)
        self:insert_action_group(v[1], v[2])
    end,
}

Gtk.Widget._attribute.no_implicit_destroy = {
    set = function(self, idestroy)
        if no_implicit_destroy[self] == nil then
            self.on_destroy = function()
                no_implicit_destroy[self] = nil
            end
        end
        no_implicit_destroy[self] = idestroy
    end,
    get = function(self)
        return not not no_implicit_destroy[self]
    end,
}

---@class AstalLua.Astalified: Gtk.Widget
---@field type? string
---@field css? string
---@field class_name string
---@field vertical boolean
---@field children Gtk.Widget[]
---@field no_implicit_destroy boolean
---@field toggle_class_name fun(self: Gtk.Widget, class_name: string, condition: boolean)
---@field hook fun(self: Gtk.Widget | AstalLua.Astalified , object: AstalLua.Connectable, signalOrCallback: string | fun(gobject: AstalLua.Connectable, prop: any), callback?: fun(gobject: AstalLua.Connectable, prop: any))

local default_props = {
    set_children = utils.not_implemented('set_children'),
    get_children = utils.not_implemented('get_children'),
    set_css = utils.not_implemented('set_css'),
    get_css = utils.not_implemented('get_css'),
    set_class_name = utils.not_implemented('set_class_name'),
    get_class_name = utils.not_implemented('get_class_name'),
    hook = function(self, object, signalOrCallback, callback)
        if GObject.Object:is_type_of(object) and type(signalOrCallback) == 'string' then
            local id
            if string.sub(signalOrCallback, 1, 8) == 'notify::' then
                local prop = string.gsub(signalOrCallback, 'notify::', '')
                id = object.on_notify:connect(function()
                    callback(self, object[prop])
                end, prop, false)
            else
                id = object['on_' .. signalOrCallback]:connect(function(_, ...)
                    callback(self, ...)
                end)
            end
            self.on_destroy = function()
                GObject.signal_handler_disconnect(object, id)
            end
        elseif type(object.subscribe) == 'function' then
            local unsub = object:subscribe(function(...)
                signalOrCallback(self, ...)
            end)
            self.on_destroy = unsub
        else
            error('can not hook: not gobject+signal or subscribable')
        end
    end,
}

return function(additional_props)
    for key, value in pairs(additional_props) do
        default_props[key] = value
    end

    return default_props
end
