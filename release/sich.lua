--
-- Sich
-- Cossacks 3 lua server
--

VERSION = "Sich v0.1.1"

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
			return table.insert(result, (("%q"):format(value):gsub("\\\n", "\\n")))
		elseif value_type == "nil" or value_type == "boolean" or value_type == "number" then
			return table.insert(result, tostring(value))
		elseif value_type ~= "table" then
			return error("can not serialize: " .. value_type)
		end
		if next(value) == nil then
			return table.insert(result, "{}")
		end
		table.insert(result, "{\n")
		for key, val in pairs(value) do
			table.insert(result, ("\t"):rep(indent + 1))
			table.insert(result, "[")
			do_serialize(key, result, indent + 1)
			table.insert(result, "] = ")
			do_serialize(val, result, indent + 1)
			table.insert(result, ",\n")
		end
		table.insert(result, ("\t"):rep(indent))
		return table.insert(result, "}")
	end
	local function serialize(value)
		local result = {}
		do_serialize(value, result, 0)
		return table.concat(result)
	end
	local path = arg[0]:match("^(.+)[/\\][^/\\]+[/\\]?$")
	if not path then
		path = "."
	end
	log("info", "path = %s", path)
	xstore =
	{
		load = function (name, default)
			local fun, msg = loadfile(path .. "/" .. name .. ".store")
			if not fun then
				log("debug", msg)
				return default
			end
			log("info", "loading %q", name)
			setfenv(fun, _G)
			local ok, data = pcall(fun)
			if not ok then
				log("error", data)
				return default
			end
			return data
		end,
		save = function (name, data)
			log("info", "saving %q", name)
			local str = serialize(data)
			local file, msg = io.open(path .. "/" .. name .. ".store", "w")
			if not file then
				return log("error", msg)
			end
			file:write("return ", str)
			return file:close()
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
		self.indent = self.indent + ( value or 1 )
		return self
	end
	local function log_dec(self, value)
		self.indent = self.indent - ( value or 1 )
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

-- // xcmd // --
do
	local cmd =
	{
		[0x0190] = "SHELL_CONSOLE",
		[0x0191] = "PING",
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
		[0x01BA] = "",                             -- 
		[0x01BB] = "SERVER_SESSION_PARSER",        -- LanPublicServerSendSessionParser
		[0x01BC] = "USER_SESSION_PARSER",          -- leSessionParser
		[0x01BD] = "USER_SESSION_RECREATE",        -- leSessionRecreate
		[0x01BE] = "USER_SESSION_REJOIN",          -- leSessionRejoin
	}
	xcmd = {}
	for code, name in pairs(cmd) do
		xcmd[code] = name
		xcmd[name] = code
	end
	cmd = nil
end

-- // xkeys // --
do
	local log = xlog("xkeys")
	local keystore = xstore.load("keys")
	if keystore then
		local keys = {}
		for _, key in ipairs(keystore) do
			keys[key] = true
		end
		keystore = nil
		xkeys = function (cdkey)
			return keys[cdkey]
		end
	else
		log("info", "disabled")
		xkeys = function (cdkey)
			return true
		end
	end
end

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

-- // xparser // --
do
	local log = xlog("xparser")
	xparser = xclass
	{
		read = function (class, package)
			local key = package:read_long_string()
			local value = package:read_long_string()
			local count = package:read_dword()
			if not ( key and value and count ) then
				return
			end
			local self = class(key, value)
			for _ = 1, count do
				local node = class:read(package)
				if not node then
					return nil
				end
				self:append(node)
			end
			return self
		end,
		__create = function (self, key, value)
			self.key = key
			self.value = value
			self.nodes = {}
			return self
		end,
		append = function (self, node)
			table.insert(self.nodes, node)
			return self
		end,
		add = function (self, key, value)
			return self:append(xparser(key, value))
		end,
		write = function (self, package)
			package
				:write_long_string(self.key)
				:write_long_string(tostring(self.value))
				:write_dword(#self.nodes)
			for _, node in ipairs(self.nodes) do
				node:write(package)
			end
			return package
		end,
		dump = function (self, subnode)
			if not log:check("debug") then
				return
			end
			if not subnode then
				log("debug", "PARSER: key = %q, value = %q", self.key, self.value)
			else
				log("debug", "key = %q, value = %q", self.key, self.value)
			end
			log:inc()
			for _, node in ipairs(self.nodes) do
				node:dump(true)
			end
			log:dec()
		end,
	}
end

-- // xpackage // --
do
	local log = xlog("xpackage")
	local custom_package custom_package = xclass
	{
		__create = function (self, buffer, position)
			self.buffer = buffer or {}
			self.position = buffer and ( position or 1 )
			return self
		end,
		get_buffer = function (self)
			if type(self.buffer) == "table" then
				return table.concat(self.buffer)
			else
				return self.buffer
			end
		end,
		read_check = function (self, size)
			local left = ( #self.buffer - self.position + 1 )
			if size > left then
				log("error", "read_check: size=%d, left=%d", size, left)
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
			local result = self.buffer:sub(self.position, self.position + size - 1)
			self.position = self.position + size
			return result
		end,
		read_number = function (self, size)
			if not self:read_check(size) then
				return nil
			end
			local result = 0
			for i = self.position + size - 1, self.position, -1 do
				result = result * 256 + self.buffer:byte(i)
			end
			self.position = self.position + size
			return result
		end,
		read_byte = function (self)
			if not self:read_check(1) then
				return nil
			end
			local result = self.buffer:byte(self.position)
			self.position = self.position + 1
			return result
		end,
		read_boolean = function (self)
			return self:read_byte() ~= 0
		end,
		read_word = function (self)
			return self:read_number(2)
		end,
		read_dword = function (self)
			return self:read_number(4)
		end,
		read_datetime = function (self)
			return self:read_number(8)
		end,
		read_string = function (self)
			local size = self:read_byte()
			if size == nil then
				return nil
			end
			return self:read_buffer(size)
		end,
		read_long_string = function (self)
			local size = self:read_number(4)
			if size == nil then
				return nil
			end
			return self:read_buffer(size)
		end,
		read_array = function (self, format)
			local array = {}
			for i = 1, #format do
				local fmt, value = format:sub(i, i)
				if fmt == "s" then
					value = self:read_string()
				elseif fmt == "b" then
					value = ( self:read_byte() ~= 0 )
				elseif fmt == "1" then
					value = self:read_byte()
				else
					value = self:read_number(tonumber(fmt))
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
				object[select(index, ...)] = value
			end
			return object
		end,
		read = function (self, format)
			local array = self:read_array(format)
			if array == nil then
				return nil
			end
			return unpack(array)
		end,
		read_parser = function (self)
			return xparser:read(self)
		end,
		read_parser_with_size = function (self)
			local buffer = self:read_long_string()
			if buffer == nil then
				return nil
			end
			return xparser:read(custom_package(buffer))
		end,
		write_buffer = function (self, buffer)
			table.insert(self.buffer, buffer)
			return self
		end,
		write_number = function (self, size, value)
			assert(type(value) == "number", "number expected")
			local frac
			for _ = 1, size do
				value, frac = math.modf(value / 256)
				table.insert(self.buffer, string.char(frac * 256))
			end
			return self
		end,
		write_byte = function (self, value)
			assert(type(value) == "number", "number expected")
			table.insert(self.buffer, string.char(value))
			return self
		end,
		write_boolean = function (self, value)
			return self:write_byte(value and 1 or 0)
		end,
		write_word = function (self, value)
			return self:write_number(2, value)
		end,
		write_dword = function (self, value)
			return self:write_number(4, value)
		end,
		write_datetime = function (self, value)
			return self:write_number(8, value)
		end,
		write_string = function (self, value)
			assert(type(value) == "string", "string expected")
			table.insert(self.buffer, string.char(#value))
			table.insert(self.buffer, value)
			return self
		end,
		write_long_string = function (self, value)
			assert(type(value) == "string", "string expected")
			self:write_number(4, #value)
			table.insert(self.buffer, value)
			return self
		end,
		write_array = function (self, format, array)
			for i = 1, #format do
				local fmt, value = format:sub(i, i), array[i]
				if fmt == "s" then
					self:write_string(value)
				elseif fmt == "b" then
					table.insert(self.buffer, string.char(value and 1 or 0))
				elseif fmt == "1" then
					assert(type(value) == "number", "number expected")
					table.insert(self.buffer, string.char(value))
				else
					self:write_number(tonumber(fmt), value)
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
		write = function (self, format, ...)
			return self:write_array(format, {...})
		end,
		write_parser = function (self, parser)
			return parser:write(self)
		end,
		write_parser_with_size = function (self, parser)
			local buffer = custom_package()
				:write_parser(parser)
				:get_buffer()
			return self:write_long_string(buffer)
		end,
	}
	xpackage = xclass
	{
		__parent = custom_package,
		__create = function (self, code, id_from, id_to, buffer)
			self = custom_package.__create(self, buffer)
			self.code = assert(code, "no code")
			self.id_from = assert(id_from, "no id_from")
			self.id_to = assert(id_to, "no id_to")
			return self
		end,
		receive = function (class, socket)
			local head = socket:receive(4 + 2 + 4 + 4)
			if not head then
				return nil
			end
			local payload_length, code, id_from, id_to =
				custom_package(head):read("4244")
			local payload = socket:receive(payload_length)
			if not payload then
				return nil
			end
			return class(code, id_from, id_to, payload)
		end,
		get = function (self)
			local payload = self:get_buffer()
			return custom_package()
				:write_array("4244", {#payload, self.code, self.id_from, self.id_to})
				:write_buffer(payload)
				:get_buffer()
		end,
		dump_head = function (self)
			return log("debug", "%04X %s  id_from=%d id_to=%d",
				self.code, xcmd[self.code] or "UNKNOWN", self.id_from, self.id_to)
		end,
		dump_payload = function (self)
			if not log:check("debug") then
				return
			end
			local pos = 1
			local buffer = self:get_buffer()
			while pos <= #buffer do
				local line = buffer:sub(pos, pos + 16 - 1)
				local hex = 
					line:gsub(".", function (c) return ("%02X "):format(c:byte()) end)
					..
					("   "):rep( #buffer - pos < 17 and 15 - (#buffer - pos) or 0 )
				log("debug", "%04X | %s %s| %s",
					pos - 1,
					hex:sub(1, 24),
					hex:sub(25),
					(line:gsub("%c", "?")))
				pos = pos + 16
			end
		end,
		transmit = function (self, client)
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
	}
end

-- // xpacket // --
do
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
end

-- // xregister // --
do
	local log = xlog("xregister")
	register = xstore.load("register", {})
	local next_id = 1
	for _, account in pairs(register) do
		if account.id >= next_id then
			next_id = account.id + 1
		end
	end
	log("debug", "next_id = %d", next_id)
	local function save_register()
		return xstore.save("register", register)
	end
	local function assign(client, email, account)
		client.email = email
		client.password = account.password
		client.cdkey = account.cdkey
		client.nickname = account.nickname
		client.country = account.country
		client.info = account.info
		client.id = account.id
		client.score = account.score
		client.games_played = account.games_played
		client.games_win = account.games_win
		client.last_game = account.last_game
		client.blocked = account.blocked
		return true
	end
	xregister =
	{
		new = function (client, email, password, cdkey, nickname, country, info)
			if register[email:lower()] then
				return false
			end
			log("info", "registering new user: %s", email)
			local account = {
				password = password,
				cdkey = cdkey,
				nickname = nickname,
				country = country,
				info = info,
				id = next_id,
				score = 0,
				games_played = 0,
				games_win = 0,
				last_game = 0,
				blocked = false,
			}
			next_id = next_id + 1
			register[email:lower()] = account
			save_register()
			return assign(client, email, account)
		end,
		get = function (client, email)
			local account = register[email:lower()]
			if not account then
				return false
			end
			return assign(client, email, account)
		end,
		find = function (email)
			return register[email:lower()] ~= nil
		end,
		update = function (client, email, password, nickname, country, info)
			local account = register[email:lower()]
			if not account then
				return false
			end
			log("info", "updating user info: %s", email)
			account.password = password
			account.nickname = nickname
			account.country = country
			account.info = info
			save_register()
			return assign(client, email, account)
		end,
		block = function (email, blocked)
			local account = register[email:lower()]
			if not account then
				return false
			end
			account.blocked = blocked
			save_register()
			return true
		end,
	}
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
			self.team = 0
			self.states = 0
			self.rejoin = nil
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
				self.clients[package.id_to].socket:send(package:get())
			end
			return package
		end,
	}
end

-- // xsession // --
do
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
			self.justname, self.justpass = self.gamename:match('"(.-)"\t"(.-)"')
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
			self.justname, self.justpass = self.gamename:match('"(.-)"\t"(.-)"')
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
				:broadcast(remote)
		end,
	}
end

-- // xserver // --
do
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
			log("debug", "remote is not session master")
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
			return self:master_session_action("client_update", remote, request)
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
				-- 4 data version is outdated
				remote.log("warn", "requested unknown core version: %s", request.vcore)
			end
			if not datas[request.vdata] then
				-- 5 core version is outdated
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
				packet:dump_head()
				if code ~= xcmd.SERVER_SESSION_PARSER then
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
	end
end

-- // xsocket // --
do
	local socket = require "socket"
	local log = xlog("xsocket")
	local sendt = {}
	local recvt = {}
	local wrap = {}
	local wrapper wrapper = setmetatable(
	{
		accept = function (self)
			if self.closed then
				return nil, "closed"
			end
			while true do
				coroutine.yield(self.sock, recvt)
				local client, err = self.sock:accept()
				if client then
					client:setoption("tcp-nodelay", true)
					return wrapper(client)
				elseif err ~= "timeout" then
					log("debug", "socket error: %s", err)
					self.closed = true
					return nil, err
				end
			end
		end,
		send = function (self, data)
			if self.closed then
				return nil, "closed"
			end
			local pos = 1
			while pos <= #data do
				coroutine.yield(self.sock, sendt)
				local sent, err, last = self.sock:send(data, pos)
				if sent then
					return true
				elseif err == "timeout" then
					pos = last + 1
				else
					log("debug", "socket error: %s", err)
					self.closed = true
					return false
				end
			end
			return true
		end,
		sendto = function (self, data, ip, port)
			if self.closed then
				return nil, "closed"
			end
			while true do
				coroutine.yield(self.sock, sendt)
				local ok, err = self.sock:sendto(data, ip, port)
				if ok then
					return ok
				elseif err ~= "timeout" then
					log("debug", "socket error: %s", err)
					self.closed = true
					return nil, err
				end
			end
		end,
		receive = function (self, size)
			if self.closed then
				return nil, "closed"
			end
			local buffer = { self.stored }
			local buffer_size = #self.stored
			while size > buffer_size do
				coroutine.yield(self.sock, recvt)
				local data, err, partial = self.sock:receive(32 * 1024)
				if err == "timeout" then
					data = partial
				elseif not data then
					log("debug", "socket error: %s", err)
					self.closed = true
					return nil, err
				end
				table.insert(buffer, data)
				buffer_size = buffer_size + #data
			end
			buffer = table.concat(buffer)
			self.stored = buffer:sub(size + 1)
			return buffer:sub(1, size)
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
					log("debug", "socket error: %s", ip)
					self.closed = true
					return nil, ip
				end
			end
		end,
		close = function (self)
			self.closed = true
			self.sock:shutdown("both")
			return self.sock:close()
		end,
	},
	{
		__index = function (wrapper, name)
			log("debug", "missing wrapper:%s()", name)
			wrapper[name] = function (self, ...)
				return self.sock[name](self.sock, ...)
			end
			return wrapper[name]
		end,
		__call = function (wrapper, sock)
			log("debug", "socket created")
			sock:settimeout(0)
			wrap[sock] =
			{
				sock = sock,
				closed = false,
				stored = "",
			}
			return setmetatable(wrap[sock], wrapper.index_mt)
		end,
	})
	wrapper.index_mt = {
		__index = wrapper,
	}
	function append(thread, success, sock, set)
		if not success then
			xsocket.threads = xsocket.threads - 1
			log("error", "thread crashed: %s", sock)
			return print(debug.traceback(thread))
		end
		if not sock then
			xsocket.threads = xsocket.threads - 1
			return log("debug", "thread stopped")
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
	function resume(sock, set)
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
	xsocket =
	{
		threads = 0,
		tcp = function ()
			local sock = socket.tcp()
			sock:setoption("reuseaddr", true)
			return wrapper(sock)
		end,
		udp = function ()
			local sock = socket.udp()
			sock:setoption("reuseaddr", true)
			return wrapper(sock)
		end,
		spawn = function (func, ...)
			local thread = coroutine.create(
				function (...)
					func(...)
					return nil, nil
				end)
			log("debug", "starting thread")
			xsocket.threads = xsocket.threads + 1
			return append(thread, coroutine.resume(thread, ...))
		end,
		loop = function ()
			while true do
				for _, sock in ipairs(recvt) do
					if wrap[sock].closed then
						resume(sock, recvt)
					end
				end
				for _, sock in ipairs(sendt) do
					if wrap[sock].closed then
						resume(sock, sendt)
					end
				end
				local read, write = socket.select(recvt, sendt)
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

-- // xadmin // --
do
	local log = xlog("xadmin")
	if not xconfig.admin then
		log("info", "disabled")
	else
		local function find_user(who)
			local id = tonumber(who)
			for email, account in pairs(register) do
				if email == who
				or account.id == id
				or account.nickname == who
				then
					return email, account.id
				end
			end
			return nil, nil
		end
		local function find_remote(id)
			for _, server in pairs(servers) do
				for client_id, client in pairs(server.clients) do
					if client_id == id then
						return client
					end
				end
			end
			return nil
		end
		local table_head
		local table_cols
		local table_rows
		local function table_begin(...)
			table_head = {...}
			table_cols = {}
			table_rows = {}
			for i, head in ipairs(table_head) do
				table_cols[i] = #head
			end
		end
		local function table_row(...)
			local row = {}
			for i, cell in ipairs {...} do
				cell = tostring(cell)
				row[i] = cell
				if ( not table_cols[i] )
				or ( table_cols[i] < #cell ) then
					table_cols[i] = #cell
				end
			end
			table_rows[#table_rows + 1] = row
		end
		local function table_end(socket)
			local row_strips = {}
			local row_format = {}
			for _, col in ipairs(table_cols) do
				table.insert(row_strips, ("-"):rep(col))
				table.insert(row_format, "%-" .. col .. "s")
			end
			row_strips = "+-" .. table.concat(row_strips, "-+-") .. "-+\r\n"
			row_format = "| " .. table.concat(row_format, " | ") .. " |\r\n"
			local buffer = {}
			table.insert(buffer, row_strips)
			if #table_head > 0 then
				table.insert(buffer, row_format:format(unpack(table_head)))
				table.insert(buffer, row_strips)
			end
			for _, row in ipairs(table_rows) do
				table.insert(buffer, row_format:format(unpack(row)))
			end
			table.insert(buffer, row_strips)
			table_head = nil
			table_cols = nil
			table_rows = nil
			return socket:send(table.concat(buffer))
		end
		local function writeln(socket, fmt, ...)
			return socket:send((fmt .. "\r\n"):format(...))
		end
		local commands = {}
		local function command(name, description, argc, handler)
			local command =
			{
				name = name,
				description = description,
				argc = argc,
				handler = handler,
			}
			commands[#commands + 1] = command
			commands[name] = command
		end
		command("exit", "close this console", 0, function (socket)
			return socket:close()
		end)
		command("info", "server info", 0, function (socket)
			table_begin()
			local users = 0
			for _, account in pairs(register) do
				if type(account) == "table" then
					users = users + 1
				end
			end
			table_row("registered users", users)
			users = 0
			for _, server in pairs(servers) do
				for _ in pairs(server.clients) do
					users = users + 1
				end
			end
			table_row("online users", users)
			table_row("running threads", xsocket.threads)
			return table_end(socket)
		end)
		command("reg", "list registered users", 0, function (socket)
			local byid = {}
			for email, account in pairs(register) do
				if type(account) == "table" then
					byid[#byid + 1] = email:lower()
				end
			end
			table.sort(byid, function (a, b) return register[a].id < register[b].id end)
			table_begin("id", "email", "nickname", "password", "blocked")
			for _, email in ipairs(byid) do
				local account = register[email]
				table_row(account.id, email, account.nickname, account.password, tostring(account.blocked))
			end
			return table_end(socket)
		end)
		command("users", "list online users", 0, function (socket)
			table_begin("vcore/vdata", "id", "nickname", "session", "state")
			for client in pairs(auth_server.clients) do
				table_row("", "", client.host .. ":" .. client.port, "", "auth")
			end
			for tag, server in pairs(servers) do
				for _, client in pairs(server.clients) do
					local state
					for _, state_name in ipairs {"played", "master", "session", "online"} do
						if client:get_state(state_name) then
							state = state_name
							break
						end
					end
					local session_name = client.session and client.session.justname or ""
					table_row(tag, client.id, client.nickname, session_name, state)
				end
			end
			return table_end(socket)
		end)
		command("sessions", "list sessions", 0, function (socket)
			table_begin("vcore/vdata", "name", "password", "state", "users")
			for tag, server in pairs(servers) do
				for _, session in pairs(server.sessions) do
					local state = ""
					if session.locked then
						state = "locked"
					elseif session.closed then
						state = "closed"
					end
					table_row(tag, session.justname, session.justpass, state, session.master.nickname)
					for _, client in pairs(session.clients) do
						if client ~= session.master then
							table_row("", "", "", "", client.nickname)
						end
					end
				end
			end
			return table_end(socket)
		end)
		command("kick", "kick <user>", 1, function (socket, who)
			local _, id = find_user(who)
			if not id then
				return writeln(socket, "not registered")
			end
			local remote = find_remote(id)
			if not remote then
				return writeln(socket, "user is offline")
			end
			remote.socket:close()
			return writeln(socket, "kicked: #%d %s", remote.id, remote.nickname)
		end)
		command("block", "block <user>", 1, function (socket, who)
			local email = find_user(who)
			if not ( email and xregister.block(email, true) ) then
				return writeln(socket, "unknown user: %s", who)
			end
			return writeln(socket, "account blocked: %s", email)
		end)
		command("unblock", "unblock <user>", 1, function (socket, who)
			local email = find_user(who)
			if not ( email and xregister.block(email, false) ) then
				return writeln(socket, "unknown user: %s", who)
			end
			return writeln(socket, "account unblocked: %s", email)
		end)
		command("stop", "stop server", 0, function (socket)
			return os.exit()
		end)
		command("help", "print available commands", 0, function (socket, cmd)
			if cmd and commands[cmd] then
				return writeln(socket, "%s", commands[cmd].description)
			end
			table_begin()
			for _, command in ipairs(commands) do
				table_row(command.name, command.description)
			end
			return table_end(socket)
		end)
		local function process(socket, cmd, argv)
			if #cmd < 3 then
				return writeln(socket, "type at least 3 first letters of command")
			end
			local selected = nil
			local pattern = "^" .. cmd:gsub("%W", "%%%1")
			for _, command in ipairs(commands) do
				if command.name:match(pattern) then
					if selected == nil then
						selected = command
					elseif selected == false then
						writeln(socket, "? %s", command.name)
					else
						writeln(socket, "? %s", selected.name)
						writeln(socket, "? %s", command.name)
						selected = false
					end
				end
			end
			if selected == nil then
				return writeln(socket, "unknown command")
			end
			if selected == false then
				return writeln(socket, "ambiguous command")
			end
			if #argv < selected.argc then
				return writeln(socket, "command requires at least %d argument%s", selected.argc, selected.argc > 1 and "s" or "")
			end
			return selected.handler(socket, unpack(argv))
		end
		local function repl(socket)
			writeln(socket, "Welcome to %s", VERSION)
			while true do
				socket:send("> ")
				local line = {}
				while true do
					local char, err, byte = socket:receive(1)
					if not char then
						return
					end
					byte = char:byte()
					if byte == 8 then
						line[#line] = nil
					elseif byte == 13 then
						line = table.concat(line)
						break
					elseif byte >= 32 then
						line[#line + 1] = char
					end
				end
				log("debug", "exec: %s", line)
				local words = {}
				for word in line:gmatch("[%S]+") do
					table.insert(words, word)
				end
				if words[1] then
					process(socket, table.remove(words, 1), words)
				end
			end
		end
		local host, port = assert(xconfig.admin.host), assert(xconfig.admin.port)
		local server_socket = assert(xsocket.tcp())
		assert(server_socket:bind(host, port))
		assert(server_socket:listen(32))
		log("info", "listening at tcp:%s:%s", server_socket:getsockname())
		xsocket.spawn(
			function ()
				while true do
					xsocket.spawn(
						function (client_socket)
							log("info", "connected from %s:%s", client_socket:getpeername())
							repl(client_socket)
							client_socket:close()
							log("info", "disconnected")
						end,
						assert(server_socket:accept()))
				end
			end)
	end
end

-- // xecho // --
do
	local log = xlog("xecho")
	local host = "*"
	local port = 31523
	local title = nil
	if type(xconfig.echo) == "table" then
		host = xconfig.echo.host or host
		port = xconfig.echo.port or port
		title = xconfig.echo.title
	end
	if xconfig.echo == false then
		log("info", "disabled") 
	else
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
	log("info", "%s", VERSION)
	local host = xconfig.host or "*"
	local port = xconfig.port or 31523
	local server_socket = assert(xsocket.tcp())
	assert(server_socket:bind(host, port))
	assert(server_socket:listen(32))
	log("info", "listening at tcp:%s:%s", server_socket:getsockname())
	xsocket.spawn(
		function ()
			while true do
				xsocket.spawn(
					function (client_socket)
						xserver(client_socket)
						client_socket:close()
					end,
					assert(server_socket:accept()))
			end
		end)
	xsocket.loop()
end

