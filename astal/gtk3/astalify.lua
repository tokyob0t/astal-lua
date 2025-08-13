local lgi = require('lgi')
---@type Gtk
local Gtk = lgi.require('Gtk', '3.0')
---@type GObject
local GObject = lgi.require('GObject')

---@type Astal
local Astal = lgi.require('Astal', '3.0')
local Binding = require('astal.binding')
local Variable = require('astal.variable')
local exec_async = require('astal.process').exec_async

local no_implicit_destroy = {}

local function copy(tbl)
    local new_tbl = {}
    for key, value in pairs(tbl) do
        if type(key) == 'number' then
            table.insert(new_tbl, value)
        else
            new_tbl[key] = value
        end
    end

    return new_tbl
end

local function filter(tbl, fn)
    local copy = {}
    for key, value in pairs(tbl) do
        if fn(value, key) then
            if type(key) == 'number' then
                table.insert(copy, value)
            else
                copy[key] = value
            end
        end
    end
    return copy
end

local function map(tbl, fn)
    local new_tbl = {}

    for key, value in pairs(tbl) do
        new_tbl[key] = fn(value)
    end
    return new_tbl
end

local function flatten(tbl)
    local new_tbl = {}
    for _, value in pairs(tbl) do
        if type(value) == 'table' and getmetatable(value) == nil then
            for _, inner in pairs(flatten(value)) do
                table.insert(new_tbl, inner)
            end
        else
            table.insert(new_tbl, value)
        end
    end
    return new_tbl
end

local function includes(tbl, elem)
    for _, value in pairs(tbl) do
        if value == elem then
            return true
        end
    end
    return false
end

local function set_children(parent, children)
    children = map(
        filter(flatten(children), function(item)
            return not not item
        end),
        function(item)
            if Gtk.Widget:is_type_of(item) then
                return item
            end
            return Gtk.Label({
                visible = true,
                label = tostring(item),
            })
        end
    )

    -- remove
    if Gtk.Bin:is_type_of(parent) then
        local ch = parent:get_child()
        if ch ~= nil then
            parent:remove(ch)
        end
        if ch ~= nil and not includes(children, ch) and not parent.no_implicit_destroy then
            ch:destroy()
        end
    elseif Gtk.Container:is_type_of(parent) then
        for _, ch in ipairs(parent:get_children()) do
            parent:remove(ch)
            if ch ~= nil and not includes(children, ch) and not parent.no_implicit_destroy then
                ch:destroy()
            end
        end
    end

    -- TODO: add more container types
    if Astal.Box:is_type_of(parent) then
        Astal.Box.set_children(parent, children)
    elseif Astal.Stack:is_type_of(parent) then
        Astal.Stack.set_children(parent, children)
    elseif Astal.CenterBox:is_type_of(parent) then
        parent.start_widget = children[1]
        parent.center_widget = children[2]
        parent.end_widget = children[3]
    elseif Astal.Overlay:is_type_of(parent) then
        parent:set_child(children[1])
        table.remove(children, 1)
        parent:set_overlays(children)
    elseif Gtk.Container:is_type_of(parent) then
        for _, child in pairs(children) do
            if Gtk.Widget:is_type_of(child) then
                parent:add(child)
            end
        end
    end
end

local function merge_bindings(array)
    local function get_values(...)
        local args = { ... }
        local i = 0
        return map(array, function(value)
            if getmetatable(value) == Binding then
                i = i + 1
                return args[i]
            else
                return value
            end
        end)
    end

    local bindings = filter(array, function(v)
        return getmetatable(v) == Binding
    end)

    if #bindings == 0 then
        return array
    end

    if #bindings == 1 then
        return bindings[1]:as(get_values)
    end

    return Binding.new(Variable.derive(bindings, get_values))
end

---@alias Connectable GObject.Object | { subscribe: fun(callback: function): function }

