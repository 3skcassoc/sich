require "xlog"
require "xconst"
require "xkeys"
require "xclass"
require "xconfig"
require "xpacket"
require "xpackage"
require "xregister"
require "xclient"
require "xclients"
require "xsession"

local log = xlog("xserver")

local custom_core = xclass
{
	__parent = xclients,
	
	vcore = 0x00000000,
	vdata = 0x00000000,
	
	connected = function (self, remote)
		remote.server = self
	end,
	
	disconnected = function (self, remote)
		remote.server = nil
	end,
	
	process = function (self, remote, packet)
		local request = packet:parse(self.vcore, self.vdata)
		if not request then
			return
		end
		local code = request.code
		if not self[code] then
			return log("warn", "request is not allowed or not implemented: %s", xcmd.format(code))
		end
		return self[code](self, remote, request)
	end,
}

local server_core = xclass
{
	__parent = custom_core,
	
	__create = function (self, vcore, vdata)
		self = custom_core.__create(self)
		self.vcore = vcore
		self.vdata = vdata
		self.sessions = {}
		return self
	end,
	
	connected = function (self, remote)
		self.clients[remote.id] = remote
		remote.log = xlog("xclient", remote.nickname)
		remote:set_state("online", true)
		return custom_core.connected(self, remote)
	end,
	
	disconnected = function (self, remote)
		if remote.session then
			remote.session:leave(remote)
		end
		remote:set_state("online", false)
		self.clients[remote.id] = nil
		self:broadcast(
			xpackage(xcmd.USER_DISCONNECTED, remote.id, 0))
		return custom_core.disconnected(self, remote)
	end,
	
	check_session = function (self, remote)
		if not remote.session then
			remote.log("warn", "remote has no session")
			return false
		end
		return true
	end,
	
	check_session_master = function (self, remote)
		if not self:check_session(remote) then
			return false
		end
		if remote.session.master_id ~= remote.id then
			remote.log("debug", "remote is not session master")
			return false
		end
		return true
	end,
	
	session_action = function (self, action, remote, request)
		if not self:check_session(remote) then
			return
		end
		return remote.session[action](remote.session, remote, request)
	end,
	
	master_session_action = function (self, action, remote, request)
		if not self:check_session_master(remote) then
			return
		end
		return remote.session[action](remote.session, remote, request)
	end,
	
	get_server_clients = function (self, response)
		for _, client in pairs(self.clients) do
			response
				:write_object(client, "41sss",
					"id",
					"states",
					"nickname",
					"country",
					"info")
			if self.vdata >= 0x00020100 then
				response
					:write_object(client, "444td",
						"score",
						"games_played",
						"games_win",
						"last_game",
						"pingtime")
			end
		end
		response
			:write_dword(0)
	end,
	
	get_server_sessions = function (self, response)
		for _, session in pairs(self.sessions) do
			if not session.locked then
				response
					:write_object(session, "44ss4b1",
						"master_id",
						"max_players",
						"gamename",
						"mapname",
						"money",
						"fog_of_war",
						"battlefield")
					:write_objects(session.clients, "4",
						"id")
			end
		end
		response
			:write_dword(0)
	end,
	
	[xcmd.SERVER_CLIENTINFO] = function (self, remote, request)
		if not self:check_client(request.id) then
			return
		end
		local client = self.clients[request.id]
		local response = xpackage(xcmd.USER_CLIENTINFO, client.id, remote.id)
			:write_object(client, "41ss444ts",
				"id",
				"states",
				"nickname",
				"country",
				"score",
				"games_played",
				"games_win",
				"last_game",
				"info")
		if self.vdata >= 0x00020100 then
			response
				:write_object(client, "d",
					"pingtime")
		end
		return response
			:transmit(remote)
	end,
	
	[xcmd.SERVER_SESSION_MSG] = function (self, remote, request)
		return self:session_action("message", remote, request)
	end,
	
	[xcmd.SERVER_MESSAGE] = function (self, remote, request)
		xpackage(xcmd.USER_MESSAGE, request.id_from, request.id_to)
			:write("s", request.message)
			:dispatch(remote)
	end,
	
	[xcmd.SERVER_SESSION_CREATE] = function (self, remote, request)
		xsession(remote, request)
	end,
	
	[xcmd.SERVER_SESSION_JOIN] = function (self, remote, request)
		if not self.sessions[request.master_id] then
			return remote.log("debug", "no such session: %d", request.master_id)
		end
		return self.sessions[request.master_id]:join(remote, request)
	end,
	
	[xcmd.SERVER_SESSION_LEAVE] = function (self, remote, request)
		return self:session_action("leave", remote, request)
	end,
	
	[xcmd.SERVER_SESSION_LOCK] = function (self, remote, request)
		return self:master_session_action("lock", remote, request)
	end,
	
	[xcmd.SERVER_SESSION_INFO] = function (self, remote, request)
		return self:session_action("info", remote, request)
	end,
	
	[xcmd.SERVER_SESSION_UPDATE] = function (self, remote, request)
		return self:master_session_action("update", remote, request)
	end,
	
	[xcmd.SERVER_SESSION_CLIENT_UPDATE] = function (self, remote, request)
		return self:session_action("client_update", remote, request)
	end,
	
	[xcmd.SERVER_VERSION_INFO] = function (self, remote, request)
		return xpackage(xcmd.USER_VERSION_INFO, 0, remote.id)
			:write("vvq",
				self.vcore,
				self.vdata,
				null_parser)
			:transmit(remote)
	end,
	
	[xcmd.SERVER_SESSION_CLOSE] = function (self, remote, request)
		return self:master_session_action("close", remote, request)
	end,
	
	[xcmd.SERVER_GET_TOP_USERS] = function (self, remote, request)
		remote.log("debug", "get top users")
		local count = request.count
		local ids = {}
		local accounts = {}
		for id, account in register:pairs() do
			if not account.banned then
				ids[account] = id
				table.insert(accounts, account)
			end
		end
		table.sort(accounts, function (a, b)
			a = a.score * 10000 + a.games_win
			b = b.score * 10000 + b.games_win
			return a > b
		end)
		local mark = 1
		if self.vdata >= 0x00010306 then
			mark = 2
		end
		local response = xpackage(xcmd.USER_GET_TOP_USERS, remote.id, remote.id)
		for _, account in ipairs(accounts) do
			if count == 0 then
				break
			end
			count = count - 1
			response
				:write_byte(mark)
				:write_object(account, "ss444t",
					"nickname",
					"country",
					"score",
					"games_played",
					"games_win",
					"last_game")
			if mark >= 2 then
				response
					:write_dword(ids[account])
			end
		end
		return response
			:write_byte(0)
			:transmit(remote)
	end,
	
	[xcmd.SERVER_UPDATE_INFO] = function (self, remote, request)
		remote.log("info", "updating client info")
		remote.password = request.password
		remote.nickname = request.nickname
		remote.country = request.country
		remote.info = request.info
		register:update(remote)
		local response = xpackage(xcmd.USER_UPDATE_INFO, remote.id, 0)
			:write_object(remote, "sss1",
				"nickname",
				"country",
				"info",
				"states")
		if self.vdata >= 0x00020100 then
			response
				:write_object(remote, "444td",
					"score",
					"games_played",
					"games_win",
					"last_game",
					"pingtime")
		end
		return response
			:broadcast(remote)
	end,
	
	[xcmd.SERVER_SESSION_KICK] = function (self, remote, request)
		return self:master_session_action("kick", remote, request)
	end,
	
	[xcmd.SERVER_SESSION_CLSCORE] = function (self, remote, request)
		return self:master_session_action("clscore", remote, request)
	end,
	
	[xcmd.SERVER_SESSION_PARSER] = function (self, remote, request)
		if request.parser_id == xconst.parser.LAN_ROOM_SERVER_DATASYNC then
			self:master_session_action("datasync", remote, request)
		end
		return xpackage(xcmd.USER_SESSION_PARSER, request.id_from, request.id_to)
			:write_object(request, "4p",
				"parser_id",
				"parser")
			:write_dword(0)
			:session_dispatch(remote)
	end,
	
	[xcmd.SERVER_GET_SESSIONS] = function (self, remote, request)
		local response = xpackage(xcmd.USER_GET_SESSIONS, remote.id, remote.id)
		self:get_server_sessions(response)
		return response
			:transmit(remote)
	end,
	
	[xcmd.SERVER_PING_LOCK] = function (self, remote, request)
	end,
	
	[xcmd.SERVER_PING_UNLOCK] = function (self, remote, request)
	end,
	
	[xcmd.SERVER_CHECKSUM] = function (self, remote, request)
	end,
	
	[xcmd.LAN_PARSER] = function (self, remote, request)
		if request.parser_id == xconst.parser.LAN_GAME_SESSION_RESULTS
		or request.parser_id == xconst.parser.LAN_GAME_SURRENDER_CONFIRM then
			return self:master_session_action("results", remote, request)
		end
	end,
}

