require "xlog"
require "xcmd"
require "xclass"
require "xclients"
require "xpackage"
require "xparser"

local log = xlog("xsession")

xsession = xclass
{
	__parent = xclients,
	
	__create = function (self, remote, request)
		if remote.session then
			remote.session:leave(remote)
		end
		
		self = xclients.__create(self)
		self.locked = false
		self.closed = false
		self.master = remote
		self.max_players = request.max_players
		self.password = request.password
		self.gamename = request.gamename
		self.justname, self.justpass = self.gamename:match('"(.-)"\9"(.-)"')
		self.mapname = request.mapname
		self.money = request.money
		self.fog_of_war = request.fog_of_war
		self.battlefield = request.battlefield
		self.clients[remote.id] = remote
		
		remote.log("info", "creating new room: name=%s, pass=%s", self.justname, self.justpass)
		remote.session = self
		remote:set_state("session", true)
		remote:set_state("master", true)
		
		xpackage(xcmd.USER_SESSION_CREATE, remote.id, 0)
			:write_byte(remote.states)
			:write_object(self, "4ss4b1",
				"max_players",
				"gamename",
				"mapname",
				"money",
				"fog_of_war",
				"battlefield")
			:broadcast(remote)
		
		if remote.rejoin then
			local invite = xpackage(xcmd.USER_SESSION_REJOIN, remote.id, 0)
			for _, client in ipairs(remote.rejoin) do
				if client ~= remote then
					invite:transmit(client)
				end
			end
		end
		remote.rejoin = nil
		
		return self
	end,
	
	message = function (self, remote, request)
		xpackage(xcmd.USER_SESSION_MSG, request.id_from, request.id_to)
			:write_string(request.message)
			:session_dispatch(remote)
	end,
	
	kill = function (self, remote)
		if self.master == remote and not self.closed then
			self:close(remote)
		end
		return self:leave(remote)
	end,
	
	join = function (self, remote, request)
		if remote.session then
			remote.session:leave(remote)
		end
		
		remote.log("info", "joining room: %s", self.justname)
		if self.locked then
			return remote.log("warn", "session locked")
		end
		if self:get_clients_count() == self.max_players then
			return remote.log("warn", "can not join, session is full")
		end
		
		self.clients[remote.id] = remote
		remote.session = self
		remote:set_state("session", true)
		
		return xpackage(xcmd.USER_SESSION_JOIN, remote.id, 0)
			:write("41",
				self.master.id,
				remote.states)
			:broadcast(remote)
	end,
	
	leave = function (self, remote)
		remote.log("info", "leaving room: %s", self.justname)
		
		local new_master
		if self.master == remote and self.closed then
			for _, client in pairs(self.clients) do
				if client == remote then
				elseif not new_master then
					new_master = client
					new_master.rejoin =
					{
						[1] = new_master,
					}
				else
					table.insert(new_master.rejoin, client)
				end
			end
		end
		
		local response = xpackage(xcmd.USER_SESSION_LEAVE, remote.id, 0)
			:write_boolean(self.master == remote)
		local function leave_client(client)
			client.session = nil
			client:set_state("played", false)
			client:set_state("session", false)
			self.clients[client.id] = nil
			response
				:write_object(client, "41",
					"id",
					"states")
		end
		if self.master == remote then
			remote:set_state("master", false)
			response
				:write_dword(self:get_clients_count())
			for _, client in pairs(self.clients) do
				leave_client(client)
			end
			log("debug", "destroying room: %s", self.justname)
			remote.server.sessions[remote.id] = nil
		else
			response
				:write_dword(1)
			leave_client(remote)
		end
		response:broadcast(remote)
		
		if not new_master then
			return
		end
		local clientlist = xparser("clientlist", "\0")
		for _, client in ipairs(new_master.rejoin) do
			clientlist:add("*", client.id)
		end
		local parser = xparser("", "\0")
			:add("gamename", self.gamename)
			:add("mapname", self.mapname)
			:add("master", new_master.id)
			:add("clients", #new_master.rejoin)
			:append(clientlist)
		parser:dump()
		return xpackage(xcmd.USER_SESSION_RECREATE, new_master.id, new_master.id)
			:write_parser_with_size(parser)
			:transmit(new_master)
	end,
	
	lock = function (self, remote, request)
		remote.log("info", "locking room: %s", self.justname)
		self.locked = true
		
		for _, info in ipairs(request.clients) do
			local client = self.clients[info.id]
			if client then
				client.team = info.team
			end
		end
		
		local response = xpackage(xcmd.USER_SESSION_LOCK, remote.id, 0)
			:write_dword(self:get_clients_count())
		for _, client in pairs(self.clients) do
			client:set_state("played", true)
			response
				:write_object(client, "41",
					"id",
					"states")
		end
		return response:broadcast(remote)
	end,
	
	info = function (self, remote, request)
		local response = xpackage(xcmd.USER_SESSION_INFO, self.master.id, 0)
			:write_object(self, "4ss4b1",
				"max_players",
				"gamename",
				"mapname",
				"money",
				"fog_of_war",
				"battlefield")
			:write_dword(self:get_clients_count())
		for _, client in pairs(self.clients) do
			response
				:write_object(client, "41",
					"id",
					"states")
		end
		return response:broadcast(remote)
	end,
	
	update = function (self, remote, request)
		remote.log("debug", "updating room: %s", self.justname)
		self.gamename = request.gamename
		self.justname, self.justpass = self.gamename:match('"(.-)"\9"(.-)"')
		self.mapname = request.mapname
		self.money = request.money
		self.fog_of_war = request.fog_of_war
		self.battlefield = request.battlefield
		return self:info(remote)
	end,
	
	client_update = function (self, remote, request)
		remote.log("info", "updating clients team: %d", request.team)
		for _, client in pairs(self.clients) do
			client.team = request.team
		end
		return xpackage(xcmd.USER_SESSION_CLIENT_UPDATE, remote.id, 0)
			:write_byte(remote.team)
			:broadcast(remote)
	end,
	
	close = function (self, remote)
		remote.log("info", "closing room: %s", self.justname)
		self.closed = true
		local response = xpackage(xcmd.USER_SESSION_CLOSE, remote.id, 0)
			:write("84",
				0,
				self:get_clients_count())
		for _, client in pairs(self.clients) do
			response
				:write_object(client, "44",
					"id",
					"score")
		end
		return response:session_broadcast(remote)
	end,
	
	kick = function (self, remote, request)
		if not self:check_client(request.id) then
			return
		end
		local client = self.clients[request.id]
		remote.log("info", "kicking user: %s", client.nickname)
		self:leave(client)
		return xpackage(xcmd.USER_SESSION_KICK, remote.id, 0)
			:write_dword(client.id)
			:transmit(remote)
	end,
	
	clscore = function (self, remote, request)
		if not self:check_client(request.id) then
			return
		end
		local client = self.clients[request.id]
		client.score = request.score
		return xpackage(xcmd.USER_SESSION_CLSCORE, remote.id, 0)
			:write_object(client, "44",
				"id",
				"score")
			:broadcast()
	end,
}
