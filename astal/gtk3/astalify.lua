local lgi = require('lgi')

---@type Gtk
local Gtk = lgi.require('Gtk', '3.0')

---@type Astal
local Astal = lgi.require('Astal', '3.0')

local construct = require('astal._construct')

local config = require('astal._props')
local utils = require('astal._utils')

local set_children = {}
local get_children = {}

local env = config({
    -- must include
    set_children = function(self, children)
        for _, ch in ipairs(get_children[self._name](self)) do
            self:remove(ch)

            if not utils.includes(children, ch) and not ch.no_implicit_destroy then
                ch:destroy()
            end
        end

        set_children[self._name](self, utils.ensure_widgets(children))
    end,
    get_children = function(self)
        return get_children[self._name](self)
    end,
    set_class_name = function(self, class_name)
        local names = {}
        for word in class_name:gmatch('%S+') do
            table.insert(names, word)
        end
        Astal.widget_set_class_names(self, names)
    end,
    get_class_name = function(self)
        return table.concat(Astal.widget_get_class_names(self), ' ')
    end,
    set_css = Astal.widget_set_css,
    get_css = Astal.widget_get_css,
    toggle_class_name = function(self, name, on)
        Astal.widget_toggle_class_name(self, name, on)
    end,

    -- gtk3 additional props
    set_cursor = Astal.widget_set_cursor,
    get_cursor = Astal.widget_get_cursor,
    set_click_through = Astal.widget_set_click_through,
    get_click_through = Astal.widget_get_click_through,
})

local do_set_children = function(self, children)
    if Gtk.Bin:is_type_of(self) then
        self:add(children[1])
    elseif Gtk.Container:is_type_of(self) then
        for _, child in pairs(children) do
            self:add(child)
        end
    else
        error('can not set children on ' .. tostring(self))
    end
end

local do_get_children = function(self)
    if Gtk.Bin:is_type_of(self) then
        return { self:get_child() }
    elseif Gtk.Container:is_type_of(self) then
        return Gtk.Container.get_children(self)
    else
        error('can not get children on ' .. tostring(self))
    end
end

-- EventControllerSignals

---@generic T: Gtk.Widget
---@param ctor T
---@param config? { set_children?: fun(self: T, children: Gtk.Widget[]), get_children?: fun(self: T): Gtk.Widget[] }
---@return fun(args?: T | Astalified | { setup: fun(self: T | Astalified) }): T | Astalified
return function(ctor, config)
    if not config then
        config = {}
    end

    get_children[ctor._name] = config.get_children or do_get_children
    set_children[ctor._name] = config.set_children or do_set_children

    for key, value in pairs(env) do
        ctor[key] = value

        local prefix, propname = key:match('^([gs]et)_(.+)$')

        if prefix then
            if not ctor._attribute[propname] then
                ctor._attribute[propname] = {}
            end

            ctor._attribute[propname][prefix] = value
        end
    end

    return function(args, ...)
        return construct(ctor, args, ...)
    end
end
