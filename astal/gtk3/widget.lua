local lgi = require('lgi')
---@type Astal
local Astal = lgi.require('Astal', '3.0')
---@type Gtk
local Gtk = lgi.require('Gtk', '3.0')
local astalify = require('astal.gtk3.astalify')

return {
    astalify = astalify,
    Box = astalify(Astal.Box),
    Button = astalify(Astal.Button),
    CenterBox = astalify(Astal.CenterBox),
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
    MenuButton = astalify(Gtk.MenuButton),
    Overlay = astalify(Astal.Overlay),
    Revealer = astalify(Gtk.Revealer),
    Scrollable = astalify(Astal.Scrollable),
    Slider = astalify(Astal.Slider),
    Stack = astalify(Astal.Stack),
    Switch = astalify(Gtk.Switch),
    Window = astalify(Astal.Window),
}
