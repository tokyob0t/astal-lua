local lgi = require('lgi')

local GLib = lgi.require('GLib')

local utils = require('astal._utils')

function GLib.Variant:decode(depth)
    return utils.decode_variant(self, depth)
end
