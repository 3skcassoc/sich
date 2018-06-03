local names = setmetatable(
	{
		__index = setmetatable(
			{
				raw = function (self, key)
					return rawget(self, key)
				end,
				len = function (self)
					local maxlen = 0
					for _, name in pairs(self) do
						if #name > maxlen then
							maxlen = #name
						end
					end
					return maxlen
				end,
			},
			{
				__index = function (self, key)
					return "???"
				end,
			}),
	},
	{
		__call = function (self, tbl)
			return setmetatable(tbl, self)
		end,
	})

names.command = names
{
	[0x0190] = "SHELL_CONSOLE",
	[0x0191] = "PING",
	[0x0192] = "SERVER_CLIENTINFO",
	[0x0193] = "USER_CLIENTINFO",
	[0x0194] = "SERVER_SESSION_MSG",
	[0x0195] = "USER_SESSION_MSG",
	[0x0196] = "SERVER_MESSAGE",
	[0x0197] = "USER_MESSAGE",
	[0x0198] = "SERVER_REGISTER",
	[0x0199] = "USER_REGISTER",
	[0x019A] = "SERVER_AUTHENTICATE",
	[0x019B] = "USER_AUTHENTICATE",
	[0x019C] = "SERVER_SESSION_CREATE",
	[0x019D] = "USER_SESSION_CREATE",
	[0x019E] = "SERVER_SESSION_JOIN",
	[0x019F] = "USER_SESSION_JOIN",
	[0x01A0] = "SERVER_SESSION_LEAVE",
	[0x01A1] = "USER_SESSION_LEAVE",
	[0x01A2] = "SERVER_SESSION_LOCK",
	[0x01A3] = "USER_SESSION_LOCK",
	[0x01A4] = "SERVER_SESSION_INFO",
	[0x01A5] = "USER_SESSION_INFO",
	[0x01A6] = "USER_CONNECTED",
	[0x01A7] = "USER_DISCONNECTED",
	[0x01A8] = "SERVER_USER_EXIST",
	[0x01A9] = "USER_USER_EXIST",
	[0x01AA] = "SERVER_SESSION_UPDATE",
	[0x01AB] = "SERVER_SESSION_CLIENT_UPDATE",
	[0x01AC] = "USER_SESSION_CLIENT_UPDATE",
	[0x01AD] = "SERVER_VERSION_INFO",
	[0x01AE] = "USER_VERSION_INFO",
	[0x01AF] = "SERVER_SESSION_CLOSE",
	[0x01B0] = "USER_SESSION_CLOSE",
	[0x01B1] = "SERVER_GET_TOP_USERS",
	[0x01B2] = "USER_GET_TOP_USERS",
	[0x01B3] = "SERVER_UPDATE_INFO",
	[0x01B4] = "USER_UPDATE_INFO",
	[0x01B5] = "SERVER_SESSION_KICK",
	[0x01B6] = "USER_SESSION_KICK",
	[0x01B7] = "SERVER_SESSION_CLSCORE",
	[0x01B8] = "USER_SESSION_CLSCORE",
	[0x01B9] = "SERVER_FORGOT_PSW",
	[0x01BB] = "SERVER_SESSION_PARSER",
	[0x01BC] = "USER_SESSION_PARSER",
	[0x01BD] = "USER_SESSION_RECREATE",
	[0x01BE] = "USER_SESSION_REJOIN",
	[0x01C0] = "0x01C0",
	
	[0x0001] = "0x0001",
	[0x0002] = "0x0002",
	[0x0003] = "0x0003",
	[0x0004] = "0x0004",
	[0x0032] = "LAN_PARSER",
	[0x0064] = "LAN_CLIENT_INFO",
	[0x0065] = "0x0065",
	[0x0066] = "0x0066",
	[0x0067] = "0x0067",
	[0x00C8] = "LAN_SERVER_INFO",
	[0x00C9] = "0x00C9",
	[0x00CA] = "0x00CA",
	[0x00CB] = "0x00CB",
	[0x0456] = "LAN_DO_START",
	[0x0457] = "LAN_DO_START_GAME",
	[0x0460] = "LAN_DO_READY",
	[0x0461] = "LAN_DO_READY_DONE",
	[0x04B0] = "LAN_RECORD",
}

names.parser = names
{
	[1] = "LAN_GENERATE",
	[2] = "LAN_READYSTART",
	[3] = "LAN_START",
	[4] = "LAN_ROOM_READY",
	[5] = "LAN_ROOM_START",
	[6] = "LAN_ROOM_CLIENT_CHANGES",
	[7] = "LAN_GAME_READY",
	[8] = "LAN_GAME_ANSWER_READY",
	[9] = "LAN_GAME_START",
	[10] = "LAN_GAME_SURRENDER",
	[11] = "LAN_GAME_SURRENDER_CONFIRM",
	[12] = "LAN_GAME_SERVER_LEAVE",
	[13] = "LAN_GAME_SESSION_RESULTS",
	[14] = "LAN_GAME_SYNC_REQUEST",
	[15] = "LAN_GAME_SYNC_DATA",
	[16] = "LAN_GAME_SYNC_GAMETIME",
	[17] = "LAN_GAME_SYNC_ALIVE",
	[100] = "LAN_ROOM_SERVER_DATASYNC",
	[101] = "LAN_ROOM_SERVER_DATACHANGE",
	[102] = "LAN_ROOM_CLIENT_DATACHANGE",
	[103] = "LAN_ROOM_CLIENT_LEAVE",
	[200] = "LAN_MODS_MODSYNC_REQUEST",
	[201] = "LAN_MODS_MODSYNC_PARSER",
	[202] = "LAN_MODS_CHECKSUM_REQUEST",
	[203] = "LAN_MODS_CHECKSUM_ANSWER",
	[204] = "LAN_MODS_CHECKSUM_REQUESTCANJOIN",
	[205] = "LAN_MODS_CHECKSUM_ANSWERCANJOIN",
	[206] = "LAN_MODS_CHECKSUM_ANSWERCANNOTJOIN",
	[300] = "LAN_ADVISER_CLIENT_DATACHANGE",
}

