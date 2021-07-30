require "xversion"
require "xlog"
require "xconfig"
require "xserver"
require "xsocket"
require "xadmin"
require "xecho"

local log = xlog("sich")

local host = xconfig.host or "*"
local port = xconfig.port or 31523

local server_socket = assert(xsocket.tcp())
assert(server_socket:bind(host, port))
assert(server_socket:listen(32))
log("info", "listening at %s", tostring(server_socket))

xsocket.spawn(
	function ()
		while true do
			xsocket.spawn(xserver, assert(server_socket:accept()))
		end
	end)

xsocket.loop()
