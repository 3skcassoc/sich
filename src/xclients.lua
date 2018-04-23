require "xlog"
require "xclass"

local log = xlog("xclients")

xclients = xclass
{
	__create = function (self)
		self.clients = {}
		return self
	end,
	
	get_clients_count = function (self)
		local count = 0
		for _ in pairs(self.clients) do
			count = count + 1
		end
		return count
	end,
	
	check_client = function (self, client_id)
		if self.clients[client_id] then
			return true
		end
		log("debug", "client not found: %d", client_id)
		return false
	end,
	
	broadcast = function (self, package)
		package:dump_head()
		local buffer = package:get()
		for _, client in pairs(self.clients) do
			client.socket:send(buffer)
		end
		return package
	end,
	
	dispatch = function (self, package)
		if package.id_to == 0 then
			return self:broadcast(package)
		end
		if self:check_client(package.id_to) then
			package:transmit(self.clients[package.id_to])
		end
		return package
	end,
}
