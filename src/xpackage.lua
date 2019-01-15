require "xlog"
require "xconst"
require "xclass"
require "xpack"

local log = xlog("xpackage")

xpackage = xclass
{
	__parent = xpack,
	
	__create = function (self, code, id_from, id_to, buffer)
		self = xpack.__create(self, buffer)
		self.code = assert(code, "no code")
		self.id_from = assert(id_from, "no id_from")
		self.id_to = assert(id_to, "no id_to")
		return self
	end,
	
	get = function (self)
		local payload = self:get_buffer()
		return xpack()
			:write("4244", #payload, self.code, self.id_from, self.id_to)
			:write_buffer(payload)
			:get_buffer()
	end,
	
	transmit = function (self, client)
		self:dump_head(client.log)
		client.socket:send(self:get())
		return self
	end,
	
	broadcast = function (self, client)
		return client.server:broadcast(self)
	end,
	
	dispatch = function (self, client)
		return client.server:dispatch(self)
	end,
	
	session_broadcast = function (self, client)
		return client.session:broadcast(self)
	end,
	
	session_dispatch = function (self, client)
		return client.session:dispatch(self)
	end,
	
	dump_head = function (self, flog)
		flog = flog or log
		return flog("debug", "%s  from=%d to=%d",
			xcmd.format(self.code), self.id_from, self.id_to)
	end,
	
	dump_payload = function (self, flog)
		flog = flog or log
		if not flog:check("debug") then
			return
		end
		local pos = 1
		local buffer = self:get_buffer()
		while pos <= #buffer do
			local line = buffer:sub(pos, pos + 16 - 1)
			local hex = 
				line:gsub(".", function (c) return ("%02X "):format(c:byte()) end)
				..
				("   "):rep(#buffer - pos < 17 and 15 - (#buffer - pos) or 0)
			flog("debug", "%04X | %s %s| %s",
				pos - 1,
				hex:sub(1, 24),
				hex:sub(25),
				(line:gsub("[^\32-\126]", "?")))
			pos = pos + 16
		end
	end,
}
