#pragma semicolon 1

#include <sourcemod>

#include <adminmenu>
#include <cstrike>
#include <sdktools>
#include <smlib/arrays>

#undef REQUIRE_PLUGIN
#include <SurfTimer>
#include <SurfTimerZones>

#define MAX_FILE_LEN 255

enum User
{
	UserId,
	String:SteamID[AUTHID_MAX],
	String:Username[USERNAME_MAX],
	firstConnect,
	lastConnect,
	connectCount,
	userPoints
}

enum UserJumps
{
	LastJumpTimes[3],
}

enum UserLastTriggerTime
{
	TriggerTime,
}

// mysql 
new g_iSQLReconnectCounter = 0;
new Handle:g_hSQL;

// player
new g_userHide[MAXPLAYERS];
new g_users[MAXPLAYERS][User];
new g_userJumps[MAXPLAYERS][UserJumps];
new g_userLastTriggerTime[MAXPLAYERS][UserLastTriggerTime];

new String:g_soundEndName[] = "surftimer/SurfTimer_30seconds1.mp3";
new bool:g_endSoundPlayed = false;

new String:g_soundConnectName[] = "surftimer/SurfTimer_connect2.mp3";

new Handle:g_TriggerList = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "[SurfTimer]-User",
	author = "Fuxx",
	description = "The ultimative user tool",
	version = PLUGIN_VERSION,
	url = "http://www.stefanpopp.de"
};

/**
* On Connect
*/

public OnPluginStart()
{
	ConnectSQL();
	PrintToServer("[SurfTimer-User] %s loaded...", PLUGIN_URL);	
	// Commands
	RegConsoleCmd("sm_start", User_start);
	RegConsoleCmd("sm_stop", User_stop);
	RegConsoleCmd("sm_restart", User_restart);
	RegConsoleCmd("sm_teleport", User_teleport);
	RegConsoleCmd("sm_tele", User_teleport);
	RegConsoleCmd("sm_hide", User_hide);
	RegConsoleCmd("sm_unhide", User_unhide);
	RegConsoleCmd("sm_respawn", User_respawn);
	RegConsoleCmd("sm_spawn", User_respawn);
	RegConsoleCmd("sm_redie", User_respawn);
	RegConsoleCmd("sm_spectate", User_spectate);
	RegConsoleCmd("sm_spec", User_spectate);
	RegConsoleCmd("sm_s", User_practiceStage);
	RegConsoleCmd("sm_stage", User_practiceStage);

	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_Say);
	
	HookEvent("player_spawn", User_spawned);
	HookEvent("player_team", User_joinTeam);
	HookEvent("player_jump", User_jumped);

	HookEvent("player_death", User_died);
	g_TriggerList = CreateArray(32);
	PushArrayString(g_TriggerList, "!start");
	PushArrayString(g_TriggerList, "!stop");
	PushArrayString(g_TriggerList, "!restart");
	PushArrayString(g_TriggerList, "!teleport");
}

