require "xlog"
require "xconfig"
require "xsocket"

local log = xlog("xecho")

local host = "*"
local port = 31523
local title = nil

if type(xconfig.echo) == "table" then
	host = xconfig.echo.host or host
	port = xconfig.echo.port or port
	title = xconfig.echo.title
end

if xconfig.echo == false then
	log("info", "disabled") 
else
	local echo_socket = assert(xsocket.udp())
	assert(echo_socket:setsockname(host or "*", port or 31523))
	log("info", "listening at udp:%s:%s", echo_socket:getsockname())
	xsocket.spawn(function ()
		while true do
			local msg, ip, port = echo_socket:receivefrom()
			if not msg then
				return log("warn", "closed")
			end
			log("debug", "got %q from %s:%s", msg, ip, port)
			echo_socket:sendto(title or VERSION, ip, port)
		end
	end)
end
