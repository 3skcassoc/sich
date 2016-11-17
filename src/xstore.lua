local log_wait = {}
local function log(...)
	if not xlog then
		return table.insert(log_wait, {...})
	end
	log = xlog("xstore")
	for _, wait in ipairs(log_wait) do
		log(unpack(wait))
	end
	log_wait = nil
	return log(...)
end

local function do_serialize(value, result, indent)
	local value_type = type(value)
	if value_type == "string" then
		return table.insert(result, (("%q"):format(value):gsub("\\\n", "\\n")))
	elseif value_type == "nil" or value_type == "boolean" or value_type == "number" then
		return table.insert(result, tostring(value))
	elseif value_type ~= "table" then
		return error("can not serialize: " .. value_type)
	end
	if next(value) == nil then
		return table.insert(result, "{}")
	end
	table.insert(result, "{\n")
	for key, val in pairs(value) do
		table.insert(result, ("\t"):rep(indent + 1))
		table.insert(result, "[")
		do_serialize(key, result, indent + 1)
		table.insert(result, "] = ")
		do_serialize(val, result, indent + 1)
		table.insert(result, ",\n")
	end
	table.insert(result, ("\t"):rep(indent))
	return table.insert(result, "}")
end

local function serialize(value)
	local result = {}
	do_serialize(value, result, 0)
	return table.concat(result)
end

local path = arg[0]:match("^(.+)[/\\][^/\\]+[/\\]?$")

if not path then
	path = "."
end

log("info", "path = %s", path)

xstore =
{
	load = function (name, default)
		local fun, msg = loadfile(path .. "/" .. name .. ".store")
		if not fun then
			log("debug", msg)
			return default
		end
		log("info", "loading %q", name)
		setfenv(fun, _G)
		local ok, data = pcall(fun)
		if not ok then
			log("error", data)
			return default
		end
		return data
	end,
	
	save = function (name, data)
		log("info", "saving %q", name)
		local str = serialize(data)
		local file, msg = io.open(path .. "/" .. name .. ".store", "w")
		if not file then
			return log("error", msg)
		end
		file:write("return ", str)
		return file:close()
	end,
}
