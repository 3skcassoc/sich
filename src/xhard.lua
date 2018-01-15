require "xlog"
require "xclass"
require "xpack"
require "xsocket"
require "xlink"
require "xsocks"

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
