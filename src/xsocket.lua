require "xlog"
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
