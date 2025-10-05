local lgi = require('lgi')
local Gtk = lgi.require('Gtk', '4.0')
local Gdk = lgi.require('Gdk', '4.0')
local GLib = lgi.require('GLib', '2.0')
local ApplicationBase = require('astal.application')

local DISPLAY = Gdk.Display.get_default()

---@class AstalLua.ApplicationGtk4: AstalLua.ApplicationBase
local ApplicationGtk4 = ApplicationBase

ApplicationGtk4._attribute.monitors = {
    get = function()
        local list = DISPLAY:get_monitors()
        local monitors = {}

        for i = 1, list:get_n_items() do
            table.insert(monitors, list:get_item(i - 1))
        end

        return monitors
    end,
}

function ApplicationGtk4:add_css_provider(provider)
    Gtk.StyleContext.add_provider_for_display(DISPLAY, provider, Gtk.STYLE_PROVIDER_PRIORITY_USER)

    table.insert(self.priv.css_providers, provider)
end

function ApplicationGtk4:remove_css_provider(provider)
    Gtk.StyleContext.remove_provider_for_display(
        DISPLAY,
        provider,
        Gtk.STYLE_PROVIDER_PRIORITY_USER
    )

    for index, prov in ipairs(self.priv.css_providers) do
        if prov == provider then
            table.remove(self.priv.css_providers, index)
        end
    end
end

function ApplicationGtk4:reset_css()
    for _, provider in ipairs(self.priv.css_providers) do
        Gtk.StyleContext.remove_provider_for_display(DISPLAY, provider)
    end

    self.priv.css_providers = {}
end

function ApplicationGtk4:add_icons(path)
    if path and GLib.file_test(path, 'IS_DIR') and GLib.file_test(path, 'EXISTS') then
        Gtk.IconTheme.get_for_display(DISPLAY):add_search_path(path)
    end
end

---@type AstalLua.ApplicationGtk4
local app = ApplicationGtk4()

return app
