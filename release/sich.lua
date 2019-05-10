--
-- Sich
-- Cossacks 3 lua server
--

VERSION = "Sich v0.2.7"

-- // xclass // --
do
	local call = function (class, ...)
		return setmetatable({__class = class}, class.__objmt):__create(...)
	end
	xclass = setmetatable(
	{
		__create = function (self)
			return self
		end,
	},
	{
		__call = function (xclass, class)
			class.__objmt = {__index = class}
			return setmetatable(class, {
				__index = class.__parent or xclass,
				__call = call,
			})
		end,
	})
end

-- // xstore // --
do
	local log_wait = {}
	local function log(...)
		if not xlog then
			return table.insert(log_wait, {...})
		end
		log = xlog("xstore")
		for _, wait in ipairs(log_wait) do
			log(unpack(wait))
		end
		log_wait = nil
		return log(...)
	end
	local function do_serialize(value, result, indent)
		local value_type = type(value)
		if value_type == "string" then
			table.insert(result, (("%q"):format(value):gsub("\\\n", "\\n")))
		elseif value_type == "nil" or value_type == "boolean" or value_type == "number" then
			table.insert(result, tostring(value))
		elseif value_type ~= "table" then
			error("can not serialize: " .. value_type)
		elseif next(value) == nil then
			table.insert(result, "{}")
		else
			local keys = {}
			for key in pairs(value) do
				table.insert(keys, key)
			end
			table.sort(keys, function (a, b)
				local ta, tb = type(a), type(b)
				if ta ~= tb then
					a, b = ta, tb
				elseif ta == "string" then
					local na, nb = tonumber(a), tonumber(b)
					if na and nb then
						a, b = na, nb
					end
				elseif ta ~= "number" then
					a, b = tostring(a), tostring(b)
				end
				return a < b
			end)
			table.insert(result, "{\n")
			for _, key in ipairs(keys) do
				table.insert(result, ("\t"):rep(indent + 1))
				table.insert(result, "[")
				do_serialize(key, result, indent + 1)
				table.insert(result, "] = ")
				do_serialize(value[key], result, indent + 1)
				table.insert(result, ",\n")
			end
			table.insert(result, ("\t"):rep(indent))
			table.insert(result, "}")
		end
		return result
	end
	local function serialize(value)
		return table.concat(do_serialize(value, {}, 0))
	end
	local path = arg and arg[0] and arg[0]:match("^(.+)[/\\][^/\\]+[/\\]?$") or "."
	path = path:gsub("%%", "%%%%") .. "/%s.store"
	log("debug", "path: %s", path)
	xstore =
	{
		load = function (name, default)
			name = path:format(name)
			log("debug", "loading %q", name)
			local file, msg = io.open(name, "r")
			if not file then
				log("debug", msg)
				return default
			end
			file:close()
			local fun = assert(loadfile(name))
			setfenv(fun, _G)
			local _, data = assert(pcall(fun))
			return data
		end,
		save = function (name, data)
			name = path:format(name)
			log("debug", "saving %q", name)
			local str = serialize(data)
			local file, msg = io.open(name, "w")
			if not file then
				log("error", msg)
				return false
			end
			file:write("return ", str, "\n")
			file:close()
			return true
		end,
	}
end

-- // xconfig // --
do
	xconfig = xstore.load("config", {})
end

-- // xlog // --
do
	local numeric =
	{
		debug = 0,
		info = 1,
		warn = 2,
		error = 3,
		disabled = 4,
	}
	local name_length = 10
	local level = numeric["info"]
	local units = {}
	local output = io.output()
	if type(xconfig.log) == "table" then
		level = assert(numeric[xconfig.log.level or "info"], "invalid log level")
		if xconfig.log.units then
			for unit, level in pairs(xconfig.log.units) do
				units[unit] = assert(numeric[level], "invalid log level")
			end
		end
		output = xconfig.log.output or output
	elseif type(xconfig.log) == "string" then
		level = assert(numeric[xconfig.log], "invalid log level")
	end
	local function log_check(self, level)
		return assert(numeric[level], "invalid log level") >= self.minlevel
	end
	local function log_print(self, level, fmt, ...)
		if not log_check(self, level) then
			return
		end
		return output:write(
			os.date("%Y.%m.%d %H:%M:%S"),
			(" | %%-5s | %%-%ds | %%%ds%s")
				:format(name_length, self.indent, fmt)
				:format(level, self.name, "", ...)
				:gsub("\\\n", "\\n"),
			"\n")
	end
	local function log_inc(self, value)
		self.indent = self.indent + (value or 1)
		return self
	end
	local function log_dec(self, value)
		self.indent = self.indent - (value or 1)
		return self
	end
	local function log_dummy()
	end
	local log_disabled = setmetatable({
		minlevel = numeric["disabled"],
		check = log_dummy,
		indent = 0,
		inc = log_dummy,
		dec = log_dummy,
	}, {
		__call = log_dummy,
	})
	xlog = function (unit, name)
		assert(type(unit) == "string", "no unit name")
		name = name or unit
		if name_length < #name then
			name_length = #name
		end
		local minlevel = units[unit] or level
		if minlevel >= numeric["disabled"] then
			return log_disabled
		end
		return setmetatable({
			name = name,
			minlevel = minlevel,
			check = log_check,
			indent = 0,
			inc = log_inc,
			dec = log_dec,
		}, {
			__call = log_print,
		})
	end
end

