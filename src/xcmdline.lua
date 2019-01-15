require "xlog"
require "xclass"

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
					if eq == "=" then
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
