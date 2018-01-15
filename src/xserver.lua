require "xlog"
require "xcmd"
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
	
	__create = function (self)
		self = xclients.__create(self)
		self.sessions = {}
		return self
	end,
	
	connected = function (self, remote)
		remote.server = self
	end,
	
	disconnected = function (self, remote)
		remote.server = nil
	end,
	
	process = function (self, remote, packet)
		local request, err = packet:parse()
		if not request then
			return log("error", "packet parse: %s", err)
		end
		
		if not self[request.code] then
			return log("warn", "request is not allowed or not implemented: [0x04X] %s", request.code, xcmd[request.code] or "UNKNOWN")
		end
		return self[request.code](self, remote, request)
	end,
}

local cores = {}

cores["1.0.0.7"] = xclass
{
	__parent = custom_core,
	
	connected = function (self, remote)
		self.clients[remote.id] = remote
		remote:set_state("online", true)
		return custom_core.connected(self, remote)
	end,
	
	disconnected = function (self, remote)
		if remote.session then
			remote.session:kill(remote)
		end
		remote:set_state("online", false)
		self.clients[remote.id] = nil
		self:broadcast(
			xpackage(xcmd.USER_DISCONNECTED, remote.id, 0))
		return custom_core.disconnected(self, remote)
	end,
	
	check_session = function (self, remote)
		if remote.session then
			return true
		end
		remote.log("warn", "remote has no session")
		return false
	end,
	
	check_session_master = function (self, remote)
		if not self:check_session(remote) then
			return false
		end
		if remote.session.master == remote then
			return true
		end
		remote.log("debug", "remote is not session master")
		return false
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
	
	[xcmd.SERVER_CLIENTINFO] = function (self, remote, request)
		if not self:check_client(request.id) then
			return
		end
		return xpackage(xcmd.USER_CLIENTINFO, 0, 0)
			:write_object(self.clients[request.id], "41ss4448s",
				"id",
				"states",
				"nickname",
				"country",
				"score",
				"games_played",
				"games_win",
				"last_game",
				"info")
			:transmit(remote)
	end,
	
	[xcmd.SERVER_SESSION_MSG] = function (self, remote, request)
		return self:session_action("message", remote, request)
	end,
	
	[xcmd.SERVER_MESSAGE] = function (self, remote, request)
		xpackage(xcmd.USER_MESSAGE, request.id_from, request.id_to)
			:write_string(request.message)
			:dispatch(remote)
	end,
	
	[xcmd.SERVER_SESSION_CREATE] = function (self, remote, request)
		self.sessions[remote.id] = xsession(remote, request)
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
		return xpackage(xcmd.USER_VERSION_INFO, 0, 0)
			:write("ss4",
				remote.vcore,
				remote.vdata,
				0)
			:transmit(remote)
	end,
	
	[xcmd.SERVER_SESSION_CLOSE] = function (self, remote, request)
		return self:master_session_action("close", remote, request)
	end,
	
	[xcmd.SERVER_GET_TOP_USERS] = function (self, remote, request)
		remote.log("debug", "get top users")
		local count = request.count
		local response = xpackage(xcmd.USER_GET_TOP_USERS, 0, 0)
		for _, client in pairs(self.clients) do
			if count == 0 then
				break
			end
			count = count - 1
			response
				:write_byte(1)
				:write_object(client, "ss4448",
					"nickname",
					"country",
					"score",
					"games_played",
					"games_win",
					"last_game")
		end
		return response
			:write_byte(0)
			:transmit(remote)
	end,
	
	[xcmd.SERVER_UPDATE_INFO] = function (self, remote, request)
		xregister.update(remote,
			remote.email,
			request.password,
			request.nickname,
			request.country,
			request.info)
		return xpackage(xcmd.USER_UPDATE_INFO, remote.id, 0)
			:write_object(remote, "sss1",
				"nickname",
				"country",
				"info",
				"states")
			:broadcast(remote)
	end,
	
	[xcmd.SERVER_SESSION_KICK] = function (self, remote, request)
		return self:master_session_action("kick", remote, request)
	end,
	
	[xcmd.SERVER_SESSION_CLSCORE] = function (self, remote, request)
		return self:master_session_action("clscore", remote, request)
	end,
}

servers = {}
local defcore = "1.0.0.7"
local datas = xconfig.datas or {}

