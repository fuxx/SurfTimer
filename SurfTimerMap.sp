#pragma semicolon 1

#include <SurfTimerMap>

#undef REQUIRE_PLUGIN
#include <SurfTimer>
#include <SurfTimerZones>
#include <SurfTimerRank>

new Handle:g_hSQL;
new String:g_sCurrentMap[MAPNAME_MAX];

// Admin menu
new Handle:hTopMenu = INVALID_HANDLE;
new TopMenuObject:oMapConfigMenu;

// mysql 
new g_iSQLReconnectCounter = 0;

enum Map {
	Id,
	Bool:Enabled,
	MapType,
	Tier,
	LastPlayed,
	TimesPlayed,
	TotalCompletions,
	MapBonusType,
	StageCount,
	BonusStageCount,
}

public Plugin:myinfo =
{
	name = "[SurfTimer]-Map",
	author = "Fuxx",
	description = "The map configuration plugin for SurfTimer",
	version = PLUGIN_VERSION,
	url = "http://www.stefanpopp.de"
};

new g_map[Map] = INVALID_HANDLE;
new bool:g_mapLoaded = false;

// Strings
new g_tierName[5][20];

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("SurfTimerMap_reloadInfo", Native_SurfTimerMap_reloadInfo);
	CreateNative("SurfTimerMap_hasStages", Native_SurfTimerMap_hasStages);
	CreateNative("SurfTimerMap_stageCount", Native_SurfTimerMap_stageCount);
	
	return APLRes_Success;
}

/**
* On Connect
*/

public OnPluginStart()
{
	// load map informations form sql
	if (g_hSQL == INVALID_HANDLE) {
		ConnectSQL();
	}
	PrintToServer("[SurfTimer-Map] %s loaded...", PLUGIN_URL);	

	RegConsoleCmd("sm_m", Map_infoshort);
	RegConsoleCmd("sm_mapinfo", Map_info);

	new Handle:topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE)) {
		OnAdminMenuReady(topmenu);
	}

	// set names to string
	g_tierName[0] = "Very easy";
	g_tierName[1] = "Easy";
	g_tierName[2] = "Medium";
	g_tierName[3] = "Hard";
	g_tierName[4] = "Very hard";

	HookEvent("server_cvar", Event_ServerCvar, EventHookMode_Pre);
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "adminmenu")) {
		hTopMenu = INVALID_HANDLE;
	}
}

public OnMapStart()
{
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
	StringToLower(g_sCurrentMap);

	// load map informations form sql
	if (g_hSQL == INVALID_HANDLE) {
		ConnectSQL();
	}

	// check for spawn points and create new ones if we got not enough
	new maxSpawnPoints = (NumberOfSpawnsForClass("info_player_counterterrorist") + NumberOfSpawnsForClass("info_player_terrorist"));

	PrintToServer("[SurfTimer-Map] Found max spawnpoints :%d", maxSpawnPoints);
	if ((MAXPLAYERS-1) > maxSpawnPoints) {
		PrintToServer("[SurfTimer-Map] Creating %d additional spawnpoints", ((MAXPLAYERS-1) - maxSpawnPoints));
		
		new additionalSpawnPoints = MAXPLAYERS - maxSpawnPoints;
		CreateSpawnForClass("info_player_counterterrorist", additionalSpawnPoints / 2);
		CreateSpawnForClass("info_player_terrorist", additionalSpawnPoints / 2);
	} 
	
	decl String:sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "UPDATE maps SET map_times_played = map_times_played + 1, map_last_played = %d WHERE map_name = '%s'", GetTime(), g_sCurrentMap);
	SQL_LockDatabase(g_hSQL);
	if (! SQL_FastQuery(g_hSQL, sQuery)) {
		new String:uerror[255];
		SQL_GetError(g_hSQL, uerror, sizeof(uerror));
		PrintToServer("[SurfTimer] Failed to update map_times_played for map %s (error: %s)", g_sCurrentMap, uerror); 
		SQL_UnlockDatabase(g_hSQL);
		return;
	}
	SQL_UnlockDatabase(g_hSQL);

	g_mapLoaded = false;
	g_map[Id] = 0;
	g_map[Enabled] = false;
	g_map[MapType] = 0;
	g_map[Tier] = 0;
	g_map[LastPlayed] = 0;
	g_map[TimesPlayed] = 0;
	g_map[TotalCompletions] = 0;
	g_map[MapBonusType] = 0;
	g_map[StageCount] = 0;
	g_map[BonusStageCount] = 0;
	LoadMap();
}

