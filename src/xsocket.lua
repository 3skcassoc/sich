require "xlog"
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
		if self.sock.shutdown then
			self.sock:shutdown("both")
		end
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
	
	__tostring = function (self)
		local sock = self.sock
		local proto = tostring(sock):match("^[^{]+")
		local _, ip, port = pcall(sock.getsockname, sock)
		return ("%s:%s:%s"):format(proto or "?", ip or "?", port or "?")
	end,
}

if package.config:sub(1, 1) == "\\" then
	wrapper.connect = wrapper.connect_windows
else
	wrapper.connect = wrapper.connect_unix
end

local function append(thread, success, sock, set)
	if not success then
		xsocket.thread_count = xsocket.thread_count - 1
		log("error", "thread crashed: %s", debug.traceback(thread, sock))
		return
	end
	if not sock then
		xsocket.thread_count = xsocket.thread_count - 1
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
	sendt = sendt,
	recvt = recvt,
	slept = slept,
	
	thread_count = 0,
	
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
		xsocket.thread_count = xsocket.thread_count + 1
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
