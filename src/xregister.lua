require "xlog"
require "xstore"
require "xclass"

local log = xlog("xregister")

local function assign(client, id, account)
	client.id = id
	
	client.email = account.email
	client.password = account.password
	client.cdkey = account.cdkey
	client.nickname = account.nickname
	client.country = account.country
	client.info = account.info
	
	client.score = account.score
	client.games_played = account.games_played
	client.games_win = account.games_win
	client.last_game = account.last_game
	client.banned = account.banned
end

xregister = xclass
{
	__create = function ()
		local self = xstore.load("register", {})
		setmetatable(self, xregister.__objmt)
		
		local maxid = 0
		while true do
			local email, account
			for em, acc in pairs(self) do
				if type(em) == "string" then
					email = em
					account = acc
					break
				elseif maxid < em then
					maxid = em
				end
			end
			if not email then
				break
			end
			self[email] = nil
			account.email = email
			self[account.id] = account
			account.id = nil
			if account.blocked ~= nil then
				account.banned = account.blocked
				account.blocked = nil
			end
		end
		for id = 1, maxid do
			if type(self[id]) ~= "table" then
				self[id] = false
			end
		end
		
		return self
	end,
	
	save = function (self)
		return xstore.save("register", self)
	end,
	
	pairs = function (self)
		local iter, state, var = ipairs(self)
		local function iter1(state, var)
			local id, account = iter(state, var)
			if not id then
				return nil, nil
			elseif account then
				return id, account
			end
			return iter1(state, id)
		end
		return iter1, state, var
	end,
	
	find = function (self, email)
		if self[email] then
			return email, self[email]
		else
			email = email:lower()
			for id, account in self:pairs() do
				if account.email == email then
					return id, account
				end
			end
		end
		return nil, nil
	end,
	
	exist = function (self, email)
		return self:find(email) ~= nil
	end,
	
	new = function (self, client, request)
		local email = assert(request.email)
		if self:exist(email) then
			return false
		end
		log("info", "registering new user: %s", email)
		local account =
		{
			email = email:lower(),
			password = assert(request.password),
			cdkey = assert(request.cdkey),
			nickname = assert(request.nickname),
			country = assert(request.country),
			info = assert(request.info),
			
			score = 0,
			games_played = 0,
			games_win = 0,
			last_game = 0,
			banned = false,
		}
		table.insert(self, account)
		self:save()
		assign(client, #self, account)
		return true
	end,
	
	get = function (self, client, email)
		local id, account = self:find(email)
		if not id then
			return false
		end
		assign(client, id, account)
		return true
	end,
	
	update = function (self, client, do_not_save)
		local id, account = self:find(client.id)
		if not id then
			return false
		end
		account.password = client.password
		account.nickname = client.nickname
		account.country = client.country
		account.info = client.info
		account.score = client.score
		account.games_played = client.games_played
		account.games_win = client.games_win
		account.last_game = client.last_game
		if not do_not_save then
			self:save()
		end
		return true
	end,
	
	remove = function (self, email)
		local id = self:find(email)
		if not id then
			return false
		end
		self[id] = false
		self:save()
		return true
	end,
	
	ban = function (self, email, banned)
		local id, account = self:find(email)
		if not id then
			return false
		end
		account.banned = banned
		self:save()
		return true
	end,
}

register = xregister()