-- // xconst // --
do
	xconst = setmetatable({},
		{
			__call = function (_, tbl)
				local result = {}
				for code, name in pairs(tbl) do
					result[code] = name
					result[name] = code
				end
				return result
			end,
		})
	xcmd = xconst
	{
		[0x0190] = "SHELL_CONSOLE",                -- 
		[0x0191] = "PING",                         -- lePingInfo
		[0x0192] = "SERVER_CLIENTINFO",            -- LanPublicServerUpdateClientInfo
		[0x0193] = "USER_CLIENTINFO",              -- leShellClientInfo
		[0x0194] = "SERVER_SESSION_MSG",           -- LanPublicServerSendSessionMessage
		[0x0195] = "USER_SESSION_MSG",             -- leShellSessionMessage
		[0x0196] = "SERVER_MESSAGE",               -- LanPublicServerSendMessage
		[0x0197] = "USER_MESSAGE",                 -- leShellMessage
		[0x0198] = "SERVER_REGISTER",              -- LanPublicServerRegister
		[0x0199] = "USER_REGISTER",                -- leShellLogged
		[0x019A] = "SERVER_AUTHENTICATE",          -- LanPublicServerLogin
		[0x019B] = "USER_AUTHENTICATE",            -- leShellLogged
		[0x019C] = "SERVER_SESSION_CREATE",        -- LanCreateGame
		[0x019D] = "USER_SESSION_CREATE",          -- leShellSessionCreate
		[0x019E] = "SERVER_SESSION_JOIN",          -- LanJoinGame
		[0x019F] = "USER_SESSION_JOIN",            -- leShellSessionJoin
		[0x01A0] = "SERVER_SESSION_LEAVE",         -- LanTerminateGame
		[0x01A1] = "USER_SESSION_LEAVE",           -- leShellSessionLeave
		[0x01A2] = "SERVER_SESSION_LOCK",          -- LanLockServer
		[0x01A3] = "USER_SESSION_LOCK",            -- leShellSessionLock
		[0x01A4] = "SERVER_SESSION_INFO",          -- LanPublicServerUpdateMySessionInfo
		[0x01A5] = "USER_SESSION_INFO",            -- leShellSessionInfo
		[0x01A6] = "USER_CONNECTED",               -- leShellClientConnected
		[0x01A7] = "USER_DISCONNECTED",            -- leShellClientDisconnected
		[0x01A8] = "SERVER_USER_EXIST",            -- LanPublicServerUserExist
		[0x01A9] = "USER_USER_EXIST",              -- leShellValidEmail
		[0x01AA] = "SERVER_SESSION_UPDATE",        -- LanSrvSet*
		[0x01AB] = "SERVER_SESSION_CLIENT_UPDATE", -- LanClSetMyTeam
		[0x01AC] = "USER_SESSION_CLIENT_UPDATE",   -- 
		[0x01AD] = "SERVER_VERSION_INFO",          -- LanPublicServerUpdateInfo
		[0x01AE] = "USER_VERSION_INFO",            -- leShellServerInfo
		[0x01AF] = "SERVER_SESSION_CLOSE",         -- LanPublicServerCloseSession
		[0x01B0] = "USER_SESSION_CLOSE",           -- leShellSessionClose
		[0x01B1] = "SERVER_GET_TOP_USERS",         -- LanPublicServerUpdateTopUsers
		[0x01B2] = "USER_GET_TOP_USERS",           -- leShellUpdateTopList
		[0x01B3] = "SERVER_UPDATE_INFO",           -- LanPublicServerRegister
		[0x01B4] = "USER_UPDATE_INFO",             -- leShellClientUpdateInfo
		[0x01B5] = "SERVER_SESSION_KICK",          -- LanKillClient
		[0x01B6] = "USER_SESSION_KICK",            -- 
		[0x01B7] = "SERVER_SESSION_CLSCORE",       -- LanSrvSetClientScore
		[0x01B8] = "USER_SESSION_CLSCORE",         -- 
		[0x01B9] = "SERVER_FORGOT_PSW",            -- LanPublicServerForgotPassword
		[0x01BA] = "SERVER_SESSION_WRONG_CLOSE",   -- 
		[0x01BB] = "SERVER_SESSION_PARSER",        -- LanPublicServerSendSessionParser
		[0x01BC] = "USER_SESSION_PARSER",          -- leSessionParser
		[0x01BD] = "USER_SESSION_RECREATE",        -- leSessionRecreate
		[0x01BE] = "USER_SESSION_REJOIN",          -- leSessionRejoin
		[0x01BF] = "SERVER_PING_TEST",             -- 
		[0x01C0] = "USER_PING_TEST",               -- 
		[0x01C1] = "SERVER_SESSION_REJOIN",        -- 
		[0x01C2] = "SERVER_SELECT_FRIENDS",        -- 
		[0x01C3] = "USER_SELECT_FRIENDS",          -- leSelectFriends
		[0x01C4] = "SERVER_UPDATE_FRIENDS",        -- 
		[0x01C5] = "SERVER_DELETE_FRIENDS",        -- 
		[0x01C6] = "SERVER_SELECT_CHATS",          -- 
		[0x01C7] = "USER_SELECT_CHATS",            -- leSelectChats
		[0x01C8] = "SERVER_INSERT_CHATS",          -- 
		[0x01C9] = "SERVER_UPDATE_CHATS",          -- 
		[0x01CA] = "SERVER_DELETE_CHATS",          -- 
		[0x01CB] = "SERVER_SELECT_CLANS",          -- 
		[0x01CC] = "USER_SELECT_CLANS",            -- leSelectClans
		[0x01CD] = "SERVER_INSERT_CLANS",          -- 
		[0x01CE] = "SERVER_UPDATE_CLANS",          -- 
		[0x01CF] = "SERVER_DELETE_CLANS",          -- 
		[0x01D0] = "SERVER_SELECT_MEMBERS",        -- 
		[0x01D1] = "USER_SELECT_MEMBERS",          -- leSelectMembers
		[0x01D2] = "SERVER_INSERT_MEMBERS",        -- 
		[0x01D3] = "SERVER_DELETE_MEMBERS",        -- 
		[0x01D4] = "SERVER_SELECT_ADMINS",         -- 
		[0x01D5] = "USER_SELECT_ADMINS",           -- leSelectAdmins
		[0x01D6] = "SERVER_UPDATE_ADMINS",         -- 
		[0x01D7] = "SERVER_DELETE_ADMINS",         -- 
		[0x01D8] = "SERVER_BANNING_ADMINS",        -- 
		[0x01D9] = "SERVER_RESERV0_ADMINS",        -- 
		[0x01DA] = "SERVER_RESERV1_ADMINS",        -- 
		[0x01DB] = "SERVER_RESERV2_ADMINS",        -- 
		[0x01DC] = "SERVER_SELECT_STATS",          -- 
		[0x01DD] = "USER_SELECT_STATS",            -- leSelectStats
		[0x01DE] = "SERVER_UPDATE_STATS",          -- 
		[0x01DF] = "SERVER_DELETE_STATS",          -- 
		[0x01E0] = "SERVER_GET_SESSIONS",          -- 
		[0x01E1] = "USER_GET_SESSIONS",            -- leGetSessions
		[0x01E2] = "SERVER_PING_LOCK",             -- 
		[0x01E3] = "SERVER_PING_UNLOCK",           -- 
		[0x01E4] = "SERVER_CHECKSUM",              -- 
		[0x01E5] = "USER_CHECKSUM",                -- 
		[0x01E6] = "USER_CHECKSUM_FAILED",         -- leChecksumFailed
		[0x0032] = "LAN_PARSER",                   -- LanSendParser
		[0x0064] = "LAN_CLIENT_INFO",              -- leClientInfo
		[0x00C8] = "LAN_SERVER_INFO",              -- leServerInfo
		[0x0456] = "LAN_DO_START",                 -- LanDoStart
		[0x0457] = "LAN_DO_START_GAME",            -- DoStartGame, leGenerate
		[0x0460] = "LAN_DO_READY",                 -- LanDoReady
		[0x0461] = "LAN_DO_READY_DONE",            -- LanDoReadyDone, leReady
		[0x04B0] = "LAN_RECORD",                   -- 
	}
	xcmd.format = function (code)
		return ("[0x%04X] %s"):format(code, xcmd[code] or "UNKNOWN")
	end
	xconst.parser = xconst
	{
		[  1] = "LAN_GENERATE",
		[  2] = "LAN_READYSTART",
		[  3] = "LAN_START",
		[  4] = "LAN_ROOM_READY",
		[  5] = "LAN_ROOM_START",
		[  6] = "LAN_ROOM_CLIENT_CHANGES",
		[  7] = "LAN_GAME_READY",
		[  8] = "LAN_GAME_ANSWER_READY",
		[  9] = "LAN_GAME_START",
		[ 10] = "LAN_GAME_SURRENDER",
		[ 11] = "LAN_GAME_SURRENDER_CONFIRM",
		[ 12] = "LAN_GAME_SERVER_LEAVE",
		[ 13] = "LAN_GAME_SESSION_RESULTS",
		[ 14] = "LAN_GAME_SYNC_REQUEST",
		[ 15] = "LAN_GAME_SYNC_DATA",
		[ 16] = "LAN_GAME_SYNC_GAMETIME",
		[ 17] = "LAN_GAME_SYNC_ALIVE",
		[100] = "LAN_ROOM_SERVER_DATASYNC",
		[101] = "LAN_ROOM_SERVER_DATACHANGE",
		[102] = "LAN_ROOM_CLIENT_DATACHANGE",
		[103] = "LAN_ROOM_CLIENT_LEAVE",
		[200] = "LAN_MODS_MODSYNC_REQUEST",
		[201] = "LAN_MODS_MODSYNC_PARSER",
		[202] = "LAN_MODS_CHECKSUM_REQUEST",
		[203] = "LAN_MODS_CHECKSUM_ANSWER",
		[204] = "LAN_MODS_CHECKSUM_REQUESTCANJOIN",
		[205] = "LAN_MODS_CHECKSUM_ANSWERCANJOIN",
		[206] = "LAN_MODS_CHECKSUM_ANSWERCANNOTJOIN",
		[300] = "LAN_ADVISER_CLIENT_DATACHANGE",
	}
	xconst.player_victorystate = xconst
	{
		[0] = "none",
		[1] = "win",
		[2] = "lose",
	}
	xconst.spectator_countryid = -2
