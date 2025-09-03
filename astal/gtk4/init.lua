local lgi = require('lgi')

return {
    -- App = require('astal.gtk4.app'),
    astalify = require('astal.gtk4.astalify'),
    Widget = require('astal.gtk4.widget'),

    Gtk = lgi.require('Gtk', '4.0'),
    Gdk = lgi.require('Gdk', '4.0'),
    Astal = lgi.require('Astal', '4.0'),
}
