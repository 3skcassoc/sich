require "xlog"
require "xstore"

local log = xlog("xkeys")

local keystore = xstore.load("keys")
if type(keystore) == "function" then
	xkeys = keystore
elseif type(keystore) == "table" then
	local keys = nil
	if #keystore == 0 then
		keys = keystore
	else
		keys = {}
		for _, key in ipairs(keystore) do
			keys[key] = true
		end
	end
	xkeys = function (cdkey, email)
		return keys[cdkey] and true or false
	end
else
	log("info", "disabled")
	xkeys = function (cdkey, email)
		return true
	end
end
keystore = nil
