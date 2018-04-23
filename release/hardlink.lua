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
			self.closed = true
			return nil, err
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
			log("error", "thread crashed: %s", sock)
			return print(debug.traceback(thread))
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
			local sock, msg = socket.tcp()
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
			local sock, msg = socket.udp()
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
			coroutine.yield(socket.gettime() + sec, slept)
		end,
		sleep_until = function (ts)
			if ts > socket.gettime() then
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
					local now = socket.gettime()
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
					timeout = math.max(0, timeout - socket.gettime())
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
			log("debug", "%skey = %q, value = %q", (subnode and "" or "PARSER: "), self.key, self.value)
			log:inc()
			for _, node in ipairs(self.nodes) do
				node:dump(true)
			end
			log:dec()
		end,
	}
end

-- // xpack // --
do
	local log = xlog("xpack")
	xpack = xclass
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
			return xparser:read(xpack(buffer))
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
			local buffer = xpack()
				:write_parser(parser)
				:get_buffer()
			return self:write_long_string(buffer)
		end,
	}
end

-- // xlink // --
do
	local log = xlog("link")
	math.randomseed(os.time())
	local next_uid = (math.random(0, 255) * 256 + math.random(0, 255)) * 256 * 256
	local function async_call(async, func, ...)
		if async then
			xsocket.spawn(func, ...)
		else
			func(...)
		end
	end
	xlink = xclass
	{
		links = {},
		connect = function (class, uid, rhost, rport)
			local socket = assert(xsocket.tcp())
			if not socket:connect(rhost, rport) then
				return nil
			end
			return class(uid, socket, rhost, rport)
		end,
		__create = function (self, uid, socket, rhost, rport)
			self.uid = uid or self:gen_uid()
			assert(not self.links[self.uid], "duplicate uid")
			self.links[self.uid] = self
			self.socket = assert(socket, "no socket")
			self.rhost = rhost
			self.rport = rport
			self.queue = {}
			self.queue_add = 0
			self.queue_seq = 0
			self.recv_seq = 0
			self.hard = nil
			self.active = false
			xsocket.spawn(self.process, self)
			return self
		end,
		free = function (self, notify, async)
			if not self.links[self.uid] then
				return
			end
			self.links[self.uid] = nil
			if notify and self.hard then
				self.hard:send_D(self)
			end
			async_call(async, function ()
				self.socket:send("")
				log("info", "[%08x] close: %s:%s", self.uid, self.rhost, self.rport)
				self.socket:close()
				self.socket = nil
				self.hard = nil
				self.active = false
			end)
		end,
		gen_uid = function (self)
			next_uid = next_uid + 1
			return next_uid
		end,
		send = function (self, data, async)
			if not self.socket then
				return false
			end
			async_call(async, function ()
				local ok = self.socket:send(data)
				if not ok then
					self:free(true, false)
					return
				end
				if self.hard then
					self.hard:send_A(self)
				end
			end)
			return true
		end,
		dispatch_queue = function (self, async)
			if not self.active then
				return
			end
			async_call(async, function ()
				while self.queue_seq < self.queue_add do
					local seq = self.queue_seq + 1
					local data = self.queue[seq]
					self.queue_seq = seq
					if not self.hard then
						return
					end
					if not self.hard:send_B(self, seq, data) then
						return
					end
				end
			end)
		end,
		eck = function (self, seq)
			if not self:ack(seq) then
				return false
			end
			self.queue_seq = seq
			self.active = true
			return true
		end,
		ack = function (self, seq)
			if seq ~= self.queue_add and not self.queue[seq + 1] then
				log("error", "[%08x] invalid ack: seq=%u, queue_seq=%u, queue_add=%u", self.uid, seq, self.queue_seq, self.queue_add)
				self:free(true, true)
				return false
			end
			if seq > self.queue_seq then
				log("warn", "[%08x] late seq: seq=%u, queue_seq=%u, queue_add=%u", self.uid, seq, self.queue_seq, self.queue_add)
				self.queue_seq = seq
			end
			while self.queue[seq] do
				self.queue[seq] = nil
				seq = seq - 1
			end
			return true
		end,
		process = function (self)
			while self.socket do
				local data, msg = self.socket:receive()
				if not data then
					break
				end
				self.queue_add = self.queue_add + 1
				self.queue[self.queue_add] = data
				self:dispatch_queue(true)
			end
			self:free(true, false)
		end,
	}
