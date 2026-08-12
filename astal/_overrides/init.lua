---@class GObject.Object
---@field protected priv table
---@field _name string
---@field _gtype unknown
---@field _property table
---@field _attribute table
---@field _property_set table
---@field on_notify table
---@field is_type_of fun(self: GObject.Object, instance: any): boolean

if table.unpack == nil then
    table.unpack = unpack
end

if table.pack == nil then
    table.pack = function(...)
        return {
            n = select('#', ...),
            ...,
        }
    end
end

require('astal._overrides.Gio')
require('astal._overrides.GLib')
