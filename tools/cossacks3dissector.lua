local Cossacks3 = Proto("cossacks3", "Cossacks 3")
Cossacks3.fields.code = ProtoField.uint16("cossacks3.code", "Command code", base.HEX)
Cossacks3.fields.command = ProtoField.string("cossacks3.command", "Command name")
Cossacks3.fields.id_from = ProtoField.uint16("cossacks3.id_from", "ID from", base.DEC)
Cossacks3.fields.id_to = ProtoField.uint16("cossacks3.id_to", "ID to", base.DEC)

local cmd = {}
for code, name in pairs
{
	[0x0192] = "SERVER_CLIENTINFO",
	[0x0193] = "USER_CLIENTINFO",
	[0x0194] = "SERVER_SESSION_MSG",
	[0x0195] = "USER_SESSION_MSG",
	[0x0196] = "SERVER_MESSAGE",
	[0x0197] = "USER_MESSAGE",
	[0x0198] = "SERVER_REGISTER",
	[0x0199] = "USER_REGISTER",
	[0x019A] = "SERVER_AUTHENTICATE",
	[0x019B] = "USER_AUTHENTICATE",
	[0x019C] = "SERVER_SESSION_CREATE",
	[0x019D] = "USER_SESSION_CREATE",
	[0x019E] = "SERVER_SESSION_JOIN",
	[0x019F] = "USER_SESSION_JOIN",
	[0x01A0] = "SERVER_SESSION_LEAVE",
	[0x01A1] = "USER_SESSION_LEAVE",
	[0x01A2] = "SERVER_SESSION_LOCK",
	[0x01A3] = "USER_SESSION_LOCK",
	[0x01A4] = "SERVER_SESSION_INFO",
	[0x01A5] = "USER_SESSION_INFO",
	[0x01A6] = "USER_CONNECTED",
	[0x01A7] = "USER_DISCONNECTED",
	[0x01A8] = "SERVER_USER_EXIST",
	[0x01A9] = "USER_USER_EXIST",
	[0x01AA] = "SERVER_SESSION_UPDATE",
	[0x01AB] = "SERVER_SESSION_CLIENT_UPDATE",
	[0x01AC] = "USER_SESSION_CLIENT_UPDATE",
	[0x01AD] = "SERVER_VERSION_INFO",
	[0x01AE] = "USER_VERSION_INFO",
	[0x01AF] = "SERVER_SESSION_CLOSE",
	[0x01B0] = "USER_SESSION_CLOSE",
	[0x01B1] = "SERVER_GET_TOP_USERS",
	[0x01B2] = "USER_GET_TOP_USERS",
	[0x01B3] = "SERVER_UPDATE_INFO",
	[0x01B4] = "USER_UPDATE_INFO",
	[0x01B5] = "SERVER_SESSION_KICK",
	[0x01B6] = "USER_SESSION_KICK",
	[0x01B7] = "SERVER_SESSION_CLSCORE",
	[0x01B8] = "USER_SESSION_CLSCORE",
	[0x01B9] = "SERVER_FORGOT_PSW",
	[0x01BB] = "SERVER_SESSION_PARSER",
	[0x01BC] = "USER_SESSION_PARSER",
	[0x01BD] = "USER_SESSION_RECREATE",
	[0x01BE] = "USER_SESSION_REJOIN",
}
do
	cmd[code] = name
	cmd[name] = code
end

local state_name =
{
	[0] = "online",
	[1] = "session",
	[2] = "master",
	[3] = "played",
}

local client_names = {}

