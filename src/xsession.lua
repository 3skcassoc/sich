require "xlog"
require "xconst"
require "xclass"
require "xclients"
require "xpackage"
require "xparser"
require "xsocket"

local log = xlog("xsession")

xsession = xclass
{
	__parent = xclients,
	
	__create = function (self, remote, request)
		if remote.session then
			remote.session:leave(remote)
		end
		
		self = xclients.__create(self)
		self.real_name = ""
		self.real_pass = ""
		self.locked = false
		self.closed = false
		self.server = remote.server
		self.master_id = remote.id
		self.max_players = request.max_players
		self.password = request.password
		self.gamename = request.gamename
		self:split_gamename()
		self.mapname = request.mapname
		self.money = request.money
		self.fog_of_war = request.fog_of_war
		self.battlefield = request.battlefield
		self.clients[remote.id] = remote
		
		self.score_updated = remote.score_updated or {}
		remote.score_updated = nil
		
		remote.log("info", "creating new room: name=%q, pass=%q", self.real_name, self.real_pass)
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
		
		return self
	end,
	
	split_gamename = function (self)
		local parts = {}
		for part in self.gamename:gmatch("[^\t]+") do
			part = part:match('^"(.*)"$') or part
			table.insert(parts, part)
		end
		if #parts >= 2 then
			self.real_name, self.real_pass = unpack(parts)
		end
	end,
	
	message = function (self, remote, request)
		xpackage(xcmd.USER_SESSION_MSG, request.id_from, request.id_to)
			:write("s", request.message)
			:session_dispatch(remote)
	end,
	
	join = function (self, remote)
		if remote.session then
			remote.session:leave(remote)
		end
		
		remote.log("info", "joining room: %s", self.real_name)
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
				self.master_id,
				remote.states)
			:broadcast(remote)
	end,
	
	leave = function (self, remote)
		local new_master = nil
		local new_clients = {}
		local is_master = (self.master_id == remote.id)
		
		if not is_master then
			remote:set_state("played", false)
			remote:set_state("session", false)
		else
			for _, client in pairs(self.clients) do
				client:set_state("played", false)
				client:set_state("session", false)
			end
			remote:set_state("master", false)
			
			if self.locked then
				if not self.closed then
					self:close(remote)
				end
				for _, client in pairs(self.clients) do
					if client == remote then
						--
					elseif not new_master then
						new_master = client
					else
						table.insert(new_clients, client)
					end
				end
			end
		end
		
		remote.log("info", "leaving room: %s", self.real_name)
		xpackage(xcmd.USER_SESSION_LEAVE, remote.id, 0)
			:write_boolean(is_master)
			:write_objects(is_master and self.clients or {remote}, "41",
				"id",
				"states")
			:broadcast(remote)
		
		remote.session = nil
		self.clients[remote.id] = nil
		if self:get_clients_count() == 0 then
			remote.log("info", "destroying room: %s", self.real_name)
			self.server.sessions[self.master_id] = nil
		end
		
		if new_master then
			remote.log("info", "new session master: %s", new_master.nickname)
			
			new_master.score_updated = self.score_updated
			xsocket.spawn(
				function ()
					xsocket.sleep(90.0)
					new_master.score_updated = nil
				end)
			
			local parser = xparser("", "\0")
			parser:add("gamename", self.gamename)
			parser:add("mapname", self.mapname)
			parser:add("master", new_master.id)
			parser:add("session", 0)
			parser:add("clients", 1 + #new_clients)
			local clientlist = parser:add("clientlist", "\0")
			clientlist:add("*", new_master.id)
			for _, client in ipairs(new_clients) do
				clientlist:add("*", client.id)
			end
			
			xpackage(xcmd.USER_SESSION_RECREATE, new_master.id, new_master.id)
				:write_parser_with_size(parser)
				:transmit(new_master)
			
			local rejoin = xpackage(xcmd.USER_SESSION_REJOIN, new_master.id, 0)
			for _, client in ipairs(new_clients) do
				rejoin:transmit(client)
			end
		end
	end,
	
	lock = function (self, remote, request)
		remote.log("info", "locking room: %s", self.real_name)
		self.locked = true
		
		for _, info in ipairs(request.clients) do
			local client = self.clients[info.id]
			if client then
				client.team = info.team
			end
		end
		
		for _, client in pairs(self.clients) do
			if client.cid == xgc.spectator_countryid then
				self.score_updated[client.id] = true
			end
			client:set_state("played", true)
		end
		
		return xpackage(xcmd.USER_SESSION_LOCK, remote.id, 0)
			:write_objects(self.clients, "41",
				"id",
				"states")
			:broadcast(remote)
	end,
	
	info = function (self, remote)
		return xpackage(xcmd.USER_SESSION_INFO, self.master_id, 0)
			:write_object(self, "4ss4b1",
				"max_players",
				"gamename",
				"mapname",
				"money",
				"fog_of_war",
				"battlefield")
			:write_objects(self.clients, "41",
				"id",
				"states")
			:broadcast(remote)
	end,
	
	update = function (self, remote, request)
		remote.log("debug", "updating room: %s", self.real_name)
		self.gamename = request.gamename
		self:split_gamename()
		self.mapname = request.mapname
		self.money = request.money
		self.fog_of_war = request.fog_of_war
		self.battlefield = request.battlefield
		return self:info(remote)
	end,
	
	client_update = function (self, remote, request)
		remote.log("debug", "updating client team: %d", request.team)
		remote.team = request.team
		return xpackage(xcmd.USER_SESSION_CLIENT_UPDATE, remote.id, 0)
			:write_byte(remote.team)
			:broadcast(remote)
	end,
	
	close = function (self, remote)
		remote.log("info", "closing room: %s", self.real_name)
		self.closed = true
		return xpackage(xcmd.USER_SESSION_CLOSE, remote.id, 0)
			:write("t", xsocket.gettime())
			:write_objects(self.clients, "44",
				"id",
				"score")
			:session_broadcast(remote)
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
			:broadcast(remote)
	end,
	
	datasync = function (self, remote, request)
		local parser_s = request.parser:get("s")
		if not parser_s then
			return
		end
		for str in parser_s:gmatch("[^|]+") do
			local parts = {}
			for sub in str:gmatch("[^,]+") do
				table.insert(parts, tonumber(sub))
			end
			if #parts == 5 then
				local id, cid, team, color, ready = unpack(parts)
				local client = self.clients[id]
				if client then
					client.cid = cid
				end
			end
		end
	end,
	
	results = function (self, remote, request)
		local save_register = false
		for _, node in request.parser:pairs() do
			local id = tonumber(node:get("id"))
			local res = tonumber(node:get("res"))
			if not id or not res then
				--
			elseif id == 0 or res == xgc.player_victorystate_none then
				--
			elseif self.score_updated[id] then
				--
			else
				local client = self.clients[id] or self.server.clients[id]
				if not client then
					client = {}
					if not register:get(client, id) then
						client = nil
					end
				end
				
				if not client then
					log("warn", "unknown client id: %d", id)
				else
					client.last_game = xsocket.gettime()
					client.games_played = client.games_played + 1
					if res == xgc.player_victorystate_win then
						client.games_win = client.games_win + 1
					end
					
					--[[
						win,%   score   rank
						 0          0   -2 Esquire
						40        800   -1 Esquire
						45        900    0 Esquire
						50.05    1001    1 Esquire
						55       1100    2 Nobleman
						57.5     1150    3 Knight
						61.5     1230    4 Baron
						65       1300    5 Viscount
						69       1380    6 Earl
						71.25    1425    7 Marquis
						73.75    1475    8 Duke
						80       1600    9 King
						95       1900   10 Emperor
					]]
					client.score = math.ceil(client.games_win / client.games_played * 2000.0)
					log("info", "updating score for %s: state=%s, played=%s, win=%s, score=%s", client.nickname,
						xgc.player_victorystate[res], client.games_played, client.games_win, client.score)
					
					register:update(client, true)
					save_register = true
					self.score_updated[id] = true
				end
			end
		end
		if save_register then
			register:save()
		end
	end,
}
