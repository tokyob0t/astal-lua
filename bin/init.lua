#!/usr/bin/env lua

local lgi = require('lgi')
local Gio = lgi.require('Gio')
local GLib = lgi.require('GLib')
local argparse = require('argparse')

local IFACE = 'io.Astal.Application'
local PATH = '/io/Astal/Application'

local function printerr(fmt, ...)
    io.stderr:write(('\27[31mError:\27[0m ' .. fmt .. '\n'):format(...))
end

---@return string[]
local function list_instances()
    local conn = Gio.bus_get_sync('SESSION')

    local response = conn:call_sync(
        'org.freedesktop.DBus',
        '/org/freedesktop/DBus',
        'org.freedesktop.DBus',
        'ListNames',
        GLib.Variant('()', {}),
        GLib.VariantType('(as)'),
        { 'NONE' },
        -1
    )

    local instances = {}
    local prefix = 'io.Astal.'
    for _, name in response.value[1]:ipairs() do
        if name:sub(1, #prefix) == prefix then
            table.insert(instances, name:sub(#prefix + 1))
        end
    end
    return instances
end

---@return boolean
local function is_running(name)
    for _, instance in ipairs(list_instances()) do
        if instance == name then
            return true
        end
    end
    return false
end

local function call_method(instance_name, method, args)
    local conn = Gio.bus_get_sync('SESSION')
    local name = string.format('io.Astal.%s', instance_name)
    local vtype = GLib.VariantType(method == 'Request' and '(s)' or '()')

    return conn:call_sync(name, PATH, IFACE, method, args, vtype, { 'NONE' }, -1)
end

local function main()
    local parser =
        argparse():name('astal-lua'):description('CLI for controlling Astal application instances.')

    parser:command('list'):summary('List active instances.')

    -- Startup Options
    local run = parser:command('run'):summary('Run an Astal application instance.'):description(
        'Starts a new Astal application by running the given Lua entry point file.'
    )

    run:argument('file', 'Entry point Lua file.', './init.lua')
    run:option('--lua-version', 'Specify Lua version to run.', 'jit'):argname('<ver>')
    run:flag('--gtk4', 'Use GTK4 layer-shell.')
    run:flag('--gdk-wayland', 'Use GDK backend Wayland.')
    run:flag('--nvidia', 'Use GBM backend NVIDIA.')
    run:flag('--vulkan', 'Force Vulkan renderer in GTK4.')

    -- Request Methods
    local request = parser
        :command('request')
        :summary('Send a request to a running Astal instance.')
        :description('Communicates with an already running Astal application instance over D-Bus.')

    request:argument('args', 'A list of arguments to send to Astal.Application.'):args('*')
    request
        :option('-i --instance', 'Instance name of the Astal.Application.', 'lua')
        :argname('<name>')
    request:option('-t --toggle-window', 'Show or hide a window.'):argname('<name>')
    request:flag('-q --quit', 'Quit a running instance.')
    request:flag('-I --inspector', 'Open GTK inspector/debug tool.')

    local args = parser:parse()

    local instance_name = args.instance

    if args.list then
        for _, inst in ipairs(list_instances()) do
            print(inst)
        end
        return 0
    end

    if args.run then
        if args.gtk4 then
            GLib.setenv('LD_PRELOAD', '/usr/lib/libgtk4-layer-shell.so')
        end

        if args.gdk_wayland then
            GLib.setenv('GDK_BACKEND', 'wayland,x11')
        end

        if args.nvidia then
            GLib.setenv('GBM_BACKEND', 'nvidia-drm')
        end

        if args.vulkan then
            GLib.setenv('GSK_RENDERER', 'vulkan')
        end

        return os.execute(string.format('lua%s %s', args.lua_version, args.file))
    end

    if args.request then
        if args.instance and not is_running(instance_name) then
            printerr("Instance '%s' is not running", instance_name)
            return 1
        end

        if args.inspector then
            call_method(instance_name, 'Inspector', GLib.Variant('()'))
        end

        if args.quit then
            call_method(instance_name, 'Quit', GLib.Variant('()'))
        end

        if args.toggle_window then
            call_method(instance_name, 'ToggleWindow', GLib.Variant('(s)', { args.toggle_window }))
        end

        if args.args then
            local variant =
                call_method(instance_name, 'Request', GLib.Variant('(as)', { args.args }))
            if variant then
                print(variant.value[1])
            else
                printerr("Instance '%s' did't give a response", instance_name)
                return 1
            end
        end

        return 0
    end
end

return os.exit(main())
