#!/usr/bin/env lua

local lgi = require('lgi')
local Gio = lgi.require('Gio', '2.0')
local GLib = lgi.require('GLib', '2.0')
local argparse = require('argparse')

require('astal._overrides')

local Instance = {
    name = 'astal-lua',
}

function Instance.list_instances()
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

function Instance:is_running()
    for _, instance in ipairs(self.list_instances()) do
        if instance == self.name then
            return true
        end
    end

    return false
end

---@param name string
---@param variant GLib.Variant
---@param return_type GLib.VariantType
function Instance:invoke_method(name, variant, return_type)
    local conn = Gio.bus_get_sync('SESSION')
    local instance_name = string.format('io.Astal.%s', self.name)

    return conn:call_sync(
        instance_name,
        '/io/Astal/Application',
        'io.Astal.Application',
        name,
        variant,
        return_type,
        { 'NONE' },
        -1
    )
end

---@param args string[]
function Instance:Request(args)
    return self:invoke_method('Request', GLib.Variant('(as)', { args }), GLib.VariantType('(s)'))
        :decode()[1]
end

function Instance:ListWindows()
    return self:invoke_method('ListWindows', GLib.Variant('()'), GLib.VariantType('(as)'))
        :decode()[1]
end

function Instance:ToggleWindow(name)
    return self:invoke_method('ToggleWindow', GLib.Variant('(s)', { name }), GLib.VariantType('()'))
        :decode()
end

function Instance:Inspector()
    return self:invoke_method('Inspector', GLib.Variant('()'), GLib.VariantType('()')):decode()
end

function Instance:Quit()
    return self:invoke_method('Quit', GLib.Variant('()'), GLib.VariantType('()')):decode()
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
    request:flag('-l --list-windows', 'List registered windows.')
    request:flag('-q --quit', 'Quit a running instance.')
    request:flag('-I --inspector', 'Open GTK inspector/debug tool.')

    -- local bundle = parser:command('bundle'):summary('Pack your project in a single file')

    local args = parser:parse()

    Instance.name = args.instance

    if args.list then
        for _, inst in ipairs(Instance.list_instances()) do
            io.stdout:write(inst .. '\n')
            io.stdout:flush()
        end

        return 0
    elseif args.run then
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
    elseif args.request then
        if not Instance:is_running() then
            io.stderr:write(string.format('Instance \'%s\' is not running', Instance.name))
            io.stderr:flush()
            return 1
        elseif args.inspector then
            Instance:Inspector()
            return 0
        elseif args.quit then
            Instance:Quit()
            return 0
        elseif args.toggle_window then
            Instance:ToggleWindow(args.toggle_window)
            return 0
        elseif args.list_windows then
            local windows = Instance:ListWindows()

            for _, win in ipairs(windows) do
                io.stdout:write(win .. '\n')
            end

            io.stdout:flush()

            return 0
        elseif args.args then
            local response = Instance:Request(args.args)

            if response then
                io.stdout:write(response .. '\n')
                io.stdout:flush()
                return 0
            else
                io.stderr:write(
                    string.format('Instance \'%s\' did\'t give a response', Instance.name)
                )
                return 1
            end
        end

        return 0
    end
end

return os.exit(main())
