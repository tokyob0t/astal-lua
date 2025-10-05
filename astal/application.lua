local lgi = require('lgi')
local Gtk = lgi.require('Gtk')
local Gio = lgi.require('Gio')
local GLib = lgi.require('GLib')
local GObject = lgi.require('GObject')

local DEFAULT_INSTANCE_NAME = 'lua'
local PATH = '/io/Astal/Application'

local IFACE_INFO = Gio.DBusInterfaceInfo({
    name = 'io.Astal.Application',
    methods = {
        Gio.DBusMethodInfo({ name = 'Quit' }),
        Gio.DBusMethodInfo({ name = 'Inspector' }),
        Gio.DBusMethodInfo({
            name = 'ToggleWindow',
            in_args = { Gio.DBusArgInfo({ name = 'name', signature = 's' }) },
        }),
        Gio.DBusMethodInfo({
            name = 'Request',
            in_args = { Gio.DBusArgInfo({ name = 'args', signature = 'as' }) },
            out_args = { Gio.DBusArgInfo({ name = 'out', signature = 's' }) },
        }),
    },
})

---@class AstalLua.ApplicationBase: Gtk.Application
---@field monitors Gdk.Monitor[]
local Application = Gtk.Application:derive('AstalLua.ApplicationBase')

Application._attribute.instance_name = {
    set = function(self, instance_name)
        self.priv.instance_name = instance_name
    end,
    get = function(self)
        return self.priv.instance_name or DEFAULT_INSTANCE_NAME
    end,
}

---@private
function Application:register_dbus()
    ---@type Gio.DBusConnection | { register_object: fun(self: Gio.DBusConnection, object_path: string, iface_info: Gio.DBusInterfaceInfo, skibidi_toilet: GObject.Closure ) }
    local connection = self:get_dbus_connection()

    connection:register_object(
        PATH,
        IFACE_INFO,
        GObject.Closure(function(...)
            local args = { ... }

            ---@type string, GLib.Variant, Gio.DBusMethodInvocation
            local method, variant, callback = table.unpack(args, 5, 7)

            if method == 'ToggleWindow' then
                self:toggle_window(variant[1])
                return callback:return_value()
            end

            if method == 'Inspector' then
                self:inspector()
                return callback:return_value()
            end

            if method == 'Quit' then
                callback:return_value()
                return self:quit()
            end

            if method == 'Request' then
                local request_args = {}

                local array = variant.value[1]

                for _, value in array:ipairs() do
                    table.insert(request_args, value)
                end

                if #self.priv.request_handlers == 0 then
                    return callback:return_value(
                        GLib.Variant('(s)', { "This app doesn't provide a request handler" })
                    )
                end

                for i = #self.priv.request_handlers, 1, -1 do
                    self.priv.request_handlers[i](request_args, function(r)
                        callback:return_value(GLib.Variant('(s)', { tostring(r) }))
                    end)
                end
            end
        end)
    )
end

---@param name string
---@return Gtk.Window?
function Application:get_window(name)
    for _, win in ipairs(self:get_windows()) do
        if win.name == name then
            return win
        end
    end
end

---@param name string
function Application:toggle_window(name)
    local w = assert(self:get_window(name))

    w.visible = not w.visible
end

function Application:inspector()
    Gtk.Window.set_interactive_debugging(true)
end

function Application:apply_css(style, reset)
    ---@type Gtk.CssProvider
    local provider = Gtk.CssProvider.new()

    provider.on_parsing_error = function(_, _, error)
        io.stderr:write(string.format('CSS Error: %s\n', error.message))
    end

    if reset then
        self:reset_css()
    end

    if GLib.file_test(style, 'EXISTS') then
        provider:load_from_path(style)
    elseif string.find(style, '^resource://') then
        style = style:gsub('^resource://', '')
        provider:load_from_resource(style)
    else
        provider:load_from_string(style)
    end

    self:add_css_provider(provider)
end

function Application:add_css_provider(provider)
    error("The method 'add_css_provider' must be overridden in a subclass", 2)
end

function Application:remove_css_provider(provider)
    error("The method 'remove_css_provider' must be overridden in a subclass", 2)
end

function Application:reset_css()
    error("The method 'reset_css' must be overridden in a subclass", 2)
end

---@param path string
function Application:add_icons(path)
    error("The method 'add_icons' must be overridden in a subclass", 2)
end

---@param fn fun(args: string[], callback: fun(response: string))
function Application:add_request_handler(fn)
    table.insert(self.priv.request_handlers, fn)
end

function Application:_init()
    self.flags = { 'HANDLES_COMMAND_LINE', 'IS_SERVICE' }
    self.priv.css_providers = {}
    self.priv.request_handlers = {}
end

---@class ApplicationStartArgs
---@field instance_name? string
---@field main function
---@field request_handler? fun(args: string[], response: fun(message: string, ...: string))
---@field hold? boolean
---@field icons? string
---@field icon_theme? string
---@field cursor_theme? string
---@field css? string

---@param args ApplicationStartArgs
function Application:start(args)
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

    self:quit(self:run({ table.unpack(arg, 0, #arg) }))
end

function Application:quit(code)
    if type(code) ~= 'number' then
        code = 0
    end

    Gtk.Application.quit(self)
    os.exit(code)
end

return Application
