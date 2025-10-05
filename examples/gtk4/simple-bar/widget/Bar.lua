local astal = require("astal")
local Widget = require("astal.gtk4.widget")
local Variable = require("astal.variable")
local GLib = astal.require("GLib")
local bind = astal.bind
local Mpris = astal.require("AstalMpris")
local Battery = astal.require("AstalBattery")
local Wp = astal.require("AstalWp")
local Network = astal.require("AstalNetwork")
local Tray = astal.require("AstalTray")
local Hyprland = astal.require("AstalHyprland")
local map = require("lib").map

local function SysTray()
	local tray = Tray.get_default()

	return Widget.Box({
		css_classes = { "SysTray" },
		bind(tray, "items"):as(function(items)
			return map(items, function(item)
				return Widget.MenuButton({
					tooltip_markup = bind(item, "tooltip_markup"),
					menu_model = bind(item, "menu-model"),
					action_group = bind(item, "action-group"):as(
						function(ag) return { "dbusmenu", ag } end
					),
					Widget.Image({
						gicon = bind(item, "gicon"),
					}),
				})
			end)
		end),
	})
end

local function FocusedClient()
	local hypr = Hyprland.get_default()
	local focused = bind(hypr, "focused-client")

	return Widget.Box({
		css_classes = { "Focused" },
		visible = focused,
		focused:as(
			function(client)
				return client
					and Widget.Label({
						label = bind(client, "title"):as(tostring),
					})
			end
		),
	})
end

local function Wifi()
	local network = Network.get_default()
	local wifi = bind(network, "wifi")

	return Widget.Box({
		visible = wifi:as(function(v) return v ~= nil end),
		wifi:as(
			function(w)
				return Widget.Image({
					tooltip_text = bind(w, "ssid"):as(tostring),
					css_classes = { "Wifi" },
					icon_name = bind(w, "icon-name"),
				})
			end
		),
	})
end

local function AudioSlider()
	local speaker = Wp.get_default().audio.default_speaker

	return Widget.Box({
		css_classes = { "AudioSlider" },
		width_request = 140,
		Widget.Image({
			icon_name = bind(speaker, "volume-icon"),
		}),
		Widget.Slider({
			hexpand = true,
			-- value = bind(speaker, "volume"),
			-- on_value_changed = function(self) speaker.volume = self.value end,
			setup = function(self)
				self:bind_property("value", speaker, "volume", "BIDIRECTIONAL")
			end,
		}),
	})
end

local function BatteryLevel()
	local bat = Battery.get_default()

	return Widget.Box({
		css_classes = { "Battery" },
		visible = bind(bat, "is-present"),
		Widget.Image({
			icon_name = bind(bat, "battery-icon-name"),
		}),
		Widget.Label({
			label = bind(bat, "percentage"):as(
				function(p) return tostring(math.floor(p * 100)) .. " %" end
			),
		}),
	})
end

local function Media()
	local player = Mpris.Player.new("spotify")

	return Widget.Box({
		css_classes = { "Media" },
		visible = bind(player, "available"),
		Widget.Image({
			css_classes = { "Cover" },
			valign = "CENTER",
			file = bind(player, "cover-art"),
		}),
		Widget.Label({
			label = bind(player, "metadata"):as(
				function()
					return (player.title or "")
						.. " - "
						.. (player.artist or "")
				end
			),
		}),
	})
end

local function Workspaces()
	local hypr = Hyprland.get_default()

	return Widget.Box({
		css_classes = { "Workspaces" },
		bind(hypr, "workspaces"):as(function(wss)
			table.sort(wss, function(a, b) return a.id < b.id end)

			return map(wss, function(ws)
				if not (ws.id >= -99 and ws.id <= -2) then -- filter out special workspaces
					return Widget.Button({
						css_classes = bind(hypr, "focused-workspace"):as(
							function(fw) return fw == ws and { "focused" } or {} end
						),
						on_clicked = function() ws:focus() end,
						label = bind(ws, "id"):as(
							function(v)
								return type(v) == "number"
										and string.format("%.0f", v)
									or v
							end
						),
					})
				end
			end)
		end),
	})
end

local function Time(format)
	local time = Variable.new(""):poll(
		1000,
		function() return GLib.DateTime.new_now_local():format(format) end
	)

	return Widget.Label({
		css_classes = { "Time" },
		on_destroy = function() time:drop() end,
		label = bind(time),
	})
end

return function(gdkmonitor)
	return Widget.Window({
		css_classes = { "Bar" },
		gdkmonitor = gdkmonitor,
		anchor = { "TOP", "LEFT", "RIGHT" },
		exclusivity = "EXCLUSIVE",
		Widget.CenterBox({
			Widget.Box({
				halign = "START",
				Workspaces(),
				FocusedClient(),
			}),
			Widget.Box({
				Media(),
			}),
			Widget.Box({
				halign = "END",
				SysTray(),
				Wifi(),
				AudioSlider(),
				BatteryLevel(),
				Time("%H:%M - %A %e."),
			}),
		}),
	})
end