public Action:Command_Say(client, args)
{	
	decl String:text[192];
	GetCmdArgString(text, sizeof(text));
	
	new startidx;
	if (text[strlen(text)-1] == '"')
	{
		text[strlen(text)-1] = '\0';
		startidx = 1;
	}
	
	decl String:trigger[192];
	BreakString(text[startidx], trigger, sizeof(trigger));
	
	decl String:hidden[64];
	new count = GetArraySize(g_TriggerList);
	for (new i = 0; i < count; i++)
	{
		GetArrayString(g_TriggerList, i, hidden, sizeof(hidden));
		if (strcmp(trigger, hidden, false) == 0)
		{
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;	
}

public Action:OnWeaponPickUp(client, weapon)
{
	return Plugin_Handled;
}


public OnClientSettingsChanged(client)
{
	PrintToServer("%s", g_users[client][Username]);
	decl String:newNick[USERNAME_MAX];
	GetClientName(client, newNick, sizeof(newNick));

	if (0 == strcmp(g_users[client][Username], newNick, false)) {
		strcopy(g_users[client][Username], USERNAME_MAX, newNick);
		AddNickname(client);
	}
}

public OnClientAuthorized(client, const String:auth[])
{
	if (g_hSQL == INVALID_HANDLE){
		ConnectSQL();
	}

	strcopy(g_users[client][SteamID], AUTHID_MAX, auth);
	
	decl username[USERNAME_MAX];
	GetClientName(client, username, sizeof(username));
	strcopy(g_users[client][Username], USERNAME_MAX, username);

	g_users[client][firstConnect] = GetTime();
	g_users[client][lastConnect] = GetTime();
	g_users[client][connectCount] = 0;
	g_users[client][userPoints] = 0;
	g_userHide[client] = false;

	g_userJumps[client][LastJumpTimes][2] = 0;
	g_userJumps[client][LastJumpTimes][1] = 0;
	g_userJumps[client][LastJumpTimes][0] = 0;

	g_userLastTriggerTime[client][LastJumpTimes] = 0;

	LoadUser(client);
}

public OnClientPutInServer(client) 
{ 
    g_userHide[client] = false; 
    SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit);
}

public OnConfigsExecuted()
{
	decl String:buffer[128];
	PrecacheSound(g_soundEndName, true);
	Format(buffer, sizeof(buffer), "sound/%s", g_soundEndName);
	AddFileToDownloadsTable(buffer);
	// PrecacheSound(g_soundConnectName, true);
	// Format(buffer, sizeof(buffer), "sound/%s", g_soundConnectName);
	// AddFileToDownloadsTable(buffer);
}

public OnMapStart()
{
	g_endSoundPlayed = false;
	CreateTimer(1.0, MapEndSound, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	ReloadChatRanks(INVALID_HANDLE);
	CreateTimer(300.0, ReloadChatRanks, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public OnClientPostAdminCheck(client)
{
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponPickUp);
	// EmitSoundToClient(client, g_soundConnectName);
}

/**
Player activity
*/

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
    return Plugin_Continue;
}

/**
* Hooks
*/

public Action:Hook_SetTransmit(entity, client) 
{ 
    if (client != entity && (0 < entity <= MaxClients) && g_userHide[client]) {
        return Plugin_Handled;
    }
     
    return Plugin_Continue; 
} 

/**
* User
*/

AddUser(client)
{
	decl String:sQuery[1024];
	decl String:escapedUser[USERNAME_MAX*2+1];
	
	SQL_EscapeString(g_hSQL, g_users[client][Username], escapedUser, sizeof(escapedUser));
	
	FormatEx(sQuery, sizeof(sQuery), "INSERT INTO user (user_steam_id, user_name, user_first_connect, user_last_connect, user_connect_count, user_points) VALUES ('%s', '%s', %d, %d, 0, 0);", g_users[client][SteamID], escapedUser, GetTime(), GetTime());
	PrintToServer("[SurfTimer] Adding User %s to database", g_users[client][Username]);
	SQL_LockDatabase(g_hSQL);
	SQL_FastQuery(g_hSQL, "SET NAMES 'UTF8'");
	SQL_UnlockDatabase(g_hSQL);
	SQL_LockDatabase(g_hSQL);
	if (! SQL_FastQuery(g_hSQL, sQuery)) {
		new String:error[255];
		SQL_GetError(g_hSQL, error, sizeof(error));
		PrintToServer("[SurfTimer] SQL Error on AddUser: %s", error);
		SQL_UnlockDatabase(g_hSQL);
		return;
	}
	SQL_UnlockDatabase(g_hSQL);
	LoadUser(client);
}

LoadUser(client)
{
	decl String:sQuery[1024];

	new Handle:data = CreateDataPack();
	WritePackCell(data, client);
	FormatEx(sQuery, sizeof(sQuery), "select * from user where user_steam_id = '%s'", g_users[client][SteamID]);
	SQL_TQuery(g_hSQL, LoadUserCallback, sQuery, data, DBPrio_High);
}

public LoadUserCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	ResetPack(data);
	new client = ReadPackCell(data);
	if (hndl == INVALID_HANDLE) {
		PrintToServer("SQL Error on LoadUser: %s", error);
		return;
	}

	if (! SQL_GetRowCount(hndl)) {
		PrintToServer("[SurfTimer] No informations found for user %s", g_users[client][Username]);
		PrintToServer("[SurfTimer] Trying to create user...");
		AddUser(client);
		return;
	}

	SQL_FetchRow(hndl);

	// primitives
	g_users[client][UserId] = SQL_FetchInt(hndl, 0);

	decl username[USERNAME_MAX], steamid[AUTHID_MAX];
	SQL_FetchString(hndl, 1, steamid, sizeof(steamid));
	SQL_FetchString(hndl, 2, username, sizeof(username));
	strcopy(g_users[client][Username], USERNAME_MAX, username);
	strcopy(g_users[client][SteamID], AUTHID_MAX, steamid);

	g_users[client][firstConnect] = SQL_FetchInt(hndl, 3);
	g_users[client][lastConnect] = SQL_FetchInt(hndl, 4);
	g_users[client][connectCount] = SQL_FetchInt(hndl, 5);
	g_users[client][userPoints] = SQL_FetchInt(hndl, 6);
	
	PrintToServer("[SurfTimer] Loaded user: %s with SteamID %s", g_users[client][Username], g_users[client][SteamID]);

	
	decl String:escapedUserName[USERNAME_MAX*2+1];
	decl String:sQuery[1024];
	GetClientName(client, username, sizeof(username));
	strcopy(g_users[client][Username], USERNAME_MAX, username);
	SQL_LockDatabase(g_hSQL);
	SQL_FastQuery(g_hSQL, "SET NAMES 'UTF8'");
	SQL_EscapeString(g_hSQL, username, escapedUserName, sizeof(escapedUserName));
	SQL_UnlockDatabase(g_hSQL);

	FormatEx(sQuery, sizeof(sQuery), "UPDATE user SET user_last_connect = %d, user_connect_count = user_connect_count + 1, user_name = '%s' WHERE user_id = '%d'", GetTime(), escapedUserName, g_users[client][UserId]);
	SQL_LockDatabase(g_hSQL);
	if (! SQL_FastQuery(g_hSQL, sQuery)) {
		new String:uerror[255];
		SQL_GetError(g_hSQL, uerror, sizeof(uerror));
		PrintToServer("[SurfTimer] Failed to update user: %s (%d) (error: %s)", g_users[client][Username], g_users[client][UserId], uerror); 
	}
	SQL_UnlockDatabase(g_hSQL);
}

AddNickname(client)
{
	decl String:escapedUserName[USERNAME_MAX*2+1];
	decl String:sQuery[1024];
	decl String:username[USERNAME_MAX];

	GetClientName(client, username, sizeof(username));
	strcopy(g_users[client][Username], USERNAME_MAX, username);
	SQL_LockDatabase(g_hSQL);
	SQL_FastQuery(g_hSQL, "SET NAMES 'UTF8'");
	SQL_EscapeString(g_hSQL, username, escapedUserName, sizeof(escapedUserName));
	SQL_UnlockDatabase(g_hSQL);

	FormatEx(sQuery, sizeof(sQuery), "INSERT INTO user_names (user_id, user_name) VALUES (%d, '%s')", g_users[client][UserId], escapedUserName);
	SQL_LockDatabase(g_hSQL);
	if (! SQL_FastQuery(g_hSQL, sQuery)) {
		new String:error[255];
		SQL_GetError(g_hSQL, error, sizeof(error));
		PrintToServer("[SurfTimer] Failed to add new username %s for %d (error: %s)", g_users[client][Username], g_users[client][UserId], error); 
		SQL_UnlockDatabase(g_hSQL);
		return;
	}
	SQL_UnlockDatabase(g_hSQL);
	LoadUser(client);
}

/**
* MySQL
*/

ConnectSQL()
{
	if (g_hSQL != INVALID_HANDLE) {
		CloseHandle(g_hSQL);
	}

	g_hSQL = INVALID_HANDLE;

	if (SQL_CheckConfig("default")) {
		SQL_TConnect(ConnectSQLCallback, "default");
	} else {
		SetFailState("PLUGIN STOPPED - Reason: no config entry found for 'default' in databases.cfg - PLUGIN STOPPED");
	}
}

public ConnectSQLCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (g_iSQLReconnectCounter >= 5) {
		PrintToServer("PLUGIN STOPPED - Reason: reconnect counter reached max - PLUGIN STOPPED");
		return;
	}

	if (hndl == INVALID_HANDLE) {
		PrintToServer("Connection to SQL database has failed, Reason: %s", error);
		g_iSQLReconnectCounter++;
		ConnectSQL();
		return;
	}

	decl String:sDriver[16];
	SQL_GetDriverIdent(owner, sDriver, sizeof(sDriver));

	if (g_hSQL != INVALID_HANDLE) {
		CloseHandle(g_hSQL);
	}

	g_hSQL = INVALID_HANDLE;
	g_hSQL = CloneHandle(hndl);
	
	if (StrEqual(sDriver, "mysql", false)) {
		SQL_TQuery(g_hSQL, SetNamesCallback, "SET NAMES  'UTF8'", _, DBPrio_High);
	} else {
		SetFailState("PLUGIN STOPPED - Reason: MySQL required. Please define valid data source - PLUGIN STOPPED");
	}
	
	g_iSQLReconnectCounter = 1;
}

public SetNamesCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE) {
		PrintToServer("SQL Error on SetNames: %s", error);
		return;
	}
	if (g_iSQLReconnectCounter) {
		g_iSQLReconnectCounter = 0;
	}
}

/**
* Player commands
*/

// restart
public Action:User_restart(client, args)
{
	if (! IsClientInGame(client)) {
		return Plugin_Handled;
	}

	User_start(client, args);
	return Plugin_Handled;
}

// start 
public Action:User_start(client, args)
{
	if (! CanUserTriggerCommand(client)) return Plugin_Handled;

	if (IsClientInGame(client) && ! IsPlayerAlive(client)) {
		User_respawn(client, args);
		SurfTimer_clientStopTimer(client);
		SurfTimerZones_teleportPlayer(client);
		return Plugin_Handled;
	}

	if (! IsClientInGame(client) || ! IsPlayerAlive(client)) {
		return Plugin_Handled;
	}

	SurfTimerZones_teleportPlayer(client, true);
	return Plugin_Handled;
}

// stop
public Action:User_stop(client, args)
{
	if (! IsClientInGame(client) || ! IsPlayerAlive(client)) {
		return;
	}
	SurfTimer_clientStopTimer(client);
}

// respawn
public Action:User_respawn(client, args)
{
	if (! IsClientInGame(client)) {
		return Plugin_Handled;
	}

	// respawn
	if(client > 0 && IsClientConnected(client) && IsClientInGame(client)) {
		SurfTimer_clientStopTimer(client);
		if(! IsPlayerAlive(client)) {
			if (CS_TEAM_SPECTATOR == GetClientTeam(client)) {
				// put player into a team
				CS_SwitchTeam(client, (GetTeamClientCount(CS_TEAM_T) > GetTeamClientCount(CS_TEAM_CT)) ? CS_TEAM_CT : CS_TEAM_T);
			}
			CS_RespawnPlayer(client);
		} 
	}
	return Plugin_Handled;
}

