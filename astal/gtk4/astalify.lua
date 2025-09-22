local lgi = require('lgi')
---@type Gtk
local Gtk = lgi.require('Gtk', '4.0')
---@type GObject
local GObject = lgi.require('GObject')

---@type Gdk
local Gdk = lgi.require('Gdk')

local Variable = require('astal.variable')
local bind = require('astal.binding')
local dummy_builder = Gtk.Builder.new()

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
    local copy = {}
    for key, value in pairs(tbl) do
        copy[key] = fn(value)
    end
    return copy
end

local function flatten(tbl)
    local copy = {}
    for _, value in pairs(tbl) do
        if type(value) == 'table' and getmetatable(value) == nil then
            for _, inner in pairs(flatten(value)) do
                table.insert(copy, inner)
            end
        else
            table.insert(copy, value)
        end
    end
    return copy
end

local function includes(tbl, elem)
    for _, value in pairs(tbl) do
        if value == elem then
            return true
        end
    end
    return false
end

local function merge_bindings(array)
    local function get_values(...)
        local args = { ... }
        local i = 0
        return map(array, function(value)
            if bind:is_type_of(value) then
                i = i + 1
                return args[i]
            else
                return value
            end
        end)
    end

    local bindings = filter(array, function(v)
        return bind:is_type_of(v)
    end)

    if #bindings == 0 then
        return array
    end

    if #bindings == 1 then
        return bindings[1]:as(get_values)
    end

    return bind(Variable.derive(bindings, get_values))
end

---@class EventController
---@field on_focus_enter fun(self: Gtk.Widget)
---@field on_focus_leave fun(self: Gtk.Widget)
---@field on_key_pressed fun(self: Gtk.Widget, keyval: number, keycode: number, state: Gdk.ModifierType)
---@field on_key_released fun(self: Gtk.Widget, keyval: number, keycode: number, state: Gdk.ModifierType)
---@field on_key_modifier fun(self: Gtk.Widget, state: Gdk.ModifierType)
---@field on_hover_enter fun(self: Gtk.Widget, x: number, y: number)
---@field on_hover_leave fun(self: Gtk.Widget)
---@field on_motion fun(self: Gtk.Widget, x: number, y: number)
---@field on_scroll fun(self: Gtk.Widget, dx: number, dy: number)
---@field on_scroll_decelerate fun(self: Gtk.Widget, velocity_x: number, velocity_y: number)
---@field on_button_pressed fun(self: Gtk.Widget, button: number, n_press: number, x: number, y: number )
---@field on_button_released fun(self: Gtk.Widget, button: number, n_press: number, x: number, y: number )
---@field on_drag_begin fun(self: Gtk.Widget, start_x: number, start_y: number)
---@field on_drag_update fun(self: Gtk.Widget, offset_x: number, offset_y: number)
---@field on_drag_end fun(self: Gtk.Widget, offset_x: number, offset_y: number)

---@param widget Gtk.Widget | Astalified4
---@param args EventController
local function setup_controllers(widget, args)
    local function pick(...)
        local tbl = {}
        for _, value in ipairs({ ... }) do
            if args[value] then
                table.insert(tbl, args[value])
                args[value] = nil
            else
                table.insert(tbl, false)
            end
        end
        return table.unpack(tbl)
    end

    local function attach(controller, signals)
        widget:add_controller(controller)
        for signal, handler in pairs(signals) do
            if handler then
                widget:hook(controller, signal, function(_, ...)
                    return handler(widget, ...)
                end)
            end
        end
    end

    -- Focus
    local on_focus_enter, on_focus_leave = pick('on_focus_enter', 'on_focus_leave')

    if on_focus_enter or on_focus_leave then
        attach(Gtk.EventControllerFocus.new(), {
            enter = on_focus_enter,
            leave = on_focus_leave,
        })
    end

    -- Keys
    local on_key_pressed, on_key_released, on_key_modifier =
        pick('on_key_pressed', 'on_key_released', 'on_key_modifier')

    if on_key_pressed or on_key_released or on_key_modifier then
        attach(Gtk.EventControllerKey.new(), {
            ['key-pressed'] = on_key_pressed,
            ['key-released'] = on_key_released,
            modifiers = on_key_modifier,
        })
    end

    -- Legacy mouse / generic events
    local on_button_pressed, on_button_released = pick('on_button_pressed', 'on_button_released')

    if on_button_pressed or on_button_released then
        local primary, middle, secondary =
            Gtk.GestureClick({ button = Gdk.BUTTON_PRIMARY }),
            Gtk.GestureClick({ button = Gdk.BUTTON_MIDDLE }),
            Gtk.GestureClick({ button = Gdk.BUTTON_SECONDARY })

        for _, controller in ipairs({ primary, middle, secondary }) do
            widget:add_controller(controller)

            if on_button_pressed then
                widget:hook(controller, 'pressed', function(_, ...)
                    return on_button_pressed(widget, controller.button, ...)
                end)
            end

            if on_button_released then
                widget:hook(controller, 'released', function(_, ...)
                    return on_button_released(widget, controller.button, ...)
                end)
            end
        end
    end

    -- Hover / Motion
    local on_hover_enter, on_hover_leave, on_motion =
        pick('on_hover_enter', 'on_hover_leave', 'on_motion')

    if on_hover_enter or on_hover_leave or on_motion then
        attach(Gtk.EventControllerMotion.new(), {
            enter = on_hover_enter,
            leave = on_hover_leave,
            motion = on_motion,
        })
    end

    -- Scroll
    local on_scroll, on_scroll_decelerate = pick('on_scroll', 'on_scroll_decelerate')

    if on_scroll or on_scroll_decelerate then
        attach(Gtk.EventControllerScroll.new({ 'BOTH_AXES', 'KINETIC' }), {
            scroll = on_scroll,
            decelerate = on_scroll_decelerate,
        })
    end

    local on_drag_begin, on_drag_update, on_drag_end =
        pick('on_drag_begin', 'on_drag_update', 'on_drag_end')

    if on_drag_begin or on_drag_update or on_drag_end then
        attach(Gtk.GestureDrag.new(), {
            ['drag-begin'] = on_drag_begin,
            ['drag-update'] = on_drag_update,
            ['drag-end'] = on_drag_end,
        })
    end

    return args
