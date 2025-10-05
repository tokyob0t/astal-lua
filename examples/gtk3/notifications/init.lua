local astal = require("astal")

local NotificationPopups = require("notifications.NotificationPopups")
local src = require("lib").src

local scss = src("style.scss")
local css = "/tmp/style.css"

astal.exec("sass " .. scss .. " " .. css)

local App = require("astal.gtk3.app")

App:start({
	instance_name = "notifications",
	css = css,
	main = function()
		for _, mon in pairs(App.monitors) do
			NotificationPopups(mon)
		end
	end,
})
