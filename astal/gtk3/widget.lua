local lgi = require('lgi')
---@type Gtk
local Gtk = lgi.require('Gtk', '3.0')
---@type Astal
local Astal = lgi.require('Astal', '3.0')

local astalify = require('astal.gtk3.astalify')

return {
    astalify = astalify,
    Box = astalify(Astal.Box),
    Button = astalify(Astal.Button),
    CenterBox = astalify(Astal.CenterBox, {
        set_children = function(self, children)
            self.start_widget = children[1]
            self.center_widget = children[2]
            self.end_widget = children[3]
        end,
    }),
    CircularProgress = astalify(Astal.CircularProgress),
    DrawingArea = astalify(Gtk.DrawingArea),
    Entry = astalify(Gtk.Entry),
    EventBox = astalify(Astal.EventBox),
    -- TODO: Fixed
    -- TODO: FlowBox
    Icon = astalify(Astal.Icon),
    Label = astalify(Gtk.Label),
    LevelBar = astalify(Astal.LevelBar),
    -- TODO: ListBox
    MenuButton = astalify(Gtk.MenuButton, {
        set_children = function(self, children)
            for _, child in ipairs(children) do
                if Gtk.Popover:is_type_of(child) then
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
    Overlay = astalify(Astal.Overlay, {
        set_children = function(self, children)
            self:set_child(table.remove(children, 1))
            self:set_overlays(children)
        end,
    }),
    Revealer = astalify(Gtk.Revealer),
    Scrollable = astalify(Astal.Scrollable),
    Slider = astalify(Astal.Slider),
    Stack = astalify(Astal.Stack, {
        set_children = function(self, children)
            local i = 0
            for _, ch in ipairs(children) do
                if ch.name then
                    self:add_named(ch, ch.name)
                else
                    i = i + 1
                    self:add_named(ch, tostring(i))
                end
            end
        end,
    }),
    Switch = astalify(Gtk.Switch),
    Window = astalify(Astal.Window),
}
