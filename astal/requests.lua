local astal = require('astal')
local Soup = astal.require('Soup', '3.0')
local Gio = astal.require('Gio', '2.0')
local GLib = astal.require('GLib', '2.0')
local async, await = astal.async, astal.await

---@alias Requests.ResponseCtorArgs { url: string, status_code: number, ok: boolean, reason_phrase: string, text: string, bytes: GLib.Bytes, body:  Gio.InputStream }

---@class Requests.Response
---@field url string
---@field status_code number
---@field ok boolean
---@field reason_phrase string
---@field text string
---@field bytes GLib.Bytes
---@field body Gio.InputStream
---@overload fun(args: Requests.ResponseCtorArgs): Requests.Response
local Response = {}

Response.__index = Response

Response.__newindex = function(_, k)
    io.stderr:write(string.format("Requests.Response: '%s' property is read-only\n", k))
end

---@param args Requests.ResponseCtorArgs
Response.new = function(args)
    return setmetatable({
        url = args.url,
        status_code = args.status_code,
        ok = args.ok,
        reason_phrase = args.reason_phrase,
        text = args.text,
        bytes = args.bytes,
        body = args.body,
    }, Response)
end

-- function Response:json() return json.decode(self.text) end

---@param params table<string, any>
---@param parent_key string | nil
---@return string
local function encode_query_params(params, parent_key)
    local encoded_params = {}
    local encoded_val, encoded_key

    for key, value in pairs(params) do
        local full_key = parent_key and (parent_key .. '[' .. key .. ']') or key
        encoded_key = GLib.Uri.escape_string(tostring(full_key), nil, true)

        if type(value) == 'table' then
            table.insert(encoded_params, encode_query_params(value, full_key))
        else
            encoded_val = GLib.Uri.escape_string(tostring(value), nil, true)
            table.insert(encoded_params, encoded_key .. '=' .. encoded_val)
        end
    end
    return table.concat(encoded_params, '&')
end

---@class Requests
local Requests = {}

---@class RequestsRequestArgs
---@field url string
---@field params? table<string, any>
---@field headers? table<string, string> | { ["Content-Type"]: 'application/json' | 'text/plain' | 'application/x-www-form-urlencoded' }
---@field body? string

---@param method "GET" | "POST" | "PUT" | "DELETE" | "PATCH"
---@param args RequestsRequestArgs
---@return Requests.Response
function Requests.async_request(method, args)
    local session = Soup.Session.new()

    local content_type = 'text/plain'

    if args.params then
        args.url = string.format('%s?%s', args.url, encode_query_params(args.params))
    end

    local message = Soup.Message.new_from_uri(method, GLib.Uri.parse(args.url, 'NONE'))

    if args.headers then
        for header_name, header_value in pairs(args.headers) do
            if header_name == 'Content-Type' then
                content_type = header_name
            else
                message:get_request_headers():append(header_name, header_value)
            end
        end
    end

    if type(args.body) == 'string' then
        message:set_request_body_from_bytes(content_type, GLib.Bytes(args.body, #args.body))
    end

    local input_stream = session:async_send(message)
    local output_stream = Gio.MemoryOutputStream.new_resizable()

    output_stream:async_splice(input_stream, { 'CLOSE_SOURCE', 'CLOSE_TARGET' })

    local bytes = output_stream:steal_as_bytes()

    return Response.new({
        body = input_stream,
        text = bytes:get_data(bytes:get_size()),
        bytes = bytes,
        url = args.url,
        status_code = message.status_code,
        ok = message.status_code >= 200 and message.status_code < 300,
        reason_phrase = message.reason_phrase,
    })
end

Requests.request_async = async(
    ---@param method "GET" | "POST" | "PUT" | "DELETE" | "PATCH"
    ---@param args RequestsRequestArgs
    ---@param callback fun(res: Requests.Response)
    function(method, args, callback)
        callback(Requests.async_request(method, args))
    end
)

---@param method "GET" | "POST" | "PUT" | "DELETE" | "PATCH"
---@param args RequestsRequestArgs
---@return Requests.Response
Requests.request = await(function(method, args)
    return Requests.async_request(method, args)
end)

---@param args RequestsRequestArgs
Requests.async_get = function(args)
    return Requests.async_request('GET', args)
end

---@param args RequestsRequestArgs
Requests.get_async = async(function(args, callback)
    return callback(Requests.async_get(args))
end)

---@param args RequestsRequestArgs
Requests.get = await(function(args)
    return Requests.async_get(args)
end)

---@param args RequestsRequestArgs
Requests.async_post = function(args)
    return Requests.async_request('POST', args)
end

---@param args RequestsRequestArgs
Requests.async_put = function(args)
    return Requests.async_request('PUT', args)
end

---@param args RequestsRequestArgs
Requests.async_delete = function(args)
    return Requests.async_request('DELETE', args)
end

---@param args RequestsRequestArgs
Requests.async_patch = function(args)
    return Requests.async_request('PATCH', args)
end

return Requests
