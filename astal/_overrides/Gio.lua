local lgi = require('lgi')

local Gio = lgi.require('Gio', '2.0')

Gio.MenuItem._attribute.label = {
    set = function(self, label)
        Gio.MenuItem.set_label(self, label)
    end,
}

Gio.MenuItem._attribute.icon = {
    set = function(self, icon)
        Gio.MenuItem.set_icon(self, icon)
    end,
}

Gio.MenuItem._attribute.action = {
    set = function(self, action)
        Gio.MenuItem.set_detailed_action(self, action)
    end,
}

Gio.MenuItem._attribute.action_and_target_value = {
    set = function(self, v)
        local action = v[1]
        local target_value = v[2]

        Gio.MenuItem.set_action_and_target_value(self, action, target_value)
    end,
}

Gio.MenuItem._attribute.attribute_value = {
    set = function(self, pair)
        local attribute = pair[1]
        local value = pair[2]

        Gio.MenuItem.set_attribute_value(self, attribute, value)
    end,
}

Gio.MenuItem._attribute.section = {
    set = function(self, section)
        Gio.MenuItem.set_section(self, section)
    end,
}

Gio.MenuItem._attribute.submenu = {
    set = function(self, submenu)
        Gio.MenuItem.set_submenu(self, submenu)
    end,
}

Gio.MenuItem._attribute.link = {
    set = function(self, pair)
        local link = pair[1]
        local model = pair[2]

        Gio.MenuItem.set_link(self, link, model)
    end,
}

function Gio.MenuItem:_container_add(child)
    if Gio.Menu:is_type_of(child) then
        return self:set_submenu(child)
    end
end

function Gio.Menu:_container_add(child)
    if Gio.MenuItem:is_type_of(child) then
        return self:append_item(child)
    elseif Gio.Menu:is_type_of(child) then
        return self:append_section(nil, child)
    end
end

function Gio.SimpleActionGroup:_container_add(child)
    if Gio.Action:is_type_of(child) then
        self:insert(child)
    elseif Gio.ActionEntry:is_type_of(child) then
        self:add_entries { child }
    end
end
