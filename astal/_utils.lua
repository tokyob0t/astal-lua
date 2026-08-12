local M = {}

function M.kebabify(s)
    return (string.gsub(s, '_', '-'))
end

function M.normalize_keys(tbl)
    local copy = {}

    -- normalize props just in case we're using fennel :3
    for key, value in pairs(tbl) do
        copy[key:gsub('-', '_')] = value
    end

    return copy
end

function M.filter(tbl, fn)
    local copy = {}
    for key, value in pairs(tbl) do
        if fn(value, key) then
            if type(key) == 'number' then
                table.insert(copy, value)
            else
                copy[key] = value
            end
        end
    end
    return copy
end

function M.map(tbl, fn)
    local copy = {}
    for key, value in pairs(tbl) do
        copy[key] = fn(value)
    end
    return copy
end

function M.flatten(tbl)
    local copy = {}
    for _, value in pairs(tbl) do
        if type(value) == 'table' and getmetatable(value) == nil then
            for _, inner in pairs(M.flatten(value)) do
                table.insert(copy, inner)
            end
        else
            table.insert(copy, value)
        end
    end
    return copy
end

function M.includes(tbl, elem)
    for _, value in pairs(tbl) do
        if value == elem then
            return true
        end
    end
    return false
end

function M.merge_bindings(array)
    local bind = require('astal.binding')
    local Variable = require('astal.variable')

    local function get_values(...)
        local args = { ... }
        local i = 0
        return M.flatten(M.map(array, function(value)
            if bind:is_type_of(value) then
                i = i + 1
                return args[i]
            else
                return value
            end
        end))
    end

    local bindings = M.filter(array, function(v)
        return bind:is_type_of(v)
    end)

    if #bindings == 0 then
        return array
    end

    if #bindings == 1 then
        return bindings[1]:as(get_values)
    end

    return bind(Variable.derive(bindings, get_values))
end

function M.ensure_widgets(children)
    local lgi = require('lgi')

    local Gtk = lgi.Gtk
    local GObject = lgi.GObject

    return M.map(
        M.filter(M.flatten(children), function(item)
            return not not item
        end),
        function(item)
            if Gtk.Widget:is_type_of(item) or GObject.Object:is_type_of(item) then
                return item
            end
            return Gtk.Label {
                visible = true,
                label = tostring(item),
            }
        end
    )
end

local primitive = {
    BOOLEAN = 'get_boolean',
    BYTE = 'get_byte',

    INT16 = 'get_int16',
    UINT16 = 'get_uint16',

    INT32 = 'get_int32',
    UINT32 = 'get_uint32',

    INT64 = 'get_int64',
    UINT64 = 'get_uint64',

    DOUBLE = 'get_double',

    STRING = 'get_string',
    OBJECT_PATH = 'get_string',
    SIGNATURE = 'get_string',
}

function M.decode_variant(v, depth, level)
    if type(v) ~= 'userdata' then
        return v
    end

    if not level then
        level = 0
    end

    if not depth then
        depth = math.huge
    end

    if level >= depth then
        return v
    end

    local class = v:classify()

    if primitive[class] then
        return v[primitive[class]](v)
    elseif class == 'MAYBE' then
        local child = v:get_maybe()
        return child and M.decode_variant(child, depth, level + 1) or nil
    elseif class == 'VARIANT' then
        return M.decode_variant(v:get_variant(), depth, level + 1)
    elseif class == 'DICT_ENTRY' then
        return {
            M.decode_variant(v:get_child_value(0), depth, level + 1),
            M.decode_variant(v:get_child_value(1), depth, level + 1),
        }
    elseif class == 'ARRAY' then
        local t = v:get_type_string()

        -- a{...}
        if t:sub(1, 2) == 'a{' then
            local out = {}

            for i = 0, v:n_children() - 1 do
                local entry = v:get_child_value(i)

                local k = M.decode_variant(entry:get_child_value(0), depth, level + 1)

                local val = M.decode_variant(entry:get_child_value(1), depth, level + 1)

                if k ~= nil and val ~= nil then
                    out[k] = val
                end
            end

            return out
        end

        local out = {}

        for i = 0, v:n_children() - 1 do
            local val = M.decode_variant(v:get_child_value(i), depth, level + 1)

            if val ~= nil then
                table.insert(out, val)
            end
        end

        return out
    elseif class == 'TUPLE' then
        local out = {}

        for i = 0, v:n_children() - 1 do
            out[#out + 1] = M.decode_variant(v:get_child_value(i), depth, level + 1)
        end

        return out
    end

    return v
end

---@param maybe_css string
---@return string
---@overload fun(maybe_css: table): string
function M.normalize_css(maybe_css)
    if type(maybe_css) == 'table' then
        local parts = {}

        for k, v in pairs(maybe_css) do
            table.insert(parts, M.kebabify(k) .. ':' .. v .. ';')
        end

        return '* { ' .. table.concat(parts, ' ') .. ' }'
    end

    maybe_css = maybe_css:gsub('^%s+', ''):gsub('%s+$', '')

    if maybe_css:find('{') and maybe_css:find('}') then
        return maybe_css
    end

    maybe_css = maybe_css:gsub(';+%s*$', '')

    return '* { ' .. maybe_css .. '; }'
end

function M.for_widget(key, each, render)
    if type(key) == 'nil' then
        key = function(item)
            return item
        end
    elseif type(key) == 'string' then
        local k = key
        key = function(item)
            return item[k]
        end
    end

    local cache = {}

    return each:as(function(items)
        local next_cache = {}
        local output = {}

        for i, item in ipairs(items) do
            local k = key(item, i)

            local child = cache[k]
            if not child then
                child = render(item)
            end

            next_cache[k] = child
            output[#output + 1] = child
        end

        cache = next_cache

        return output
    end)
end

return M
