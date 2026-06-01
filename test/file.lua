local astal = require('astal')

local File = require('astal.file')

local async = astal.async

local benchmark = require('test.benchmark')

return function()
    benchmark("read_file('/var/log/pacman.log')", function(done)
        File.read_file('/var/log/pacman.log')

        done()
    end)

    benchmark("read_file_async('/var/log/pacman.log')", function(done)
        File.read_file_async('/var/log/pacman.log', function(contents)
            done()
        end)
    end)

    benchmark(
        "async_read_file('/var/log/pacman.log')",
        async(function(done)
            File.async_read_file('/var/log/pacman.log')
            done()
        end)
    )
end