names.client = names
{
	[0] = "ALL",
}

names.state = names
{
	[0] = "online", [1] = "session", [2] = "master", [3] = "played",
}

names.difficulty = names
{
	[0] = "Normal", [1] = "Hard", [2] = "Very Hard", [3] = "Impossible",
}

names.nation = names
{
	[-2] = "SPECTATOR",
	[0] = "Austria",      [1] = "France",       [2] = "England",  [3] = "Spain",
	[4] = "Russia",       [5] = "Ukraine",      [6] = "Poland",   [7] = "Sweden",
	[8] = "Prussia",      [9] = "Venice",       [10] = "Turkey",  [11] = "Algeria",
	[12] = "Originals",   [13] = "Netherlands", [14] = "Denmark", [15] = "Portugal",
	[16] = "Piedmont",    [17] = "Saxony",      [18] = "Bavaria", [19] = "Hungary",
	[20] = "Switzerland", [21] = "Scotland",    [24] = "Random",
}

names.color = names
{
	[0] = "red",    [1] = "blue",  [2] = "cyan",     [3] = "purple",
	[4] = "orange", [5] = "green", [6] = "white",    [7] = "pink",
	[8] = "yellow", [9] = "teal",  [10] = "ltgreen", [11] = "olive",
}

names.season = names
{
	[-1] = "Random", [0] = "Summer", [2] = "Winter", [3] = "Desert",
}

names.terraintype = names
{
	[0] = "Land",               [1] = "Mediterranean",    [2] = "Peninsulas", [3] = "Islands",
	[4] = "Several Continents", [5] = "Single Continent", [6] = "Random",
}

names.relieftype = names
{
	[0] = "Plain",     [1] = "Low Mountains", [2] = "High Mountains",
	[3] = "Highlands", [4] = "Plateaus",      [5] = "Random",
}

names.resourcestart = names
{
	[0] = "Normal",     [1] = "Rich",   [2] = "Thousands",
	[3] = "Millions",   [4] = "Random",
}

names.resourcemines = names
{
	[0] = "Poor", [1] = "Medium", [2] = "Rich", [3] = "Random",
}

names.mapsize = names
{
	[0] = "Normal", [1] = "Large 2x", [2] = "Huge 4x", [3] = "Tiny",
}

names.startingunits = names
{
	[0] = "Default",          [1] = "Army",              [2] = "Big Army", [3] = "Huge Army",
	[4] = "Army of Peasants", [5] = "Different Nations", [6] = "Towers",   [7] = "Cannons",
	[8] = "Cannons and Howitzers",                       [9] = "18th Century Barracks",
}

names.balloon = names
{
	[0] = "Default", [1] = "No Balloons", [2] = "Balloons",
}

names.cannons = names
{
	[0] = "Default", [1] = "No Cannons, Towers and Walls", [2] = "Expensive Cannons",
}

names.peacetime = names
{
	[0] = "No Peace Time", [1] = "10 min",  [2] = "20 min",    [3] = "30 min",
	[4] = "45 min",        [5] = "60 min",  [6] = "1.5 hours", [7] = "2 hours",
	[8] = "3 hours",       [9] = "4 hours", [11] = "15 min",
}

names.century18 = names
{
	[0] = "Default", [1] = "Never", [2] = "Immediately",
}

names.capture = names
{
	[0] = "Default",                          [1] = "No Capturing Peasants",
	[2] = "No Capturing Peasants or Centres", [3] = "Artillery Only",
}

names.marketdip = names
{
	[0] = "Default", [1] = "Without dip. center", [2] = "Without market", [3] = "Without both",
}

names.teams = names
{
	[0] = "Default", [1] = "Nearby",
}

names.limit = names
{
	[0] = "Without limitation",
	[1] = "500 units",  [2] = "750 units",  [3] = "1000 units", [4] = "1500 units",
	[5] = "2200 units", [6] = "3000 units", [7] = "5000 units", [8] = "8000 units",
}

names.gamespeed = names
{
	[-1] = "Adjustable", [0] = "Normal", [1] = "Fast", [2] = "Very Fast",
}

names.adviserassistant = names
{
	[0] = "Default", [1] = "Without adviser",
}

names.battle = names
{
	[-1] = "none",
	[0] = "Battle of Nieuwpoort (1600)",   [1] = "Battle of Pyliavtsi (1648)",
	[2] = "Battle of Prostki (1656)",      [3] = "Battle of Saint Gotthard (1664)",
	[4] = "Battle of Villaviciosa (1710)", [5] = "Battle of Sheriffmuir (1715)",
	[6] = "Oran (1732)",                   [7] = "Battle of Soor(1745)",
}

local cmd = {}
for code, name in pairs(names.command) do
	cmd[name] = code
end

function str_states(b_value)
	local states = {}
	for i = 0, 3 do
		if b_value:bitfield(7 - i) ~= 0 then
			table.insert(states, names.state[i])
		end
	end
	return "[" .. table.concat(states, ", ") .. "]"
