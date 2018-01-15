local function include(self, name)
	if self.done[name] then
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
			include(self, req)
		elseif not line:match("^%s*$") then
			if not do_end then
				do_end = true
				print("including " .. name)
				self.file:write(
					"-- // " .. name .. " // --\n",
					"do\n")
			end
			self.file:write("\t" .. line .. "\n")
		end
	end
	unit:close()
	if do_end then
		self.file:write("end\n")
	end
	self.file:write("\n")
	self.done[name] = true
end

local function release(name, head)
	print("assembling " .. name)
	local file = assert(io.open("./release/" .. name .. ".lua", "wb"))
	if head then
		file:write(table.concat(head, "\n"), "\n")
	end
	include({done = {}, file = file}, name)
	file:close()
end

local file = assert(io.open("./VERSION"))
local VERSION = file:read("*a"):match("^%s*(.-)%s*$")
file:close()
print(VERSION)

release("sich", {
	"--",
	"-- Sich",
	"-- Cossacks 3 lua server",
	"--",
	"",
	'VERSION = "' .. VERSION .. '"',
	"",
})

release("hardlink")

print("done")
