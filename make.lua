local lfs = require "lfs"

if not lfs.attributes("./src") then
	error("src dir not found")
end

if not lfs.attributes("./release") then
	error("release dir not found")
end

local file = assert(io.open("./VERSION"))
local VERSION = file:read("*a"):match("^%s*(.-)%s*$")
file:close()
print(VERSION)

local unit_deps = {}
local unit_text = {}

for unit_file in lfs.dir("./src") do
	local unit_name = unit_file:match("^(.+)%.lua$")
	if unit_name then
		local file, msg = io.open("./src/" .. unit_file, "rb")
		if not file then
			error(msg)
		end
		
		local deps = {}
		local text = {
			"-- // " .. unit_name .. " // --",
			"do",
		}
		while true do
			local line = file:read("*l")
			if not line then
				break
			end
			local req = line:match("^require.-(%w+).-$")
			if req then
				table.insert(deps, req)
			elseif not line:match("^%s*$") then
				table.insert(text, "\t" .. line)
			end
		end
		table.insert(text, "end")
		
		unit_deps[unit_name] = deps
		unit_text[unit_name] = text
		
		file:close()
	end
end

local function combine(main)
	local done = {}
	local combined = {
		"--",
		"-- Sich",
		"-- Cossacks 3 lua server",
		"--",
		"",
		'VERSION = "' .. VERSION .. '"',
		"",
	}
	
	local function include(name)
		if done[name] then
			return
		end
		for _, dep in ipairs(assert(unit_deps[name], "unknown unit: " .. name)) do
			include(dep)
		end
		print("including " .. name)
		for _, line in ipairs(unit_text[name]) do
			table.insert(combined, line)
		end
		table.insert(combined, "")
		done[name] = true
	end
	
	print("processing " .. main)
	include(main)
	
	local file, msg = io.open("./release/" .. main .. ".lua", "wb")
	if not file then
		error(msg)
	end
	file:write(table.concat(combined, "\n"))
	file:close()
end

combine("sich")
print("done")
