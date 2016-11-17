require "xlog"
require "xconfig"
require "xserver"
require "xsocket"
require "xadmin"
require "xecho"

local log = xlog("sich")

VERSION = VERSION or "Sich DEV"
log("info", "%s", VERSION)

local host = xconfig.host or "*"
local port = xconfig.port or 31523

local server_socket = assert(xsocket.tcp())
assert(server_socket:bind(host, port))
assert(server_socket:listen(32))
log("info", "listening at tcp:%s:%s", server_socket:getsockname())

xsocket.spawn(
	function ()
		while true do
			xsocket.spawn(
				function (client_socket)
					xserver(client_socket)
					client_socket:close()
				end,
				assert(server_socket:accept()))
		end
	end)

xsocket.loop()
