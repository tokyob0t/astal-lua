local lgi = require('lgi')
---@type Gtk
local Gtk = lgi.require('Gtk', '4.0')
---@type Gio
local Gio = lgi.require('Gio', '2.0')
---@type Astal
local Astal = lgi.require('Astal', '4.0')

local astalify = require('astal.gtk4.astalify')

local CircularProgress = require('astal.gtk4.widgets.circularprogress')

---@diagnostic disable-next-line
Gtk.Widget._attribute.vertical = {
    get = function(self)
        return self.orientation == 'VERTICAL'
    end,
    set = function(self, vertical)
        self.orientation = vertical and 'VERTICAL' or 'HORIZONTAL'

        self:toggle_css_class('vertical', self.orientation == 'VERTICAL')
        self:toggle_css_class('horizontal', self.orientation == 'HORIZONTAL')
    end,
}

Gtk.Popover._attribute.offset = {
    get = function(self)
        return { self:get_offset() }
    end,
    set = function(self, v)
        local x, y = v[1], v[2]

        self:set_offset(x, y)
    end,
}

---@type Astal.Slider | { format_value_function: (fun(self: Astal.Slider, value: number): string) }
local Slider = Astal.Slider

---@diagnostic disable-next-line
Slider._attribute.format_value_func = {
    set = function(self, fn)
        self:set_format_value_func(fn)
    end,
}

---@type Gtk.DrawingArea | { draw_func: fun(self: Gtk.DrawingArea, cr: cairo.Context, width: integer, height: integer) }
local DrawingArea = Gtk.DrawingArea

---@diagnostic disable-next-line
DrawingArea._attribute.draw_func = {
    set = function(self, fn)
        self:set_draw_func(fn)
    end,
}

return {
    astalify = astalify,

    DrawingArea = astalify(DrawingArea),
    CircularProgress = astalify(CircularProgress, {
        set_children = function(self, children)
            self.child = children[1]
        end,
        get_children = function(self)
            return { self.child }
        end,
    }),

    Window = astalify(Astal.Window),

    Box = astalify(Gtk.Box, {
        set_children = function(self, children)
            for _, ch in ipairs(children) do
                self:append(ch)
            end
        end,
        get_children = function(self)
            local children = {}
            local child = self:get_first_child()

            while child do
                table.insert(children, child)
                child = child:get_next_sibling()
            end

            return children
        end,
    }),

    Entry = astalify(Gtk.Entry, {
        get_children = function(self)
            return {}
        end,
    }),

    CenterBox = astalify(Gtk.CenterBox, {
        set_children = function(self, children)
            for i, ch in ipairs(children) do
                if ch.type == 'start' then
                    self.start_widget = ch
                elseif ch.type == 'center' then
                    self.center_widget = ch
                elseif ch.type == 'end' then
                    self.end_widget = ch
                -- fallback
                elseif i == 1 then
                    self.start_widget = ch
                elseif i == 2 then
                    self.center_widget = ch
                elseif i == 3 then
                    self.end_widget = ch
                end
            end
        end,
        get_children = function(self)
            return { self.start_widget, self.center_widget, self.end_widget }
        end,
    }),

    Overlay = astalify(Gtk.Overlay, {
        set_children = function(self, children)
            self.child = table.remove(children, 1)

            for _, ch in ipairs(children) do
                self:add_overlay(ch)
            end
        end,
        get_children = function()
            return {}
        end,
    }),

    Label = astalify(Gtk.Label, {
        set_children = function(self, children)
            self.label = tostring(children[1])
        end,
        get_children = function()
            return {}
        end,
    }),

    Stack = astalify(Gtk.Stack, {
        set_children = function(self, children)
            for _, ch in ipairs(children) do
                if ch.name ~= '' then
                    self:add_named(ch, ch.name)
                else
                    self:add_child(ch)
                end
            end
        end,
    }),

    Slider = astalify(Slider, {
        get_children = function()
            return {}
        end,
    }),

    Button = astalify(Gtk.Button),
    ToggleButton = astalify(Gtk.ToggleButton),

    Image = astalify(Gtk.Image, {
        get_children = function()
            return {}
        end,
    }),

    Popover = astalify(Gtk.Popover),

    MenuButton = astalify(Gtk.MenuButton, {
        set_children = function(self, children)
            for _, child in ipairs(children) do
                if Gtk.Popover:is_type_of(child) then
                    self:set_popover(child)
                elseif Gio.MenuModel:is_type_of(child) then
                    self:set_menu_model(child)
                else
                    self:set_child(child)
                end
            end
        end,
        get_children = function(self)
            return { self.popover, self.child }
        end,
    }),

    Revealer = astalify(Gtk.Revealer, {}),

    Switch = astalify(Gtk.Switch, {
        get_children = function()
            return {}
        end,
    }),

    ProgressBar = astalify(Gtk.ProgressBar, {
        get_children = function()
            return {}
        end,
    }),
}
