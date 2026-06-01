local astal = require('astal')
local async = astal.async

local Process = require('astal.process')

local benchmark = require('test.benchmark')

return function()
    benchmark("exec('cat /var/log/pacman.log')", function(done)
        Process.exec('cat /var/log/pacman.log')

        done()
    end)

    benchmark("exec_async('cat /var/log/pacman.log')", function(done)
        Process.exec_async('cat /var/log/pacman.log', function(stdout, stderr)
            done()
        end)
    end)

    benchmark(
        "async_exec('cat /var/log/pacman.log')",
        async(function(done)
            Process.async_exec('cat /var/log/pacman.log')
            done()
        end)
    )
end