local reader = setmetatable(
{
	check = function (self, size)
		return ( self.position + size - 1 <= self.range:len() )
	end,
	
	buffer = function (self, size)
		if not self:check(size) then
			return
		end
		local result = self.range(self.position, size):bytes()
		self.position = self.position + size
		return (tostring(result):gsub('..', function (hex) return string.char(tonumber(hex, 16)) end))
	end,
	
	number = function (self, size)
		if not self:check(size) then
			return
		end
		local result = self.range(self.position, size):le_uint()
		self.position = self.position + size
		return result
	end,
	
	byte = function (self)
		return self:number(1)
	end,
	
	boolean = function (self)
		return ( self:byte() ~= 0 ) and "true" or "false"
	end,
	
	word = function (self)
		return self:number(2)
	end,
	
	dword = function (self)
		return self:number(4)
	end,
	
	datetime = function (self)
		if not self:check(8) then
			return
		end
		local result = self.range(self.position, 8):le_float()
		self.position = self.position + 8
		result = ( result - 25569.0 ) * 86400.0
		return format_date(result):match("^(.-)%.")
	end,
	
	string = function (self)
		local size = self:byte()
		if not size then
			return
		end
		return self:buffer(size)
	end,
	
	long_string = function (self)
		local size = self:dword()
		if not size then
			return
		end
		return self:buffer(size)
	end,
	
	states = function (self)
		local b_value = self.range(self.position, 1)
		self.position = self.position + 1
		local states = {}
		for i = 0, 3 do
			if b_value:bitfield(7 - i) ~= 0 then
				table.insert(states, state_name[i])
			end
		end
 		return "[" .. table.concat(states, ", ") .. "]"
	end,
	
	array = function (self, format)
		local array = {}
		for i = 1, #format do
			local position = self.position
			local fmt, value = format:sub(i, i)
			if fmt == "s" then
				value = self:string()
			elseif fmt == "b" then
				value = self:boolean()
			elseif fmt == "t" then
				value = self:states()
			elseif fmt == "8" then
				value = self:datetime()
			else
				value = self:number(tonumber(fmt))
			end
			if not value then
				return
			end
			array[i] =
			{
				position = position,
				size = self.position - position,
				value = value,
			}
		end
		return array
	end,
	
	object = function (self, tree, format, ...)
		local fields = self:array(format)
		if fields == nil then
			return
		end
		for index, field in ipairs(fields) do
			local title = select(index, ...)
			local position = field.position
			local size = field.size
			local value = field.value
			self.result[title] = value
			tree:add(self.range(position, size), title .. ": " .. value)
		end
		return true
	end,
	
	parser = function (self, tree, subnode)
		local position = self.position
		local key = self:long_string()
		local value = self:long_string()
		local count = self:dword()
		if not ( key and value and count ) then
			return
		end
		local t_parser = tree:add(self.range(position, 1), ( subnode and "" or "Parser: " ) .. ("key=%q, value=%q"):format(key, value))
		for _ = 1, count do
			if not self:parser(t_parser, true) then
				return
			end
		end
		t_parser:set_len(self.position - position)
		return true
	end,
	
	parser_with_size = function (self, tree)
		local size = self:dword()
		if not size or size == 0 then
			return
		end
		return self:parser(tree)
	end,
	
	authenticate = function (self, tree)
		local error_code = self:byte()
		if not ( error_code and error_code == 0 ) then
			return
		end
		
		if not self:object(tree, "ss4448s",
			"nickname",
			"country",
			"score",
			"games_played",
			"games_win",
			"last_game",
			"info")
		then
			return
		end
		
		local position = self.position
		local t_clients = tree:add(self.range(position, 1), "Clients")
		while true do
			local position = self.position
			local id = self:dword()
			if id == nil then
				return
			elseif id == 0 then
				break
			end
			local t_client = t_clients:add(self.range(position, 1), "[" .. id .. "] ")
			t_client:add(self.range(position, 4), "id: " .. id)
			if not self:object(t_client, "tsss",
				"states",
				"nickname",
				"country",
				"info")
			then
				return
			end
			t_client:set_len(self.position - position)
			t_client:append_text(self.result.nickname)
			client_names[id] = self.result.nickname
		end
		t_clients:set_len(self.position - position)
		
		local position = self.position
		local t_sessions = tree:add(self.range(position, 1), "Sessions")
		while true do
			local position = self.position
			local id_master = self:dword()
			if id_master == nil then
				return
			elseif id_master == 0 then
				break
			end
			local t_session = t_sessions:add(self.range(position, 1), "[" .. id_master .. "] (" .. client_names[id_master] .. ")")
			t_session:add(self.range(position, 4), "id_master: " .. id_master)
			if not self:object(t_session, "4ss4b1",
					"max_players",
					"gamename",
					"mapname",
					"money",
					"fog_of_war",
					"battlefield")
			then
				return
			end
			local justname, justpass = self.result.gamename:match('"(.-)"\t"(.-)"')
			t_session:append_text((" name: %q pass: %q"):format(justname, justpass))
			t_session:set_len(self.position - position)
			local count = self:dword()
			if count == nil then
				return
			end
			for i = 1, count do
				local position = self.position
				local id = self:dword()
				if id == nil then
					return
				end
				t_session:add(self.range(position, 4), "[" .. id .. "] " .. client_names[id])
			end
			t_session:set_len(self.position - position)
		end
		t_sessions:set_len(self.position - position)
	end,
	
	clients = function (self, tree, format, ...)
		local position = self.position
		local count = self:dword()
		if count == nil then
			return
		end
		local t_clients = tree:add(self.range(position, 1), "Clients")
		for i = 1, count do
			local position = self.position
			local t_client = t_clients:add(self.range(self.position, 1), "")
			if not self:object(t_client, format, ...) then
				return
			end
			t_client:append_text("[" .. self.result.id .. "] " .. (client_names[self.result.id] or "?"))
			t_client:set_len(self.position - position)
		end
		t_clients:set_len(self.position - position)
	end,
	
	[cmd.SERVER_CLIENTINFO] = function (self, tree)
		return self:object(tree, "4",
			"id")
	end,
	
	[cmd.USER_CLIENTINFO] = function (self, tree)
		return self:object(tree, "4tss4448s",
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
	
	[cmd.SERVER_SESSION_MSG] = function (self, tree)
		return self:object(tree, "s",
			"message")
	end,
	
	[cmd.USER_SESSION_MSG] = function (self, tree)
		return self:object(tree, "s",
			"message")
	end,
	
	[cmd.SERVER_MESSAGE] = function (self, tree)
		return self:object(tree, "s",
			"message")
	end,
	
	[cmd.USER_MESSAGE] = function (self, tree)
		return self:object(tree, "s",
			"message")
	end,
	
	[cmd.SERVER_REGISTER] = function (self, tree)
		return self:object(tree, "ssssssss",
			"vcore",
			"vdata",
			"email",
			"password",
			"cdkey",
			"nickname",
			"country",
			"info")
	end,
	
	[cmd.USER_REGISTER] = function (self, tree)
		return self:authenticate(tree)
	end,
	
	[cmd.SERVER_AUTHENTICATE] = function (self, tree)
		return self:object(tree, "sssss",
			"vcore",
			"vdata",
			"email",
			"password",
			"cdkey")
	end,
	
	[cmd.USER_AUTHENTICATE] = function (self, tree)
		return self:authenticate(tree)
	end,
	
	[cmd.SERVER_SESSION_CREATE] = function (self, tree)
		return self:object(tree, "4sss4b1",
			"max_players",
			"password",
			"gamename",
			"mapname",
			"money",
			"fog_of_war",
			"battlefield")
	end,
	
	[cmd.USER_SESSION_CREATE] = function (self, tree)
		return self:object(tree, "t4ss4b1",
			"states",
			"max_players",
			"gamename",
			"mapname",
			"money",
			"fog_of_war",
			"battlefield")
	end,
	
	[cmd.SERVER_SESSION_JOIN] = function (self, tree)
		return self:object(tree, "4",
			"id_master")
	end,
	
	[cmd.USER_SESSION_JOIN] = function (self, tree)
		return self:object(tree, "4t",
			"id_master",
			"states")
	end,
	
	[cmd.SERVER_SESSION_LEAVE] = function (self, tree)
	end,
	
	[cmd.USER_SESSION_LEAVE] = function (self, tree)
		if not self:object(tree, "b", "force") then
			return
		end
		return self:clients(tree, "4t",
			"id",
			"states")
	end,
	
	[cmd.SERVER_SESSION_LOCK] = function (self, tree)
		return self:clients(tree, "41",
			"id",
			"team")
	end,
	
	[cmd.USER_SESSION_LOCK] = function (self, tree)
		return self:clients(tree, "4t",
			"id",
			"states")
	end,
	
	[cmd.SERVER_SESSION_INFO] = function (self, tree)
	end,
	
	[cmd.USER_SESSION_INFO] = function (self, tree)
		if not self:object(tree, "4ss4b1",
			"max_players",
			"gamename",
			"mapname",
			"money",
			"fog_of_war",
			"battlefield")
		then
			return
		end
		return self:clients(tree, "4t",
			"id",
			"states")
	end,
	
	[cmd.USER_CONNECTED] = function (self, tree)
		self:object(tree, "ssst",
			"nickname",
			"country",
			"info",
			"states")
		client_names[self.result.id_from] = self.result.nickname
	end,
	
	[cmd.USER_DISCONNECTED] = function (self, tree)
	end,
	
	[cmd.SERVER_USER_EXIST] = function (self, tree)
		return self:object(tree, "s",
			"email")
	end,
	
	[cmd.USER_USER_EXIST] = function (self, tree)
		return self:object(tree, "sb",
			"email",
			"exists")
	end,
	
	[cmd.SERVER_SESSION_UPDATE] = function (self, tree)
		return self:object(tree, "ss4b1",
			"gamename",
			"mapname",
			"money",
			"fog_of_war",
			"battlefield")
	end,
	
	[cmd.SERVER_SESSION_CLIENT_UPDATE] = function (self, tree)
		return self:object(tree, "1",
			"team")
	end,
	
	[cmd.USER_SESSION_CLIENT_UPDATE] = function (self, tree)
		return self:object(tree, "1",
			"team")
	end,
	
	[cmd.SERVER_VERSION_INFO] = function (self, tree)
		return self:object(tree, "s",
			"vdata")
	end,
	
	[cmd.USER_VERSION_INFO] = function (self, tree)
		if not self:object(tree, "ss",
			"vcore",
			"vdata")
		then
			return
		end
		self:parser_with_size(tree)
	end,
	
	[cmd.SERVER_SESSION_CLOSE] = function (self, tree)
	end,
	
	[cmd.USER_SESSION_CLOSE] = function (self, tree)
		if not self:object(tree, "8",
			"timestamp")
		then
			return nil
		end
		return self:clients(tree, "44",
			"id",
			"score")
	end,
	
	[cmd.SERVER_GET_TOP_USERS] = function (self, tree)
		return self:object(tree, "4",
			"count")
	end,
	
	[cmd.USER_GET_TOP_USERS] = function (self, tree)
	end,
	
	[cmd.SERVER_UPDATE_INFO] = function (self, tree)
		return self:object(tree, "ssss",
			"password",
			"nickname",
			"country",
			"info")
	end,
	
	[cmd.USER_UPDATE_INFO] = function (self, tree)
		return self:object(tree, "ssst",
			"nickname",
			"country",
			"info",
			"states")
	end,
	
	[cmd.SERVER_SESSION_KICK] = function (self, tree)
		return self:object(tree, "4",
			"id")
	end,
	
	[cmd.USER_SESSION_KICK] = function (self, tree)
		return self:object(tree, "4",
			"id")
	end,
	
	[cmd.SERVER_SESSION_CLSCORE] = function (self, tree)
		return self:object(tree, "44",
			"id",
			"score")
	end,
	
	[cmd.USER_SESSION_CLSCORE] = function (self, tree)
		return self:object(tree, "44",
			"id",
			"score")
	end,
	
	[cmd.SERVER_FORGOT_PSW] = function (self, tree)
		return self:object(tree, "s",
			"email")
	end,
	
	[cmd.SERVER_SESSION_PARSER] = function (self, tree)
		if not self:object(tree, "4",
			"parser_id")
		then
			return
		end
		return self:parser(tree)
	end,
	
	[cmd.USER_SESSION_PARSER] = function (self, tree)
		if not self:object(tree, "4",
			"parser_id")
		then
			return
		end
		return self:parser(tree)
	end,
	
	[cmd.USER_SESSION_RECREATE] = function (self, tree)
		return self:parser_with_size(tree)
	end,
	
	[cmd.USER_SESSION_REJOIN] = function (self, tree)
	end,
},
{
	__call = function (reader, range)
		return setmetatable(
			{
				range = range,
				position = 0,
				result = {},
			},
			{
				__index = reader,
			}
		)
	end,
})

Cossacks3.dissector = function (range, pinfo, tree)
	pinfo.cols.protocol = "cossacks3"
	
	local r_length = range(0, 4)
	local length = r_length:le_uint()
	local pdu_length = 4 + 2 + 4 + 4 + length
	
	if range:len() < pdu_length then
		pinfo.desegment_len = pdu_length - range:len()
		return
	end
	
	local r_command = range(4, 2)
	local command = r_command:le_uint()
	local command_name = cmd[command] or ("[0x%04X]"):format(command)
	
	local r_id_from = range(6, 4)
	local id_from = r_id_from:le_uint()
	local from = ( id_from == 0 and "ALL" or ( client_names[id_from] or "?") )
	
	local r_id_to = range(10, 4)
	local id_to = r_id_to:le_uint()
	local to = ( id_to == 0 and "ALL" or ( client_names[id_to] or "?") )
	
	pinfo.cols.info = ("%-28s [%6s => %6s] "):format(command_name, id_from, id_to)
	tree = tree:add(Cossacks3, range(), ("Cossacks 3, %s, From: %s, To: %s"):format(command_name, from, to))
	tree:add(r_length, "Payload length: " .. length)
	tree:add(Cossacks3.fields.code, r_command, command)
	tree:add(Cossacks3.fields.command, r_command, cmd[command] or "UNKNOWN")
	tree:add(Cossacks3.fields.id_from, r_id_from, id_from):append_text(" (" .. from .. ")")
	tree:add(Cossacks3.fields.id_to, r_id_to, id_to):append_text(" (" .. to .. ")")
	
	if reader[command] then
		local rr = reader(range(14, length))
		rr.result.code = command
		rr.result.id_from = id_from
		rr.result.id_to = id_to
		reader[command](rr, tree)
	end
end

DissectorTable.get("tcp.port"):add(31523, Cossacks3)
