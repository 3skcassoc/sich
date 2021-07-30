require "xlog"

local log = xlog("xversion")

xversion =
{
	sich = SICH_VERSION or "Sich DEV",
	lua = jit and jit.version or _VERSION,
	socket = (require "socket")._VERSION,
}

log("info", "%s, %s, %s", xversion.sich, xversion.lua, xversion.socket)
