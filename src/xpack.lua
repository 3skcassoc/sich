require "xlog"
require "xclass"
require "xparser"

local log = xlog("xpack")

xpack = xclass
{
	formats =
	{
		["1"] = "byte",
		["b"] = "boolean",
		["d"] = "datetime",
		["t"] = "timestamp",
		["s"] = "byte_string",
		["w"] = "word_string",
		["z"] = "dword_string",
		["v"] = "version",
		["p"] = "parser",
		["q"] = "parser_with_size",
	},
	
	__create = function (self, buffer, position)
		self.buffer = buffer or {}
		self.position = buffer and (position or 1) or nil
		return self
	end,
	
	reader = function (self, buffer, position)
		self.buffer = buffer or self:get_buffer()
		self.position = position or 1
		return self
	end,
	
	get_buffer = function (self)
		local buffer = self.buffer
		if type(buffer) == "table" then
			buffer = table.concat(buffer)
		end
		return buffer
	end,
	
	remain = function (self)
		return math.max(0, #self.buffer - self.position + 1)
	end,
	
	read_check = function (self, size)
		local remain = self:remain()
		if size > remain then
			log("error", "read_check: size=%d, remain=%d", size, remain)
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
		self.position = self.position + size
		return self.buffer:sub(self.position - size, self.position - 1)
	end,
	
	read_number = function (self, size)
		if not self:read_check(size) then
			return nil
		end
		self.position = self.position + size
		local byte = { self.buffer:byte(self.position - size, self.position - 1) }
		local result = 0
		for i = size, 1, -1 do
			result = result * 256 + byte[i]
		end
		return result
	end,
	
	read_byte = function (self)
		if not self:read_check(1) then
			return nil
		end
		self.position = self.position + 1
		return self.buffer:byte(self.position - 1)
	end,
	
	read_boolean = function (self)
		local byte = self:read_byte()
		if byte == nil then
			return nil
		end
		return byte ~= 0
	end,
	
	read_word = function (self)
		return self:read_number(2)
	end,
	
	read_dword = function (self)
		return self:read_number(4)
	end,
	
	read_datetime = function (self)
		if not self:read_check(8) then
			return nil
		end
		self.position = self.position + 8
		local byte = { self.buffer:byte(self.position - 8, self.position - 1) }
		local sign = (byte[8] < 128)
		local exponent = (byte[8] % 128) * 16 + math.floor(byte[7] / 16)
		local mantissa = byte[7] % 16
		for i = 6, 1, -1 do
			mantissa = mantissa * 256 + byte[i]
		end
		if (mantissa == 0 and exponent == 0) or (sign == false) or (exponent == 2047) then
			return 0
		end
		mantissa = 1 + math.ldexp(mantissa, -52)
		return math.ldexp(mantissa, exponent - 1023)
	end,
	
	read_timestamp = function (self)
		local datetime = self:read_datetime()
		if datetime == nil then
			return nil
		end
		return math.max(0, (datetime - 25569.0) * 86400.0)
	end,
	
	read_string = function (self, len_size)
		local len = self:read_number(len_size)
		if len == nil then
			return nil
		end
		return self:read_buffer(len)
	end,
	
	read_byte_string = function (self)
		return self:read_string(1)
	end,
	
	read_word_string = function (self)
		return self:read_string(2)
	end,
	
	read_dword_string = function (self)
		return self:read_string(4)
	end,
	
	read_version = function (self)
		local str = self:read_byte_string()
		if str == nil then
			return nil
		end
		local result = 0
		for part in str:gmatch("[0-9]+") do
			result = result * 256 + tonumber(part)
		end
		return result
	end,
	
	read_parser = function (self)
		if self:remain() == 0 then
			return null_parser
		end
		local key, value, count = self:read("zz4")
		if key == nil then
			return nil
		end
		local parser = xparser(key, value)
		for _ = 1, count do
			local node = self:read_parser()
			if node == nil then
				return nil
			end
			parser:append(node)
		end
		return parser
	end,
	
	read_parser_with_size = function (self)
		local buffer = self:read_dword_string()
		if buffer == nil then
			return nil
		end
		return xpack(buffer):read_parser()
	end,
	
	read_array = function (self, format)
		local array = {}
		for i = 1, #format do
			local fmt, value = format:sub(i, i), nil
			local ftype = self.formats[fmt]
			if ftype then
				value = self["read_" .. ftype](self)
			else
				fmt = assert(tonumber(fmt), "invalid format")
				value = self:read_number(fmt)
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
			local key = assert(select(index, ...), "no more keys")
			object[key] = value
		end
		return object
	end,
	
	read_objects = function (self, objects, format, ...)
		local count = self:read_dword()
		if count == nil then
			return nil
		end
		for _ = 1, count do
			local object = self:read_object({}, format, ...)
			if object == nil then
				return nil
			end
			table.insert(objects, object)
		end
		return objects
	end,
	
	read = function (self, format)
		local array = self:read_array(format)
		if array == nil then
			return nil
		end
		return unpack(array)
	end,
	
	write_buffer = function (self, buffer)
		assert(type(buffer) == "string", "not a string buffer")
		table.insert(self.buffer, buffer)
		return self
	end,
	
	write_number = function (self, size, value)
		assert(type(value) == "number", "not a numeric value")
		local frac = nil
		for _ = 1, size do
			value, frac = math.modf(value / 256)
			table.insert(self.buffer, string.char(frac * 256))
		end
		return self
	end,
	
	write_byte = function (self, value)
		assert(type(value) == "number", "not a numeric value")
		table.insert(self.buffer, string.char(value))
		return self
	end,
	
	write_boolean = function (self, value)
		assert(type(value) == "boolean", "not a boolean value")
		return self:write_byte(value and 1 or 0)
	end,
	
	write_word = function (self, value)
		return self:write_number(2, value)
	end,
	
	write_dword = function (self, value)
		return self:write_number(4, value)
	end,
	
	write_datetime = function (self, value)
		assert(type(value) == "number", "not a numeric value")
		if value < 0 or value == math.huge or value ~= value then
			value = 0
		end
		local mantissa, exponent = 0, 0
		if value ~= 0 then
			mantissa, exponent = math.frexp(value)
			mantissa = math.floor(0.5 + math.ldexp(mantissa * 2 - 1, 52))
			exponent = exponent - 1 + 1023
		end
		local byte = {}
		for _ = 1, 6 do
			mantissa, value = math.modf(mantissa / 256)
			table.insert(byte, value * 256)
		end
		table.insert(byte, mantissa + exponent % 16 * 16)
		table.insert(byte, math.floor(exponent / 16))
		table.insert(self.buffer, string.char(unpack(byte)))
		return self
	end,
	
	write_timestamp = function (self, value)
		assert(type(value) == "number", "not a numeric value")
		return self:write_datetime(value / 86400.0 + 25569.0)
	end,
	
	write_string = function (self, len_size, value)
		assert(type(value) == "string", "not a string value")
		self:write_number(len_size, #value)
		return self:write_buffer(value)
	end,
	
	write_byte_string = function (self, value)
		return self:write_string(1, value)
	end,
	
	write_word_string = function (self, value)
		return self:write_string(2, value)
	end,
	
	write_dword_string = function (self, value)
		return self:write_string(4, value)
	end,
	
	write_version = function (self, value)
		assert(type(value) == "number", "not a numeric value")
		local version, frac = {}, nil
		while value > 0 do
			value, frac = math.modf(value / 256)
			table.insert(version, 1, tostring(frac * 256))
		end
		return self:write_byte_string(table.concat(version, "."))
	end,
	
	write_parser = function (self, parser)
		assert(type(parser) == "table" and parser.__class == xparser, "not a parser value")
		if parser ~= null_parser then
			self:write("zz4",
				tostring(parser.key),
				tostring(parser.value),
				parser:count())
			for _, node in parser:pairs() do
				self:write_parser(node)
			end
		end
		return self
	end,
	
	write_parser_with_size = function (self, parser)
		local buffer = xpack()
			:write_parser(parser)
			:get_buffer()
		return self:write_dword_string(buffer)
	end,
	
	write_array = function (self, format, array)
		for i = 1, #format do
			local fmt, value = format:sub(i, i), array[i]
			local ftype = self.formats[fmt]
			if ftype then
				self["write_" .. ftype](self, value)
			else
				fmt = assert(tonumber(fmt), "invalid format")
				self:write_number(fmt, value)
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
	
	write_objects = function (self, objects, format, ...)
		local count = 0
		for _ in pairs(objects) do
			count = count + 1
		end
		self:write_dword(count)
		for _, object in pairs(objects) do
			self:write_object(object, format, ...)
		end
		return self
	end,
	
	write = function (self, format, ...)
		return self:write_array(format, {...})
	end,
}