NumberOfSpawnsForClass(const String:className[])
{
	new spawnCount = 0;
	new index = -1;
	while ((index = FindEntityByClassname(index, className)) != -1) {
		spawnCount++;
	}
	return spawnCount;
}

CreateSpawnForClass(const String:className[], numberOfSpawns)
{
	new index = FindEntityByClassname(-1, className);
	if (! IsValidEntity(index)) {
		PrintToServer("[SurfTimer-Map] Cant create spawnpoints for %s. No valid spawn entity was found as base.", className);
	}

	new Float:Origin[3];
	GetEntPropVector(index, Prop_Send, "m_vecOrigin", Origin);
	new createdSpawns = 0;
	for (new i = 0; i < numberOfSpawns; i++) {
		new ent = CreateEntityByName("info_player_terrorist");
		if (IsValidEntity(ent)) {
			if(DispatchSpawn(ent)) {
				ActivateEntity(ent);
				TeleportEntity(ent, Origin, NULL_VECTOR, NULL_VECTOR);
				createdSpawns++;
			} else {
				PrintToServer("[SurfTimer-Map] Error: Cant dispatch spawn entity %d for class %s", i, className);
			}
		} else {
				PrintToServer("[SurfTimer-Map] Error: Cant create entity %d for class %s", i, className);
		}
	}
	PrintToServer("[SurfTimer-Map] Created %d additional spawnpoints for class %s.", createdSpawns, className);
}

/**
* Admin menu
*/

public OnAdminMenuReady(Handle:topmenu)
{
	// Block this from being called twice
	if (topmenu == hTopMenu) {
		return;
	}

	// Save the Handle
	hTopMenu = topmenu;
	
	oMapConfigMenu = FindTopMenuCategory(topmenu, "Map Management");
	if (oMapConfigMenu == INVALID_TOPMENUOBJECT) {
		oMapConfigMenu = AddToTopMenu(hTopMenu,
		"Map Management",
		TopMenuObject_Category,
		AdminMenu_CategoryHandler,
		INVALID_TOPMENUOBJECT);
	}

	AddToTopMenu(hTopMenu, 
		"timer_mapconfig_chgdifficulty",
		TopMenuObject_Item,
		AdminMenu_ChangeDifficulty,
		oMapConfigMenu,
		"timer_mapconfig_chgdifficulty",
		ADMFLAG_RCON
	);

	AddToTopMenu(hTopMenu, 
		"timer_mapconfig_setenabled",
		TopMenuObject_Item,
		AdminMenu_ChangeMapStatus,
		oMapConfigMenu,
		"timer_mapconfig_setenabled",
		ADMFLAG_RCON
	);

	AddToTopMenu(hTopMenu, 
		"timer_reload_stats",
		TopMenuObject_Item,
		AdminMenu_ReloadStats,
		oMapConfigMenu,
		"timer_reload_stats",
		ADMFLAG_RCON
	);
}

public AdminMenu_CategoryHandler(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayTitle)  {
		FormatEx(buffer, maxlength, "[ST] Map config", param);
	} else if (action == TopMenuAction_DisplayOption) {
		FormatEx(buffer, maxlength, "[ST] Map config", param);
	}
}

public AdminMenu_ChangeDifficulty(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption) {
		FormatEx(buffer, maxlength, "Change Map difficulty", param);
	} else if (action == TopMenuAction_SelectOption) {	
		AdminMenu_ShowDifficulty(param);
	}
}

public AdminMenu_ChangeMapStatus(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption) {
		FormatEx(buffer, maxlength, "%s Map timer", (SurfTimerZones_isMapEnabled() ? "Enable" : "Disable"));
	} else if (action == TopMenuAction_SelectOption) {	
		SurfTimerZones_setMapEnabled(! SurfTimerZones_isMapEnabled());
		RedisplayAdminMenu(topmenu, param);
	}
}

public AdminMenu_ReloadStats(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption) {
		FormatEx(buffer, maxlength, "Reload stats", param);
	} else if (action == TopMenuAction_SelectOption) {	
		SurfTimer_reloadStats();
		RedisplayAdminMenu(topmenu, param);
	}
}


