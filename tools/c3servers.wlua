require "socket"
require "iuplua"
require "iupluaimglib"

local function is_file(filepath)
	local file = io.open(filepath)
	if not file then
		return false
	end
	file:close()
	return true
end

local servers_path
do
	local basepath = arg[0]:match("^(.+)[/\\][^/\\]+[/\\]?$") or "."
	local check =
	{
		"",
		"/..",
		"/../..",
		"/Cossacks3",
		"/../Cossacks3",
		"/Cossacks 3",
		"/../Cossacks 3",
	}
	
	for _, path in ipairs(check) do
		path = basepath .. path .. "/data/resources/servers.dat"
		if is_file(path) then
			servers_path = path
			break
		end
	end
end

if not servers_path then
	iup.messagedlg
	{
		dialogtype = "error",
		title = "error",
		value = "./data/resources/servers.dat not found.\nPlace this file to Cossacks 3 root directory.",
	}
	:popup()
	os.exit()
end

if not is_file(servers_path .. ".bak") then
	local src = io.open(servers_path, "rb")
	local dst = io.open(servers_path .. ".bak", "wb")
	dst:write(src:read("*a"))
	src:close()
	dst:close()
end

local servers = {}
local selected = 1

do
	local section_begin = false
	local file = io.open(servers_path, "rb")
	while true do
		local line = file:read("*l")
		if line == nil then
			break
		end
		line = line:match("^%s*(.-)%s*$")
		if line == "section.begin" then
			section_begin = true
		elseif line == "section.end" then
			break
		elseif section_begin then
			local enabled, server = line:match("^(/?/?)%*%s*=%s*(.-)%s*$")
			table.insert(servers, server)
			if enabled ~= "//" then
				selected = #servers
			end
		end
	end
	file:close()
end

local toolbar, listbox, textbox

local function update_textbox()
	local lines =
	{
		"section.begin",
	}
	for i, server in ipairs(servers) do
		local line = "* = " .. server
		if i ~= selected then
			line = "//" .. line
		end
		table.insert(lines, "   " .. line)
	end
	table.insert(lines, "section.end")
	table.insert(lines, "")
	lines = table.concat(lines, "\n")
	textbox.value = lines
	
	local file = io.open(servers_path, "wb")
	file:write(lines)
	file:close()
end

local function update_listbox()
	listbox[1] = nil
	for i, server in ipairs(servers) do
		listbox[i] = server
	end
	listbox.value = selected
	update_textbox()
end

local ping_socket = assert(socket.udp())
assert(ping_socket:setsockname("*", 0))
assert(ping_socket:setoption("broadcast", true))
assert(ping_socket:settimeout(0))

local pong, ping_timer, find_button

iup.SetIdle(function ()
	local title, ip, port = ping_socket:receivefrom()
	if title and pong then
		pong[ip .. ":" .. port] = title
	end
end)

ping_timer = iup.timer
{
	time = 1000,
	run = "no",
	action_cb = function ()
		ping_timer.run = "no"
		local list = {}
		local found = {}
		for addr, title in pairs(pong) do
			table.insert(list, "[" .. addr .. "] " .. title)
			table.insert(found, addr)
		end
		if #list > 0 then
			local ok, index = iup.GetParam("select server", nil, "found: %l|" .. table.concat(list, "|") .. "|\n", 0)
			if ok then
				table.insert(servers, found[index + 1])
				selected = #servers
				update_listbox()
			end
		end
		find_button.active = "yes"
		pong = nil
	end,
}

local function ping()
	pong = {}
	local function ping_ip(ip)
		assert(ping_socket:sendto("ping", ip, 31523))
	end
	ping_ip("127.255.255.255")
	ping_ip("255.255.255.255")
	local ip, info = socket.dns.toip(socket.dns.gethostname())
	if ip and info.ip then
		for _, ip in ipairs(info.ip) do
			ping_ip(ip:match("^([0-9]+%.[0-9]+%.[0-9]+%.)[0-9]+$") .. "255")
		end
	end
	ping_timer.run = "yes"
end

local ask_remove = iup.messagedlg
{
	dialogtype = "question",
	buttons = "yesno",
	title = "confirm",
	value = "remove selected server?",
}

toolbar = iup.hbox
{
	iup.button
	{
		title = "find",
		flat = "yes",
		canfocus = "no",
		image = "IUP_EditFind",
		button_cb = function (self, _, down)
			if down ~= 1 then return end
			find_button = self
			find_button.active = "no"
			ping()
		end,
	},
	iup.button
	{
		title = "add",
		flat = "yes",
		canfocus = "no",
		image = "IUP_FileNew",
		button_cb = function (self, _, down)
			if down ~= 1 then return end
			local ok, ip, port = nil, "127.0.0.1", 31523
			while true do
				ok, ip, port = iup.GetParam("add new server", nil, "ip:%s\nport: %i\n", ip, port)
				if not ok then
					return
				end
				table.insert(servers, ip .. ":" .. port)
				selected = #servers
				return update_listbox()
			end
		end,
	},
	iup.button
	{
		title = "edit",
		flat = "yes",
		canfocus = "no",
		image = "IUP_FileProperties",
		button_cb = function (self, _, down)
			if down ~= 1 then return end
			local ok, ip, port = nil, servers[selected]:match("^(.+)%:(.+)$")
			while true do
				ok, ip, port = iup.GetParam("edit server", nil, "ip:%s\nport: %i\n", ip, port)
				if not ok then
					return
				end
				servers[selected] = ip .. ":" .. port
				return update_listbox()
			end
		end,
	},
	iup.button
	{
		title = "remove",
		flat = "yes",
		canfocus = "no",
		image = "IUP_EditErase",
		button_cb = function (self, _, down)
			if down ~= 1 then return end
			ask_remove:popup()
			if tonumber(ask_remove.buttonresponse) ~= 1 then
				return
			end
			table.remove(servers, selected)
			if selected > #servers then
				selected = #servers
			end
			update_listbox()
		end,
	},
	iup.button
	{
		title = "",
		flat = "yes",
		canfocus = "no",
		image = "IUP_ArrowUp",
		button_cb = function (self, _, down)
			if down ~= 1 then return end
			if selected == 1 then
				return
			end
			local upper = selected - 1
			local server = servers[upper]
			servers[upper] = servers[selected]
			servers[selected] = server
			selected = upper
			update_listbox()
		end,
	},
	iup.button
	{
		title = "",
		flat = "yes",
		canfocus = "no",
		image = "IUP_ArrowDown",
		button_cb = function (self, _, down)
			if down ~= 1 then return end
			if selected == #servers then
				return
			end
			local lower = selected + 1
			local server = servers[lower]
			servers[lower] = servers[selected]
			servers[selected] = server
			selected = lower
			update_listbox()
		end,
	},
	margin = "10x2",
	gap = 0,
}

textbox = iup.multiline
{
	expand = "yes",
	readonly = "yes",
	fontsize = 10,
	bgcolor = "230 230 230",
}

listbox = iup.list
{
	expand = "yes",
	action = function (self, text, index, value)
		if value == 1 then
			selected = index
			update_textbox()
		end
	end,
}

local dialog = iup.dialog
{
	iup.vbox
	{
		toolbar,
		iup.split
		{
			listbox,
			textbox,
			value = 350,
			minmax = "0:1000",
		},
		expandchildren = "yes",
	},
	title = "cossacks 3 servers",
	rastersize = "512x256",
}

dialog:showxy(iup.CENTER, iup.CENTER)
update_listbox()
iup.MainLoop()