end

local cp1251 =
{
	[128] = "\208\130",     [129] = "\208\131",     [130] = "\226\128\154", [131] = "\209\147",
	[132] = "\226\128\158", [133] = "\226\128\166", [134] = "\226\128\160", [135] = "\226\128\161",
	[136] = "\226\130\172", [137] = "\226\128\176", [138] = "\208\137",     [139] = "\226\128\185",
	[140] = "\208\138",     [141] = "\208\140",     [142] = "\208\139",     [143] = "\208\143",
	[144] = "\209\146",     [145] = "\226\128\152", [146] = "\226\128\153", [147] = "\226\128\156",
	[148] = "\226\128\157", [149] = "\226\128\162", [150] = "\226\128\147", [151] = "\226\128\148",
	[152] = "\63",          [153] = "\226\132\162", [154] = "\209\153",     [155] = "\226\128\186",
	[156] = "\209\154",     [157] = "\209\156",     [158] = "\209\155",     [159] = "\209\159",
	[160] = "\78\66\83\80", [161] = "\208\142",     [162] = "\209\158",     [163] = "\208\136",
	[164] = "\194\164",     [165] = "\210\144",     [166] = "\194\166",     [167] = "\194\167",
	[168] = "\208\129",     [169] = "\194\169",     [170] = "\208\132",     [171] = "\194\171",
	[172] = "\194\172",     [173] = "\83\72\89",    [174] = "\194\174",     [175] = "\208\135",
	[176] = "\194\176",     [177] = "\194\177",     [178] = "\208\134",     [179] = "\209\150",
	[180] = "\210\145",     [181] = "\194\181",     [182] = "\194\182",     [183] = "\194\183",
	[184] = "\209\145",     [185] = "\226\132\150", [186] = "\209\148",     [187] = "\194\187",
	[188] = "\209\152",     [189] = "\208\133",     [190] = "\209\149",     [191] = "\209\151",
	[192] = "\208\144",     [193] = "\208\145",     [194] = "\208\146",     [195] = "\208\147",
	[196] = "\208\148",     [197] = "\208\149",     [198] = "\208\150",     [199] = "\208\151",
	[200] = "\208\152",     [201] = "\208\153",     [202] = "\208\154",     [203] = "\208\155",
	[204] = "\208\156",     [205] = "\208\157",     [206] = "\208\158",     [207] = "\208\159",
	[208] = "\208\160",     [209] = "\208\161",     [210] = "\208\162",     [211] = "\208\163",
	[212] = "\208\164",     [213] = "\208\165",     [214] = "\208\166",     [215] = "\208\167",
	[216] = "\208\168",     [217] = "\208\169",     [218] = "\208\170",     [219] = "\208\171",
	[220] = "\208\172",     [221] = "\208\173",     [222] = "\208\174",     [223] = "\208\175",
	[224] = "\208\176",     [225] = "\208\177",     [226] = "\208\178",     [227] = "\208\179",
	[228] = "\208\180",     [229] = "\208\181",     [230] = "\208\182",     [231] = "\208\183",
	[232] = "\208\184",     [233] = "\208\185",     [234] = "\208\186",     [235] = "\208\187",
	[236] = "\208\188",     [237] = "\208\189",     [238] = "\208\190",     [239] = "\208\191",
	[240] = "\209\128",     [241] = "\209\129",     [242] = "\209\130",     [243] = "\209\131",
	[244] = "\209\132",     [245] = "\209\133",     [246] = "\209\134",     [247] = "\209\135",
	[248] = "\209\136",     [249] = "\209\137",     [250] = "\209\138",     [251] = "\209\139",
	[252] = "\209\140",     [253] = "\209\141",     [254] = "\209\142",     [255] = "\209\143",
}

function utf8(str)
	return str:gsub("[^\t\n\r\32-\126]",
		function (c)
			return cp1251[c:byte()] or "?"
		end)
end

local function convert_version(str)
	local version = 0
	for part in str:gmatch("[0-9]+") do
		version = version * 256 + tonumber(part)
	end
	return version
end

local data_version = convert_version("2.1.0")

