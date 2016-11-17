require "xlog"
require "xcmd"
require "xclass"
require "xpackage"

local log = xlog("xpacket")

xpacket = xclass
{
	__parent = xpackage,
	
	parse = function (self)
		if not self[self.code] then
			return nil, "unknown"
		end
		
		local result = self[self.code](self, {})
		if not result then
			return nil, "failed"
		end
		
		if self.position <= #self.buffer then
			return nil, "leftover"
		end
		
		result.code = self.code
		result.id_from = self.id_from
		result.id_to = self.id_to
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
		
		if not self:read_object(result, "ss4448s",
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
			local client = {
				id = id,
			}
			if not self:read_object(client, "1sss",
				"states",
				"nickname",
				"country",
				"info")
			then
				return nil
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
			local session = {
				master_id = master_id
			}
			if not self:read_object(session, "4ss4b1",
					"max_players",
					"gamename",
					"mapname",
					"money",
					"fog_of_war",
					"battlefield")
			then
				return nil
			end
			local count = self:read_dword()
			if count == nil then
				return nil
			end
			session.clients = {}
			for i = 1, count do
				local id = self:read_dword()
				if id == nil then
					return nil
				end
				session.clients[i] = id
			end
			table.insert(result.sessions, session)
		end
		return result
	end,
	
	read_clients = function (self, result, format, ...)
		local count = self:read_dword()
		if count == nil then
			return false
		end
		result.clients = {}
		for i = 1, count do
			result.clients[i] = {}
			if not self:read_object(result.clients[i], format, ...) then
				return nil
			end
		end
		return result
	end,
	
	[xcmd.SERVER_CLIENTINFO] = function (self, result)
		return self:read_object(result, "4",
			"id")
	end,
	
	[xcmd.USER_CLIENTINFO] = function (self, result)
		return self:read_object(result, "41ss4448s",
			"id",
			"states",
			"nickname",
			"country",
			"score",
			"games_played",
			"games_win",
			"last_game",
			"info")
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
		return self:read_object(result, "ssssssss",
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
		return self:read_object(result, "sssss",
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
		if not self:read_object(result, "b", "force") then
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
		return self:read_object(result, "sss1",
			"nickname",
			"country",
			"info",
			"states")
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
			"exists")
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
		return self:read_object(result, "s",
			"vdata")
	end,
	
	[xcmd.USER_VERSION_INFO] = function (self, result)
		if not self:read_object(result, "ss",
			"vcore",
			"vdata")
		then
			return nil
		end
		result.parser = self:read_parser_with_size()
		if not result.parser then
			return nil
		end
		return result
	end,
	
	[xcmd.SERVER_SESSION_CLOSE] = function (self, result)
		return result
	end,
	
	[xcmd.USER_SESSION_CLOSE] = function (self, result)
		if not self:read_object(result, "8",
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
			local client = {}
			if not self:read_object(client, "ss4448",
				"nickname",
				"country",
				"score",
				"games_played",
				"games_win",
				"last_game")
			then
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
		return self:read_object(result, "sss1",
			"nickname",
			"country",
			"info",
			"states")
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
		result.parser_id = self:read_dword()
		if result.parser_id == nil then
			return nil
		end
		result.parser = self:read_parser()
		if result.parser == nil then
			return nil
		end
		return result
	end,
	
	[xcmd.USER_SESSION_PARSER] = function (self, result)
		result.parser_id = self:read_dword()
		if result.parser_id == nil then
			return nil
		end
		result.parser = self:read_parser()
		if result.parser == nil then
			return nil
		end
		self:read_dword()
		return result
	end,
	
	[xcmd.USER_SESSION_RECREATE] = function (self, result)
		result.parser = self:read_parser_with_size()
		if not result.parser then
			return nil
		end
		return result
	end,
	
	[xcmd.USER_SESSION_REJOIN] = function (self, result)
		return result
	end,
}
