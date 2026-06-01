local bind = require('astal.binding')
local utils = require('astal._utils')

local lgi = require('lgi')
local Gtk = lgi.require('Gtk')

---@alias EventControllerFocusSignals { on_focus_enter?: fun(widget: Gtk.Widget), on_focus_leave?: fun(widget: Gtk.Widget) }
---@alias EventControllerKeySignals { on_key_pressed?: fun(widget: Gtk.Widget, keyval: number, keycode: number, state: Gdk.ModifierType), on_key_released?: fun(widget: Gtk.Widget, keyval: number, keycode: number, state: Gdk.ModifierType), on_key_modifier?: fun(widget: Gtk.Widget, state: Gdk.ModifierType ) }
---@alias EventControllerMotionSignals { on_hover_enter?: fun(widget: Gtk.Widget, x: number, y: number), on_hover_leave?: fun(widget: Gtk.Widget), on_motion?: fun(widget: Gtk.Widget, x: number, y: number) }
---@alias EventControllerScrollSignals { on_scroll?: fun(widget: Gtk.Widget, dx: number, dy: number), on_scroll_decelerate?: fun(widget: Gtk.Widget, velocity_x: number, velocity_y: number) }
---@alias GestureClickSignals { on_button_pressed?: fun(widget: Gtk.Widget, button: number, n_press: number, x: number, y: number), on_button_pressed?: fun(widget: Gtk.Widget, button: number, n_press: number, x: number, y: number) }
---@alias GestureDragSignals { on_drag_begin?: fun(widget: Gtk.Widget, button: number, start_x: number, start_y: number), on_drag_update?: fun(widget: Gtk.Widget, button: number, offset_x: number, offset_y: number), on_drag_end?: fun(widget: Gtk.Widget, button: number, offset_x: number, offset_y: number) }
---@alias EventControllerSignals EventControllerFocusSignals | EventControllerKeySignals | EventControllerMotionSignals | EventControllerScrollSignals | GestureClickSignals | GestureDragSignals

---@param widget Gtk.Widget | Astalified
---@param args EventControllerSignals
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
        attach(Gtk.EventControllerFocus({ propagation_phase = 'CAPTURE' }), {
            enter = on_focus_enter,
            leave = on_focus_leave,
        })
    end

    -- Keys
    local on_key_pressed, on_key_released, on_key_modifier =
        pick('on_key_pressed', 'on_key_released', 'on_key_modifier')

    if on_key_pressed or on_key_released or on_key_modifier then
        attach(Gtk.EventControllerKey({ propagation_phase = 'CAPTURE' }), {
            ['key-pressed'] = on_key_pressed,
            ['key-released'] = on_key_released,
            modifiers = on_key_modifier,
        })
    end

    -- Legacy mouse / generic events
    local on_button_pressed, on_button_released = pick('on_button_pressed', 'on_button_released')

    if on_button_pressed or on_button_released then
        local gesture = Gtk.GestureClick({ button = 0, propagation_phase = 'CAPTURE' })

        widget:add_controller(gesture)

        if on_button_pressed then
            widget:hook(gesture, 'pressed', function(_, ...)
                return on_button_pressed(widget, gesture:get_current_button(), ...)
            end)
        end

        if on_button_released then
            widget:hook(gesture, 'released', function(_, ...)
                return on_button_released(widget, gesture:get_current_button(), ...)
            end)
        end
    end

    -- Hover / Motion
    local on_hover_enter, on_hover_leave, on_motion =
        pick('on_hover_enter', 'on_hover_leave', 'on_motion')

    if on_hover_enter or on_hover_leave or on_motion then
        attach(Gtk.EventControllerMotion({ propagation_phase = 'CAPTURE' }), {
            enter = on_hover_enter,
            leave = on_hover_leave,
            motion = on_motion,
        })
    end

    -- Scroll
    local on_scroll, on_scroll_decelerate = pick('on_scroll', 'on_scroll_decelerate')

    if on_scroll or on_scroll_decelerate then
        attach(
            Gtk.EventControllerScroll({
                propagation_phase = 'CAPTURE',
                flags = { 'BOTH_AXES', 'KINETIC' },
            }),
            { scroll = on_scroll, decelerate = on_scroll_decelerate }
        )
    end

    local on_drag_begin, on_drag_update, on_drag_end =
        pick('on_drag_begin', 'on_drag_update', 'on_drag_end')

    if on_drag_begin or on_drag_update or on_drag_end then
        local gesture = Gtk.GestureDrag({ button = 0, propagation_phase = 'CAPTURE' })

        widget:add_controller(gesture)

        if on_drag_begin then
            widget:hook(gesture, 'drag-begin', function(_, ...)
                return on_drag_begin(widget, gesture:get_current_button(), ...)
            end)
        end
        if on_drag_update then
            widget:hook(gesture, 'drag-update', function(_, ...)
                return on_drag_update(widget, gesture:get_current_button(), ...)
            end)
        end

        if on_drag_end then
            widget:hook(gesture, 'drag-end', function(_, ...)
                return on_drag_end(widget, gesture:get_current_button(), ...)
            end)
        end
    end

    return args
end

return function(ctor, args, ...)
    if not args then
        args = {}
    end

    local bindings = {}
    local signal_handlers = {}
    local setup = args.setup

    if args.visible == nil then
        args.visible = true
    end

    args.setup = nil

    local children = utils.flatten(utils.filter(args, function(value, key)
        return type(key) == 'number' and not Gtk.EventController:is_type_of(value)
    end))

    local n = select('#', ...)

    for i = 1, n do
        table.insert(children, select(i, ...))
    end

    children = utils.merge_bindings(children)

    local controllers = utils.filter(args, function(value, key)
        return type(key) == 'number' and Gtk.EventController:is_type_of(value)
    end)

    local props = utils.filter(args, function(_, key)
        return type(key) == 'string'
    end)

    do
        local _props = {}
        -- normalize props just in case we're using fennel :3
        for key, value in pairs(props) do
            _props[key:gsub('-', '_')] = value
        end

        props = _props
    end

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

    local new = ctor(props)

    if Gtk._version == '4.0' then
        setup_controllers(new, signal_handlers)

        for _, controller in ipairs(controllers) do
            new:add_controller(controller)
        end
    end

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

    if setup then
        setup(new)
    end

    return new
end
