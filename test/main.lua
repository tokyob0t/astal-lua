package.preload.lgi = function()
    return require('LuaGObject')
end

local astal = require('astal')
local gtk4 = require('astal.gtk3')

local Widget = gtk4.Widget
local Gtk = gtk4.Gtk
local astalify = gtk4.astalify
local GLib = astal.require('GLib', '2.0')

local GtkWindow = astalify(Gtk.Window)

local win = GtkWindow({
    Gtk.GestureSingle({
        button = 0,
        propagation_phase = 'CAPTURE',
        on_begin = function(self, ...)
            print('click', self:get_current_button(), ...)
        end,
    }),
})

local loop = GLib.MainLoop()

loop:run()
