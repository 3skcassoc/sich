local cmd =
{
	[0x0190] = "SHELL_CONSOLE",                -- 
	[0x0191] = "PING",                         -- 
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
	
	[0x01BB] = "SERVER_SESSION_PARSER",        -- LanPublicServerSendSessionParser
	[0x01BC] = "USER_SESSION_PARSER",          -- leSessionParser
	[0x01BD] = "USER_SESSION_RECREATE",        -- leSessionRecreate
	[0x01BE] = "USER_SESSION_REJOIN",          -- leSessionRejoin
	[0x01C0] = "0x01C0",                       --
	
	[0x0032] = "LAN_PARSER",                   -- LanSendParser
	[0x0064] = "LAN_CLIENT_INFO",              -- leClientInfo
	[0x00C8] = "LAN_SERVER_INFO",              -- leServerInfo
	[0x0456] = "LAN_DO_START",                 -- LanDoStart
	[0x0457] = "LAN_DO_START_GAME",            -- DoStartGame, leGenerate
	[0x0460] = "LAN_DO_READY",                 -- LanDoReady
	[0x0461] = "LAN_DO_READY_DONE",            -- LanDoReadyDone, leReady
	[0x04B0] = "LAN_RECORD",                   -- 
}

xcmd = {}
for code, name in pairs(cmd) do
	xcmd[code] = name
	xcmd[name] = code
end
cmd = nil

xgc = {}

xgc.LAN_GENERATE = 1
xgc.LAN_READYSTART = 2
xgc.LAN_START = 3
xgc.LAN_ROOM_READY = 4
xgc.LAN_ROOM_START = 5
xgc.LAN_ROOM_CLIENT_CHANGES = 6
xgc.LAN_GAME_READY = 7
xgc.LAN_GAME_ANSWER_READY = 8
xgc.LAN_GAME_START = 9
xgc.LAN_GAME_SURRENDER = 10
xgc.LAN_GAME_SURRENDER_CONFIRM = 11
xgc.LAN_GAME_SERVER_LEAVE = 12
xgc.LAN_GAME_SESSION_RESULTS = 13
xgc.LAN_GAME_SYNC_REQUEST = 14
xgc.LAN_GAME_SYNC_DATA = 15
xgc.LAN_GAME_SYNC_GAMETIME = 16
xgc.LAN_GAME_SYNC_ALIVE = 17
xgc.LAN_ROOM_SERVER_DATASYNC = 100
xgc.LAN_ROOM_SERVER_DATACHANGE = 101
xgc.LAN_ROOM_CLIENT_DATACHANGE = 102
xgc.LAN_ROOM_CLIENT_LEAVE = 103
xgc.LAN_MODS_MODSYNC_REQUEST = 200
xgc.LAN_MODS_MODSYNC_PARSER = 201
xgc.LAN_MODS_CHECKSUM_REQUEST = 202
xgc.LAN_MODS_CHECKSUM_ANSWER = 203
xgc.LAN_MODS_CHECKSUM_REQUESTCANJOIN = 204
xgc.LAN_MODS_CHECKSUM_ANSWERCANJOIN = 205
xgc.LAN_MODS_CHECKSUM_ANSWERCANNOTJOIN = 206
xgc.LAN_ADVISER_CLIENT_DATACHANGE = 300

xgc.spectator_countryid = -2

xgc.player_victorystate_none = 0
xgc.player_victorystate_win = 1
xgc.player_victorystate_lose = 2

xgc.player_victorystate =
{
	[xgc.player_victorystate_none] = "none",
	[xgc.player_victorystate_win] = "win",
	[xgc.player_victorystate_lose] = "lose",
}
