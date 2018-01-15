require "xlog"
require "xclass"
require "xconfig"
require "xsocket"
require "xhard"
require "xcmdline"

local log = xlog("hardlink")

local function explode(str, pattern)
	local result = {}
	for sub in str:gmatch(pattern) do
		table.insert(result, sub)
	end
	return result
end

local function get_addr_2(str)
	local parts = explode(str, "[^:]+")
	local host, port = "*", nil
	if #parts == 1 then
		port = unpack(parts)
	elseif #parts == 2 then
		host, port = unpack(parts)
	else
		log("debug", "get_addr_2() failed on [%s]", str)
		return nil
	end
	return host, tonumber(port)
end

local function get_addr_4(str)
	local parts = explode(str, "[^:]+")
	local host1, port1, host2, port2 = "*", nil, "*", nil
	if #parts == 1 then
		port2 = unpack(parts)
		port1 = port2
	elseif #parts == 2 then
		host2, port2 = unpack(parts)
		port1 = port2
	elseif #parts == 3 then
		port1, host2, port2 = unpack(parts)
	elseif #parts == 4 then
		host1, port1, host2, port2 = unpack(parts)
	else
		log("debug", "get_addr_4() failed on [%s]", str)
		return nil
	end
	return host1, tonumber(port1), host2, tonumber(port2)
end

local function mpairs(...)
	local function loop(dst, src, ...)
		if not src then
			return ipairs(dst)
		end
		for _, value in ipairs(src) do
			table.insert(dst, value)
		end
		return loop(dst, ...)
	end
	return loop({}, ...)
end

local cmdline = xcmdline(arg)

local function usage(mode)
	log.minlevel = 0
	if not mode or mode == "server" then
		log("info", "usage: %s [-s|--server] [[host:]port]", cmdline.filename)
	end
	if not mode or mode == "client" then
		log("info", "usage: %s [-c|--client] [[host:]port] [port_forwarding]", cmdline.filename)
		log("info", "  port_forwarding: -D[host:]port -L[[[lhost:]lport:]rhost:]rport")
	end
end

local opt_help = cmdline:get("h", "help", true)
local opt_server = cmdline:get("s", "server", true)
local opt_client = cmdline:get("c", "client", true)
local opt_dynamic = cmdline:get("D", "dynamic", true)
local opt_local = cmdline:get("L", "local", true)

if opt_help then
	return usage()
end

local opt_mode = nil
if opt_server and opt_client then
	log("error", "requested both server and client mode")
	return usage()
elseif opt_server then
	opt_mode = "server"
elseif opt_client then
	opt_mode = "client"
end

local cfg = xconfig.hardlink or {}
local mode = opt_mode or cfg.mode

local unknown_args = {}
for name in pairs(cmdline.shorts) do
	table.insert(unknown_args, "-"..name)
end
for name in pairs(cmdline.longs) do
	table.insert(unknown_args, "--"..name)
end
for _, value in ipairs(cmdline.positionals) do
	table.insert(unknown_args, value)
end
if #unknown_args > 0 then
	log("error", "unknown args: %s", table.concat(unknown_args, ", "))
	return usage(opt_mode)
end

if mode == "server" then
	local cfg = xconfig.hardlink and xconfig.hardlink.server or {}
	local host, port = cfg.host, cfg.port
	
	if opt_server and opt_server[1] and opt_server[1] ~= "" then
		host, port = get_addr_2(opt_server[1])
	end
	
	if not host or not port then
		log("error", "server mode: no host:port")
		return usage(opt_mode)
	end
	
	log("debug", "server mode: %s:%s", host, port)
	xhard_server:start(host, port)
elseif mode == "client" then
	local cfg = xconfig.hardlink and xconfig.hardlink.client or {}
	local host, port = cfg.host, cfg.port
	
	if opt_client and opt_client[1] and opt_client[1] ~= "" then
		host, port = get_addr_2(opt_client[1])
	end
	
	if not host or not port then
		log("error", "client mode: no host:port")
		return usage(opt_mode)
	end
	
	log("debug", "client mode: %s:%s", host, port)
	local hard = xhard_client(nil, host, port)
	local ready = {}
	
	for _, addr in mpairs(opt_dynamic or {}, cfg["dynamic"] or {}) do
		local lhost, lport = get_addr_2(addr)
		if not lhost then
			return usage(opt_mode)
		end
		lhost = (lhost ~= "*") and lhost or "0.0.0.0"
		local hp = lhost .. "L" .. lport
		if ready[hp] then
			log("error", "[%s:%s] is already in use", lhost, lport)
			return
		end
		ready[hp] = true
		log("info", "dynamic forward: [%s:%s]", lhost, lport)
		hard:dynamic_forward(lhost, lport)
	end
	
	for _, addr in mpairs(opt_local or {}, cfg["local"] or {}) do
		local lhost, lport, rhost, rport = get_addr_4(addr)
		if not lhost then
			return usage(opt_mode)
		end
		lhost = (lhost ~= "*") and lhost or "0.0.0.0"
		rhost = (rhost ~= "*") and rhost or "127.0.0.1"
		local hp = lhost .. "L" .. lport
		if ready[hp] then
			log("error", "[%s:%s] is already in use", lhost, lport)
			return
		end
		ready[hp] = true
		log("info", "local forward: [%s:%s => %s:%s]", lhost, lport, rhost, rport)
		hard:local_forward(lhost, lport, rhost, rport)
	end
	
	if not next(ready) then
		log("error", "client mode: nothing to forward")
		return usage(opt_mode)
	end
else
	return usage()
end

xsocket.loop()
