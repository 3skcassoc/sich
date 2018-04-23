require "xlog"
require "xclass"

local state_index =
{
	online = 0,
	session = 1,
	master = 2,
	played = 3,
}

xclient = xclass
{
	__create = function (self, socket)
		local host, port = socket:getpeername()
		self.log = xlog("xclient", host)
		self.log("debug", "creating new client")
		self.host = host
		self.port = port
		self.team = 0
		self.states = 0
		self.socket = socket
		return self
	end,
	
	set_state = function (self, state, enabled)
		local flag = math.pow(2, assert(state_index[state], "invalid client state"))
		if enabled then
			if self.states % (2 * flag) < flag then
				self.states = self.states + flag
			end
		else
			if self.states % (2 * flag) >= flag then
				self.states = self.states - flag
			end
		end
		self.log("debug", "state changed: %s=%s", state, tostring(enabled))
	end,
	
	get_state = function (self, state)
		local flag = math.pow(2, assert(state_index[state], "invalid client state"))
		return self.states % (2 * flag) >= flag
	end,
}
