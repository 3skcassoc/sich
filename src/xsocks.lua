require "xlog"

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
		local host = nil
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
