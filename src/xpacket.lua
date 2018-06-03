require "xlog"
require "xconst"
require "xclass"
require "xpackage"

local log = xlog("xpacket")

xpacket = xclass
{
	__parent = xpackage,
	
	parse = function (self, vcore, vdata)
		local read_proc = self[self.code]
		if not read_proc then
			return nil, "unknown"
		end
		
		self.vcore = vcore
		self.vdata = vdata
		self.position = 1
		local result = read_proc(self, {})
		if not result then
			return nil, "failed"
		end
		
		if self:remain() > 0 then
			return nil, "remain"
		end
		
		result.code = self.code
		result.id_from = self.id_from
		result.id_to = self.id_to
		return result
	end,
	
	read_clients = function (self, result, format, ...)
		local clients = self:read_objects({}, format, ...)
		if not clients then
			return nil
		end
		result.clients = clients
		return result
	end,
	
	read_authenticate = function (self, result)
		result.error_code = self:read_byte()
		
		if not result.error_code then
			return nil
		end
		
		if result.error_code ~= 0 then
			return result
		end
		
		if not self:read_object(result, "ss444ts",
			"nickname",
			"country",
			"score",
			"games_played",
			"games_win",
			"last_game",
			"info")
		then
			return nil
		end
		
		result.clients = {}
		while true do
			local id = self:read_dword()
			if id == nil then
				return nil
			elseif id == 0 then
				break
			end
			local client = self:read_object({id = id}, "1sss",
				"states",
				"nickname",
				"country",
				"info")
			if not client then
				return nil
			end
			if self.vdata >= 0x00020100 then
				if not self:read_object(client, "444td",
					"score",
					"games_played",
					"games_win",
					"last_game",
					"pingtime")
				then
					return nil
				end
			end
			table.insert(result.clients, client)
		end
		
		result.sessions = {}
		while true do
			local master_id = self:read_dword()
			if master_id == nil then
				return nil
			elseif master_id == 0 then
				break
			end
			local session = self:read_object({master_id = master_id}, "4ss4b1",
				"max_players",
				"gamename",
				"mapname",
				"money",
				"fog_of_war",
				"battlefield")
			if not session then
				return nil
			end
			if not self:read_clients(session, "4",
				"id")
			then
				return nil
			end
			table.insert(result.sessions, session)
		end
		return result
	end,
	
	[xcmd.PING] = function (self, result)
		if result.id_from ~= 0 then
			return self:read_object(result, "d",
				"pingtime")
		else
			return self:read_clients(result, "4d",
				"id",
				"pingtime")
		end
	end,
	
	[xcmd.SERVER_CLIENTINFO] = function (self, result)
		return self:read_object(result, "4",
			"id")
	end,
	
	[xcmd.USER_CLIENTINFO] = function (self, result)
		if not self:read_object(result, "41ss444ts",
			"id",
			"states",
			"nickname",
			"country",
			"score",
			"games_played",
			"games_win",
			"last_game",
			"info")
		then
			return nil
		end
		if self.vdata >= 0x00020100 then
			if not self:read_object(result, "d",
				"pingtime")
			then
				return nil
			end
		end
		return result
	end,
	
	[xcmd.SERVER_SESSION_MSG] = function (self, result)
		return self:read_object(result, "s",
			"message")
	end,
	
	[xcmd.USER_SESSION_MSG] = function (self, result)
		return self:read_object(result, "s",
			"message")
	end,
	
	[xcmd.SERVER_MESSAGE] = function (self, result)
		return self:read_object(result, "s",
			"message")
	end,
	
	[xcmd.USER_MESSAGE] = function (self, result)
		return self:read_object(result, "s",
			"message")
	end,
	
	[xcmd.SERVER_REGISTER] = function (self, result)
		return self:read_object(result, "vvssssss",
			"vcore",
			"vdata",
			"email",
			"password",
			"cdkey",
			"nickname",
			"country",
			"info")
	end,
	
	[xcmd.USER_REGISTER] = function (self, result)
		return self:read_authenticate(result)
	end,
	
	[xcmd.SERVER_AUTHENTICATE] = function (self, result)
		return self:read_object(result, "vvsss",
			"vcore",
			"vdata",
			"email",
			"password",
			"cdkey")
	end,
	
	[xcmd.USER_AUTHENTICATE] = function (self, result)
		return self:read_authenticate(result)
	end,
	
	[xcmd.SERVER_SESSION_CREATE] = function (self, result)
		return self:read_object(result, "4sss4b1",
			"max_players",
			"password",
			"gamename",
			"mapname",
			"money",
			"fog_of_war",
			"battlefield")
	end,
	
	[xcmd.USER_SESSION_CREATE] = function (self, result)
		return self:read_object(result, "14ss4b1",
			"states",
			"max_players",
			"gamename",
			"mapname",
			"money",
			"fog_of_war",
			"battlefield")
	end,
	
	[xcmd.SERVER_SESSION_JOIN] = function (self, result)
		return self:read_object(result, "4",
			"master_id")
	end,
	
	[xcmd.USER_SESSION_JOIN] = function (self, result)
		return self:read_object(result, "41",
			"master_id",
			"states")
	end,
	
	[xcmd.SERVER_SESSION_LEAVE] = function (self, result)
		return result
	end,
	
	[xcmd.USER_SESSION_LEAVE] = function (self, result)
		if not self:read_object(result, "b", "is_master") then
			return nil
		end
		return self:read_clients(result, "41",
			"id",
			"states")
	end,
	
	[xcmd.SERVER_SESSION_LOCK] = function (self, result)
		return self:read_clients(result, "41",
			"id",
			"team")
	end,
	
	[xcmd.USER_SESSION_LOCK] = function (self, result)
		return self:read_clients(result, "41",
			"id",
			"states")
	end,
	
	[xcmd.SERVER_SESSION_INFO] = function (self, result)
		return result
	end,
	
	[xcmd.USER_SESSION_INFO] = function (self, result)
		if not self:read_object(result, "4ss4b1",
			"max_players",
			"gamename",
			"mapname",
			"money",
			"fog_of_war",
			"battlefield")
		then
			return nil
		end
		return self:read_clients(result, "41",
			"id",
			"states")
	end,
	
	[xcmd.USER_CONNECTED] = function (self, result)
		if not self:read_object(result, "sss1",
			"nickname",
			"country",
			"info",
			"states")
		then
			return nil
		end
		if self.vdata >= 0x00020100 then
			if not self:read_object(result, "444td",
				"score",
				"games_played",
				"games_win",
				"last_game",
				"pingtime")
			then
				return nil
			end
		end
		return result
	end,
	
	[xcmd.USER_DISCONNECTED] = function (self, result)
		return result
	end,
	
	[xcmd.SERVER_USER_EXIST] = function (self, result)
		return self:read_object(result, "s",
			"email")
	end,
	
	[xcmd.USER_USER_EXIST] = function (self, result)
		return self:read_object(result, "sb",
			"email",
			"exist")
	end,
	
	[xcmd.SERVER_SESSION_UPDATE] = function (self, result)
		return self:read_object(result, "ss4b1",
			"gamename",
			"mapname",
			"money",
			"fog_of_war",
			"battlefield")
	end,
	
	[xcmd.SERVER_SESSION_CLIENT_UPDATE] = function (self, result)
		return self:read_object(result, "1",
			"team")
	end,
	
	[xcmd.USER_SESSION_CLIENT_UPDATE] = function (self, result)
		return self:read_object(result, "1",
			"team")
	end,
	
	[xcmd.SERVER_VERSION_INFO] = function (self, result)
		return self:read_object(result, "v",
			"vdata")
	end,
	
	[xcmd.USER_VERSION_INFO] = function (self, result)
		return self:read_object(result, "vvq",
			"vcore",
			"vdata",
			"parser")
	end,
	
	[xcmd.SERVER_SESSION_CLOSE] = function (self, result)
		return result
	end,
	
	[xcmd.USER_SESSION_CLOSE] = function (self, result)
		if not self:read_object(result, "t",
			"timestamp")
		then
			return nil
		end
		return self:read_clients(result, "44",
			"id",
			"score")
	end,
	
	[xcmd.SERVER_GET_TOP_USERS] = function (self, result)
		return self:read_object(result, "4",
			"count")
	end,
	
	[xcmd.USER_GET_TOP_USERS] = function (self, result)
		result.clients = {}
		while true do
			local mark = self:read_byte()
			if mark == nil then
				return nil
			elseif mark ~= 1 then
				break
			end
			local client = self:read_object({}, "ss444t",
				"nickname",
				"country",
				"score",
				"games_played",
				"games_win",
				"last_game")
			if not client then
				return nil
			end
			table.insert(result.clients, client)
		end
		return result
	end,
	
	[xcmd.SERVER_UPDATE_INFO] = function (self, result)
		return self:read_object(result, "ssss",
			"password",
			"nickname",
			"country",
			"info")
	end,
	
	[xcmd.USER_UPDATE_INFO] = function (self, result)
		if not self:read_object(result, "sss1",
			"nickname",
			"country",
			"info",
			"states")
		then
			return nil
		end
		if self.vdata >= 0x00020100 then
			if not self:read_object(result, "444td",
				"score",
				"games_played",
				"games_win",
				"last_game",
				"pingtime")
			then
				return nil
			end
		end
		return result
	end,
	
	[xcmd.SERVER_SESSION_KICK] = function (self, result)
		return self:read_object(result, "4",
			"id")
	end,
	
	[xcmd.USER_SESSION_KICK] = function (self, result)
		return self:read_object(result, "4",
			"id")
	end,
	
	[xcmd.SERVER_SESSION_CLSCORE] = function (self, result)
		return self:read_object(result, "44",
			"id",
			"score")
	end,
	
	[xcmd.USER_SESSION_CLSCORE] = function (self, result)
		return self:read_object(result, "44",
			"id",
			"score")
	end,
	
	[xcmd.SERVER_FORGOT_PSW] = function (self, result)
		return self:read_object(result, "s",
			"email")
	end,
	
	[xcmd.SERVER_SESSION_PARSER] = function (self, result)
		return self:read_object(result, "4p",
			"parser_id",
			"parser")
	end,
	
	[xcmd.USER_SESSION_PARSER] = function (self, result)
		return self:read_object(result, "4p4",
			"parser_id",
			"parser",
			"unk_dw")
	end,
	
	[xcmd.USER_SESSION_RECREATE] = function (self, result)
		return self:read_object(result, "q",
			"parser")
	end,
	
	[xcmd.USER_SESSION_REJOIN] = function (self, result)
		return result
	end,
	
	[xcmd.LAN_PARSER] = function (self, result)
		return self:read_object(result, "4p",
			"parser_id",
			"parser")
	end,
	
	[xcmd.LAN_CLIENT_INFO] = function (self, result)
		return self:read_object(result, "wwb41411",
			"player",
			"nickname",
			"spectator",
			"id",
			"team",
			"score",
			"field_1C",
			"field_1D")
	end,
	
	[xcmd.LAN_SERVER_INFO] = function (self, result)
		return self:read_object(result, "ww44wb1b4",
			"gamename",
			"mapname",
			"max_players",
			"protocol_ver",
			"host",
			"secured",
			"battlefield",
			"fog_of_war",
			"money")
	end,
	
	[xcmd.LAN_DO_START] = function (self, result)
	end,
	
	[xcmd.LAN_DO_START_GAME] = function (self, result)
	end,
	
	[xcmd.LAN_DO_READY] = function (self, result)
	end,
	
	[xcmd.LAN_DO_READY_DONE] = function (self, result)
	end,
	
	[xcmd.LAN_RECORD] = function (self, result)
	end,
}