local function get_server(vcore, vdata)
	if not cores[vcore] then
		vcore = defcore
	end
	if datas[vdata] then
		vdata = datas[vdata]
	end
	local tag = vcore .. "/" .. vdata
	local server = servers[tag]
	if not server then
		log("debug", "creating new server: %s", tag)
		server = cores[vcore]()
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
		if not xkeys(request.cdkey) then
			remote.log("info", "invalid cd key")
			return 3
		end
		if not cores[request.vcore] then
			-- 4 core version is outdated
			remote.log("warn", "requested unknown core version: %s", request.vcore)
		end
		if not datas[request.vdata] then
			-- 5 data version is outdated
			remote.log("debug", "requested unknown data version: %s", request.vdata)
		end
		if request.code == xcmd.SERVER_REGISTER then
			-- 6 incorrect registration data
			if not xregister.new(remote, request.email, request.password, request.cdkey, request.nickname, request.country, request.info) then
				remote.log("info", "email is already in use: %s", request.email)
				return 1
			end
		else
			if not xregister.get(remote, request.email) then
				remote.log("info", "email is not registered: %s", request.email)
				return 1
			elseif remote.blocked then
				remote.log("info", "account is blocked: %s", request.email)
				return 2
			elseif remote.password ~= request.password then
				remote.log("info", "incorrect password for: %s", request.email)
				return 1
			end
		end
		return 0
	end,
	
	user_auth = function (self, remote, request)
		local response_code = ( request.code == xcmd.SERVER_REGISTER ) and xcmd.USER_REGISTER or xcmd.USER_AUTHENTICATE
		local error_code = self:try_user_auth(remote, request)
		
		local response = xpackage(response_code, remote.id, 0)
			:write_byte(error_code)
		if error_code ~= 0 then
			return response:transmit(remote)
		end
		
		remote.log = xlog("xclient", remote.nickname)
		remote.vcore = request.vcore
		remote.vdata = request.vdata
		
		remote.server:disconnected(remote)
		get_server(request.vcore, request.vdata):connected(remote)
		
		response
			:write_object(remote, "ss4448s",
				"nickname",
				"country",
				"score",
				"games_played",
				"games_win",
				"last_game",
				"info")
		
		for _, client in pairs(remote.server.clients) do
			response:write_object(client, "41sss",
				"id",
				"states",
				"nickname",
				"country",
				"info")
		end
		response
			:write_dword(0)
		
		for _, session in pairs(remote.server.sessions) do
			if not session.locked then
				response
					:write_dword(session.master.id)
					:write_object(session, "4ss4b1",
						"max_players",
						"gamename",
						"mapname",
						"money",
						"fog_of_war",
						"battlefield")
					:write_dword(session:get_clients_count())
				for client_id in pairs(session.clients) do
					response:write_dword(client_id)
				end
			end
		end
		
		response
			:write_dword(0)
			:transmit(remote)
		
		xpackage(xcmd.USER_CONNECTED, remote.id, 0)
			:write_object(remote, "sss1",
				"nickname",
				"country",
				"info",
				"states")
			:broadcast(remote)
		
		xpackage(xcmd.USER_MESSAGE, 0, 0)
			:write_string(("%%color(FFFFFF)%% %s powered by %s"):format(VERSION, _VERSION))
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
				xregister.find(request.email))
			:transmit(remote)
	end,
	
	[xcmd.SERVER_FORGOT_PSW] = function (self, remote, request)
		local user = {}
		if not xregister.get(user, request.email) then
			return
		end
		return remote.log("info", "user forgot password, email=%s, password=%s", user.email, user.password)
	end,
}

auth_server = auth_core()

xserver = function (socket)
	local remote = xclient(socket)
	remote.log("info", "connected")
	auth_server:connected(remote)
	
	while true do
		local packet = xpacket:receive(socket)
		if not packet then
			break
		end
		local code = packet.code
		local session = remote.session
		if 0x0190 <= code and code <= 0x01F4 then
			if code ~= xcmd.SERVER_SESSION_PARSER then
				packet:dump_head()
				remote.server:process(remote, packet)
			elseif session then
				packet.code = xcmd.USER_SESSION_PARSER
				packet:session_dispatch(remote)
			end
		elseif session then
			local id_to = packet.id_to
			if id_to ~= 0 then
				if session.clients[id_to] then
					packet:transmit(session.clients[id_to])
				end
			else
				local buffer = packet:get()
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
