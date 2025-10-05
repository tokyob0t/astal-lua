local astal = require("astal")

local Apps = astal.require("AstalApps")
local App = require("astal.gtk4.app")
local Widget = require("astal.gtk4.widget")
local Gdk = require("astal.gtk4").Gdk
local Variable = astal.Variable
local bind = astal.bind

local slice = require("lib").slice
local map = require("lib").map

local MAX_ITEMS = 8

local function hide()
	local launcher = App:get_window("launcher")
	if launcher then launcher:hide() end
end

local function AppButton(app)
	return Widget.Button({
		css_classes = { "AppButton" },
		on_clicked = function()
			hide()
			app:launch()
		end,
		Widget.Box({
			Widget.Image({ icon_name = app.icon_name, pixel_size = 48 }),
			Widget.Box({
				valign = "CENTER",
				vertical = true,
				Widget.Label({
					css_classes = { "name" },
					xalign = 0,
					ellipsize = "END",
					max_width_chars = 10,
					label = app.name,
				}),
				app.description and Widget.Label({
					css_classes = { "description" },
					xalign = 0,
					ellipsize = "END",
					max_width_chars = 30,
					label = app.description,
				}),
			}),
		}),
	})
end

return function()
	local apps = Apps.Apps()

	local text = Variable.new("")
	local list = bind(text):as(
		function(t) return slice(apps:fuzzy_query(t), 1, MAX_ITEMS) end
	)

	local on_enter = function()
		local found = apps:fuzzy_query(text:get())[1]
		if found then
			found:launch()
			hide()
		end
	end

	return Widget.Window({
		name = "launcher",
		anchor = { "TOP", "LEFT", "RIGHT", "BOTTOM" },
		exclusivity = "IGNORE",
		keymode = "ON_DEMAND",
		application = App,
		on_show = function() text:set("") end,
		on_hide = function() App:quit(0) end,
		on_key_pressed = function(self, keyval)
			if keyval == Gdk.KEY_Escape then self:hide() end
		end,
		Widget.Box({
			Widget.Box({
				hexpand = true,
				vexpand = true,
				on_button_pressed = hide,
				-- width_request = 4000,
			}),
			Widget.Box({
				hexpand = false,
				vertical = true,
				Widget.Box({ on_button_pressed = hide, height_request = 100 }),
				Widget.Box({
					vertical = true,
					width_request = 500,
					css_classes = { "Applauncher" },
					Widget.Entry({
						placeholder_text = "Search",
						on_changed = function(self) text:set(self.text) end,
						on_activate = on_enter,
					}),
					Widget.Box({
						spacing = 6,
						vertical = true,
						list:as(function(l) return map(l, AppButton) end),
					}),
					Widget.Box({
						halign = "CENTER",
						css_classes = { "not-found" },
						vertical = true,
						visible = list:as(function(l) return #l == 0 end),
						Widget.Image({
							icon_name = "system-search-symbolic",
							pixel_size = 96,
						}),
						Widget.Label({ label = "No match found" }),
					}),
				}),
				Widget.Box({
					vexpand = true,
					hexpand = true,
					on_button_pressed = hide,
				}),
			}),
			Widget.Box({
				-- width_request = 4000,
				hexpand = true,
				vexpand = true,
				on_button_pressed = hide,
			}),
		}),
	})
end
