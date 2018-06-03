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
		self.socket = socket
		
		self.id = 0
		self.cid = -1
		self.team = 0
		self.states = 0
		self.vcore = 0
		self.vdata = 0
		self.pingtime = 0
		
		self.email = ""
		self.password = ""
		self.cdkey = ""
		self.nickname = ""
		self.country = ""
		self.info = ""
		self.score = 0
		self.games_played = 0
		self.games_win = 0
		self.last_game = 0
		self.banned = false
		
		self.score_updated = nil
		return self
	end,
	
	set_state = function (self, state, enabled)
		local index = assert(state_index[state], "invalid client state")
		local flag = math.pow(2, index)
		local update = false
		if enabled then
			update = (self.states % (2 * flag) < flag)
			if update then
				self.states = self.states + flag
			end
		else
			update = (self.states % (2 * flag) >= flag)
			if update then
				self.states = self.states - flag
			end
		end
		if update then
			self.log("debug", "state changed: %s=%s", state, tostring(enabled))
		end
	end,
	
	get_state = function (self, state)
		local index = assert(state_index[state], "invalid client state")
		local flag = math.pow(2, index)
		return self.states % (2 * flag) >= flag
	end,
}
