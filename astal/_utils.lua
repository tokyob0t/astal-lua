local Variable = require('astal.variable')
local bind = require('astal.binding')

local lgi = require('lgi')
local Gtk = lgi.Gtk
local GObject = lgi.GObject

local M = {}

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
    local function get_values(...)
        local args = { ... }
        local i = 0
        return M.map(array, function(value)
            if bind:is_type_of(value) then
                i = i + 1
                return args[i]
            else
                return value
            end
        end)
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
    return M.map(
        M.filter(M.flatten(children), function(item)
            return not not item
        end),
        function(item)
            if Gtk.Widget:is_type_of(item) or GObject.Object:is_type_of(item) then
                return item
            end
            return Gtk.Label({
                visible = true,
                label = tostring(item),
            })
        end
    )
end

return M
