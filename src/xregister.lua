require "xlog"
require "xstore"

local log = xlog("xregister")

register = xstore.load("register", {})

local next_id = 1
for _, account in pairs(register) do
	if account.id >= next_id then
		next_id = account.id + 1
	end
end
log("debug", "next_id = %d", next_id)

local function save_register()
	return xstore.save("register", register)
end

local function assign(client, email, account)
	client.email = email
	client.password = account.password
	client.cdkey = account.cdkey
	client.nickname = account.nickname
	client.country = account.country
	client.info = account.info
	
	client.id = account.id
	client.score = account.score
	client.games_played = account.games_played
	client.games_win = account.games_win
	client.last_game = account.last_game
	client.blocked = account.blocked
	
	return true
end

xregister =
{
	new = function (client, email, password, cdkey, nickname, country, info)
		if register[email:lower()] then
			return false
		end
		log("info", "registering new user: %s", email)
		local account = {
			password = password,
			cdkey = cdkey,
			nickname = nickname,
			country = country,
			info = info,
			
			id = next_id,
			score = 0,
			games_played = 0,
			games_win = 0,
			last_game = 0,
			blocked = false,
		}
		next_id = next_id + 1
		register[email:lower()] = account
		save_register()
		return assign(client, email, account)
	end,
	
	get = function (client, email)
		local account = register[email:lower()]
		if not account then
			return false
		end
		return assign(client, email, account)
	end,
	
	find = function (email)
		return register[email:lower()] ~= nil
	end,
	
	update = function (client, email, password, nickname, country, info)
		local account = register[email:lower()]
		if not account then
			return false
		end
		log("info", "updating user info: %s", email)
		account.password = password
		account.nickname = nickname
		account.country = country
		account.info = info
		save_register()
		return assign(client, email, account)
	end,
	
	block = function (email, blocked)
		local account = register[email:lower()]
		if not account then
			return false
		end
		account.blocked = blocked
		save_register()
		return true
	end,
}