end

-- // xkeys // --
do
	local log = xlog("xkeys")
	local keystore = xstore.load("keys")
	if type(keystore) == "function" then
		xkeys = keystore
	elseif type(keystore) == "table" then
		local keys = nil
		if #keystore == 0 then
			keys = keystore
		else
			keys = {}
			for _, key in ipairs(keystore) do
				keys[key] = true
			end
		end
		xkeys = function (cdkey)
			return keys[cdkey] and true or false
		end
	else
		log("info", "disabled")
		xkeys = function (cdkey)
			return true
		end
	end
	keystore = nil
end

-- // xparser // --
do
	local log = xlog("xparser")
	xparser = xclass
	{
		__create = function (self, key, value)
			self.key = assert(key, "no key")
			self.value = assert(value, "no value")
			return self
		end,
		count = function (self)
			return #self
		end,
		pairs = function (self)
			return ipairs(self)
		end,
		append = function (self, node)
			table.insert(self, node)
			return node
		end,
		find = function (self, key)
			for _, node in self:pairs() do
				if node.key == key then
					return node
				end
			end
			return nil
		end,
		add = function (self, key, value)
			return self:append(xparser(key, value))
		end,
		get = function (self, key, default)
			local node = self:find(key)
			if node then
				return node.value
			end
			return default
		end,
		set = function (self, key, value)
			local node = self:find(key)
			if node then
				node.value = value
				return node
			end
			return self:add(key, value)
		end,
		remove = function (self, key)
			local i = self:count()
			while i > 0 do
				if self[i].key == key then
					table.remove(self, i)
				end
				i = i - 1
			end
		end,
		dump = function (self, flog)
			flog = flog or log
			if not flog:check("debug") then
				return
			end
			local function do_dump(parser)
				flog("debug", "key = %q, value = %q", parser.key, parser.value)
				flog:inc(2)
				for _, node in parser:pairs() do
					do_dump(node)
				end
				flog:dec(2)
			end
			return do_dump(self)
		end,
	}
	null_parser = xparser("", "")
end

