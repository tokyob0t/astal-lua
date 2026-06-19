local lgi = require('lgi')
local Gtk = lgi.require('Gtk', '3.0')
local Gdk = lgi.require('Gdk', '3.0')
local GLib = lgi.require('GLib')
local ApplicationBase = require('astal.application')

local DISPLAY = Gdk.Display.get_default()
local SCREEN = Gdk.Screen.get_default()

---@class AstalLua.ApplicationGtk3: AstalLua.ApplicationBase
local ApplicationGtk3 = ApplicationBase

ApplicationGtk3._attribute.monitors = {
    get = function()
        local monitors = {}

        for i = 1, DISPLAY:get_n_monitors() do
            table.insert(monitors, DISPLAY:get_monitor(i - 1))
        end

        return monitors
    end,
}

function ApplicationGtk3:add_css_provider(provider)
    Gtk.StyleContext.add_provider_for_screen(SCREEN, provider, Gtk.STYLE_PROVIDER_PRIORITY_USER)

    self.priv.css_providers[provider] = true
end

function ApplicationGtk3:remove_css_provider(provider)
    Gtk.StyleContext.remove_provider_for_screen(SCREEN, provider, Gtk.STYLE_PROVIDER_PRIORITY_USER)

    self.priv.css_providers[provider] = nil
end

function ApplicationGtk3:reset_css()
    for provider in pairs(self.priv.css_providers) do
        Gtk.StyleContext.remove_provider_for_screen(SCREEN, provider)
    end

    self.priv.css_providers = {}
end

function ApplicationGtk3:add_icons(path)
    if path and GLib.file_test(path, 'IS_DIR') and GLib.file_test(path, 'EXISTS') then
        Gtk.IconTheme.get_default():prepend_search_path(path)
    end
end

function ApplicationGtk3:_init()
    self.priv.css_providers = {}
    self.priv.request_handlers = {}
end

---@type AstalLua.ApplicationGtk3
local app = ApplicationGtk3({
    flags = { 'HANDLES_COMMAND_LINE' },
})

return app