// teleport
public Action:User_teleport(client, args)
{
	if (! CanUserTriggerCommand(client)) return Plugin_Handled;

	if (! IsClientInGame(client) || ! IsPlayerAlive(client)) {
		return Plugin_Handled;
	}
	SurfTimerZones_teleportPlayer(client);
	return Plugin_Handled;
}

public Action:User_practiceStage(client, args) 
{
	if (! CanUserTriggerCommand(client)) return;

	new String:arg[128];
	GetCmdArg(args, arg, sizeof(arg));

	if (! args || 0 == StringToInt(arg)) {
		CPrintToChat(client, "%s{lightgreen}Use !stage <stagenumber> or !s <stagenumber>", PLUGIN_PREFIX);
		return;
	}

	SurfTimer_clientStopTimer(client);
	SurfTimerZones_teleportPlayerToStage(client, StringToInt(arg));
}

// spectate
public Action:User_spectate(client, args)
{
	if (! IsClientInGame(client) || ! IsPlayerAlive(client)) {
		return;
	}
	
	// spectate
	User_unhide(client, false);
	SurfTimer_clientStopTimer(client);
	ChangeClientTeam(client, 1);
	
}

// hide
public Action:User_hide(client, args)
{
	if (! IsClientInGame(client) || ! IsPlayerAlive(client)) {
		return;
	}
	// hide all players
	g_userHide[client] = ! g_userHide[client];
	CPrintToChat(client, "%s {lightgreen}Players are now %s", PLUGIN_PREFIX, ((g_userHide[client]) ? "hidden" : "visible"));
}

public Action:User_unhide(client, args)
{
	if (! IsClientInGame(client) || ! IsPlayerAlive(client)) {
		return;
	}
	// hide all players
	g_userHide[client] = false;
	CPrintToChat(client, "%s{lightgreen}Players are now %s", PLUGIN_PREFIX, "visible");
}

public Action:User_spawned(Handle:event,const String:name[],bool:dontBroadcast)
{
	new client_id = GetEventInt(event, "userid");
	new client = GetClientOfUserId(client_id);
	RemovePlayerWeapons(client);
}

