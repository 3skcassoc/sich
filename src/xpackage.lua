require "xlog"
require "xcmd"
require "xclass"
require "xparser"

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