end

-- // xsocks // --
do
	local log = xlog("socks")
	local function make_addr(ip0, ip1, ip2, ip3)
		return ("%u.%u.%u.%u"):format(ip0, ip1, ip2, ip3)
	end
	local function make_port(port0, port1)
		return port0 * 256 + port1
	end
	xsocks = xclass
	{
		__create = function (self, socket)
			self.ver = 0
			self.socket = socket
			return self
		end,
		receive = function (self, count)
			local data = self.socket:receive(count)
			if not data then
				return nil
			end
			return data:byte(1, count)
		end,
		receive_string = function (self)
			local len = self:receive(1)
			if not len then
				return nil
			end
			return self.socket:receive(len)
		end,
		receive_null_string = function (self)
			local result = {}
			while true do
				local b = self:receive(1)
				if not b then
					return nil
				end
				if b == 0 then
					break
				end
				table.insert(result, b)
			end
			return string.char(unpack(result))
		end,
		send = function (self, ...)
			local buffer = {}
			for _, c in ipairs {...} do
				if type(c) == "string" then
					table.insert(buffer, string.char(#c))
					table.insert(buffer, c)
				else
					table.insert(buffer, string.char(c))
				end
			end
			return self.socket:send(table.concat(buffer))
		end,
		process = function (self)
			local ver = self:receive(1)
			if not ver then
				return
			end
			local proc = ("process_%u"):format(ver)
			if not self[proc] then
				return
			end
			self.ver = ver
			return self[proc](self)
		end,
		process_4 = function (self)
			-- VER CMD PORT DSTIP USERID NULL
			--   1   1    2     4      L   00
			local cmd, port0, port1, ip0, ip1, ip2, ip3 = self:receive(7)
			if not cmd then
				return
			end
			local user_id = self:receive_null_string()
			if not user_id then
				return
			end
			if cmd ~= 0x01 then
				log("warn", "socks4: not CONNECT")
				return
			end
			local host = make_addr(ip0, ip1, ip2, ip3)
			local port = make_port(port0, port1)
			if host:match("^0.0.0.") then
				host = self:receive_null_string()
				if not host then
					return
				end
			end
			-- VER CMD PORT DSTIP
			--   1   1    2     4
			--     self:send(0, 0x5B, 0,0, 0,0,0,0)
			if not self:send(0, 0x5A, math.random(0, 255),math.random(0, 255), 0,0,0,0) then
				return
			end
			return host, port
		end,
		process_5 = function (self)
			-- VER NMETHODS METHODS
			--   1        1       N
			local nmet = self:receive(1)
			if not nmet then
				return
			end
			local mets = { self:receive(nmet) }
			if #mets == 0 then
				log("error", "no methods")
				return
			end
			local no_auth = false
			for _, met in ipairs(mets) do
				if met == 0x00 then
					no_auth = true
				end
			end
			-- VER METHODS
			--   1       1
			if not no_auth then
				log("error", "need auth")
				self:send(5, 0xFF)
				return
			end
			if not self:send(5, 0x00) then
				return
			end
			-- VER CMD RSV ATYP ADDR PORT
			--   1   1  00    1    L    2
			local ver, cmd, rsv, atyp = self:receive(4)
			if not ver or rsv ~= 0x00 then
				return
			end
			if cmd ~= 0x01 then
				log("warn", "socks5: not CONNECT")
				return
			end
			local host
			if atyp == 0x01 then
				local ip0, ip1, ip2, ip3 = self:receive(4)
				if not ip0 then
					return
				end
				host = make_addr(ip0, ip1, ip2, ip3)
			elseif atyp == 0x03 then
				host = self:receive_string()
				if not host then
					return
				end
			elseif atyp == 0x04 then
				log("warn", "socks5: IPv6")
				return
			end
			local port0, port1 = self:receive(2)
			if not port0 then
				return
			end
			local port = make_port(port0, port1)
			-- VER REP RSV ATYP ADDR PORT
			--   1   1  00    1    L    2
			--     self:send(5, 0x01, 0x00, 0x03, host, 0,0)
			if not self:send(5, 0x00, 0x00, 0x03, host, math.random(0, 255),math.random(0, 255)) then
				return
			end
			return host, port
		end,
	}
end

-- // xhard // --
do
	local log = xlog("hard")
	local function hardpack(cmd, uid, seq, payload)
		local pack = xpack(payload)
		pack.cmd = assert(cmd, "no cmd")
		pack.uid = assert(uid, "no uid")
		pack.seq = assert(seq, "no seq")
		return pack
	end
	xhard = xclass
	{
		__create = function (self, socket, host, port)
			self.socket = socket
			self.host = host
			self.port = port
			xsocket.spawn(self.process, self)
			return self
		end,
		stop = function (self)
			if self.socket then
				self.socket:close()
				self.socket = nil
			end
		end,
		receive = function (self)
			if not self.socket then
				return nil
			end
			local head = self.socket:receive(1 + 4 + 4 + 3)
			if not head then
				return nil
			end
			local cmd, uid, seq, length = xpack(head):read("1443")
			local payload = self.socket:receive(length)
			if not payload then
				return nil
			end
			return hardpack(cmd, uid, seq, payload)
		end,
		send = function (self, pack)
			if not self.socket then
				return false
			end
			local payload = pack:get_buffer()
			local data = xpack()
				:write("1443", pack.cmd, pack.uid, pack.seq, #payload)
				:write_buffer(payload)
				:get_buffer()
			if not self.socket:send(data) then
				self:stop()
				return false
			end
			return true
		end,
		send_C = function (self, link)
			local cmd_C = hardpack(0xC, link.uid, link.recv_seq)
				:write_string(link.rhost)
				:write_word(link.rport)
			if not self:send(cmd_C) then
				log("error", "send_C: failed")
				return false
			end
			link.hard = self
			return true
		end,
		send_D = function (self, link, uid)
			uid = link and link.uid or uid
			local cmd_D = hardpack(0xD, uid, 0)
			if not self:send(cmd_D) then
				log("error", "send_D: failed")
				return false
			end
			return true
		end,
		send_B = function (self, link, seq, data)
			local cmd_B = hardpack(0xB, link.uid, seq)
				:write_buffer(data)
			if not self:send(cmd_B) then
				log("error", "send_B: failed")
				return false
			end
			return true
		end,
		send_E = function (self, link)
			if not link.hard then
				log("error", "send_E: not hard")
				return false
			end
			local cmd_E = hardpack(0xE, link.uid, link.recv_seq)
			if not self:send(cmd_E) then
				log("error", "send_E: failed")
				return false
			end
			return true
		end,
		send_A = function (self, link)
			if not link.hard then
				log("error", "send_A: not hard")
				return false
			end
			local cmd_A = hardpack(0xA, link.uid, link.recv_seq)
			if not self:send(cmd_A) then
				log("error", "send_A: failed")
				return false
			end
			return true
		end,
		cmd_C = function (self, pack, link)
			local rhost = pack:read_string()
			local rport = pack:read_word()
			if (not link) and (pack.seq ~= 0) then
				self:send_D(nil, pack.uid)
				return true, "broken link"
			end
			xsocket.spawn(function ()
				if not link then
					log("info", "[%08x] forward: %s:%s", pack.uid, rhost, rport)
					link = xlink:connect(pack.uid, rhost, rport)
					if not link then
						log("info", "[%08x] no response", pack.uid)
						self:send_D(nil, pack.uid)
						return
					end
				end
				if not link:eck(pack.seq) then
					return
				end
				link.hard = self
				self:send_E(link)
				link:dispatch_queue(false)
			end)
			return true
		end,
		cmd_D = function (self, pack, link)
			if not link then
				return true, "unknown uid"
			end
			link:free(false, true)
			return true
		end,
		cmd_B = function (self, pack, link)
			local data = pack:read_all()
			if not link then
				self:send_D(nil, pack.uid)
				return true, "unknown uid"
			end
			if pack.seq < link.recv_seq + 1 then
				self:send_A(link)
				return true, "duplicate packet"
			end
			if pack.seq > link.recv_seq + 1 then
				link:free(true, true)
				return true, "broken link"
			end
			link.recv_seq = pack.seq
			if not link:send(data, true) then
				return true, "data send failed"
			end
			return true
		end,
		cmd_E = function (self, pack, link)
			if not link then
				self:send_D(nil, pack.uid)
				return true, "unknown uid"
			end
			if not link:eck(pack.seq) then
				return true, "bad ack"
			end
			link:dispatch_queue(true)
			return true
		end,
		cmd_A = function (self, pack, link)
			if not link then
				return true
			end
			if not link:ack(pack.seq) then
				return true, "bad ack"
			end
			return true
		end,
		process = function (self)
			local host, port = self.socket:getpeername()
			log("info", "connected to %s:%s", host, port)
			while true do
				local pack = self:receive()
				if not pack then
					break
				end
				local ok, err
				local func = self[("cmd_%X"):format(pack.cmd)]
				if not func then
					ok, err = false, "unknown"
				else
					ok, err = func(self, pack, xlink.links[pack.uid])
				end
				if err then
					log("error", "[%08x] cmd_%X: error=%s", pack.uid, pack.cmd, err)
				end
				if not ok then
					break
				end
			end
			for uid, link in pairs(xlink.links) do
				if link.hard == self then
					link.hard = nil
					link.active = false
				end
			end
			self:stop()
			log("info", "disconnected from %s:%s", host, port)
		end,
	}
	xhard_server = xclass
	{
		__parent = xhard,
		start = function (class, host, port)
			local socket = assert(xsocket.tcp())
			assert(socket:bind(host, port))
			assert(socket:listen(32))
			log("info", "listening at tcp:%s:%s", socket:getsockname())
			xsocket.spawn(
				function ()
					while true do
						class(assert(socket:accept()))
					end
				end)
		end,
	}
	xhard_client = xclass
	{
		__parent = xhard,
		dynamic_forward = function (self, lhost, lport)
			local socket = assert(xsocket.tcp())
			assert(socket:bind(lhost, lport))
			assert(socket:listen(32))
			log("info", "listening at tcp:%s:%s", socket:getsockname())
			xsocket.spawn(
				function ()
					while true do
						local socks = xsocks(assert(socket:accept()))
						xsocket.spawn(function ()
							local rhost, rport = socks:process()
							if not rhost then
								socks.socket:close()
								return
							end
							local link = xlink(nil, socks.socket, rhost, rport)
							log("info", "[%08x] socks%u: %s:%s", link.uid, socks.ver, rhost, rport)
							self:send_C(link)
						end)
					end
				end)
		end,
		local_forward = function (self, lhost, lport, rhost, rport)
			local socket = assert(xsocket.tcp())
			assert(socket:bind(lhost, lport))
			assert(socket:listen(32))
			log("info", "listening at tcp:%s:%s", socket:getsockname())
			xsocket.spawn(
				function ()
					while true do
						local link = xlink(nil, assert(socket:accept()), rhost, rport)
						log("info", "[%08x] local: %s:%s => %s:%s", link.uid, lhost, lport, rhost, rport)
						self:send_C(link)
					end
				end)
		end,
		process = function (self)
			while true do
				local socket = assert(xsocket.tcp())
				log("info", "connecting to %s:%s", self.host, self.port)
				while true do
					if socket:connect(self.host, self.port) then
						break
					end
					xsocket.sleep(1.0)
				end
				local start_time = xsocket.gettime()
				do
					self.socket = socket
					for uid, link in pairs(xlink.links) do
						if not self:send_C(link) then
							break
						end
					end
					if self.socket then
						xhard.process(self)
					end
				end
				xsocket.sleep_until(start_time + 1.0)
			end
		end,
	}
end

-- // xcmdline // --
do
	local log = xlog("cmdline")
	xcmdline = xclass
	{
		__create = function (self, args)
			if args then
				self:parse(args)
			else
				self:clear()
			end
			return self
		end,
		clear = function (self)
			self.command = ""
			self.filename = ""
			self.shorts = {}
			self.longs = {}
			self.positionals = {}
		end,
		parse = function (self, args)
			self:clear()
			self.command = args[0]
			self.filename = args[0]:match("([^/\\]+)$")
			local dest, double_dash
			for _, arg in ipairs(args) do
				if double_dash then
					table.insert(self.positionals, arg)
				elseif arg == "--" then
					double_dash = true
				elseif arg:sub(1, 1) == "-" then
					local name, eq, value = arg:match("^%-%-([^%-=]+)(=?)(.*)$")
					if name then
						dest = self.longs[name] or {}
						self.longs[name] = dest
						if eq == "=" and value ~= "" then
							table.insert(dest, value:match('^"(.*)"$') or value)
							dest = nil
						end
					else
						name, value = arg:match("^%-([^%-])(.*)$")
						if name then
							dest = self.shorts[name] or {}
							self.shorts[name] = dest
							if value ~= "" then
								table.insert(dest, value)
								dest = nil
							end
						else
							log("warn", "unparsed arg: [%s]", arg)
							dest = nil
						end
					end
				elseif dest then
					table.insert(dest, arg)
					dest = nil
				else
					table.insert(self.positionals, arg)
				end
			end
		end,
		get = function (self, short, long, remove)
			local short_value = short and self.shorts[short]
			local long_value = long and self.longs[long]
			if short_value and long_value then
				log("warn", "args: short=[%s], long=[%s]", table.concat(short_value, ", "), table.concat(long_value, ", "))
			end
			if remove then
				self.shorts[short or 1] = nil
				self.longs[long or 1] = nil
			end
			return long_value or short_value
		end,
	}
end

-- // hardlink // --
do
	local log = xlog("hardlink")
	local function explode(str, pattern)
		local result = {}
		for sub in str:gmatch(pattern) do
			table.insert(result, sub)
		end
		return result
	end
	local function get_addr_2(str)
		local parts = explode(str, "[^:]+")
		local host, port = "*", nil
		if #parts == 1 then
			port = unpack(parts)
		elseif #parts == 2 then
			host, port = unpack(parts)
		else
			log("debug", "get_addr_2() failed on [%s]", str)
			return nil
		end
		return host, tonumber(port)
	end
	local function get_addr_4(str)
		local parts = explode(str, "[^:]+")
		local host1, port1, host2, port2 = "*", nil, "*", nil
		if #parts == 1 then
			port2 = unpack(parts)
			port1 = port2
		elseif #parts == 2 then
			host2, port2 = unpack(parts)
			port1 = port2
		elseif #parts == 3 then
			port1, host2, port2 = unpack(parts)
		elseif #parts == 4 then
			host1, port1, host2, port2 = unpack(parts)
		else
			log("debug", "get_addr_4() failed on [%s]", str)
			return nil
		end
		return host1, tonumber(port1), host2, tonumber(port2)
	end
	local function mpairs(...)
		local function loop(dst, src, ...)
			if not src then
				return ipairs(dst)
			end
			for _, value in ipairs(src) do
				table.insert(dst, value)
			end
			return loop(dst, ...)
		end
		return loop({}, ...)
	end
	local cmdline = xcmdline(arg)
	local function usage(mode)
		log.minlevel = 0
		if not mode or mode == "server" then
			log("info", "usage: %s [-s|--server] [[host:]port]", cmdline.filename)
		end
		if not mode or mode == "client" then
			log("info", "usage: %s [-c|--client] [[host:]port] [port_forwarding]", cmdline.filename)
			log("info", "  port_forwarding: -D[host:]port -L[[[lhost:]lport:]rhost:]rport")
		end
	end
	local opt_help = cmdline:get("h", "help", true)
	local opt_server = cmdline:get("s", "server", true)
	local opt_client = cmdline:get("c", "client", true)
	local opt_dynamic = cmdline:get("D", "dynamic", true)
	local opt_local = cmdline:get("L", "local", true)
	if opt_help then
		return usage()
	end
	local opt_mode = nil
	if opt_server and opt_client then
		log("error", "requested both server and client mode")
		return usage()
	elseif opt_server then
		opt_mode = "server"
	elseif opt_client then
		opt_mode = "client"
	end
	local cfg = xconfig.hardlink or {}
	local mode = opt_mode or cfg.mode
	local unknown_args = {}
	for name in pairs(cmdline.shorts) do
		table.insert(unknown_args, "-"..name)
	end
	for name in pairs(cmdline.longs) do
		table.insert(unknown_args, "--"..name)
	end
	for _, value in ipairs(cmdline.positionals) do
		table.insert(unknown_args, value)
	end
	if #unknown_args > 0 then
		log("error", "unknown args: %s", table.concat(unknown_args, ", "))
		return usage(opt_mode)
	end
	if mode == "server" then
		local cfg = xconfig.hardlink and xconfig.hardlink.server or {}
		local host, port = cfg.host, cfg.port
		if opt_server and opt_server[1] and opt_server[1] ~= "" then
			host, port = get_addr_2(opt_server[1])
		end
		if not host or not port then
			log("error", "server mode: no host:port")
			return usage(opt_mode)
		end
		log("debug", "server mode: %s:%s", host, port)
		xhard_server:start(host, port)
	elseif mode == "client" then
		local cfg = xconfig.hardlink and xconfig.hardlink.client or {}
		local host, port = cfg.host, cfg.port
		if opt_client and opt_client[1] and opt_client[1] ~= "" then
			host, port = get_addr_2(opt_client[1])
		end
		if not host or not port then
			log("error", "client mode: no host:port")
			return usage(opt_mode)
		end
		log("debug", "client mode: %s:%s", host, port)
		local hard = xhard_client(nil, host, port)
		local ready = {}
		for _, addr in mpairs(opt_dynamic or {}, cfg["dynamic"] or {}) do
			local lhost, lport = get_addr_2(addr)
			if not lhost then
				return usage(opt_mode)
			end
			lhost = (lhost ~= "*") and lhost or "0.0.0.0"
			local hp = lhost .. "L" .. lport
			if ready[hp] then
				log("error", "[%s:%s] is already in use", lhost, lport)
				return
			end
			ready[hp] = true
			log("info", "dynamic forward: [%s:%s]", lhost, lport)
			hard:dynamic_forward(lhost, lport)
		end
		for _, addr in mpairs(opt_local or {}, cfg["local"] or {}) do
			local lhost, lport, rhost, rport = get_addr_4(addr)
			if not lhost then
				return usage(opt_mode)
			end
			lhost = (lhost ~= "*") and lhost or "0.0.0.0"
			rhost = (rhost ~= "*") and rhost or "127.0.0.1"
			local hp = lhost .. "L" .. lport
			if ready[hp] then
				log("error", "[%s:%s] is already in use", lhost, lport)
				return
			end
			ready[hp] = true
			log("info", "local forward: [%s:%s => %s:%s]", lhost, lport, rhost, rport)
			hard:local_forward(lhost, lport, rhost, rport)
		end
		if not next(ready) then
			log("error", "client mode: nothing to forward")
			return usage(opt_mode)
		end
	else
		return usage()
	end
	xsocket.loop()
end

