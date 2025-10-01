require("astal.gtk3")
local astal = require("astal")

local Bar = require("widget.Bar")
local src = require("lib").src

local scss = src("style.scss")
local css = "/tmp/style.css"

astal.exec("sass " .. scss .. " " .. css)

local App = require("astal.gtk3.app")

App:start({
	instance_name = "lua",
	css = css,
	request_handler = function(args, res)
		print(table.unpack(args))
		res("ok")
	end,
	main = function()
		for _, mon in pairs(App.monitors) do
			Bar(mon)
		end
	end,
})