local function version_str(...)
	local count = select("#", ...)
	return xpack()
		:write(("v"):rep(count), ...)
		:reader()
		:read(("s"):rep(count))
end

servers = {}

local function get_server(vcore, vdata)
	local tag = ("%s/%s"):format(version_str(vcore, vdata))
	local server = servers[tag]
	if not server then
		log("debug", "creating new server: %s", tag)
		server = server_core(vcore, vdata)
		servers[tag] = server
	end
	return server
end

local auth_core = xclass
{
	__parent = custom_core,
	
	connected = function (self, remote)
		self.clients[remote] = true
		return custom_core.connected(self, remote)
	end,
	
	disconnected = function (self, remote)
		self.clients[remote] = nil
		return custom_core.disconnected(self, remote)
	end,
	
	try_user_auth = function (self, remote, request)
		-- 3 Incorrect Internet game key
		-- 4 (core) Your version is outdated. Do you want to update it automatically?
		-- 5 (data) Your version of the game is outdated. Please close the program to permit the automatic
		--   update service of your distribution platform to bring the game up to date.
		if not xkeys(request.cdkey) then
			remote.log("info", "invalid cd key")
			return 3
		end
		if request.code == xcmd.SERVER_REGISTER then
			-- 1 This e-mail is already in use
			-- 6 Incorrect registration data
			if not register:new(remote, request) then
				remote.log("error", "email is already in use: %s", request.email)
				return 1
			end
		else
			-- 1 Invalid password
			-- 2 This account is blocked
			if not register:get(remote, request.email) then
				remote.log("error", "email is not registered: %s", request.email)
				return 1
			elseif remote.banned then
				remote.log("info", "account is banned: %s", request.email)
				return 2
			elseif remote.password ~= request.password then
				remote.log("info", "incorrect password for: %s", request.email)
				return 1
			else
				for _, server in pairs(servers) do
					if server.clients[remote.id] then
						remote.log("info", "already logged in: %s", request.email)
						return 2
					end
				end
			end
		end
		return 0
	end,
	
	user_auth = function (self, remote, request)
		local response_code = (request.code == xcmd.SERVER_REGISTER) and xcmd.USER_REGISTER or xcmd.USER_AUTHENTICATE
		remote.log("debug", "auth: email=%s, vcore=%s, vdata=%s", request.email, version_str(request.vcore, request.vdata))
		
		local error_code = self:try_user_auth(remote, request)
		local response = xpackage(response_code, remote.id or 0, remote.id or 0)
			:write_byte(error_code)
		if error_code ~= 0 then
			return response
				:transmit(remote)
		end
		
		self:disconnected(remote)
		self = get_server(request.vcore, request.vdata)
		self:connected(remote)
		
		response
			:write_object(remote, "ss444ts",
				"nickname",
				"country",
				"score",
				"games_played",
				"games_win",
				"last_game",
				"info")
		
		self:get_server_clients(response)
		self:get_server_sessions(response)
		response
			:transmit(remote)
		
		response = xpackage(xcmd.USER_CONNECTED, remote.id, 0)
			:write_object(remote, "sss1",
				"nickname",
				"country",
				"info",
				"states")
		if self.vdata >= 0x00020100 then
			response
				:write_object(remote, "444td",
					"score",
					"games_played",
					"games_win",
					"last_game",
					"pingtime")
		end
		response
			:broadcast(remote)
		
		local message =
		{
			"%color(00DD00)%",
			VERSION,
			" powered by ",
			_VERSION,
			"%color(default)%"
		}
		xpackage(xcmd.USER_MESSAGE, 0, 0)
			:write("s", table.concat(message))
			:transmit(remote)
		
		return remote.log("info", "logged in")
	end,
	
	[xcmd.SERVER_REGISTER] = function (self, remote, request)
		return self:user_auth(remote, request)
	end,
	
	[xcmd.SERVER_AUTHENTICATE] = function (self, remote, request)
		return self:user_auth(remote, request)
	end,
	
	[xcmd.SERVER_USER_EXIST] = function (self, remote, request)
		return xpackage(xcmd.USER_USER_EXIST, 0, 0)
			:write("sb",
				request.email,
				register:exist(request.email))
			:transmit(remote)
	end,
	
	[xcmd.SERVER_FORGOT_PSW] = function (self, remote, request)
		local id, account = register:find(request.email)
		if not id then
			return
		end
		return remote.log("info", "user #%d forgot password, email=%s, password=%s", id, account.email, account.password)
	end,
}

auth_server = auth_core()

xserver = function (socket)
	local remote = xclient(socket)
	remote.log("info", "connected")
	auth_server:connected(remote)
	
	local server_process =
	{
		[xcmd.LAN_PARSER] = true,
	}
	while true do
		local packet = xpacket:receive(socket)
		if not packet then
			break
		end
		
		local code = packet.code
		local session = remote.session
		if 0x0190 <= code and code <= 0x01F4 then
			packet:dump_head(remote.log)
			remote.server:process(remote, packet)
		elseif session then
			if server_process[code] then
				remote.server:process(remote, packet)
			end
			
			local buffer = packet:get()
			local id_to = packet.id_to
			if id_to ~= 0 then
				local client = session.clients[id_to]
				if client then
					client.socket:send(buffer)
				end
			else
				for _, client in pairs(session.clients) do
					if client ~= remote then
						client.socket:send(buffer)
					end
				end
			end
		end
	end
	
	remote.server:disconnected(remote)
	remote.log("info", "disconnected")
	
	socket:close()
end
