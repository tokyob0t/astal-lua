local lgi = require('lgi')

return {
    astalify = require('astal.gtk4.astalify'),
    Widget = require('astal.gtk4.widget'),
    App = require('astal.gtk4.app'),

    ---@type Gtk
    Gtk = lgi.require('Gtk', '4.0'),
    ---@type Gdk
    Gdk = lgi.require('Gdk', '4.0'),
    ---@type Astal
    Astal = lgi.require('Astal', '4.0'),
}
