---@diagnostic disable:undefined-field
---@diagnostic disable:type-not-found
---@diagnostic disable:redefined-local
---@diagnostic disable:unused

local lgi = require('lgi')
local Gtk = lgi.require('Gtk')
local Gio = lgi.require('Gio', '2.0')
local GLib = lgi.require('GLib', '2.0')
local GObject = lgi.require('GObject', '2.0')

local utils = require('astal._utils')

local DEFAULT_INSTANCE_NAME = 'lua'
local PATH = '/io/Astal/Application'

local IFACE_INFO = Gio.DBusInterfaceInfo {
    name = 'io.Astal.Application',
    methods = {
        Gio.DBusMethodInfo { name = 'Quit' },
        Gio.DBusMethodInfo { name = 'Inspector' },
        Gio.DBusMethodInfo {
            name = 'ToggleWindow',
            in_args = { Gio.DBusArgInfo { name = 'name', signature = 's' } },
        },
        Gio.DBusMethodInfo {
            name = 'ListWindows',
            out_args = { Gio.DBusArgInfo { name = 'out', signature = 'as' } },
        },
        Gio.DBusMethodInfo {
            name = 'Request',
            in_args = { Gio.DBusArgInfo { name = 'args', signature = 'as' } },
            out_args = { Gio.DBusArgInfo { name = 'out', signature = 's' } },
        },
    },
}

---@class AstalLua.ApplicationBase: Gtk.Application, GObject.Object
---@field monitors GLib.List<Gdk.Monitor>
---@field visible boolean
local Application = Gtk.Application:derive('AstalLua.ApplicationBase')

Application._attribute.instance_name = {
    set = function(self, instance_name)
        self.priv.instance_name = instance_name
    end,
    get = function(self)
        return self.priv.instance_name or DEFAULT_INSTANCE_NAME
    end,
}

Application.add_css_provider = utils.not_implemented('add_css_provider')
Application.remove_css_provider = utils.not_implemented('remove_css_provider')
Application.reset_css = utils.not_implemented('reset_css')
Application.add_icons = utils.not_implemented('add_icons')

---@param method string
---@param variant GLib.Variant<'s'> | GLib.Variant<'as'>
---@param response fun(signature?: string, ... )
function Application:handle_bus_call(method, variant, response)
    if method == 'ToggleWindow' then
        response()
        local name = variant:decode()[1]
        self:toggle_window(name)
    elseif method == 'ListWindows' then
        -- stylua: ignore start
        response('(as)', utils.map(self:get_windows(), function(window)
            if window.visible then
                return string.format('*%s', window.name)
            end

            return window.name
        end))
        -- stylua: ignore end
    elseif method == 'Inspector' then
        response()
        self:inspector()
    elseif method == 'Quit' then
        response()
        self:quit()
    elseif method == 'Request' then
        local request_args = variant:decode()[1]

        if #self.priv.request_handlers == 0 then
            return response('(s)', 'This app doesn\'t provide a request handler')
        end

        local handled = false

        for i = #self.priv.request_handlers, 1, -1 do
            self.priv.request_handlers[i](request_args, function(r)
                if not handled then
                    handled = true
                    response('(s)', tostring(r))
                end
            end)
        end
    end
end

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

            self:handle_bus_call(method, variant, function(signature, ...)
                if signature then
                    return callback:return_value(GLib.Variant(signature, { ... }))
                end

                callback:return_value()
            end)
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
    local w = assert(self:get_window(name), string.format('window not found: %s', name))

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

---@param fn fun(args: string[], callback: fun(response: string))
function Application:add_request_handler(fn)
    table.insert(self.priv.request_handlers, fn)
end

---@class AstalLua.ApplicationStartArgs
---@field instance_name? string
---@field main fun(args: string[]): any
---@field request_handler? fun(args: string[], response: fun(message: string, ...: string)): any
---@field hold? boolean
---@field icons? string
---@field icon_theme? string
---@field cursor_theme? string
---@field css? string

---@param args AstalLua.ApplicationStartArgs
function Application:start(args)
    self.application_id = string.format('io.Astal.%s', args.instance_name or 'lua')

    if args.hold == nil then
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

    self.on_activate = function()
        self:register()
        self:register_dbus()

        if args.hold then
            self:hold()
        end
    end

    self.on_command_line = function(_, command_line)
        local _args = command_line:get_arguments()

        if not command_line.is_remote then
            args.main(_args)
            self:activate()
        else
            for i = #self.priv.request_handlers, 1, -1 do
                self.priv.request_handlers[i](_args, function(r)
                    command_line:print_literal(tostring(r) .. '\n')
                    command_line:done()
                end)
            end
        end

        return 0
    end

    self:quit(self:run { table.unpack(arg, 0, #arg) })
end

function Application:quit(code)
    if type(code) ~= 'number' then
        code = 0
    end

    Gtk.Application.quit(self)
    os.exit(code)
end

return Application
