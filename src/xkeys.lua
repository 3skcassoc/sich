require "xlog"
require "xstore"

local log = xlog("xkeys")

local keystore = xstore.load("keys")
if keystore then
	local keys = {}
	for _, key in ipairs(keystore) do
		keys[key] = true
	end
	keystore = nil
	xkeys = function (cdkey)
		return keys[cdkey]
	end
else
	log("info", "disabled")
	xkeys = function (cdkey)
		return true
	end
end
