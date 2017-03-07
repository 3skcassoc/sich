local file = assert(io.open("./VERSION"))
local VERSION = file:read("*a"):match("^%s*(.-)%s*$")
file:close()
print(VERSION)

local release = assert(io.open("./release/sich.lua", "wb"))
release:write(
	"--\n",
	"-- Sich\n",
	"-- Cossacks 3 lua server\n",
	"--\n",
	"\n",
	'VERSION = "' .. VERSION .. '"\n',
	"\n")

local done = {}

local function include(name)
	if done[name] then
		return
	end
	local unit = assert(io.open("./src/" .. name .. ".lua", "rb"))
	local do_end = false
	while true do
		local line = unit:read("*l")
		if not line then
			break
		end
		local req = line:match("^require.-(%w+).-$")
		if req then
			include(req)
		elseif not line:match("^%s*$") then
			if not do_end then
				do_end = true
				print("including " .. name)
				release:write(
					"-- // " .. name .. " // --\n",
					"do\n")
			end
			release:write("\t" .. line .. "\n")
		end
	end
	unit:close()
	if do_end then
		release:write("end\n")
	end
	release:write("\n")
	done[name] = true
end

include("sich")
release:close()
print("done")
