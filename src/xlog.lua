require "xconfig"

local numeric =
{
	debug = 0,
	info = 1,
	warn = 2,
	error = 3,
	disabled = 4,
}

local name_length = 10

local level = numeric["info"]
local units = {}
local output = io.output()

if type(xconfig.log) == "table" then
	level = assert(numeric[xconfig.log.level or "info"], "invalid log level")
	if xconfig.log.units then
		for unit, level in pairs(xconfig.log.units) do
			units[unit] = assert(numeric[level], "invalid log level")
		end
	end
	output = xconfig.log.output or output
elseif type(xconfig.log) == "string" then
	level = assert(numeric[xconfig.log], "invalid log level")
end

local function log_check(self, level)
	return assert(numeric[level], "invalid log level") >= self.minlevel
end

local function log_print(self, level, fmt, ...)
	if not log_check(self, level) then
		return
	end
	return output:write(
		os.date("%Y.%m.%d %H:%M:%S"),
		(" | %%-5s | %%-%ds | %%%ds%s")
			:format(name_length, self.indent, fmt)
			:format(level, self.name, "", ...)
			:gsub("\\\n", "\\n"),
		"\n")
end

local function log_inc(self, value)
	self.indent = self.indent + ( value or 1 )
	return self
end

local function log_dec(self, value)
	self.indent = self.indent - ( value or 1 )
	return self
end

local function log_dummy()
end

local log_disabled = setmetatable({
	minlevel = numeric["disabled"],
	check = log_dummy,
	indent = 0,
	inc = log_dummy,
	dec = log_dummy,
}, {
	__call = log_dummy,
})

xlog = function (unit, name)
	assert(type(unit) == "string", "no unit name")
	name = name or unit
	if name_length < #name then
		name_length = #name
	end
	local minlevel = units[unit] or level
	if minlevel >= numeric["disabled"] then
		return log_disabled
	end
	return setmetatable({
		name = name,
		minlevel = minlevel,
		check = log_check,
		indent = 0,
		inc = log_inc,
		dec = log_dec,
	}, {
		__call = log_print,
	})
end
