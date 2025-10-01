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

    table.insert(self.priv.css_providers, provider)
end

function ApplicationGtk3:remove_css_provider(provider)
    Gtk.StyleContext.remove_provider_for_screen(SCREEN, provider, Gtk.STYLE_PROVIDER_PRIORITY_USER)

    for index, prov in ipairs(self.priv.css_providers) do
        if prov == provider then
            table.remove(self.priv.css_providers, index)
        end
    end
end

function ApplicationGtk3:reset_css()
    for _, provider in ipairs(self.priv.css_providers) do
        Gtk.StyleContext.remove_provider_for_screen(SCREEN, provider)
    end

    self.priv.css_providers = {}
end

function ApplicationGtk3:add_icons(path)
    if path and GLib.file_test(path, 'IS_DIR') and GLib.file_test(path, 'EXISTS') then
        Gtk.IconTheme.get_default():prepend_search_path(path)
    end
end

---@param args ApplicationStartArgs
function ApplicationGtk3:start(args)
    self.application_id = string.format('io.Astal.%s', args.instance_name or 'lua')

    if type(args.hold) == 'nil' then
        args.hold = true
    end

    if args.request_handler then
        self:add_request_handler(args.request_handler)
    end

    if args.css then
        self:apply_css(args.css)
    end

    if args.icons then
        self:add_icons(args.icons)
    end

    self.on_startup = function()
        if args.main then
            args.main()
        end

        self:register()
        self:register_dbus()

        if args.hold then
            self:hold()
        end
    end

    self:run(arg)
end

---@type AstalLua.ApplicationGtk3
local app = ApplicationGtk3()

return app
