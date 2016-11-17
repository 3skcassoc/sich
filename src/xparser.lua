require "xlog"
require "xclass"

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
		if not subnode then
			log("debug", "PARSER: key = %q, value = %q", self.key, self.value)
		else
			log("debug", "key = %q, value = %q", self.key, self.value)
		end
		log:inc()
		for _, node in ipairs(self.nodes) do
			node:dump(true)
		end
		log:dec()
	end,
}
