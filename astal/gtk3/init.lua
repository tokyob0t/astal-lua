local lgi = require('lgi')

return {
    astalify = require('astal.gtk3.astalify'),
    Widget = require('astal.gtk3.widget'),
    App = require('astal.gtk3.app'),

    ---@type Gtk
    Gtk = lgi.require('Gtk', '3.0'),
    ---@type Gdk
    Gdk = lgi.require('Gdk', '3.0'),
    ---@type Astal
    Astal = lgi.require('Astal', '3.0'),
}
