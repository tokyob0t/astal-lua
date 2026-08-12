local lgi = require('lgi')

---@type Gtk
local Gtk = lgi.require('Gtk', '3.0')

---@type Gio
local Gio = lgi.require('Gio', '2.0')

---@type Astal
local Astal = lgi.require('Astal', '3.0')

local astalify = require('astal.gtk3.astalify')

return {
    astalify = astalify,

    ---@generic T
    ---@param args { key?: string | ( fun(item: T): any ) , each: AstalLua.Binding<T[]>, render: fun(item: T): Gtk.Widget? }
    For = function(args)
        return require('astal._utils').for_widget(args.key, args.each, args.render)
    end,

    Box = astalify(Astal.Box),
    Button = astalify(Astal.Button),
    CenterBox = astalify(Astal.CenterBox, {
        set_children = function(self, children)
            self.start_widget = children[1]
            self.center_widget = children[2]
            self.end_widget = children[3]
        end,
        get_children = function(self)
            return {
                self.start_widget,
                self.center_widget,
                self.end_widget,
            }
        end,
    }),
    CircularProgress = astalify(Astal.CircularProgress),
    DrawingArea = astalify(Gtk.DrawingArea),
    Entry = astalify(Gtk.Entry, {
        get_children = function()
            return {}
        end,
    }),
    EventBox = astalify(Astal.EventBox),
    -- TODO: Fixed
    -- TODO: FlowBox
    Icon = astalify(Astal.Icon),
    Label = astalify(Gtk.Label, {
        set_children = function(self, children)
            self.label = tostring(children[1])
        end,
        get_children = function()
            return {}
        end,
    }),
    LevelBar = astalify(Astal.LevelBar),
    -- TODO: ListBox
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
