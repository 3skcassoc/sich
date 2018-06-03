require "xlog"
require "xclass"
require "xsocket"

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
			log("info", "[%08x] close", self.uid)
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
