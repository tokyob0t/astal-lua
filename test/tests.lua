local astal = require('astal')

local GLib = astal.require('GLib')

local loop = GLib.MainLoop.new()

local _file = require('test.file')
local _process = require('test.process')
local _variable = require('test.variable')

_file()
_process()
_variable()

loop:run()
