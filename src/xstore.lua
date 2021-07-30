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
		table.insert(result, (("%q"):format(value):gsub("\\\n", "\\n")))
	elseif value_type == "nil" or value_type == "boolean" or value_type == "number" then
		table.insert(result, tostring(value))
	elseif value_type ~= "table" then
		error("can not serialize: " .. value_type)
	elseif next(value) == nil then
		table.insert(result, "{}")
	else
		local keys = {}
		for key in pairs(value) do
			table.insert(keys, key)
		end
		table.sort(keys, function (a, b)
			local ta, tb = type(a), type(b)
			if ta ~= tb then
				a, b = ta, tb
			elseif ta == "string" then
				local na, nb = tonumber(a), tonumber(b)
				if na and nb then
					a, b = na, nb
				end
			elseif ta ~= "number" then
				a, b = tostring(a), tostring(b)
			end
			return a < b
		end)
		table.insert(result, "{\n")
		for _, key in ipairs(keys) do
			table.insert(result, ("\t"):rep(indent + 1))
			table.insert(result, "[")
			do_serialize(key, result, indent + 1)
			table.insert(result, "] = ")
			do_serialize(value[key], result, indent + 1)
			table.insert(result, ",\n")
		end
		table.insert(result, ("\t"):rep(indent))
		table.insert(result, "}")
	end
	return result
end

local function serialize(value)
	return table.concat(do_serialize(value, {}, 0))
end

local path = arg and arg[0] and arg[0]:match("^(.+)[/\\][^/\\]+[/\\]?$") or "."
path = path:gsub("%%", "%%%%") .. "/%s.store"
log("debug", "path: %q", path)

xstore =
{
	load = function (name, default)
		name = path:format(name)
		log("debug", "loading %q", name)
		local file, msg = io.open(name, "r")
		if not file then
			log("debug", msg)
			return default
		end
		file:close()
		local fun = assert(loadfile(name))
		setfenv(fun, _G)
		local _, data = assert(pcall(fun))
		return data
	end,
	
	save = function (name, data)
		name = path:format(name)
		log("debug", "saving %q", name)
		local str = serialize(data)
		local file, msg = io.open(name, "w")
		if not file then
			log("error", msg)
			return false
		end
		file:write("return ", str, "\n")
		file:close()
		return true
	end,
}
