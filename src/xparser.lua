require "xlog"
require "xclass"

local log = xlog("xparser")

xparser = xclass
{
	__create = function (self, key, value)
		self.key = assert(key, "no key")
		self.value = assert(value, "no value")
		return self
	end,
	
	count = function (self)
		return #self
	end,
	
	pairs = function (self)
		return ipairs(self)
	end,
	
	append = function (self, node)
		table.insert(self, node)
		return node
	end,
	
	find = function (self, key)
		for _, node in self:pairs() do
			if node.key == key then
				return node
			end
		end
		return nil
	end,
	
	add = function (self, key, value)
		return self:append(xparser(key, value))
	end,
	
	get = function (self, key, default)
		local node = self:find(key)
		if node then
			return node.value
		end
		return default
	end,
	
	set = function (self, key, value)
		local node = self:find(key)
		if node then
			node.value = value
			return node
		end
		return self:add(key, value)
	end,
	
	remove = function (self, key)
		local i = self:count()
		while i > 0 do
			if self[i].key == key then
				table.remove(self, i)
			else
				i = i - 1
			end
		end
	end,
	
	dump = function (self, flog)
		flog = flog or log
		if not flog:check("debug") then
			return
		end
		local function do_dump(parser)
			flog("debug", "key = %q, value = %q", parser.key, parser.value)
			flog:inc(2)
			for _, node in parser:pairs() do
				do_dump(node)
			end
			flog:dec(2)
		end
		return do_dump(self)
	end,
}

null_parser = xparser("", "")
