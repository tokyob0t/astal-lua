local lgi = require('lgi')

local Gtk = lgi.require('Gtk', '4.0')
local Gsk = lgi.require('Gsk', '4.0')
local Gdk = lgi.require('Gdk', '4.0')
local GLib = lgi.require('GLib', '2.0')
local GObject = lgi.require('GObject', '2.0')
local Graphene = lgi.require('Graphene', '1.0')

local TAU = math.pi * 2

local function normalize(x)
    return ((x % 1) + 1) % 1
end

local function to_radian(value)
    return value * TAU
end

local function scale_arc_value(start, finish, value)
    start = normalize(start)
    finish = normalize(finish)

    local arc_length = (finish - start) % 1

    return value * arc_length
end

local function point_on_arc(cx, cy, radius, angle)
    return cx + math.cos(angle) * radius, cy + math.sin(angle) * radius
end

local function is_full_circle(start, finish)
    return math.abs(normalize(start) - normalize(finish)) < 1e-10
end

---@class AstalLua.CircularProgress: Gtk.Widget
---@field start_at number
---@field end_at number
---@field value number
---@field inverted boolean
---@field rounded boolean
---@field thickness number
---@field child Gtk.Widget?
local CircularProgress = Gtk.Widget:derive('AstalLua.CircularProgress')

CircularProgress._property.start_at =
    GObject.param_spec_double('start_at', nil, nil, 0, 1, 0, { 'READWRITE', 'CONSTRUCT' })

CircularProgress._property.end_at =
    GObject.param_spec_double('end_at', nil, nil, 0, 1, 1, { 'READWRITE', 'CONSTRUCT' })

CircularProgress._property.value =
    GObject.param_spec_double('value', nil, nil, 0, 1, 0, { 'READWRITE', 'CONSTRUCT' })

CircularProgress._property.inverted =
    GObject.param_spec_boolean('inverted', nil, nil, false, { 'READWRITE', 'CONSTRUCT' })

CircularProgress._property.rounded =
    GObject.param_spec_boolean('rounded', nil, nil, true, { 'READWRITE', 'CONSTRUCT' })

CircularProgress._property.thickness =
    GObject.param_spec_int('thickness', nil, nil, 0, GLib.MAXINT32, 1, { 'READWRITE', 'CONSTRUCT' })

CircularProgress._property.child =
    GObject.param_spec_object('child', nil, nil, Gtk.Widget, { 'READWRITE' })

CircularProgress._property_set.child = function(self, child)
    if Gtk.Widget:is_type_of(child) then
        child:set_parent(self)
        self.priv.child = child
        self:notify('child')
    else
        self.priv.child = nil
        self:notify('child')
    end
end

function CircularProgress:do_measure(orientation, for_size)
    local ctx = self:get_style_context()
    local padding = ctx:get_padding()

    local pad = orientation == 'HORIZONTAL' and (padding.left + padding.right)
        or (padding.top + padding.bottom)

    local child = self.priv.child

    if not child then
        return 32 + pad, 64 + pad, -1, -1
    end

    local min, nat, minb, natb = child:measure(orientation, for_size)

    return min + pad, nat + pad, minb, natb
end

function CircularProgress:do_size_allocate(width, height, baseline)
    local child = self.priv.child

    if not child then
        return
    end

    local ctx = self:get_style_context()
    local padding = ctx:get_padding()

    local content_width = width - padding.left - padding.right

    local content_height = height - padding.top - padding.bottom

    local _, child_w = child:measure('HORIZONTAL', -1)
    local _, child_h = child:measure('VERTICAL', -1)

    child:size_allocate(
        Gdk.Rectangle {
            x = padding.left + (content_width - child_w) / 2,
            y = padding.top + (content_height - child_h) / 2,
            width = child_w,
            height = child_h,
        },
        baseline
    )
end

function CircularProgress:do_get_request_mode()
    return 'CONSTANT_SIZE'
end

function CircularProgress:do_snapshot(snapshot)
    local width = self:get_width()
    local height = self:get_height()

    local cr = snapshot:append_cairo(Graphene.Rect():init(0, 0, width, height))

    local ctx = self:get_style_context()

    local accent = ctx:lookup_color('accent_color')
    local track = ctx:lookup_color('borders')

    local bg_stroke = self.thickness + 2
    local fg_stroke = self.thickness

    local radius = math.min(width, height) / 2 - math.max(bg_stroke, fg_stroke) / 2

    local cx, cy = width / 2, height / 2

    local start_bg = to_radian(self.start_at)
    local end_bg = to_radian(self.end_at)

    local full_circle = is_full_circle(self.start_at, self.end_at)

    if full_circle then
        end_bg = start_bg + TAU
    end

    local value = math.max(0, math.min(1, self.value))

    local ranged_value = full_circle and (value * TAU)
        or to_radian(scale_arc_value(self.start_at, self.end_at, value))

    local start_progress = self.inverted and (end_bg - ranged_value) or start_bg

    local end_progress = self.inverted and end_bg or (start_bg + ranged_value)

    local has_progress = value > 0.001
    local is_full_progress = value >= 0.999

    --
    -- Track
    --
    cr:set_source_rgba(track.red, track.green, track.blue, track.alpha)

    if full_circle then
        cr:arc(cx, cy, radius, 0, TAU)
    else
        cr:arc(cx, cy, radius, start_bg, end_bg)
    end

    cr:set_line_width(bg_stroke)
    cr:stroke()

    --
    -- Progress
    --
    if has_progress then
        cr:set_source_rgba(accent.red, accent.green, accent.blue, accent.alpha)

        if full_circle and is_full_progress then
            cr:arc(cx, cy, radius, 0, TAU)
        else
            cr:arc(cx, cy, radius, start_progress, end_progress)
        end

        cr:set_line_width(fg_stroke)
        cr:stroke()

        --
        -- Rounded caps
        --
        if self.rounded and not is_full_progress then
            local sx, sy = point_on_arc(cx, cy, radius, start_progress)

            local ex, ey = point_on_arc(cx, cy, radius, end_progress)

            cr:arc(sx, sy, fg_stroke / 2, 0, TAU)
            cr:fill()

            cr:arc(ex, ey, fg_stroke / 2, 0, TAU)
            cr:fill()
        end
    end

    local child = self.priv.child

    if child then
        self:snapshot_child(child, snapshot)
    end
end

function CircularProgress:do_dispose()
    if self.priv.child then
        self.priv.child:unparent()
        self.priv.child = nil
    end

    Gtk.Widget.do_dispose(self)
end

return CircularProgress
