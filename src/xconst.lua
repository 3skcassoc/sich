xconst = setmetatable({},
	{
		__call = function (_, tbl)
			local result = {}
			for code, name in pairs(tbl) do
				result[code] = name
				result[name] = code
			end
			return result
		end,
	})

xcmd = xconst
{
	[0x0190] = "SHELL_CONSOLE",                -- 
	[0x0191] = "PING",                         -- lePingInfo
	[0x0192] = "SERVER_CLIENTINFO",            -- LanPublicServerUpdateClientInfo
	[0x0193] = "USER_CLIENTINFO",              -- leShellClientInfo
	[0x0194] = "SERVER_SESSION_MSG",           -- LanPublicServerSendSessionMessage
	[0x0195] = "USER_SESSION_MSG",             -- leShellSessionMessage
	[0x0196] = "SERVER_MESSAGE",               -- LanPublicServerSendMessage
	[0x0197] = "USER_MESSAGE",                 -- leShellMessage
	[0x0198] = "SERVER_REGISTER",              -- LanPublicServerRegister
	[0x0199] = "USER_REGISTER",                -- leShellLogged
	[0x019A] = "SERVER_AUTHENTICATE",          -- LanPublicServerLogin
	[0x019B] = "USER_AUTHENTICATE",            -- leShellLogged
	[0x019C] = "SERVER_SESSION_CREATE",        -- LanCreateGame
	[0x019D] = "USER_SESSION_CREATE",          -- leShellSessionCreate
	[0x019E] = "SERVER_SESSION_JOIN",          -- LanJoinGame
	[0x019F] = "USER_SESSION_JOIN",            -- leShellSessionJoin
	[0x01A0] = "SERVER_SESSION_LEAVE",         -- LanTerminateGame
	[0x01A1] = "USER_SESSION_LEAVE",           -- leShellSessionLeave
	[0x01A2] = "SERVER_SESSION_LOCK",          -- LanLockServer
	[0x01A3] = "USER_SESSION_LOCK",            -- leShellSessionLock
	[0x01A4] = "SERVER_SESSION_INFO",          -- LanPublicServerUpdateMySessionInfo
	[0x01A5] = "USER_SESSION_INFO",            -- leShellSessionInfo
	[0x01A6] = "USER_CONNECTED",               -- leShellClientConnected
	[0x01A7] = "USER_DISCONNECTED",            -- leShellClientDisconnected
	[0x01A8] = "SERVER_USER_EXIST",            -- LanPublicServerUserExist
	[0x01A9] = "USER_USER_EXIST",              -- leShellValidEmail
	[0x01AA] = "SERVER_SESSION_UPDATE",        -- LanSrvSet*
	[0x01AB] = "SERVER_SESSION_CLIENT_UPDATE", -- LanClSetMyTeam
	[0x01AC] = "USER_SESSION_CLIENT_UPDATE",   -- 
	[0x01AD] = "SERVER_VERSION_INFO",          -- LanPublicServerUpdateInfo
	[0x01AE] = "USER_VERSION_INFO",            -- leShellServerInfo
	[0x01AF] = "SERVER_SESSION_CLOSE",         -- LanPublicServerCloseSession
	[0x01B0] = "USER_SESSION_CLOSE",           -- leShellSessionClose
	[0x01B1] = "SERVER_GET_TOP_USERS",         -- LanPublicServerUpdateTopUsers
	[0x01B2] = "USER_GET_TOP_USERS",           -- leShellUpdateTopList
	[0x01B3] = "SERVER_UPDATE_INFO",           -- LanPublicServerRegister
	[0x01B4] = "USER_UPDATE_INFO",             -- leShellClientUpdateInfo
	[0x01B5] = "SERVER_SESSION_KICK",          -- LanKillClient
	[0x01B6] = "USER_SESSION_KICK",            -- 
	[0x01B7] = "SERVER_SESSION_CLSCORE",       -- LanSrvSetClientScore
	[0x01B8] = "USER_SESSION_CLSCORE",         -- 
	[0x01B9] = "SERVER_FORGOT_PSW",            -- LanPublicServerForgotPassword
	[0x01BA] = "SERVER_SESSION_WRONG_CLOSE",   -- 
	[0x01BB] = "SERVER_SESSION_PARSER",        -- LanPublicServerSendSessionParser
	[0x01BC] = "USER_SESSION_PARSER",          -- leSessionParser
	[0x01BD] = "USER_SESSION_RECREATE",        -- leSessionRecreate
	[0x01BE] = "USER_SESSION_REJOIN",          -- leSessionRejoin
	[0x01BF] = "SERVER_PING_TEST",             -- 
	[0x01C0] = "USER_PING_TEST",               -- 
	[0x01C1] = "SERVER_SESSION_REJOIN",        -- 
	[0x01C2] = "SERVER_SELECT_FRIENDS",        -- 
	[0x01C3] = "USER_SELECT_FRIENDS",          -- leSelectFriends
	[0x01C4] = "SERVER_UPDATE_FRIENDS",        -- 
	[0x01C5] = "SERVER_DELETE_FRIENDS",        -- 
	[0x01C6] = "SERVER_SELECT_CHATS",          -- 
	[0x01C7] = "USER_SELECT_CHATS",            -- leSelectChats
	[0x01C8] = "SERVER_INSERT_CHATS",          -- 
	[0x01C9] = "SERVER_UPDATE_CHATS",          -- 
	[0x01CA] = "SERVER_DELETE_CHATS",          -- 
	[0x01CB] = "SERVER_SELECT_CLANS",          -- 
	[0x01CC] = "USER_SELECT_CLANS",            -- leSelectClans
	[0x01CD] = "SERVER_INSERT_CLANS",          -- 
	[0x01CE] = "SERVER_UPDATE_CLANS",          -- 
	[0x01CF] = "SERVER_DELETE_CLANS",          -- 
	[0x01D0] = "SERVER_SELECT_MEMBERS",        -- 
	[0x01D1] = "USER_SELECT_MEMBERS",          -- leSelectMembers
	[0x01D2] = "SERVER_INSERT_MEMBERS",        -- 
	[0x01D3] = "SERVER_DELETE_MEMBERS",        -- 
	[0x01D4] = "SERVER_SELECT_ADMINS",         -- 
	[0x01D5] = "USER_SELECT_ADMINS",           -- leSelectAdmins
	[0x01D6] = "SERVER_UPDATE_ADMINS",         -- 
	[0x01D7] = "SERVER_DELETE_ADMINS",         -- 
	[0x01D8] = "SERVER_BANNING_ADMINS",        -- 
	[0x01D9] = "SERVER_RESERV0_ADMINS",        -- 
	[0x01DA] = "SERVER_RESERV1_ADMINS",        -- 
	[0x01DB] = "SERVER_RESERV2_ADMINS",        -- 
	[0x01DC] = "SERVER_SELECT_STATS",          -- 
	[0x01DD] = "USER_SELECT_STATS",            -- leSelectStats
	[0x01DE] = "SERVER_UPDATE_STATS",          -- 
	[0x01DF] = "SERVER_DELETE_STATS",          -- 
	[0x01E0] = "SERVER_GET_SESSIONS",          -- 
	[0x01E1] = "USER_GET_SESSIONS",            -- leGetSessions
	[0x01E2] = "SERVER_PING_LOCK",             -- 
	[0x01E3] = "SERVER_PING_UNLOCK",           -- 
	[0x01E4] = "SERVER_CHECKSUM",              -- 
	[0x01E5] = "USER_CHECKSUM",                -- 
	[0x01E6] = "USER_CHECKSUM_FAILED",         -- leChecksumFailed
	
	[0x0032] = "LAN_PARSER",                   -- LanSendParser
	[0x0064] = "LAN_CLIENT_INFO",              -- leClientInfo
	[0x00C8] = "LAN_SERVER_INFO",              -- leServerInfo
	[0x0456] = "LAN_DO_START",                 -- LanDoStart
	[0x0457] = "LAN_DO_START_GAME",            -- DoStartGame, leGenerate
	[0x0460] = "LAN_DO_READY",                 -- LanDoReady
	[0x0461] = "LAN_DO_READY_DONE",            -- LanDoReadyDone, leReady
	[0x04B0] = "LAN_RECORD",                   -- 
}

