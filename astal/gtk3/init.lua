local lgi = require("lgi")

return {
    astalify = require("astal.gtk3.astalify"),
    Widget = require("astal.gtk3.widget"),

    Gtk = lgi.require("Gtk", "3.0"),
    Gdk = lgi.require("Gdk", "3.0"),
    Astal = lgi.require("Astal", "3.0"),
}