local reader = setmetatable(
{
	formats =
	{
		["1"] = "byte",
		["b"] = "boolean",
		["d"] = "datetime",
		["t"] = "timestamp",
		["s"] = "byte_string",
		["w"] = "word_string",
		["z"] = "dword_string",
		["v"] = "byte_string",
		["p"] = "parser",
		["q"] = "parser_with_size",
		["e"] = "states",
		["i"] = "dword",
		["j"] = "dword",
		["c"] = "packet",
		["n"] = "gamename",
		["m"] = "mapname",
	},
	
	remain = function (self)
		return math.max(0, self.range:len() - self.position)
	end,
	
	check = function (self, size)
		return (size <= self:remain())
	end,
	
	buffer = function (self, size)
		if not self:check(size) then
			return
		end
		self.position = self.position + size
		return (tostring(self.range(self.position - size, size):bytes())
			:gsub('..', function (hex) return string.char(tonumber(hex, 16)) end))
	end,
	
	number = function (self, size)
		if not self:check(size) then
			return
		end
		self.position = self.position + size
		return self.range(self.position - size, size):le_uint()
	end,
	
	byte = function (self)
		return self:number(1)
	end,
	
	boolean = function (self)
		local byte = self:byte()
		if not byte then
			return
		end
		return byte ~= 0
	end,
	
	word = function (self)
		return self:number(2)
	end,
	
	dword = function (self)
		return self:number(4)
	end,
	
	datetime = function (self)
		if not self:check(8) then
			return
		end
		self.position = self.position + 8
		return self.range(self.position - 8, 8):le_float()
	end,
	
	timestamp = function (self)
		local dt = self:datetime()
		if not dt then
			return
		end
		return (dt - 25569.0) * 86400.0
	end,
	
	string = function (self, len_size)
		local len = self:number(len_size)
		if not len then
			return
		end
		return self:buffer(len)
	end,
	
	byte_string = function (self)
		return self:string(1)
	end,
	
	word_string = function (self)
		return self:string(2)
	end,
	
	dword_string = function (self)
		return self:string(4)
	end,
	
	parser = function (self, tree, title)
		local parser = {}
		parser.position = {}
		
		parser.position.key = self.position
		parser.key = self:dword_string()
		
		parser.position.value = self.position
		parser.value = self:dword_string()
		
		parser.position.count = self.position
		local count = self:dword()
		
		if not (parser.key and parser.value and count) then
			return
		end
		
		local caption = ("%s = '%s'"):format(utf8(parser.key), utf8(parser.value))
		if title then
			caption = ("%s: %s"):format(title, caption)
		end
		if count > 0 then
			caption = ("%s (%d)"):format(caption, count)
		end
		
		parser.tree = tree:add(self.range(parser.position.key, 1), caption)
		for _ = 1, count do
			table.insert(parser.position, self.position)
			local node = self:parser(parser.tree)
			if not node then
				return
			end
			table.insert(parser, node)
		end
		parser.position.size = self.position - parser.position.key
		parser.tree:set_len(parser.position.size)
		return parser
	end,
	
	parser_with_size = function (self, tree, title)
		local size = self:dword()
		if not size then
			return
		end
		tree:add(self.range(self.position - 4, 4), ("Parser Size: %d bytes"):format(size))
		if size == 0 then
			return true
		end
		return self:parser(tree, title)
	end,
	
	states = function (self)
		if not self:check(1) then
			return
		end
		self.position = self.position + 1
		return self.range(self.position - 1, 1)
	end,
	
	packet = function (self, tree, code)
		return self[code](self, tree)
	end,
	
	gamename = function (self, tree, title)
		local position = self.position
		local gamename = self:byte_string()
		if not gamename then
			return
		end
		tree = tree:add(self.range(position, self.position - position), ("%s: '%s'"):format(title, utf8(gamename)))
		local index = 0
		local titles = {"real_name", "real_pass", "checksum"}
		position = position + 1
		for part in gamename:gmatch("[^\t]+") do
			index = index + 1
			title = titles[index] or ("field_" .. index)
			local value = part:match('^"(.*)"$') or part
			self.result[title] = value
			tree:add(self.range(position, #part), ("%s: '%s'"):format(title, utf8(value)))
			position = position + #part + 1
		end
		return gamename
	end,
	
	mapname = function (self, tree, title)
		local position = self.position
		local mapname = self:byte_string()
		if not mapname then
			return
		end
		tree = tree:add(self.range(position, self.position - position), ("%s: '%s'"):format(title, utf8(mapname)))
		local i = 0
		position = position + 1
		for str in mapname:gmatch("[^|]+") do
			local istr = tonumber(str)
			local title
			    if i == 0 then title = ("state_tag: %d"):format(istr)
			elseif i == 1 then title = ("human_count: %d"):format(istr)
			elseif i == 2 then title = ("ai_count: %d"):format(istr)
			elseif i == 3 then title = ("close_count: %d"):format(istr)
			elseif i == 4 then title = ("ping: %d"):format(istr)
			elseif i == 5 then title = ("rank: %d"):format(istr)
			elseif i == 6 then title = ("lanid_1: %d"):format(istr)
			elseif i == 7 then title = ("lanid_2: %d"):format(istr)
			elseif i == 8 then title = ("search_time: %d"):format(istr)
			elseif i == 9 then title = ("qp_state: %d"):format(istr)
			else
				title = ("unknown: %d"):format(istr)
			end
			tree:add(self.range(position, #str), title)
			i = i + 1
			position = position + #str + 1
		end
		return mapname
	end,
	
	parser_datasync = function (self)
		local parser = self.result.parser
		local parser_s = parser and parser[1] and parser[1].value or nil
		if not parser_s then
			return
		end
		
		local max_player_count = 9
		if data_version >= 0x00020100 then
			max_player_count = 12
		end
		
		local tree = parser[1].tree
		local i = 0
		local pos = parser[1].position.value + 4
		for str in parser_s:gmatch("[^|]+") do
			local istr = tonumber(str)
			local function tadd(title, value)
				parser[title] = value
				if not names[title] then
					title = ("%s: %d"):format(title, value)
				else
					title = ("%s: %d (%s)"):format(title, value, names[title][value])
				end
				tree:add(self.range(pos, #str), title)
			end
			if i < max_player_count then
				if str == "0" then
					tree:add(self.range(pos, 1), "{none}")
				elseif str == "x" then
					tree:add(self.range(pos, 1), "{closed}")
				else
					local t_player = tree:add(self.range(pos, #str), "")
					local j = 0
					local pos = pos
					local is_human, id, difficulty, cid, team, title
					for val in str:gmatch("[^,]+") do
						local ival = tonumber(val)
						if j == 0 then
							is_human = (ival > 0)
							if is_human then
								id = ival
								title = ("id: %d (%s)"):format(id, names.client[id])
							else
								difficulty = math.abs(ival)
								title = ("difficulty: %d (%s)"):format(difficulty, names.difficulty[difficulty])
							end
						elseif j == 1 then
							cid = names.nation[ival]
							title = ("cid: %d (%s)"):format(ival, cid)
						elseif j == 2 then
							team = (ival > 0) and ival or "-"
							title = ("team: %d"):format(ival)
						elseif j == 3 then title = ("color: %d (%s)"):format(ival, names.color[ival])
						elseif j == 4 then title = ("ready: %d (%s)"):format(ival, tostring(ival ~= 0))
						else
							title = ("unknown: %d"):format(ival)
						end
						t_player:add(self.range(pos, #val), title)
						j = j + 1
						pos = pos + #val + 1
					end
					if is_human then
						title = ("{human} [%d] %s"):format(id, names.client[id])
					else
						title = ("{ai}    [%d] %s"):format(difficulty, names.difficulty[difficulty])
					end
					t_player:set_text(("%s / team: %s / nation: %s"):format(title, team, cid))
				end
			elseif i == max_player_count + 0 then tadd("season", istr)
			elseif i == max_player_count + 1 then tadd("terraintype", istr)
			elseif i == max_player_count + 2 then tadd("relieftype", istr)
			elseif i == max_player_count + 3 then tadd("resourcestart", istr)
			elseif i == max_player_count + 4 then tadd("resourcemines", istr)
			elseif i == max_player_count + 5 then tadd("mapsize", istr)
			elseif i == max_player_count + 6 then tadd("startingunits", istr)
			elseif i == max_player_count + 7 then tadd("balloon", istr)
			elseif i == max_player_count + 8 then tadd("cannons", istr)
			elseif i == max_player_count + 9 then tadd("peacetime", istr)
			elseif i == max_player_count + 10 then tadd("century18", istr)
			elseif i == max_player_count + 11 then tadd("capture", istr)
			elseif i == max_player_count + 12 then tadd("marketdip", istr)
			elseif i == max_player_count + 13 then tadd("teams", istr)
			elseif i == max_player_count + 14 then tadd("autosave", istr)
			elseif i == max_player_count + 15 then tadd("limit", istr)
			elseif i == max_player_count + 16 then tadd("gamespeed", istr)
			elseif i == max_player_count + 17 then tadd("adviserassistant", istr)
			elseif i == max_player_count + 18 then tadd("battle", istr)
			elseif i == max_player_count + 19 then tadd("battlestage", istr)
			else
				tadd("unknown", istr)
			end
			i = i + 1
			pos = pos + #str + 1
		end
	end,
	
	parser_datachange = function (self)
		local parser = self.result.parser
		local parser_s = parser and parser[1] and parser[1].value or nil
		if not parser_s then
			return
		end
		
		local tree = parser[1].tree
		local i = 0
		local pos = parser[1].position.value + 4
		for str in parser_s:gmatch("[^|]+") do
			local istr = tonumber(str)
			    if i == 0 then title = ("cid: %d (%s)"):format(istr, names.nation[istr])
			elseif i == 1 then title = ("team: %s"):format((istr > 0) and istr or "-")
			elseif i == 2 then title = ("color: %d (%s)"):format(istr, names.color[istr])
			else
				title = ("unknown: %d"):format(istr)
			end
			tree:add(self.range(pos, #str), title)
			i = i + 1
			pos = pos + #str + 1
		end
	end,
	
	object = function (self, tree, format, ...)
		for i = 1, #format do
			local position = self.position
			local title = select(i, ...)
			local fmt, value = format:sub(i, i), nil
			
			local ftype = self.formats[fmt]
			if ftype then
				value = self[ftype](self, tree, title)
			else
				fmt = assert(tonumber(fmt), "invalid format")
				value = self:number(fmt)
			end
			
			if value == nil then
				local line = "Read error, format: " .. fmt
				tree:add(self.range(position, 1), line)
				error(line)
				return
			end
			self.result[title] = value
			
			if fmt == "p" or fmt == "q" then
				if self.result.parser_id == 100 then
					self:parser_datasync()
				elseif self.result.parser_id == 102 then
					self:parser_datachange()
				end
			elseif fmt ~= "c" and fmt ~= "n" and fmt ~= "m" then
				    if fmt == "b" then value = value and "true" or "false"
				elseif fmt == "d" then value = ("%g sec"):format(value * 86400)
				elseif fmt == "t" then value = format_date(value):gsub("  ", " "):match("^(.-)%.")
				elseif fmt == "s"
				    or fmt == "w"
				    or fmt == "z" then value = ("'%s'"):format(utf8(value))
				elseif fmt == "e" then value = str_states(value)
				elseif fmt == "i" then value = ("%d (%s)"):format(value, names.client[value])
				elseif fmt == "j" then value = ("%d (%s)"):format(value, names.parser[value])
				end
				tree:add(self.range(position, self.position - position), ("%s: %s"):format(title, value))
			end
		end
		return true
	end,
	
	clients = function (self, tree, format, ...)
		local position = self.position
		local t_clients = tree:add(self.range(position, 1), "Clients")
		local count = self:dword()
		if count == nil then
			return
		end
		t_clients:add(self.range(position, 4), ("Count: %d"):format(count))
		for i = 1, count do
			local position = self.position
			local t_client = t_clients:add(self.range(self.position, 1), "client")
			if not self:object(t_client, format, ...) then
				return
			end
			if self.result.id then
				t_client:set_text(("[%d] %s"):format(self.result.id, names.client[self.result.id]))
			end
			t_client:set_len(self.position - position)
		end
		t_clients:set_len(self.position - position)
		t_clients:append_text((" (%d)"):format(count))
		return true
	end,
	
	authenticate = function (self, tree)
		local error_code = self:byte()
		if not (error_code and error_code == 0) then
			return
		end
		
		if not self:object(tree, "ss444ts",
			"nickname",
			"country",
			"score",
			"games_played",
			"games_win",
			"last_game",
			"info")
		then
			return
		end
		
		local count = 0
		local position = self.position
		local t_clients = tree:add(self.range(position, 1), "Clients")
		while true do
			local position = self.position
			local id = self:dword()
			if id == nil then
				return
			elseif id == 0 then
				t_clients:add(self.range(position, 4), "[End]")
				break
			end
			count = count + 1
			local t_client = t_clients:add(self.range(position, 1), ("[%d] "):format(id))
			t_client:add(self.range(position, 4), ("id: %d"):format(id))
			if not self:object(t_client, "esss",
				"states",
				"nickname",
				"country",
				"info")
			then
				return
			end
			names.client[id] = self.result.nickname
			if data_version >= 0x00020100 then
				if not self:object(t_client, "444td",
					"score",
					"games_played",
					"games_win",
					"last_game",
					"pingtime")
				then
					return
				end
			end
			t_client:set_len(self.position - position)
			t_client:append_text(self.result.nickname)
		end
		t_clients:set_len(self.position - position)
		t_clients:append_text((" (%d)"):format(count))
		
		local count = 0
		local position = self.position
		local t_sessions = tree:add(self.range(position, 1), "Sessions")
		while true do
			local position = self.position
			local id_master = self:dword()
			if id_master == nil then
				return
			elseif id_master == 0 then
				t_sessions:add(self.range(position, 4), "[End]")
				break
			end
			count = count + 1
			local t_session = t_sessions:add(self.range(position, 1), ("[%s] "):format(names.client[id_master]))
			t_session:add(self.range(position, 4), ("id_master: %d (%s)"):format(id_master, names.client[id_master]))
			if not self:object(t_session, "4nm4b1",
					"max_players",
					"gamename",
					"mapname",
					"money",
					"fog_of_war",
					"battlefield")
			then
				return
			end
			t_session:append_text(utf8(self.result.real_name))
			if self.result.real_pass ~= "" then
				t_session:append_text((" (pass: %s)"):format(self.result.real_pass))
			end
			if not self:clients(t_session, "i", "id") then
				return
			end
			t_session:set_len(self.position - position)
		end
		t_sessions:set_len(self.position - position)
		t_sessions:append_text((" (%d)"):format(count))
		return true
	end,
	
	[cmd.PING] = function (self, tree)
		if self.result.id_from ~= 0 then
			return self:object(tree, "d",
				"pingtime")
		else
			return self:clients(tree, "id",
				"id",
				"pingtime")
		end
	end,
	
	[cmd.SERVER_CLIENTINFO] = function (self, tree)
		return self:object(tree, "i",
			"id")
	end,
	
	[cmd.USER_CLIENTINFO] = function (self, tree)
		if not self:object(tree, "iess444ts",
			"id",
			"states",
			"nickname",
			"country",
			"score",
			"games_played",
			"games_win",
			"last_game",
			"info")
		then
			return
		end
		if data_version >= 0x00020100 then
			if not self:object(tree, "d",
				"pingtime")
			then
				return
			end
		end
		return true
	end,
	
	[cmd.SERVER_SESSION_MSG] = function (self, tree)
		return self:object(tree, "s",
			"message")
	end,
	
	[cmd.USER_SESSION_MSG] = function (self, tree)
		return self:object(tree, "s",
			"message")
	end,
	
	[cmd.SERVER_MESSAGE] = function (self, tree)
		return self:object(tree, "s",
			"message")
	end,
	
	[cmd.USER_MESSAGE] = function (self, tree)
		return self:object(tree, "s",
			"message")
	end,
	
	[cmd.SERVER_REGISTER] = function (self, tree)
		if not self:object(tree, "vvssssss",
			"vcore",
			"vdata",
			"email",
			"password",
			"cdkey",
			"nickname",
			"country",
			"info")
		then
			return
		end
		data_version = convert_version(self.result.vdata)
		return true
	end,
	
	[cmd.USER_REGISTER] = function (self, tree)
		return self:authenticate(tree)
	end,
	
	[cmd.SERVER_AUTHENTICATE] = function (self, tree)
		if not self:object(tree, "vvsss",
			"vcore",
			"vdata",
			"email",
			"password",
			"cdkey")
		then
			return
		end
		data_version = convert_version(self.result.vdata)
		return true
	end,
	
	[cmd.USER_AUTHENTICATE] = function (self, tree)
		return self:authenticate(tree)
	end,
	
	[cmd.SERVER_SESSION_CREATE] = function (self, tree)
		return self:object(tree, "4snm4b1",
			"max_players",
			"password",
			"gamename",
			"mapname",
			"money",
			"fog_of_war",
			"battlefield")
	end,
	
	[cmd.USER_SESSION_CREATE] = function (self, tree)
		return self:object(tree, "e4nm4b1",
			"states",
			"max_players",
			"gamename",
			"mapname",
			"money",
			"fog_of_war",
			"battlefield")
	end,
	
	[cmd.SERVER_SESSION_JOIN] = function (self, tree)
		return self:object(tree, "i",
			"id_master")
	end,
	
	[cmd.USER_SESSION_JOIN] = function (self, tree)
		return self:object(tree, "ie",
			"id_master",
			"states")
	end,
	
	[cmd.SERVER_SESSION_LEAVE] = function (self, tree)
		return true
	end,
	
	[cmd.USER_SESSION_LEAVE] = function (self, tree)
		if not self:object(tree, "b", "is_master") then
			return
		end
		return self:clients(tree, "ie",
			"id",
			"states")
	end,
	
	[cmd.SERVER_SESSION_LOCK] = function (self, tree)
		return self:clients(tree, "i1",
			"id",
			"team")
	end,
	
	[cmd.USER_SESSION_LOCK] = function (self, tree)
		return self:clients(tree, "ie",
			"id",
			"states")
	end,
	
	[cmd.SERVER_SESSION_INFO] = function (self, tree)
		return true
	end,
	
	[cmd.USER_SESSION_INFO] = function (self, tree)
		if not self:object(tree, "4nm4b1",
			"max_players",
			"gamename",
			"mapname",
			"money",
			"fog_of_war",
			"battlefield")
		then
			return
		end
		return self:clients(tree, "ie",
			"id",
			"states")
	end,
	
	[cmd.USER_CONNECTED] = function (self, tree)
		if not self:object(tree, "ssse",
			"nickname",
			"country",
			"info",
			"states")
		then
			return
		end
		names.client[self.result.id_from] = self.result.nickname
		if data_version >= 0x00020100 then
			if not self:object(tree, "444td",
				"score",
				"games_played",
				"games_win",
				"last_game",
				"pingtime")
			then
				return
			end
		end
		return true
	end,
	
	[cmd.USER_DISCONNECTED] = function (self, tree)
		return true
	end,
	
	[cmd.SERVER_USER_EXIST] = function (self, tree)
		return self:object(tree, "s",
			"email")
	end,
	
	[cmd.USER_USER_EXIST] = function (self, tree)
		return self:object(tree, "sb",
			"email",
			"exist")
	end,
	
	[cmd.SERVER_SESSION_UPDATE] = function (self, tree)
		return self:object(tree, "nm4b1",
			"gamename",
			"mapname",
			"money",
			"fog_of_war",
			"battlefield")
	end,
	
	[cmd.SERVER_SESSION_CLIENT_UPDATE] = function (self, tree)
		return self:object(tree, "1",
			"team")
	end,
	
	[cmd.USER_SESSION_CLIENT_UPDATE] = function (self, tree)
		return self:object(tree, "1",
			"team")
	end,
	
	[cmd.SERVER_VERSION_INFO] = function (self, tree)
		if not self:object(tree, "v",
			"vdata")
		then
			return
		end
		data_version = convert_version(self.result.vdata)
		return true
	end,
	
	[cmd.USER_VERSION_INFO] = function (self, tree)
		if not self:object(tree, "vvq",
			"vcore",
			"vdata",
			"parser")
		then
			return
		end
		data_version = convert_version(self.result.vdata)
		return true
	end,
	
	[cmd.SERVER_SESSION_CLOSE] = function (self, tree)
		return true
	end,
	
	[cmd.USER_SESSION_CLOSE] = function (self, tree)
		if not self:object(tree, "t",
			"timestamp")
		then
			return nil
		end
		return self:clients(tree, "i4",
			"id",
			"score")
	end,
	
	[cmd.SERVER_GET_TOP_USERS] = function (self, tree)
		return self:object(tree, "4",
			"count")
	end,
	
	[cmd.USER_GET_TOP_USERS] = function (self, tree)
		local count = 0
		local position = self.position
		local t_clients = tree:add(self.range(position, 1), "Clients")
		while true do
			local position = self.position
			local mark = self:byte()
			if mark == nil then
				return nil
			elseif mark ~= 1 then
				t_clients:add(self.range(position, 1), "[End]")
				break
			end
			count = count + 1
			local t_client = t_clients:add(self.range(position, 1), "")
			if not self:object(t_client, "ss444t",
				"nickname",
				"country",
				"score",
				"games_played",
				"games_win",
				"last_game")
			then
				return
			end
			t_client:set_len(self.position - position)
			t_client:append_text(self.result.nickname)
		end
		t_clients:set_len(self.position - position)
		t_clients:append_text((" (%d)"):format(count))
		return true
	end,
	
	[cmd.SERVER_UPDATE_INFO] = function (self, tree)
		return self:object(tree, "ssss",
			"password",
			"nickname",
			"country",
			"info")
	end,
	
	[cmd.USER_UPDATE_INFO] = function (self, tree)
		return self:object(tree, "c",
			cmd.USER_CONNECTED)
	end,
	
	[cmd.SERVER_SESSION_KICK] = function (self, tree)
		return self:object(tree, "i",
			"id")
	end,
	
	[cmd.USER_SESSION_KICK] = function (self, tree)
		return self:object(tree, "i",
			"id")
	end,
	
	[cmd.SERVER_SESSION_CLSCORE] = function (self, tree)
		return self:object(tree, "i4",
			"id",
			"score")
	end,
	
	[cmd.USER_SESSION_CLSCORE] = function (self, tree)
		return self:object(tree, "i4",
			"id",
			"score")
	end,
	
	[cmd.SERVER_FORGOT_PSW] = function (self, tree)
		return self:object(tree, "s",
			"email")
	end,
	
	[cmd.SERVER_SESSION_PARSER] = function (self, tree)
		return self:object(tree, "jp",
			"parser_id",
			"parser")
	end,
	
	[cmd.USER_SESSION_PARSER] = function (self, tree)
		if not self:object(tree, "jp",
			"parser_id",
			"parser")
		then
			return
		end
		if self:remain() > 0 then
			self:object(tree, "4",
				"unk_dw")
		end
		return true
	end,
	
	[cmd.USER_SESSION_RECREATE] = function (self, tree)
		return self:object(tree, "q",
			"parser")
	end,
	
	[cmd.USER_SESSION_REJOIN] = function (self, tree)
		return true
	end,
	
	[cmd.LAN_PARSER] = function (self, tree)
		return self:object(tree, "jp",
			"parser_id",
			"parser")
	end,
	
	[cmd.LAN_CLIENT_INFO] = function (self, tree)
		if not self:object(tree, "wwbi1411",
			"player",
			"nickname",
			"spectator",
			"id",
			"team",
			"score",
			"field_1C",
			"field_1D")
		then
			return
		end
		names.client[self.result.id] = self.result.nickname
		return true
	end,
	
	[0x0065] = function (self, tree)
		return self:object(tree, "wc",
			"password",
			cmd.LAN_CLIENT_INFO)
	end,
	
	[0x0066] = function (self, tree)
		return self:object(tree, "c",
			cmd.LAN_CLIENT_INFO)
	end,
	
	[cmd.LAN_SERVER_INFO] = function (self, tree)
		return self:object(tree, "ww44wb1b4",
			"gamename",
			"mapname",
			"max_players",
			"protocol_ver",
			"host",
			"secured",
			"battlefield",
			"fog_of_war",
			"money")
	end,
	
	[0x00C9] = function (self, tree)
		if not self:object(tree, "ic",
			"id_master",
			cmd.LAN_SERVER_INFO)
		then
			return
		end
		return self:clients(tree, "ic",
			"id",
			cmd.LAN_CLIENT_INFO)
	end,
	
	[cmd.LAN_RECORD] = function (self, tree)
		self.position = self.position + self:remain()
		tree:add(self.range, ("Data: %d bytes"):format(self.range:len()))
		return true
	end,
},
{
	__call = function (reader, range)
		return setmetatable(
			{
				range = range,
				position = 0,
				result = {},
			},
			{
				__index = reader,
			}
		)
	end,
})

local Cossacks3 = Proto("cossacks3", "Cossacks 3")
Cossacks3.fields.code = ProtoField.uint16("cossacks3.code", "Command code", base.HEX)
Cossacks3.fields.command = ProtoField.string("cossacks3.command", "Command name")
Cossacks3.fields.id_from = ProtoField.uint16("cossacks3.id_from", "ID from", base.DEC)
Cossacks3.fields.id_to = ProtoField.uint16("cossacks3.id_to", "ID to", base.DEC)

Cossacks3.dissector = function (range, pinfo, root)
	pinfo.cols.protocol = "cossacks3"
	pinfo.cols.info = ""
	
	function reassemble_hint()
		local hint = "Edit→Preferences→Protocols→TCP→Allow subdissector to reassemble TCP streams"
		pinfo.cols.info = ("%s%s"):format(pinfo.cols.info, hint)
		root:add(Cossacks3, range(), ("Cossacks 3 [%s]"):format(hint))
	end
	
	while range:len() > 4 do
		local r_length = range(0, 4)
		local length = r_length:le_uint()
		local pdu_length = 4 + 2 + 4 + 4 + length
		if range:len() < pdu_length then
			pinfo.desegment_len = pdu_length - range:len()
			reassemble_hint()
			return nil
		end
		
		local r_command = range(4, 2)
		local command = r_command:le_uint()
		local command_name = names.command:raw(command) or ("0x%04X"):format(command)
		
		local r_id_from = range(6, 4)
		local id_from = r_id_from:le_uint()
		
		local r_id_to = range(10, 4)
		local id_to = r_id_to:le_uint()
		
		pinfo.cols.info = ("%s[%s] %d → %d "):format(pinfo.cols.info, command_name, id_from, id_to)
		local tree = root:add(Cossacks3, range(0, pdu_length), ("Cossacks 3 [%s] From: %s, To: %s, Len: %d bytes")
			:format(command_name, names.client:raw(id_from) or id_from, names.client:raw(id_to) or id_to, pdu_length))
		tree:add(r_length, ("Payload length: %d bytes"):format(length))
		tree:add(Cossacks3.fields.code, r_command, command)
		tree:add(Cossacks3.fields.command, r_command, names.command:raw(command) or "UNKNOWN")
		tree:add(Cossacks3.fields.id_from, r_id_from, id_from):append_text(" (" .. names.client[id_from] .. ")")
		tree:add(Cossacks3.fields.id_to, r_id_to, id_to):append_text(" (" .. names.client[id_to] .. ")")
		
		if (length > 0) and reader[command] then
			local rr = reader(range(14, length))
			rr.result.code = command
			rr.result.id_from = id_from
			rr.result.id_to = id_to
			if not rr[command](rr, tree) then
				local msg = "Read error"
				tree:add(range, msg)
				error(msg)
			elseif rr:remain() > 0 then
				local msg = "Unknown data"
				tree:add(rr.range(rr.position), msg)
				error(msg)
			end
		end
		
		if range:len() - pdu_length == 0 then
			break
		end
		range = range(pdu_length)
	end
	
	return nil
end

DissectorTable.get("tcp.port"):add(31523, Cossacks3)
