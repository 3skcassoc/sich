require "xlog"
require "xclass"
require "xconfig"
require "xsocket"

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
