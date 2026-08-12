---@diagnostic disable:undefined-field
---@diagnostic disable:type-not-found
---@diagnostic disable:redefined-local

local lgi = require('lgi')

---@type Gtk
local Gtk = lgi.require('Gtk', '4.0')

local construct = require('astal._construct')

local config = require('astal._props')
local utils = require('astal._utils')

local dummy_builder = Gtk.Builder.new()

local set_children = {}
local get_children = {}
local css_providers = {}

local lookup_children = {
    __index = function(t, k)
        for _, v in ipairs(t) do
            if v.name == k then
                return v
            end
        end
    end,
}

local env = config {
    -- must include
    set_children = function(self, children)
        local ok = pcall(function()
            return self.remove ~= nil
        end)

        if ok then
            for _, ch in ipairs(get_children[self._name](self)) do
                self:remove(ch)

                if not utils.includes(children, ch) and not ch.no_implicit_destroy then
                    ch:run_dispose()
                end
            end
        else
            for _, ch in ipairs(get_children[self._name](self)) do
                ch:unparent()

                if not utils.includes(children, ch) and not ch.no_implicit_destroy then
                    ch:run_dispose()
                end
            end
        end

        set_children[self._name](self, utils.ensure_widgets(children))
    end,
    get_children = function(self)
        return setmetatable(get_children[self._name](self), lookup_children)
    end,
    set_css = function(self, css)
        local ctx = self:get_style_context()

        if not css_providers[self] then
            css_providers[self] = Gtk.CssProvider.new()
        end

        css_providers[self]:load_from_string(utils.normalize_css(css))

        ctx:add_provider(css_providers[self], Gtk.STYLE_PROVIDER_PRIORITY_USER)
    end,
    get_css = function(self)
        if css_providers[self] then
            return css_providers[self]:to_string()
        end
        return ''
    end,
    set_class_name = function(self, class_name)
        local names = {}
        for word in class_name:gmatch('%S+') do
            table.insert(names, word)
        end
        self.css_classes = names
    end,
    get_class_name = function(self)
        return table.concat(self.css_classes, ' ')
    end,
    toggle_css_class = function(self, css_class, condition)
        if condition then
            self:add_css_class(css_class)
        else
            self:remove_css_class(css_class)
        end
    end,
}

local do_set_children = function(self, children)
    for _, ch in ipairs(children) do
        if Gtk.Widget:is_type_of(ch) then
            self:do_add_child(dummy_builder, ch, ch.type)
        else
            io.stderr:write(
                'Couldn\'t add children of type ' .. tostring(ch) .. ' to' .. tostring(self)
            )
            io.stderr:flush()
        end
    end
end

local do_get_children = function(self)
    local ok = pcall(function()
        return self.get_child ~= nil
    end)

    if ok then
        return { self:get_child() }
    end

    local children = {}
    local ch = self:get_first_child()

    while ch do
        table.insert(children, ch)
        ch = ch:get_next_sibling()
    end

    return children
end

---@generic T: Gtk.Widget
---@param ctor    T
---@param config? { set_children?: fun(self: T, children: Gtk.Widget[]), get_children?: fun(self: T): Gtk.Widget[] }
---@return fun(args?: T | AstalLua.Astalified | AstalLua.EventControllerSignals | { setup: fun(self: T | AstalLua.Astalified) }): T | AstalLua.Astalified
return function(ctor, config)
    if config == nil then
        config = {}
    end

    set_children[ctor._name] = config.set_children or do_set_children
    get_children[ctor._name] = config.get_children or do_get_children

    for key, value in pairs(env) do
        ctor[key] = value

        local prefix, propname = key:match('^([gs]et)_(.+)$')

        if prefix then
            if not ctor._attribute[propname] then
                ctor._attribute[propname] = {}
            end

            ctor._attribute[propname][prefix] = value
        end
    end

    return function(...)
        return construct(ctor, ...)
    end
end
