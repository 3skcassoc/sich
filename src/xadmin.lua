require "xlog"
require "xclass"
require "xconfig"
require "xsocket"

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
