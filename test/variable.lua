local Variable = require('astal.variable')
local astal = require('astal')
local await = astal.await
local async_read_file = require('astal.file').async_read_file

local brightness = '/sys/class/backlight/intel_backlight/brightness'

return function()
    local watchvar = Variable.new(0):watch(
        {
            'gio',
            'monitor',
            '/sys/class/backlight/intel_backlight/brightness',
        },
        await(function(prev)
            return tonumber(async_read_file(brightness))
        end)
    )

    local pollvar = Variable.new(0):poll(1000, function()
        return os.time()
    end)

    local observar = Variable.new(''):observe(pollvar, 'notify::value', function(_, value)
        print(value)
        return string.format('current value is: %s', tostring(value))
    end)

    observar:subscribe(function(value)
        print('observar:', value)
    end)
end