public AdminMenu_ShowDifficulty(client)
{
	new Handle:menu = CreateMenu(AdminMenu_DifficultySelect);
	SetMenuTitle(menu, "Select map difficulty", client);
	
	decl String:sText[256];
	
	FormatEx(sText, sizeof(sText), "Very easy", client);
	AddMenuItem(menu, "0", sText);

	FormatEx(sText, sizeof(sText), "Easy", client);
	AddMenuItem(menu, "1", sText);
	
	FormatEx(sText, sizeof(sText), "Medium", client);
	AddMenuItem(menu, "2", sText);
	
	FormatEx(sText, sizeof(sText), "Hard", client);
	AddMenuItem(menu, "3", sText);
	
	FormatEx(sText, sizeof(sText), "Very hard", client);
	AddMenuItem(menu, "4", sText);
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 360);
}

public AdminMenu_DifficultySelect(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)  {
		CloseHandle(menu);
	}  else if (action == MenuAction_Select)  {
		if (param2 == MenuCancel_Exit && hTopMenu != INVALID_HANDLE)  {
			DisplayTopMenu(hTopMenu, param1, TopMenuPosition_LastCategory);
			return;
		}
		decl String:sQuery[1024];
	
		FormatEx(sQuery, sizeof(sQuery), "UPDATE maps SET map_difficulty = %d WHERE map_name = '%s'", param2, g_sCurrentMap);
		SQL_LockDatabase(g_hSQL);
		if (! SQL_FastQuery(g_hSQL, sQuery)) {
			new String:uerror[255];
			SQL_GetError(g_hSQL, uerror, sizeof(uerror));
			PrintToServer("[SurfTimer] Failed to update map difficulty for map %s (%d) (error: %s)", g_sCurrentMap, uerror); 
			CPrintToChatAll("%s{red}Failed to update map difficulty for map %s (%d) (error: %s)", PLUGIN_PREFIX, g_sCurrentMap, uerror); 
			SQL_UnlockDatabase(g_hSQL);
			return;
		}
		SQL_UnlockDatabase(g_hSQL);

		CPrintToChatAll("%s{lightgreen}Changed map difficulty for map %s to tier: %d", PLUGIN_PREFIX, g_sCurrentMap, param2); 
		SurfTimerZones_reloadMap();
	}
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

LoadMap()
{
	decl String:sQuery[384];
	FormatEx(sQuery, sizeof(sQuery), "select map_id from maps where map_name = '%s' LIMIT 1", g_sCurrentMap);

	SQL_LockDatabase(g_hSQL);
	new Handle:query = SQL_Query(g_hSQL, sQuery);
	if (! query) {
		new String:uerror[255];
		SQL_GetError(g_hSQL, uerror, sizeof(uerror));
		PrintToServer("[SurfTimer] Failed to load map information (error: %s)", uerror); 
		CPrintToChatAll("%s{red}Failed to load map information (error: %s)", PLUGIN_PREFIX, uerror);
		CloseHandle(query);
		SQL_UnlockDatabase(g_hSQL);
		return;
	}
	SQL_UnlockDatabase(g_hSQL);

	SQL_FetchRow(query);
	g_map[Id] = SQL_FetchInt(query, 0);

	CloseHandle(query);
	
	if (! g_map[Id]) {
		PrintToServer("[SurfTimer-Map] Failed to load detailed map informations!");
		CPrintToChatAll("%s{red}Failed to load detailed map informations!", PLUGIN_PREFIX);
		return;
	}

	FormatEx(sQuery, sizeof(sQuery), "SELECT *, (SELECT IFNULL(COUNT(*), 0) FROM map_zones WHERE map_zones.map_id = %d AND map_zones.map_zone_type = 2) AS stageCount, (SELECT IFNULL(COUNT(*), 0) FROM map_zones WHERE map_zones.map_id = %d AND map_zones.map_zone_type = 5) AS bonusStageCount FROM maps WHERE maps.map_id = %d", g_map[Id], g_map[Id], g_map[Id]);
	SQL_TQuery(g_hSQL, LoadMapCallback, sQuery, _, DBPrio_High);
}

public LoadMapCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE) {
		PrintToServer("SQL Error on LoadMap: %s", error);
		return;
	}

	if (! SQL_GetRowCount(hndl)) {
		CPrintToChatAll("%s{red}No informations found for map %s", PLUGIN_PREFIX, g_sCurrentMap);
		return;
	}

	SQL_FetchRow(hndl);
	g_map[MapType] = SQL_FetchInt(hndl, 2);
	g_map[Tier] = SQL_FetchInt(hndl, 3);
	g_map[Enabled] = SQL_FetchInt(hndl, 4);
	g_map[LastPlayed] = SQL_FetchInt(hndl, 5);
	g_map[TimesPlayed] = SQL_FetchInt(hndl, 6);
	g_map[TotalCompletions] = SQL_FetchInt(hndl, 7);
	g_map[MapBonusType] = SQL_FetchInt(hndl, 8);
	g_map[StageCount] = SQL_FetchInt(hndl, 13);
	g_map[BonusStageCount] = SQL_FetchInt(hndl, 14);

	g_mapLoaded = true;
}

/**
* Commands
*/

public Action:Map_infoshort(client, args)
{
	if (! g_mapLoaded) {
		CPrintToChatAll("%s{red}No informations for map %s found. {lightgreen}Trying to reload... Please try again :)", PLUGIN_PREFIX, g_sCurrentMap);
		LoadMap();
		return;
	}

	decl String:mapInfo[1024];
	Format(mapInfo, sizeof(mapInfo), "%s{White}Map: {lightgreen}%s{white} - {lightgreen}%s{white} - ", PLUGIN_PREFIX, g_sCurrentMap, (g_map[StageCount]) ? "Staged" : "Linear");
	Format(mapInfo, sizeof(mapInfo), "%sTier: {lightgreen}%d {white} - Stages: {lightgreen}%d{white} - Bonuses: {lightgreen}%d", mapInfo, g_map[Tier], (g_map[StageCount]+1), g_map[BonusStageCount]);
	if (g_map[Enabled] == false) {
		Format(mapInfo, sizeof(mapInfo), "%s {white}-{red} Map not configured!", mapInfo);
	}
	CPrintToChatAll(mapInfo);
}

public Action:Map_info(client, args)
{
	if (! g_mapLoaded) {
		CPrintToChatAll("%s{red}No informations for map %s found. {lightgreen}Trying to reload... Please try again :)", g_sCurrentMap);
		LoadMap();
		return;
	}

	decl String:buffer[512];
	new Handle:MapInfoPanel = CreatePanel();
	SetPanelTitle(MapInfoPanel, "Informations for map");
	DrawPanelText(MapInfoPanel, g_sCurrentMap);
	DrawPanelText(MapInfoPanel, "----------------");
	DrawPanelText(MapInfoPanel, " ");
	
	Format(buffer, sizeof(buffer), "Tier: %d - %s", g_map[Tier], g_tierName[g_map[Tier]]);
	DrawPanelText(MapInfoPanel, buffer);

	Format(buffer, sizeof(buffer), "Type: %s", (g_map[StageCount]) ? "Staged" : "Linear");
	DrawPanelText(MapInfoPanel, buffer);

	if (g_map[StageCount]) {
		Format(buffer, sizeof(buffer), "Stages: %d", (g_map[StageCount]+1));
		DrawPanelText(MapInfoPanel, buffer);
	}

	DrawPanelText(MapInfoPanel, " ");
	DrawPanelItem(MapInfoPanel, "Back");

	SendPanelToClient(MapInfoPanel, client, MapInfoHandler, 20);
	CloseHandle(MapInfoPanel);
}

public MapInfoHandler(Handle:menu, MenuAction:action, param1, param2)
{
	
}

public Action:Event_ServerCvar(Handle:event, const String:name[], bool:dontBroadcast) 
{
	decl String:cvarName[64];
    GetEventString(event, "cvarname", cvarName, sizeof(cvarName));

    if (StrContains(cvarName, "sv_airaccelerate") == 0) {
    	ServerCommand ("exec sourcemod/fix_cvars.cfg");
        return Plugin_Handled;
    }

    return Plugin_Continue;  
}


/**
* Natives
*/

public Native_SurfTimerMap_reloadInfo(Handle:plugin, numParams)
{
	LoadMap();
}

public Native_SurfTimerMap_hasStages(Handle:plugin, numParams)
{
	SetNativeCellRef(1, g_map[StageCount]);
}

public Native_SurfTimerMap_stageCount(Handle:plugin, numParams)
{
	SetNativeCellRef(1, g_map[StageCount]+1);
}

