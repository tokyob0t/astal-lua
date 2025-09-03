local lgi = require('lgi')
---@type Astal
local Astal = lgi.require('Astal', '4.0')
---@type AstalIO
local AstalIO = lgi.require('AstalIO', '0.1')

---@class Application: Astal.Application
---@overload fun(): Application
local Application = Astal.Application:derive('AstalLuaApplication')
local request_handler

function Application:do_request(msg, conn)
    if type(request_handler) == 'function' then
        request_handler(msg, function(response)
            AstalIO.write_sock(conn, tostring(response), function(_, res)
                AstalIO.write_sock_finish(res)
            end)
        end)
    else
        Astal.Application.do_request(self, msg, conn)
    end
end

function Application:quit(code)
    Astal.Application.quit(self)
    os.exit(code)
end

---@class StartConfig
---@field icons? string
---@field instance_name? string
---@field gtk_theme? string
---@field icon_theme? string
---@field cursor_theme? string
---@field css? string
---@field hold? boolean
---@field request_handler? fun(msg: string, response: fun(res: any)): nil
---@field main? fun(...): nil
---@field client? fun(message: fun(msg: string): string, ...): nil

---@param config? StartConfig
function Application:start(config)
    config = config or {}

    config.client = config.client
        or function()
            print('Astal instance "' .. self.instance_name .. '" is already running')
            os.exit(1)
        end

    if config.hold == nil then
        config.hold = true
    end

    request_handler = config.request_handler

    if config.css then
        self:apply_css(config.css)
    end
    if config.icons then
        self:add_icons(config.icons)
    end

    for _, key in ipairs({ 'instance_name', 'gtk_theme', 'icon_theme', 'cursor_theme' }) do
        if config[key] then
            self[key] = config[key]
        end
    end

    self.on_activate = function()
        if type(config.main) == 'function' then
            config.main(table.unpack(arg))
        end
        if config.hold then
            self:hold()
        end
    end

    local _, err = self:acquire_socket()

    if err ~= nil then
        return config.client(function(msg)
            return AstalIO.send_request(self.instance_name, msg)
        end, table.unpack(arg))
    end

    self:run(nil)
end

local app = Application()

return app