---@generic T
---@class Astalified<T>: {
---css: string,
---class_name: string,
---cursor: string,
---click_through: boolean,
---toggle_class_name: fun(self: T, class_name: string, on: boolean),
---hook: fun(self: T, object: Connectable, signal: string, callback: function) | fun(self: T, object: Connectable, callback: function)}
local Astalified = {}

function Astalified:hook(object, signalOrCallback, callback)
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
        self.on_destroy = object.subscribe(function(...)
            signalOrCallback(self, ...)
        end)
    else
        error('can not hook: not gobject+signal or subscribable')
    end
end

function Astalified:set_class_name(class_name)
    local names = {}
    for word in class_name:gmatch('%S+') do
        table.insert(names, word)
    end
    Astal.widget_set_class_names(self, names) ---@diagnostic disable-line:missing-parameter
end

function Astalified:get_class_name()
    local result = ''
    local strings = Astal.widget_get_class_names(self)
    for i, str in ipairs(strings) do
        result = result .. str
        if i < #strings then
            result = result .. ' '
        end
    end
    return result
end

Astalified.toggle_class_name = Astal.widget_toggle_class_name

Astalified.set_css = Astal.widget_set_css
Astalified.get_css = Astal.widget_get_css

Astalified.set_cursor = Astal.widget_set_cursor
Astalified.get_cursor = Astal.widget_get_cursor

Astalified.set_click_through = Astal.widget_set_click_through
Astalified.get_click_through = Astal.widget_get_click_through

return function(ctor)
    local subclass = ctor:derive('Astalified.' .. ctor._name)

    subclass._attribute = copy(ctor._attribute)

    for key, value in pairs(Astalified) do
        subclass[key] = value
    end

    if subclass.get_children then
        subclass.set_children = set_children
        subclass._attribute.children = {
            set = set_children,
            get = Gtk.Container.get_children,
        }
    end

    subclass._attribute.action_group = {
        set = function(self, v)
            self:insert_action_group(v[1], v[2])
        end,
    }

    subclass._attribute.no_implicit_destroy = {
        get = function(self)
            return no_implicit_destroy[self] or false
        end,
        set = function(self, v)
            if no_implicit_destroy[self] == nil then
                self.on_destroy = function()
                    no_implicit_destroy[self] = nil
                end
            end
            no_implicit_destroy[self] = v
        end,
    }

    subclass._attribute.css = {
        get = Astalified.get_css,
        set = Astalified.set_css,
    }

    subclass._attribute.class_name = {
        get = Astalified.get_class_name,
        set = Astalified.set_class_name,
    }

    return function(args)
        args = args or {}

        local bindings = {}
        local setup = args.setup

        -- collect children
        local children = merge_bindings(flatten(filter(args, function(_, key)
            return type(key) == 'number'
        end)))

        -- default visible to true
        if args.visible == nil then
            args.visible = true
        end

        -- collect props
        local props = filter(args, function(_, key)
            return type(key) == 'string' and key ~= 'setup'
        end)

        -- collect signal handlers
        for prop, value in pairs(props) do
            if string.sub(prop, 0, 2) == 'on' and type(value) ~= 'function' then
                props[prop] = function()
                    exec_async(value, print)
                end
            end
        end

        -- collect bindings
        for prop, value in pairs(props) do
            if getmetatable(value) == Binding then
                bindings[prop] = value
                props[prop] = value:get()
            end
        end

        -- construct, attach bindings, add children
        local widget = subclass()

        if getmetatable(children) == Binding then
            widget.children = children:get()
            widget.on_destroy = children:subscribe(function(v)
                widget.children = v
            end)
        else
            if #children > 0 then
                widget.children = children
            end
        end

        for prop, binding in pairs(bindings) do
            widget.on_destroy = binding:subscribe(function(v)
                widget[prop] = v
            end)
        end

        for prop, value in pairs(props) do
            widget[prop] = value
        end

        if type(setup) == 'function' then
            setup(widget)
        end

        return widget
    end
end