xcmd.format = function (code)
	return ("[0x%04X] %s"):format(code, xcmd[code] or "UNKNOWN")
end

xconst.parser = xconst
{
	[  1] = "LAN_GENERATE",
	[  2] = "LAN_READYSTART",
	[  3] = "LAN_START",
	[  4] = "LAN_ROOM_READY",
	[  5] = "LAN_ROOM_START",
	[  6] = "LAN_ROOM_CLIENT_CHANGES",
	[  7] = "LAN_GAME_READY",
	[  8] = "LAN_GAME_ANSWER_READY",
	[  9] = "LAN_GAME_START",
	[ 10] = "LAN_GAME_SURRENDER",
	[ 11] = "LAN_GAME_SURRENDER_CONFIRM",
	[ 12] = "LAN_GAME_SERVER_LEAVE",
	[ 13] = "LAN_GAME_SESSION_RESULTS",
	[ 14] = "LAN_GAME_SYNC_REQUEST",
	[ 15] = "LAN_GAME_SYNC_DATA",
	[ 16] = "LAN_GAME_SYNC_GAMETIME",
	[ 17] = "LAN_GAME_SYNC_ALIVE",
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

xconst.player_victorystate = xconst
{
	[0] = "none",
	[1] = "win",
	[2] = "lose",
}

xconst.spectator_countryid = -2
