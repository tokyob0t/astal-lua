local astal = require("astal")
local Widget = require("astal.gtk3.widget")

local MprisPlayers = require("widget.MediaPlayer")
local src = require("lib").src

local scss = src("style.scss")
local css = "/tmp/style.css"

astal.exec("sass " .. scss .. " " .. css)

local App = require("astal.gtk3.app")

App:start({
	instance_name = "lua",
	css = css,
	main = function() Widget.Window({ MprisPlayers() }) end,
})
