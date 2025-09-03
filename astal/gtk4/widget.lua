local lgi = require('lgi')
---@type Gtk
local Gtk = lgi.require('Gtk', '4.0')
---@type Astal
local Astal = lgi.require('Astal', '4.0')

local astalify = require('astal.gtk4.astalify')

---@diagnostic disable-next-line
Gtk.Widget._attribute.action_group = {
    set = function(self, ag)
        self:insert_action_group(ag[1], ag[2])
    end,
}

---@type Gtk.Box | { vertical: boolean }
local Box = Gtk.Box

---@diagnostic disable-next-line
Box._attribute.vertical = {
    get = function(self)
        return self.orientation == 'VERTICAL'
    end,
    set = function(self, vertical)
        self.orientation = vertical and 'VERTICAL' or 'HORIZONTAL'
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

---@param children any[]
---@return ( Gtk.Widget | Gtk.Label )[]
local filter = function(children)
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

    return map(
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
end

return {
    __filter = filter,
    astalify = astalify,

    DrawingArea = astalify(DrawingArea),

    Window = astalify(Astal.Window),

    Box = astalify(Box, {}),

    Entry = astalify(Gtk.Entry),

    CenterBox = astalify(Gtk.CenterBox, {
        set_children = function(self, children)
            children = filter(children)
            self.start_widget = children[1] or Gtk.Box({})
            self.center_widget = children[2] or Gtk.Box({})
            self.end_widget = children[3] or Gtk.Box({})
        end,
        ---@param self Gtk.CenterBox
        get_children = function(self)
            return { self.start_widget, self.center_widget, self.end_widget }
        end,
    }),

    Label = astalify(Gtk.Label, {
        set_children = function(self, children)
            self.label = tostring(children)
        end,
        get_children = function()
            return {}
        end,
    }),

    Slider = astalify(Slider, {
        get_children = function()
            return {}
        end,
    }),

    Button = astalify(Gtk.Button),

    Image = astalify(Gtk.Image, {
        get_children = function()
            return {}
        end,
    }),

    MenuButton = astalify(Gtk.MenuButton, {
        set_children = function(self, children)
            for _, child in ipairs(filter(children)) do
                if Gtk.Popover:is_type_of(children) then
                    self:set_popover(child)
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
