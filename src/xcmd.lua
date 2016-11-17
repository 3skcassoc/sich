local cmd =
{
	[0x0190] = "SHELL_CONSOLE",
	[0x0191] = "PING",
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
	[0x01BA] = "",                             -- 
	[0x01BB] = "SERVER_SESSION_PARSER",        -- LanPublicServerSendSessionParser
	[0x01BC] = "USER_SESSION_PARSER",          -- leSessionParser
	[0x01BD] = "USER_SESSION_RECREATE",        -- leSessionRecreate
	[0x01BE] = "USER_SESSION_REJOIN",          -- leSessionRejoin
}

xcmd = {}
for code, name in pairs(cmd) do
	xcmd[code] = name
	xcmd[name] = code
end
cmd = nil