public Action:User_joinTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client == 0) {
		return;
	}
	SurfTimer_clientStopTimer(client);
	CreateTimer(1.0, RespawnPlayer, client);
}  

public Action:RespawnPlayer(Handle:timer, any:client)
{
    new team = GetClientTeam(client);
    SurfTimer_clientStopTimer(client);
    if (!IsPlayerAlive(client) && (team == 2 || team == 3)) {
    	CS_RespawnPlayer(client);
    }
	return Plugin_Continue;
} 

public RemovePlayerWeapons(client)
{
	if(! IsClientInGame(client) || ! IsPlayerAlive(client)) {
		return;
	}

	//check/drop weapons
	new primaryWeapon = GetPlayerWeaponSlot(client, 0);
	new secondaryWeapon = GetPlayerWeaponSlot(client, 1);
	new meleeWeapon = GetPlayerWeaponSlot(client, 2);
	new projectileWeapon = GetPlayerWeaponSlot(client, 3);
	new c4Weapon = GetPlayerWeaponSlot(client, 4);

	if (primaryWeapon != -1) {
		RemovePlayerItem(client, primaryWeapon);
	}

	if (secondaryWeapon != -1) {
		RemovePlayerItem(client, secondaryWeapon);
	}

	if (meleeWeapon != -1) {
		RemovePlayerItem(client, meleeWeapon);
	}

	if (projectileWeapon != -1) {
		RemovePlayerItem(client, projectileWeapon);
	}
	
	if (c4Weapon != -1) {
		RemovePlayerItem(client, c4Weapon);
	}
} 

public Action:User_jumped(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client == 0 && ! IsPlayerAlive(client) && ! IsClientObserver(client)) {
		return Plugin_Continue;
	}

	new time = GetTime() - g_userJumps[client][LastJumpTimes][2];
	g_userJumps[client][LastJumpTimes][2] = g_userJumps[client][LastJumpTimes][1];
	g_userJumps[client][LastJumpTimes][1] = g_userJumps[client][LastJumpTimes][0];
	g_userJumps[client][LastJumpTimes][0] = GetTime();

	if (time <= 3) {
		CPrintToChat(client, "%s{red}We do not allow bunny hopping.", PLUGIN_PREFIX);
		CreateTimer(0.05, DelayedVelocityToZero, client);
		g_userJumps[client][LastJumpTimes][2] = 0.0;
		g_userJumps[client][LastJumpTimes][1] = 0.0;
		g_userJumps[client][LastJumpTimes][0] = 0.0;
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action:User_died(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client;
	client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	
    if (!IsValidEntity(client)) {
    	return Plugin_Continue;
    }
    
  	new ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
  	if (ragdoll < 0) {
    	return Plugin_Continue;
  	}
    
	new String:dname[32], String:dtype[32];
	Format(dname, sizeof(dname), "dis_%d", client);
	Format(dtype, sizeof(dtype), "%d", 0);
  
  	new ent = CreateEntityByName("env_entity_dissolver");
  	if (ent > 0) {
	    DispatchKeyValue(ragdoll, "targetname", dname);
	    DispatchKeyValue(ent, "dissolvetype", dtype);
	    DispatchKeyValue(ent, "target", dname);
	    AcceptEntityInput(ent, "Dissolve");
	    AcceptEntityInput(ent, "kill");
	}
	return Plugin_Continue;	
}

public CanUserTriggerCommand(client)
{
	if ((GetTime() - g_userLastTriggerTime[client][TriggerTime]) <= 2) {
		CPrintToChat(client, "%s{red}We only allow this command every 2 seconds.", PLUGIN_PREFIX);
		return false;
	}
	g_userLastTriggerTime[client][TriggerTime] = GetTime();
	return true;
}

public Action:DelayedVelocityToZero(Handle:timer, any:client)
{
	new Float:origin[3];
	GetClientAbsOrigin(client, origin);
	TeleportEntity(client, origin, NULL_VECTOR, {0.0, 0.0, 0.0});
}

public Action:MapEndSound(Handle:timer)
{
	new timeleft;
	GetMapTimeLeft(timeleft);
	if ((timeleft <= 30 && timeleft > 0) && ! g_endSoundPlayed) {
		EmitSoundToAll(g_soundEndName);
		g_endSoundPlayed = true;
	}
}

public Action:ReloadChatRanks(Handle:timer)
{
	ServerCommand("sm_reloadccc");
	return Plugin_Handled;
}