-- // xpack // --
do
	local log = xlog("xpack")
	xpack = xclass
	{
		formats =
		{
			["1"] = "byte",
			["b"] = "boolean",
			["d"] = "datetime",
			["t"] = "timestamp",
			["s"] = "byte_string",
			["w"] = "word_string",
			["z"] = "dword_string",
			["v"] = "version",
			["p"] = "parser",
			["q"] = "parser_with_size",
		},
		__create = function (self, buffer, position)
			self.buffer = buffer or {}
			self.position = buffer and (position or 1) or nil
			return self
		end,
		reader = function (self, buffer, position)
			self.buffer = buffer or self:get_buffer()
			self.position = position or 1
			return self
		end,
		get_buffer = function (self)
			local buffer = self.buffer
			if type(buffer) == "table" then
				buffer = table.concat(buffer)
			end
			return buffer
		end,
		remain = function (self)
			return math.max(0, #self.buffer - self.position + 1)
		end,
		read_check = function (self, size)
			local remain = self:remain()
			if size > remain then
				log("error", "read_check: size=%d, remain=%d", size, remain)
				return false
			end
			return true
		end,
		read_all = function (self)
			local result = self.buffer:sub(self.position)
			self.position = #self.buffer + 1
			return result
		end,
		read_buffer = function (self, size)
			if not self:read_check(size) then
				return nil
			end
			self.position = self.position + size
			return self.buffer:sub(self.position - size, self.position - 1)
		end,
		read_number = function (self, size)
			if not self:read_check(size) then
				return nil
			end
			self.position = self.position + size
			local byte = { self.buffer:byte(self.position - size, self.position - 1) }
			local result = 0
			for i = size, 1, -1 do
				result = result * 256 + byte[i]
			end
			return result
		end,
		read_byte = function (self)
			if not self:read_check(1) then
				return nil
			end
			self.position = self.position + 1
			return self.buffer:byte(self.position - 1)
		end,
		read_boolean = function (self)
			local byte = self:read_byte()
			if byte == nil then
				return nil
			end
			return byte ~= 0
		end,
		read_word = function (self)
			return self:read_number(2)
		end,
		read_dword = function (self)
			return self:read_number(4)
		end,
		read_datetime = function (self)
			if not self:read_check(8) then
				return nil
			end
			self.position = self.position + 8
			local byte = { self.buffer:byte(self.position - 8, self.position - 1) }
			local sign = (byte[8] < 128)
			local exponent = (byte[8] % 128) * 16 + math.floor(byte[7] / 16)
			local mantissa = byte[7] % 16
			for i = 6, 1, -1 do
				mantissa = mantissa * 256 + byte[i]
			end
			if (mantissa == 0 and exponent == 0) or (sign == false) or (exponent == 2047) then
				return 0
			end
			mantissa = 1 + math.ldexp(mantissa, -52)
			return math.ldexp(mantissa, exponent - 1023)
		end,
		read_timestamp = function (self)
			local datetime = self:read_datetime()
			if datetime == nil then
				return nil
			end
			return math.max(0, (datetime - 25569.0) * 86400.0)
		end,
		read_string = function (self, len_size)
			local len = self:read_number(len_size)
			if len == nil then
				return nil
			end
			return self:read_buffer(len)
		end,
		read_byte_string = function (self)
			return self:read_string(1)
		end,
		read_word_string = function (self)
			return self:read_string(2)
		end,
		read_dword_string = function (self)
			return self:read_string(4)
		end,
		read_version = function (self)
			local str = self:read_byte_string()
			if str == nil then
				return nil
			end
			local result = 0
			for part in str:gmatch("[0-9]+") do
				result = result * 256 + tonumber(part)
			end
			return result
		end,
		read_parser = function (self)
			if self:remain() == 0 then
				return null_parser
			end
			local key, value, count = self:read("zz4")
			if key == nil then
				return nil
			end
			local parser = xparser(key, value)
			for _ = 1, count do
				local node = self:read_parser()
				if node == nil then
					return nil
				end
				parser:append(node)
			end
			return parser
		end,
		read_parser_with_size = function (self)
			local buffer = self:read_dword_string()
			if buffer == nil then
				return nil
			end
			return xpack(buffer):read_parser()
		end,
		read_array = function (self, format)
			local array = {}
			for i = 1, #format do
				local fmt, value = format:sub(i, i), nil
				local ftype = self.formats[fmt]
				if ftype then
					value = self["read_" .. ftype](self)
				else
					fmt = assert(tonumber(fmt), "invalid format")
					value = self:read_number(fmt)
				end
				if value == nil then
					return nil
				end
				array[i] = value
			end
			return array
		end,
		read_object = function (self, object, format, ...)
			local values = self:read_array(format)
			if values == nil then
				return nil
			end
			for index, value in ipairs(values) do
				local key = assert(select(index, ...), "no more keys")
				object[key] = value
			end
			return object
		end,
		read_objects = function (self, objects, format, ...)
			local count = self:read_dword()
			if count == nil then
				return nil
			end
			for _ = 1, count do
				local object = self:read_object({}, format, ...)
				if object == nil then
					return nil
				end
				table.insert(objects, object)
			end
			return objects
		end,
		read = function (self, format)
			local array = self:read_array(format)
			if array == nil then
				return nil
			end
			return unpack(array)
		end,
		write_buffer = function (self, buffer)
			assert(type(buffer) == "string", "not a string buffer")
			table.insert(self.buffer, buffer)
			return self
		end,
		write_number = function (self, size, value)
			assert(type(value) == "number", "not a numeric value")
			local frac = nil
			for _ = 1, size do
				value, frac = math.modf(value / 256)
				table.insert(self.buffer, string.char(frac * 256))
			end
			return self
		end,
		write_byte = function (self, value)
			assert(type(value) == "number", "not a numeric value")
			table.insert(self.buffer, string.char(value))
			return self
		end,
		write_boolean = function (self, value)
			assert(type(value) == "boolean", "not a boolean value")
			return self:write_byte(value and 1 or 0)
		end,
		write_word = function (self, value)
			return self:write_number(2, value)
		end,
		write_dword = function (self, value)
			return self:write_number(4, value)
		end,
		write_datetime = function (self, value)
			assert(type(value) == "number", "not a numeric value")
			if value < 0 or value == math.huge or value ~= value then
				value = 0
			end
			local mantissa, exponent = 0, 0
			if value ~= 0 then
				mantissa, exponent = math.frexp(value)
				mantissa = math.floor(0.5 + math.ldexp(mantissa * 2 - 1, 52))
				exponent = exponent - 1 + 1023
			end
			local byte = {}
			for _ = 1, 6 do
				mantissa, value = math.modf(mantissa / 256)
				table.insert(byte, value * 256)
			end
			table.insert(byte, mantissa + exponent % 16 * 16)
			table.insert(byte, math.floor(exponent / 16))
			table.insert(self.buffer, string.char(unpack(byte)))
			return self
		end,
		write_timestamp = function (self, value)
			assert(type(value) == "number", "not a numeric value")
			return self:write_datetime(value / 86400.0 + 25569.0)
		end,
		write_string = function (self, len_size, value)
			assert(type(value) == "string", "not a string value")
			self:write_number(len_size, #value)
			return self:write_buffer(value)
		end,
		write_byte_string = function (self, value)
			return self:write_string(1, value)
		end,
		write_word_string = function (self, value)
			return self:write_string(2, value)
		end,
		write_dword_string = function (self, value)
			return self:write_string(4, value)
		end,
		write_version = function (self, value)
			assert(type(value) == "number", "not a numeric value")
			local version, frac = {}, nil
			while value > 0 do
				value, frac = math.modf(value / 256)
				table.insert(version, 1, tostring(frac * 256))
			end
			return self:write_byte_string(table.concat(version, "."))
		end,
		write_parser = function (self, parser)
			assert(type(parser) == "table" and parser.__class == xparser, "not a parser value")
			if parser ~= null_parser then
				self:write("zz4",
					tostring(parser.key),
					tostring(parser.value),
					parser:count())
				for _, node in parser:pairs() do
					self:write_parser(node)
				end
			end
			return self
		end,
		write_parser_with_size = function (self, parser)
			local buffer = xpack()
				:write_parser(parser)
				:get_buffer()
			return self:write_dword_string(buffer)
		end,
		write_array = function (self, format, array)
			for i = 1, #format do
				local fmt, value = format:sub(i, i), array[i]
				local ftype = self.formats[fmt]
				if ftype then
					self["write_" .. ftype](self, value)
				else
					fmt = assert(tonumber(fmt), "invalid format")
					self:write_number(fmt, value)
				end
			end
			return self
		end,
		write_object = function (self, object, format, ...)
			local array = {}
			for i = 1, select("#", ...) do
				array[i] = object[select(i, ...)]
			end
			return self:write_array(format, array)
		end,
		write_objects = function (self, objects, format, ...)
			local count = 0
			for _ in pairs(objects) do
				count = count + 1
			end
			self:write_dword(count)
			for _, object in pairs(objects) do
				self:write_object(object, format, ...)
			end
			return self
		end,
		write = function (self, format, ...)
			return self:write_array(format, {...})
		end,
	}
end

-- // xpackage // --
do
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
end

-- // xpacket // --
do
	local log = xlog("xpacket")
	xpacket = xclass
	{
		__parent = xpackage,
		receive = function (class, socket)
			local head = socket:receive(4 + 2 + 4 + 4)
			if not head then
				return nil
			end
			local payload_length, code, id_from, id_to = xpack(head):read("4244")
			local payload = socket:receive(payload_length)
			if not payload then
				return nil
			end
			return class(code, id_from, id_to, payload)
		end,
		parse = function (self, vcore, vdata)
			local read_proc = self[self.code]
			if not read_proc then
				log("warn", "%s: not implemented", xcmd.format(self.code))
				return nil
			end
			self.vcore = vcore
			self.vdata = vdata
			self.position = 1
			local result = read_proc(self, {})
			if (not result) or (self:remain() > 0) then
				log("error", "%s: parse error", xcmd.format(self.code))
				return nil
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
		read_server_clients = function (self, result)
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
			return result
		end,
		read_server_sessions = function (self, result)
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
		read_authenticate = function (self, result)
			result.error_code = self:read_byte()
			if result.error_code == nil then
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
			if not self:read_server_clients(result) then
				return nil
			end
			return self:read_server_sessions(result)
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
			local count = self:read_dword()
			if count == nil then
				return nil
			end
			local clients = {}
			for _ = 1, count do
				local id = self:read_dword()
				if id == nil then
					return nil
				elseif id == 0 then
					if not self:read_object(result, "4",
						"session_id")
					then
						return nil
					end
				else
					local client = {id = id}
					if not self:read_object(client, "1",
						"states")
					then
						return nil
					end
					table.insert(clients, client)
				end
			end
			result.clients = clients
			return result
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
				elseif mark == 0 then
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
				if mark >= 2 then
					if not self:read_object(client, "4",
						"id")
					then
						return nil
					end
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
		[xcmd.SERVER_GET_SESSIONS] = function (self, result)
			return result
		end,
		[xcmd.USER_GET_SESSIONS] = function (self, result)
			return self:read_server_sessions(result)
		end,
		[xcmd.SERVER_PING_LOCK] = function (self, result)
			return result
		end,
		[xcmd.SERVER_PING_UNLOCK] = function (self, result)
			return result
		end,
		[xcmd.SERVER_CHECKSUM] = function (self, result)
			return self:read_object(result, "w",
				"checksum")
		end,
		[xcmd.USER_CHECKSUM] = function (self, result)
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
	}
end

-- // xregister // --
do
	local log = xlog("xregister")
	local function assign(client, id, account)
		client.id = id
		client.email = account.email
		client.password = account.password
		client.cdkey = account.cdkey
		client.nickname = account.nickname
		client.country = account.country
		client.info = account.info
		client.score = account.score
		client.games_played = account.games_played
		client.games_win = account.games_win
		client.last_game = account.last_game
		client.banned = account.banned
	end
	xregister = xclass
	{
		__create = function ()
			local self = xstore.load("register", {})
			setmetatable(self, xregister.__objmt)
			local maxid = 0
			while true do
				local email, account
				for em, acc in pairs(self) do
					if type(em) == "string" then
						email = em
						account = acc
						break
					elseif maxid < em then
						maxid = em
					end
				end
				if not email then
					break
				end
				self[email] = nil
				account.email = email
				self[account.id] = account
				account.id = nil
				if account.blocked ~= nil then
					account.banned = account.blocked
					account.blocked = nil
				end
			end
			for id = 1, maxid do
				if type(self[id]) ~= "table" then
					self[id] = false
				end
			end
			return self
		end,
		save = function (self)
			return xstore.save("register", self)
		end,
		pairs = function (self)
			local iter, state, var = ipairs(self)
			local function iter1(state, var)
				local id, account = iter(state, var)
				if not id then
					return nil, nil
				elseif account then
					return id, account
				end
				return iter1(state, id)
			end
			return iter1, state, var
		end,
		find = function (self, email)
			if self[email] then
				return email, self[email]
			else
				email = email:lower()
				for id, account in self:pairs() do
					if account.email == email then
						return id, account
					end
				end
			end
			return nil, nil
		end,
		exist = function (self, email)
			return self:find(email) ~= nil
		end,
		new = function (self, client, request)
			local email = assert(request.email)
			if self:exist(email) then
				return false
			end
			log("info", "registering new user: %s", email)
			local account =
			{
				email = email:lower(),
				password = assert(request.password),
				cdkey = assert(request.cdkey),
				nickname = assert(request.nickname),
				country = assert(request.country),
				info = assert(request.info),
				score = 0,
				games_played = 0,
				games_win = 0,
				last_game = 0,
				banned = false,
			}
			table.insert(self, account)
			self:save()
			assign(client, #self, account)
			return true
		end,
		get = function (self, client, email)
			local id, account = self:find(email)
			if not id then
				return false
			end
			assign(client, id, account)
			return true
		end,
		update = function (self, client, do_not_save)
			local id, account = self:find(client.id)
			if not id then
				return false
			end
			account.password = client.password
			account.nickname = client.nickname
			account.country = client.country
			account.info = client.info
			account.score = client.score
			account.games_played = client.games_played
			account.games_win = client.games_win
			account.last_game = client.last_game
			if not do_not_save then
				self:save()
			end
			return true
		end,
		remove = function (self, email)
			local id = self:find(email)
			if not id then
				return false
			end
			self[id] = false
			return true
		end,
		ban = function (self, email, banned)
			local id, account = self:find(email)
			if not id then
				return false
			end
			account.banned = banned
			self:save()
			return true
		end,
	}
	register = xregister()
end

-- // xclient // --
do
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
end

-- // xclients // --
do
	local log = xlog("xclients")
	xclients = xclass
	{
		__create = function (self)
			self.clients = {}
			return self
		end,
		get_clients_count = function (self)
			local count = 0
			for _ in pairs(self.clients) do
				count = count + 1
			end
			return count
		end,
		check_client = function (self, client_id)
			if self.clients[client_id] then
				return true
			end
			log("debug", "client not found: %d", client_id)
			return false
		end,
		broadcast = function (self, package)
			package:dump_head()
			local buffer = package:get()
			for _, client in pairs(self.clients) do
				client.socket:send(buffer)
			end
			return package
		end,
		dispatch = function (self, package)
			if package.id_to == 0 then
				return self:broadcast(package)
			end
			if self:check_client(package.id_to) then
				package:transmit(self.clients[package.id_to])
			end
			return package
		end,
	}
end

-- // xsocket // --
do
	local socket = require "socket"
	local log = xlog("xsocket")
	local sendt = {}
	local recvt = {}
	local slept = {}
	local wrapped = setmetatable({}, {__mode = "kv"})
	local wrapper wrapper = setmetatable(
	{
		error = function (self, err)
			if err ~= "closed" then
				log("debug", "socket error: %s", err)
			end
			self:close()
			return nil, err
		end,
		bind = function (self, host, port)
			log("debug", "socket bind: %s:%s", host, port)
			return self.sock:bind(host, port)
		end,
		listen = function (self, backlog)
			local ok, err = self.sock:listen(backlog)
			if not ok then
				return self:error(err)
			end
			self.closed = false
			return true
		end,
		accept = function (self)
			if self.closed then
				return nil, "closed"
			end
			while true do
				coroutine.yield(self.sock, recvt)
				local client, err = self.sock:accept()
				if client then
					client:setoption("tcp-nodelay", true)
					return wrapper(client, false)
				elseif err ~= "timeout" then
					return self:error(err)
				end
			end
		end,
		connect_unix = function (self, host, port)
			while true do
				local ok, err = self.sock:connect(host, port)
				if ok or err == "already connected" then
					self.closed = false
					return true
				elseif err == "timeout" or err == "Operation already in progress" then
					coroutine.yield(self.sock, sendt)
				else
					return self:error(err)
				end
			end
		end,
		connect_windows = function (self, host, port)
			local first_timeout = true
			while true do
				local ok, err = self.sock:connect(host, port)
				if ok or err == "already connected" then
					self.closed = false
					return true
				elseif err == "Operation already in progress" then
					xsocket.sleep(0.1)
				elseif err == "timeout" and first_timeout then
					first_timeout = false
					xsocket.sleep(0.1)
				elseif err == "timeout" then
					return self:error("connection refused")
				else
					return self:error(err)
				end
			end
		end,
		send = function (self, data)
			if self.closed then
				return nil, "closed"
			end
			self.writebuf = self.writebuf .. data
			while #self.writebuf > 0 do
				coroutine.yield(self.sock, sendt)
				if #self.writebuf == 0 then
					break
				end
				local sent, err, last = self.sock:send(self.writebuf)
				if sent then
					self.writebuf = self.writebuf:sub(sent + 1)
				elseif err == "timeout" then
					self.writebuf = self.writebuf:sub(last + 1)
				else
					return self:error(err)
				end
			end
			return true
		end,
		receive = function (self, size)
			if self.closed then
				return nil, "closed"
			end
			local recv_size = size or 1
			while #self.readbuf < recv_size do
				coroutine.yield(self.sock, recvt)
				if #self.readbuf >= recv_size then
					break
				end
				local data, err, partial = self.sock:receive(32 * 1024)
				if data then
					self.readbuf = self.readbuf .. data
				elseif err == "timeout" then
					self.readbuf = self.readbuf .. partial
				else
					return self:error(err)
				end
			end
			local readbuf = self.readbuf
			if size then
				self.readbuf = readbuf:sub(size + 1)
				return readbuf:sub(1, size)
			else
				self.readbuf = ""
				return readbuf
			end
		end,
		sendto = function (self, data, ip, port)
			if self.closed then
				return nil, "closed"
			end
			while true do
				coroutine.yield(self.sock, sendt)
				local ok, err = self.sock:sendto(data, ip, port)
				if ok then
					return true
				elseif err ~= "timeout" then
					return self:error(err)
				end
			end
		end,
		receivefrom = function (self)
			if self.closed then
				return nil, "closed"
			end
			while true do
				coroutine.yield(self.sock, recvt)
				local data, ip, port = self.sock:receivefrom()
				if data then
					return data, ip, port
				elseif ip ~= "timeout" then
					return self:error(ip)
				end
			end
		end,
		close = function (self)
			if self.closed then
				return false
			end
			self.closed = true
			self.sock:shutdown("both")
			return self.sock:close()
		end,
	},
	{
		__index = function (wrapper, name)
			wrapper[name] = function (self, ...)
				return self.sock[name](self.sock, ...)
			end
			return wrapper[name]
		end,
		__call = function (wrapper, sock, closed)
			sock:settimeout(0)
			wrapped[sock] =
			{
				sock = sock,
				closed = closed,
				readbuf = "",
				writebuf = "",
			}
			return setmetatable(wrapped[sock], wrapper.index_mt)
		end,
	})
	wrapper.index_mt = {
		__index = wrapper,
	}
	if package.config:sub(1, 1) == "\\" then
		wrapper.connect = wrapper.connect_windows
	else
		wrapper.connect = wrapper.connect_unix
	end
	local function append(thread, success, sock, set)
		if not success then
			xsocket.threads = xsocket.threads - 1
			log("error", "thread crashed: %s", debug.traceback(thread, sock))
			return
		end
		if not sock then
			xsocket.threads = xsocket.threads - 1
			return
		end
		if set[sock] then
			table.insert(set[sock].threads, 1, thread)
		else
			table.insert(set, sock)
			set[sock] =
			{
				index = #set,
				threads =
				{
					[1] = thread,
				},
			}
		end
	end
	local function resume(sock, set)
		local assoc = set[sock]
		local thread = table.remove(assoc.threads)
		if #assoc.threads == 0 then
			set[sock] = nil
			local last = table.remove(set)
			if last ~= sock then
				set[last].index = assoc.index
				set[assoc.index] = last
			end
		end
		return append(thread, coroutine.resume(thread))
	end
	local function rpairs(t)
		local function rnext(t, k)
			k = k - 1
			if k > 0 then
				return k, t[k]
			end
		end
		return rnext, t, #t + 1
	end
	xsocket =
	{
		threads = 0,
		tcp = function ()
			local sock, msg = (socket.tcp4 or socket.tcp)()
			if not sock then
				return nil, msg
			end
			local ok, msg = sock:setoption("reuseaddr", true)
			if not ok then
				return nil, msg
			end
			return wrapper(sock, true)
		end,
		udp = function ()
			local sock, msg = (socket.udp4 or socket.udp)()
			if not sock then
				return nil, msg
			end
			local ok, msg = sock:setoption("reuseaddr", true)
			if not ok then
				return nil, msg
			end
			return wrapper(sock, false)
		end,
		gettime = socket.gettime,
		yield = function ()
			coroutine.yield(0, slept)
		end,
		sleep = function (sec)
			coroutine.yield(xsocket.gettime() + sec, slept)
		end,
		sleep_until = function (ts)
			if ts > xsocket.gettime() then
				coroutine.yield(ts, slept)
			end
		end,
		spawn = function (func, ...)
			local thread = coroutine.create(
				function (...)
					func(...)
					return nil, nil
				end)
			xsocket.threads = xsocket.threads + 1
			return append(thread, coroutine.resume(thread, ...))
		end,
		loop = function ()
			while true do
				for _, sock in rpairs(recvt) do
					if wrapped[sock].closed then
						resume(sock, recvt)
					end
				end
				for _, sock in rpairs(sendt) do
					if wrapped[sock].closed then
						resume(sock, sendt)
					end
				end
				if #slept > 0 then
					local now = xsocket.gettime()
					for _, ts in rpairs(slept) do
						if ts <= now then
							local assoc = slept[ts]
							while #assoc.threads > 0 do
								resume(ts, slept)
							end
						end
					end
				end
				local timeout = nil
				if #slept > 0 then
					timeout = math.huge
					for _, ts in ipairs(slept) do
						timeout = math.min(timeout, ts)
					end
					timeout = math.max(0, timeout - xsocket.gettime())
				end
				local read, write = socket.select(recvt, sendt, timeout)
				for _, sock in ipairs(read) do
					resume(sock, recvt)
				end
				for _, sock in ipairs(write) do
					resume(sock, sendt)
				end
			end
		end,
	}
end

-- // xsession // --
do
	local log = xlog("xsession")
	local next_session_id = 1
	xsession = xclass
	{
		__parent = xclients,
		__create = function (self, remote, request)
			if remote.session then
				remote.session:leave(remote)
			elseif remote.server.sessions[remote.id] then
				return
			end
			self = xclients.__create(self)
			self.real_name = ""
			self.real_pass = ""
			self.locked = false
			self.closed = false
			self.server = remote.server
			self.session_id = next_session_id
			next_session_id = next_session_id + 1
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
			self.server.sessions[self.master_id] = self
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
			return xpackage(xcmd.USER_SESSION_MSG, request.id_from, request.id_to)
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
				parser:add("session", self.session_id)
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
				if client.cid == xconst.spectator_countryid then
					self.score_updated[client.id] = true
				end
				client:set_state("played", true)
			end
			local count = 0
			for _ in pairs(self.clients) do
				count = count + 1
			end
			if self.server.vdata >= 0x00020203 then
				count = count + 1
			end
			local response = xpackage(xcmd.USER_SESSION_LOCK, remote.id, 0)
				:write_dword(count)
			for _, client in pairs(self.clients) do
				response
					:write_object(client, "41",
						"id",
						"states")
			end
			if self.server.vdata >= 0x00020203 then
				response
					:write("44",
						0,
						self.session_id)
			end
			return response
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
				elseif id == 0 or res == xconst.player_victorystate.none then
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
						if res == xconst.player_victorystate.win then
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
							xconst.player_victorystate[res], client.games_played, client.games_win, client.score)
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
end

-- // xserver // --
do
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
end

-- // xadmin // --
do
	local log = xlog("xadmin")
	local function find_user(user)
		local user_id = tonumber(user)
		for id, account in register:pairs() do
			if id == user_id
			or account.email == user
			or account.nickname == user
			then
				return id, account
			end
		end
		return nil, nil
	end
	local function find_remote(id)
		for _, server in pairs(servers) do
			if server.clients[id] then
				return server.clients[id]
			end
		end
		return nil
	end
	xadmin = xclass
	{
		commands = {},
		command = function (class, name, args, description, argc, handler)
			local command =
			{
				name = name,
				args = args,
				description = description,
				argc = argc,
				handler = handler,
			}
			class.commands[name] = command
			table.insert(class.commands, command)
		end,
		__create = function (self, socket)
			self.socket = socket
			self.host, self.port = socket:getpeername()
			self:log("info", "connected")
			self:table_begin()
			self:table_row(("%s powered by %s"):format(VERSION, _VERSION))
			self:table_end()
			self:start()
			socket:close()
			self:log("info", "disconnected")
			return self
		end,
		log = function (self, level, fmt, ...)
			log(level, "[%s:%s] " .. fmt, self.host, self.port, ...)
		end,
		start = function (self)
			while true do
				self.socket:send("> ")
				local line = {}
				while true do
					local char = self.socket:receive(1)
					if not char then
						return
					end
					local byte = char:byte()
					if byte == 8 or byte == 127 then
						line[#line] = nil
					elseif byte == 13 then
						line = table.concat(line)
						break
					elseif 32 <= byte and byte < 127 then
						line[#line + 1] = char
					end
				end
				self:log("debug", "exec: %s", line)
				local words = {}
				for word in line:gmatch("[%S]+") do
					table.insert(words, word)
				end
				if words[1] then
					self:process(table.remove(words, 1), words)
				end
			end
		end,
		process = function (self, cmd, argv)
			if #cmd < 3 then
				return self:writeln("type at least 3 first letters of the command")
			end
			local selected = nil
			local pattern = "^" .. cmd:gsub("%W", "%%%1")
			for _, command in ipairs(self.commands) do
				if command.name:match(pattern) then
					if selected == nil then
						selected = command
					elseif selected == false then
						self:writeln("? %s", command.name)
					else
						self:writeln("? %s", selected.name)
						self:writeln("? %s", command.name)
						selected = false
					end
				end
			end
			if selected == nil then
				return self:writeln("unknown command")
			end
			if selected == false then
				return self:writeln("ambiguous command")
			end
			if #argv < selected.argc then
				return self:writeln("command requires at least %d argument%s", selected.argc, selected.argc > 1 and "s" or "")
			end
			return selected.handler(self, unpack(argv))
		end,
		writeln = function (self, fmt, ...)
			return self.socket:send((fmt .. "\r\n"):format(...))
		end,
		table_begin = function (self, ...)
			self.table_head = {}
			self.table_cols = {}
			self.table_rows = {}
			for i, head in ipairs {...} do
				self.table_head[i] = head
				self.table_cols[i] = #head
			end
		end,
		table_row = function (self, ...)
			local row = {}
			for i, cell in ipairs {...} do
				cell = tostring(cell)
				row[i] = cell
				if (not self.table_cols[i]) or (self.table_cols[i] < #cell) then
					self.table_cols[i] = #cell
				end
			end
			return table.insert(self.table_rows, row)
		end,
		table_end = function (self)
			local row_strips = {}
			local row_format = {}
			for _, col in ipairs(self.table_cols) do
				table.insert(row_strips, ("-"):rep(col))
				table.insert(row_format, "%-" .. col .. "s")
			end
			row_strips = "+-" .. table.concat(row_strips, "-+-") .. "-+\r\n"
			row_format = "| " .. table.concat(row_format, " | ") .. " |\r\n"
			local buffer = {}
			table.insert(buffer, row_strips)
			if #self.table_head > 0 then
				table.insert(buffer, row_format:format(unpack(self.table_head)))
				table.insert(buffer, row_strips)
			end
			for _, row in ipairs(self.table_rows) do
				table.insert(buffer, row_format:format(unpack(row)))
			end
			table.insert(buffer, row_strips)
			self.table_head = nil
			self.table_cols = nil
			self.table_rows = nil
			return self.socket:send(table.concat(buffer))
		end,
	}
	xadmin:command("exit", "", "close this console", 0, function (self)
		return self.socket:close()
	end)
	xadmin:command("info", "", "server info", 0, function (self)
		self:table_begin()
		local count = 0
		for _ in register:pairs() do
			count = count + 1
		end
		self:table_row("registered users", count)
		count = 0
		for tag, server in pairs(servers) do
			local clients_count = server:get_clients_count()
			self:table_row(tag, clients_count)
			count = count + clients_count
		end
		self:table_row("online users", count)
		self:table_row("running threads", xsocket.threads)
		return self:table_end()
	end)
	xadmin:command("users", "", "list online users", 0, function (self)
		self:table_begin("vcore/vdata", "id", "nickname", "session", "state")
		for client in pairs(auth_server.clients) do
			self:table_row("", "", client.host .. ":" .. client.port, "", "auth")
		end
		for tag, server in pairs(servers) do
			for _, client in pairs(server.clients) do
				local state = "online"
				for _, state_name in ipairs {"played", "master", "session"} do
					if client:get_state(state_name) then
						state = state_name
						break
					end
				end
				local session_name = client.session and client.session.real_name or ""
				self:table_row(tag, client.id, client.nickname, session_name, state)
			end
		end
		return self:table_end()
	end)
	xadmin:command("sessions", "", "list sessions", 0, function (self)
		self:table_begin("vcore/vdata", "master id", "name", "password", "state", "users")
		for tag, server in pairs(servers) do
			for master_id, session in pairs(server.sessions) do
				local state = ""
				if session.locked then
					state = "locked"
				elseif session.closed then
					state = "closed"
				end
				local master = session.clients[master_id]
				self:table_row(tag, master_id, session.real_name, session.real_pass, state, master and master.nickname or "[master is out]")
				for client_id, client in pairs(session.clients) do
					if client_id ~= master_id then
						self:table_row("", "", "", "", "", client.nickname)
					end
				end
			end
		end
		return self:table_end()
	end)
	xadmin:command("register", "[user]", "list registered users", 0, function (self, user)
		self:table_begin("id", "nickname", "email", "password", "games_played", "games_win", "score", "last_game", "banned")
		local function show(id, account)
			return self:table_row(id, account.nickname, account.email, account.password, account.games_played,
				account.games_win, account.score, os.date("%Y.%m.%d %H:%M:%S", account.last_game), tostring(account.banned))
		end
		local id, account = find_user(user)
		if id then
			show(id, account)
		elseif user then
			--
		else
			for id, account in register:pairs() do
				show(id, account)
			end
		end
		return self:table_end()
	end)
	xadmin:command("update", "<user> <key> <value>", "update register", 3, function (self, user, key, value)
		local id, account = find_user(user)
		if not id then
			return self:writeln("user not found")
		end
		if account[key] == nil then
			return self:writeln("key not exist")
		end
		local tp = type(account[key])
		if tp == "boolean" then
			value = value:lower()
			if value == "false" or value == "0" then
				value = false
			elseif value == "true" or value == "1" then
				value = true
			else
				return self:writeln("not a boolean value")
			end
		elseif tp == "number" then
			value = tonumber(value)
			if not value then
				return self:writeln("not a numeric value")
			end
		end
		local client = find_remote(id)
		if client then
			client[key] = value
			register:update(client)
		else
			account[key] = value
			register:save()
		end
	end)
	xadmin:command("kick", "<user>", "disconnect online user", 1, function (self, user)
		local id, account = find_user(user)
		if not id then
			return self:writeln("user not found")
		end
		local remote = find_remote(id)
		if not remote then
			return self:writeln("user is offline: #%d %s", id, account.nickname)
		end
		remote.socket:close()
		return self:writeln("kicked: #%d %s", id, account.nickname)
	end)
	xadmin:command("ban", "<user>", "disable user account", 1, function (self, user)
		local id, account = find_user(user)
		if not (id and register:ban(id, true)) then
			return self:writeln("unknown user: %s", user)
		end
		return self:writeln("account is banned: #%d %s", id, account.nickname)
	end)
	xadmin:command("unban", "<user>", "enable user account", 1, function (self, user)
		local id, account = find_user(user)
		if not (id and register:ban(id, false)) then
			return self:writeln("unknown user: %s", user)
		end
		return self:writeln("account is unbanned: #%d %s", id, account.nickname)
	end)
	xadmin:command("stop", "", "stop server", 0, function (self)
		return os.exit()
	end)
	xadmin:command("help", "", "print available commands", 0, function (self, cmd)
		if cmd and self.commands[cmd] then
			return self:writeln("%s", self.commands[cmd].description)
		end
		self:table_begin()
		for _, command in ipairs(self.commands) do
			self:table_row(command.name .. " " .. command.args, command.description)
		end
		return self:table_end()
	end)
	if not xconfig.admin then
		log("info", "disabled")
	else
		local host, port = assert(xconfig.admin.host, "no admin.host"), assert(xconfig.admin.port, "no admin.port")
		local server_socket = assert(xsocket.tcp())
		assert(server_socket:bind(host, port))
		assert(server_socket:listen(32))
		log("info", "listening at tcp:%s:%s", server_socket:getsockname())
		xsocket.spawn(
			function ()
				while true do
					xsocket.spawn(xadmin, assert(server_socket:accept()))
				end
			end)
	end
end

-- // xecho // --
do
	local log = xlog("xecho")
	if xconfig.echo == false then
		log("info", "disabled") 
	else
		local host = "*"
		local port = 31523
		local title = nil
		if type(xconfig.echo) == "table" then
			host = xconfig.echo.host or host
			port = xconfig.echo.port or port
			title = xconfig.echo.title
		end
		local echo_socket = assert(xsocket.udp())
		assert(echo_socket:setsockname(host or "*", port or 31523))
		log("info", "listening at udp:%s:%s", echo_socket:getsockname())
		xsocket.spawn(function ()
			while true do
				local msg, ip, port = echo_socket:receivefrom()
				if not msg then
					return log("warn", "closed")
				end
				log("debug", "got %q from %s:%s", msg, ip, port)
				echo_socket:sendto(title or VERSION, ip, port)
			end
		end)
	end
end

-- // sich // --
do
	local log = xlog("sich")
	VERSION = VERSION or "Sich DEV"
	if jit then
		_VERSION = jit.version
	end
	local host = xconfig.host or "*"
	local port = xconfig.port or 31523
	local server_socket = assert(xsocket.tcp())
	assert(server_socket:bind(host, port))
	assert(server_socket:listen(32))
	log("info", "listening at tcp:%s:%s", server_socket:getsockname())
	xsocket.spawn(
		function ()
			while true do
				xsocket.spawn(xserver, assert(server_socket:accept()))
			end
		end)
	log("info", "%s, %s", VERSION, _VERSION)
	xsocket.loop()
end

