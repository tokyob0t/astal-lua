require("astal.gtk3")
local astal = require("astal")

local AppLauncher = require("widget.Applauncher")
local src = require("lib").src

local scss = src("style.scss")
local css = "/tmp/style.css"

astal.exec("sass " .. scss .. " " .. css)

local App = require("astal.gtk3.app")

App:start({
	instance_name = "launcher",
	css = css,
	main = AppLauncher,
})