end

---@class Astalified4: Gtk.Widget
---@field children Gtk.Widget[]
---@field no_implicit_destroy boolean
---@field hook fun(self, object: Connectable, signal: string, callback: function) | fun(self, object: Connectable, callback: function)
---@field get_child? fun(self): Gtk.Widget
---@field get_first_child? fun(self): Gtk.Widget
local Astalified4 = {}

function Astalified4:hook(object, signalOrCallback, callback)
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
        self.on_destroy = object:subscribe(function(...)
            signalOrCallback(self, ...)
        end)
    else
        error('can not hook: not gobject+signal or subscribable')
    end
end

function Astalified4:set_children(children)
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

    for _, child in ipairs(children) do
        self:do_add_child(dummy_builder, child)
    end
end

function Astalified4:get_children()
    local ok = pcall(function()
        return self.get_child ~= nil
    end)

    if ok then
        return { self:get_child() }
    end

    local children = {}
    local ch = self:get_first_child()

    while ch do
        table.insert(children, ch)
        ch = ch:get_next_sibling()
    end

    return children
end

local set_children = {}
local get_children = {}
local no_implicit_destroy = {}

---@alias ConstructorProps Astalified4 | EventController | table<any, any>

---@generic T: Gtk.Widget
---@param ctor T
---@param config? { set_children?: fun(self: T, children: Gtk.Widget[]), get_children?: fun(self: T): Gtk.Widget[] }
---@return fun(args?: T | ConstructorProps | { setup: fun(self: T | Astalified4) }): T | Astalified4
return function(ctor, config)
    if not config then
        config = {}
    end

    ctor.hook = Astalified4.hook ---@diagnostic disable-line:inject-field

    local set, get =
        config.set_children or Astalified4.set_children,
        config.get_children or Astalified4.get_children

    get_children[ctor._name] = get

    set_children[ctor._name] = function(self, children)
        for _, child in ipairs(get(self)) do
            if Gtk.Widget:is_type_of(child) then
                child:unparent()

                if not includes(children, child) and not child.no_implicit_destroy then
                    child:run_dispose()
                end
            end
        end

        set(self, children)
    end

    ctor.get_children = function(self)
        return self.children
    end

    ctor.set_children = function(self, children)
        self.children = children
    end

    ---@diagnostic disable-next-line:undefined-field
    ctor._attribute.children = {
        set = function(self, children)
            set_children[self._name](self, children)
        end,
        get = function(self)
            return get_children[self._name](self)
        end,
    }

    ---@diagnostic disable-next-line:undefined-field
    ctor._attribute.no_implicit_destroy = {
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

    return function(args)
        local bindings = {}
        local signal_handlers = {}
        local setup = args.setup

        if type(args.visible) == 'nil' then
            args.visible = true
        end

        args.setup = nil

        local children = merge_bindings(flatten(filter(args, function(_, key)
            return type(key) == 'number'
        end)))

        local props = filter(args, function(_, key)
            return type(key) == 'string'
        end)

        for key, value in pairs(props) do
            if string.sub(key, 1, 3) == 'on_' and type(value) == 'function' then
                signal_handlers[key] = value
                props[key] = nil
            end
        end

        for key, value in pairs(props) do
            if bind:is_type_of(value) then
                bindings[key] = value
                props[key] = value:get()
            end
        end

        local new = ctor()

        setup_controllers(new, signal_handlers)

        if bind:is_type_of(children) then
            new.children = children:get()
            new.on_destroy = children:subscribe(function(value)
                new.children = value
            end)
        elseif #children > 0 then
            new.children = children
        end

        for prop, binding in pairs(bindings) do
            new.on_destroy = binding:subscribe(function(v)
                new[prop] = v
            end)
        end

        for signal, callback in pairs(signal_handlers) do
            signal = signal:sub(4)

            if string.sub(signal, 1, 7) == 'notify_' then
                signal = 'notify::' .. string.sub(signal, 8)
            end

            signal = signal:gsub('_', '-')

            new:hook(new, signal, callback)
        end

        for prop, value in pairs(props) do
            new[prop] = value
        end

        if setup then
            setup(new)
        end

        return new
    end
end
