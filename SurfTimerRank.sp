#pragma semicolon 1

#include <SurfTimerRank>

#undef REQUIRE_PLUGIN
#include <SurfTimer>
#include <SurfTimerMap>
#include <SurfTimerZones>
#include <system2>

new Handle:g_hSQL = INVALID_HANDLE;
new String:g_sCurrentMap[MAPNAME_MAX];

// mysql 
new g_iSQLReconnectCounter = 0;

#define MAX_ZONES 40

// map informations
enum Map
{
	Id,
	Difficulty,
	TimesCompleted,
	TimesCompletedDistinct,
	LatestRecordCount,
	WorldRecordCount,
	BonusTimesCompleted,
	BonusWorldRecordCount,
	CompletedStagesCount,
	StageCount,
	Float:WorldRecordTime,
}

enum Record
{
	Id,
	float:Time,
	UserId,
	String:Username[USERNAME_MAX],
	String:AuthName[AUTHID_MAX],
}

enum GlobalRank
{
	Rank,
	String:Username[USERNAME_MAX],
	UserPoints
}

enum User
{
	Id,
	String:AuthName[AUTHID_MAX],
	float:PersonalTime,
}

enum Stages
{
	Id,
	OrderId,
	Type,
	Float:WorldRecordTime,
	bool:Unfinished,
	String:Username[USERNAME_MAX],
	String:AuthName[AUTHID_MAX],
}

enum PlayerStageRecord
{
	StageId,
	OrderId,
	StageType,
	Float:RecordTime,
	bool:HasFinished,
	CompletedStages,
}

new g_map[Map];

new g_mapRecords[1000][Record];
new g_latestMapRecords[10][Record];

new g_userRank[10000][GlobalRank];

new g_mapStageRecords[MAX_ZONES][Stages]; // identified by map_zone_checkpoint_id - For normal stages only
new g_playerStageRecords[MAXPLAYERS+1][MAX_ZONES][PlayerStageRecord];

new g_user[MAXPLAYERS][User];
new g_userGlobalCount = 0;

new String:g_soundName[] = "surftimer/SurfTimer_WR1.mp3";
new String:g_soundNamePersonalWr[] = "surftimer/SurfTimer_WR2.mp3";

public Plugin:myinfo =
{
	name = "[SurfTimer]-Rank",
	author = "Fuxx",
	description = "The player rank database",
	version = PLUGIN_VERSION,
	url = "http://www.stefanpopp.de"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("SurfTimerRank_playerDidFinish", Native_SurfTimerRank_playerDidFinish);
	CreateNative("SurfTimer_currentWRData", Native_SurfTimer_currentWRData);
	CreateNative("SurfTimer_currentStageWRData", Native_SurfTimer_currentStageWRData);
	CreateNative("SurfTimer_reloadStats", Native_SurfTimer_reloadStats);
	CreateNative("SurfTimerRank_playerDidFinishStage", Native_SurfTimerRank_playerDidFinishStage);
	CreateNative("SurfTimerRank_SurfTimer_stageCount", Native_SurfTimerRank_SurfTimer_stageCount);

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
	PrintToServer("[SurfTimer-Rank] %s loaded...", PLUGIN_URL);	

	RegConsoleCmd("sm_ptop", Global_top, "Show global player top list");

	RegConsoleCmd("sm_top10", Map_top, "Show top for the current map");
	RegConsoleCmd("sm_top", Map_top, "Show map top list - Optional map name accepted");
	RegConsoleCmd("sm_mtop", Map_top, "Show map top list - Optional map name accepted");
	RegConsoleCmd("sm_wr", Map_top, "Show map top list - Optional map name accepted");

	RegConsoleCmd("sm_dhctop", Map_dhcTop, "Shows your global rank or of a given name");
	
	RegConsoleCmd("sm_rr", Map_latestRecords, "Show latest world records on current map");
	RegConsoleCmd("sm_recent", Map_latestRecords, "Show latest world records on current map");
	RegConsoleCmd("sm_rrg", Map_latestRecordsGlobal, "Show latest world records on current map");
	RegConsoleCmd("sm_recentglobal", Map_latestRecordsGlobal, "Show latest world records on current map");
	RegConsoleCmd("sm_grr", Map_latestRecordsGlobal, "Show latest world records on current map");
	RegConsoleCmd("sm_globalrecent", Map_latestRecordsGlobal, "Show latest world records on lasts map");

	RegConsoleCmd("sm_mr", Map_rank, "Shows map rank for a given map and optional player name");
	RegConsoleCmd("sm_mrank", Map_rank, "Shows map rank for a given map and optional player name");
	
	RegConsoleCmd("sm_rank", Map_User_rank, "Shows your rank on current map");
	RegConsoleCmd("sm_r", Map_User_rank, "Shows your rank on current map");

	RegConsoleCmd("sm_prank", User_rank, "Shows your global rank or of a given name");
	RegConsoleCmd("sm_pr", User_rank, "Shows your global rank or of a given name");

	RegConsoleCmd("sm_wrcp", Map_stageRecords, "Shows world records for stages on current map");
	RegConsoleCmd("sm_cpwr", Map_stageRecords, "Shows world records for stages on current map");
	RegConsoleCmd("sm_stagewr", Map_stageRecords, "Shows world records for stages on current map");
	RegConsoleCmd("sm_stages", Map_stageRecords, "Shows world records for stages on current map");
	RegConsoleCmd("sm_stagetop", Map_stageRecords, "Shows world records for stages on current map");

}

public OnMapStart()
{
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
	StringToLower(g_sCurrentMap);

	// load map informations form sql
	if (g_hSQL == INVALID_HANDLE) {
		ConnectSQL();
	}

	for (new i = 0; i < MAX_ZONES; i++) {
		g_mapStageRecords[i][Id] = 0;
		g_mapStageRecords[i][OrderId] = 0;
		g_mapStageRecords[i][WorldRecordTime] = 0.0;
	}

	for (new i = 0; i < MAXPLAYERS+1; i++) {
		for (new j = 0; j < MAX_ZONES; j++) {
			g_playerStageRecords[i][j][StageId] = 0;
			g_playerStageRecords[i][j][OrderId] = 0;
			g_playerStageRecords[i][j][RecordTime] = 0.0;
		}
	}

	LoadMap();
	LoadUserRecords();
	LoadMapStageRecords();
}

public OnMapEnd()
{
	g_userGlobalCount = 0;
}

public OnClientDisconnect(client)
{
	decl String:emptyString[AUTHID_MAX];  
	Format(emptyString, sizeof(emptyString), "");
	strcopy(g_user[client][AuthName], sizeof(emptyString), emptyString);
	ResetPlayerStageRecord(client);
}

public OnConfigsExecuted()
{
	decl String:buffer[128];
	PrecacheSound(g_soundName, true);
	Format(buffer, sizeof(buffer), "sound/%s", g_soundName);
	AddFileToDownloadsTable(buffer);

	PrecacheSound(g_soundNamePersonalWr, true);
	Format(buffer, sizeof(buffer), "sound/%s", g_soundNamePersonalWr);
	AddFileToDownloadsTable(buffer);

	// doppelt hält besser
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
	StringToLower(g_sCurrentMap);
	LoadMap();
}

public OnClientAuthorized(client, const String:auth[])
{
	ResetPlayerStageRecord(client);
	LoadUser(client);
}

public OnClientPostAdminCheck(client)
{
	GetClientAuthString(client, g_user[client][AuthName], 64);
}

public AdminMenu_IgnoreSelection(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select) {
        
    } else if (action == MenuAction_Cancel) {
		
	} else if (action == MenuAction_End) {
	   CloseHandle(menu);
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
		SQL_TQuery(g_hSQL, SetNamesCallback, "SET NAMES 'UTF8'", _, DBPrio_High);
	} else {
		SetFailState("PLUGIN STOPPED - Reason: MySQL required. Please define valid data source - PLUGIN STOPPED");
	}
	
	g_iSQLReconnectCounter = 1;
	LoadMap();
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
	g_map[TimesCompleted] = 0;
	g_map[WorldRecordCount] = 0;
	g_map[BonusTimesCompleted] = 0;
	g_map[BonusWorldRecordCount] = 0;

	decl String:sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "SELECT * FROM maps WHERE map_name = '%s' LIMIT 1", g_sCurrentMap);
	if (g_hSQL != INVALID_HANDLE) {
		SQL_TQuery(g_hSQL, LoadMapCallback, sQuery, _, DBPrio_High);	
	} else {
		CreateTimer(4.0, TimerLoadMap, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	
}

public Action:TimerLoadMap(Handle:timer, any:serial)
{
	LoadMap();
	LoadUserRecords();
	LoadMapStageRecords();
}

public LoadMapCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE) {
		PrintToServer("SQL Error on LoadMap: %s", error);
		LoadUserRecords();
		return;
	}

	if (! SQL_GetRowCount(hndl)) {
		CPrintToChatAll("%s{red}No informations found for map %s", PLUGIN_PREFIX, g_sCurrentMap);
		return;
	}

	SQL_FetchRow(hndl);
	g_map[Id] = SQL_FetchInt(hndl, 0);
	g_map[Difficulty] = SQL_FetchInt(hndl, 3);
	g_map[TimesCompletedDistinct] = SQL_FetchInt(hndl, 7);
	g_map[WorldRecordCount] = SQL_FetchInt(hndl, 9);
	g_map[BonusTimesCompleted] = SQL_FetchInt(hndl, 8);
	g_map[BonusWorldRecordCount] = SQL_FetchInt(hndl, 10);
	
	LoadMapRecords();
}

LoadMapRecords()
{
	decl String:sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "SELECT *, MIN(user_record_time) AS record_time FROM user_records LEFT JOIN user ON user.user_id = user_records.user_user_id WHERE user_record_time > 0.0 AND maps_map_id = %d GROUP BY user_user_id ORDER BY MIN(user_record_time) LIMIT 100", g_map[Id]);
	SQL_TQuery(g_hSQL, LoadMapRecordsCallback, sQuery, _, DBPrio_High);

}

LoadLatestMapRecords()
{
	g_map[LatestRecordCount] = 0;
	decl String:sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "SELECT *, user_record_time AS record_time FROM user_records LEFT JOIN user ON user.user_id = user_records.user_user_id WHERE user_record_time > 0.0 AND maps_map_id = %d ORDER BY user_records.user_record_created_at DESC LIMIT 10", g_map[Id]);
	SQL_TQuery(g_hSQL, LoadLatestMapRecordsCallback, sQuery, _, DBPrio_High);	
}

LoadMapStageRecords()
{
	g_map[CompletedStagesCount] = 0;
	g_map[StageCount] = 0;

	decl String:sQuery[2048];
	FormatEx(sQuery, sizeof(sQuery), "SELECT a.map_zone_id, a.map_zone_checkpoint_order_id, a.map_id, a.map_zone_type, b.map_enabled, IFNULL(MIN(c.user_stage_records_time), 0.0) as stage_record, d.user_name, d.user_steam_id, d.user_id FROM map_zones as a LEFT JOIN maps AS b ON b.map_id = a.map_id  LEFT JOIN user_stage_records AS c on (a.map_zone_id = c.user_stage_records_stage_id AND c.user_stage_records_time = (SELECT MIN(user_stage_records_time) FROM user_stage_records WHERE user_stage_records_stage_id = c.user_stage_records_stage_id)) LEFT JOIN user AS d on c.user_user_id = d.user_id WHERE b.map_id = %d AND (map_zone_type = 2 OR map_zone_type = 3) GROUP BY a.map_zone_id ORDER BY a.map_zone_type, a.map_zone_checkpoint_order_id", g_map[Id]);
	SQL_TQuery(g_hSQL, LoadMapStageRecordsCallback, sQuery, _, DBPrio_High);	
}

LoadPlayerStageRecords(client)
{
	decl String:sQuery[4096];
	FormatEx(sQuery, sizeof(sQuery), "SELECT a.map_zone_id, a.map_zone_checkpoint_order_id, a.map_id, a.map_zone_type, IFNULL(MIN(c.user_stage_records_time), 0.0) AS stage_record, d.user_name, d.user_steam_id, d.user_id, COALESCE(d.user_id, %d) as fixed_user_id, IF (COALESCE(MIN(c.user_stage_records_time), 0.0) = 0.0, 0, 1) as hasFinished FROM map_zones as a LEFT JOIN maps AS b ON b.map_id = a.map_id LEFT JOIN user_stage_records AS c on c.user_stage_records_stage_id = a.map_zone_id AND c.user_user_id = %d LEFT JOIN user AS d on c.user_user_id = d.user_id WHERE b.map_id = %d AND (a.map_zone_type = 2 OR a.map_zone_type = 3) GROUP BY a.map_zone_id ORDER BY a.map_zone_type, a.map_zone_checkpoint_order_id", g_user[client][Id], g_user[client][Id], g_map[Id]);
	//PrintToServer("%s", sQuery);
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, client);
	
	SQL_TQuery(g_hSQL, LoadPlayerStageRecordsCallback, sQuery, pack, DBPrio_High);	
}

LoadMapRecordsAndShowTop(client, const String:mapName[])
{
	decl String:sQuery[1024];
	new bufferLen = strlen(mapName) * 2 + 1;
	new String:newMapName[bufferLen];

	SQL_EscapeString(g_hSQL, mapName, newMapName, bufferLen);
	Format(sQuery, sizeof(sQuery), "SELECT *, MIN(user_record_time) AS record_time FROM user_records LEFT JOIN user ON user.user_id = user_records.user_user_id WHERE user_record_time > 0.0 AND maps_map_id = (SELECT map_id FROM maps where map_name = '%s') GROUP BY user_user_id ORDER BY MIN(user_record_time) LIMIT 100", newMapName);
	
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackString(pack, mapName);
	
	SQL_TQuery(g_hSQL, LoadMapRecordsAndShowTopCallback, sQuery, pack, DBPrio_High);
}

public LoadMapRecordsAndShowTopCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	decl String:mapName[MAPNAME_MAX];

	ResetPack(data);
	new client = ReadPackCell(data);
	ReadPackString(data, mapName, sizeof(mapName));
	CloseHandle(data);

	if (! SQL_GetRowCount(hndl)) {
		CPrintToChatAll("%s{lightgreen} No record informations found for map %s", PLUGIN_PREFIX, mapName);
		return;
	}

	new recordCounter = 0;
	
	new Handle:menu = CreateMenu(MapTopMenuHandler, MENU_ACTIONS_ALL);
	decl String:menuTitle[128];
	Format(menuTitle, sizeof(menuTitle), "Map top 100 - %s", mapName);
	SetMenuTitle(menu, menuTitle);

	while (SQL_FetchRow(hndl)) {

		decl username[USERNAME_MAX];
		SQL_FetchString(hndl, 9, username, USERNAME_MAX);


		decl String:sTimeString[128];
		SurfTimer_secondsToTime(SQL_FetchFloat(hndl, 14), sTimeString, sizeof(sTimeString), true);

		decl String:titleString[512];
		Format(titleString, sizeof(titleString), "[#%d] %s - %s", (recordCounter+1), username, sTimeString);
	    AddMenuItem(menu, "", titleString, ITEMDRAW_DISABLED);
		recordCounter++;
	}
	
	if (recordCounter == 0) {
		decl String:titleString[512];
		Format(titleString, sizeof(titleString), "No world record found. Good luck!");
		AddMenuItem(menu, "", titleString, ITEMDRAW_DISABLED);
	}	
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 20);
}

ShowStageRecordMenu(client, stageId)
{
	new fixedStageId = stageId+1;
	new stageCount = 0;
	SurfTimerMap_stageCount(stageCount);
	
	if (fixedStageId == stageCount) {
		fixedStageId = 0;
	} else if ((stageId+1) > stageCount) {
		CPrintToChatAll("%s{lightgreen}{red}There is no stage {white}%d{red}.", PLUGIN_PREFIX, fixedStageId);
		return;
	}

	decl String:sQuery[2048];
	Format(sQuery, sizeof(sQuery), "SELECT c.user_name, c.user_id, MIN(a.user_stage_records_time) as recordTime FROM user_stage_records AS a LEFT JOIN map_zones AS b ON b.map_zone_id = a.user_stage_records_stage_id LEFT JOIN user as c on a.user_user_id = c.user_id WHERE b.map_id = %d AND (map_zone_type = 2 OR map_zone_type = 3) AND b.map_zone_checkpoint_order_id = %d GROUP BY a.user_user_id, b.map_zone_checkpoint_order_id ORDER BY recordTime", g_map[Id], fixedStageId);
	
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, (stageId+1));
	
	SQL_TQuery(g_hSQL, ShowStageRecordMenuCallback, sQuery, pack, DBPrio_High);
}

public ShowStageRecordMenuCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	ResetPack(data);
	new client = ReadPackCell(data);
	new stageId = ReadPackCell(data);
	CloseHandle(data);

	if (! SQL_GetRowCount(hndl)) {
		CPrintToChatAll("%s{lightgreen}{red}No records found for stage {white}%d{red}.", PLUGIN_PREFIX, stageId);
		return;
	}

	new recordCounter = 0;
	
	new Handle:menu = CreateMenu(StageTopMenuHandler, MENU_ACTIONS_ALL);
	decl String:menuTitle[64];
	Format(menuTitle, 64, "Records for stage %d", stageId);
	SetMenuTitle(menu, "Stage records");

	while (SQL_FetchRow(hndl)) {

		decl username[USERNAME_MAX];
		SQL_FetchString(hndl, 0, username, USERNAME_MAX);

		new userId = SQL_FetchInt(hndl, 1);

		decl String:sTimeString[128];
		SurfTimer_secondsToTime(SQL_FetchFloat(hndl, 2), sTimeString, sizeof(sTimeString), true);

		decl String:titleString[512];
		Format(titleString, sizeof(titleString), "[#%d] %s - %s", (recordCounter+1), username, sTimeString);
	    AddMenuItem(menu, "", titleString, ITEMDRAW_DISABLED);
		recordCounter++;
	}
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 20);
}

LoadLatestGlobalMapRecordsAndShowMenu(client)
{
	decl String:sQuery[2048];
	Format(sQuery, sizeof(sQuery), "SELECT user_name, map_name, user_record_time AS record_time FROM user_records LEFT JOIN user ON user.user_id = user_records.user_user_id LEFT JOIN maps ON maps.map_id = user_records.maps_map_id WHERE user_record_was_wr = 1 ORDER BY user_records.user_record_created_at DESC LIMIT 100");
	
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, client);
	
	SQL_TQuery(g_hSQL, LoadLatestGlobalMapRecordsAndShowMenuCallback, sQuery, pack, DBPrio_High);
}

public LoadLatestGlobalMapRecordsAndShowMenuCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	ResetPack(data);
	new client = ReadPackCell(data);
	CloseHandle(data);

	if (! SQL_GetRowCount(hndl)) {
		CPrintToChatAll("%s{lightgreen} No latest global record informations found", PLUGIN_PREFIX);
		return;
	}

	new recordCounter = 0;
	
	new Handle:menu = CreateMenu(MapTopMenuHandler, MENU_ACTIONS_ALL);
	SetMenuTitle(menu, "Recent 100 world records");

	while (SQL_FetchRow(hndl)) {

		decl username[USERNAME_MAX];
		SQL_FetchString(hndl, 0, username, USERNAME_MAX);

		decl mapname[MAPNAME_MAX];
		SQL_FetchString(hndl, 1, mapname, MAPNAME_MAX);

		decl String:sTimeString[128];
		SurfTimer_secondsToTime(SQL_FetchFloat(hndl, 2), sTimeString, sizeof(sTimeString), true);

		decl String:titleString[512];
		Format(titleString, sizeof(titleString), "[#%d] %s - %s (%s)", (recordCounter+1), mapname, sTimeString, username);
	    AddMenuItem(menu, "", titleString, ITEMDRAW_DISABLED);
		recordCounter++;
	}
	
	if (recordCounter == 0) {
		decl String:titleString[512];
		Format(titleString, sizeof(titleString), "No recent global world records found.\nTry it again!");
		AddMenuItem(menu, "", titleString, ITEMDRAW_DISABLED);
	}	
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 20);
}

public LoadMapRecordsCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE) {
		PrintToServer("SQL Error on LoadMap: %s", error);
		LoadUserRecords();
		return;
	}

	if (! SQL_GetRowCount(hndl)) {
		g_map[TimesCompleted] = 0;
		CPrintToChatAll("%s{lightgreen} No record informations found for map %s", PLUGIN_PREFIX, g_sCurrentMap);
		CPrintToChatAll("%s{lightgreen} Have fun hunting the world record!", PLUGIN_PREFIX);
		PrintToServer("[SurfTimer-Records] no records found for map %s", g_sCurrentMap);
		LoadMapStageRecords();
		return;
	}

	new recordCounter = 0;
	while (SQL_FetchRow(hndl)) {
		g_mapRecords[recordCounter][Id] = SQL_FetchInt(hndl, 0);
	 	g_mapRecords[recordCounter][Time] = SQL_FetchFloat(hndl, 14);
	 	g_mapRecords[recordCounter][UserId] = SQL_FetchFloat(hndl, 7);
	 	SQL_FetchString(hndl, 8, g_mapRecords[recordCounter][AuthName], USERNAME_MAX);
	 	SQL_FetchString(hndl, 9, g_mapRecords[recordCounter][Username], USERNAME_MAX);
		recordCounter++;
	}
	
	g_map[TimesCompletedDistinct] = recordCounter;	
	g_map[WorldRecordTime] = g_mapRecords[0][Time];
	PrintToServer("[SurfTimer-Records] loaded %d records from database", recordCounter);
	LoadLatestMapRecords();
}

public LoadMapStageRecordsCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE) {
		PrintToServer("SQL Error on LoadMapStageRecordsCallback: %s", error);
		LoadMapStageRecords();
		return;
	}

	if (! SQL_GetRowCount(hndl)) {
		CPrintToChatAll("%s{lightgreen} No stage record informations found for map %s", PLUGIN_PREFIX, g_sCurrentMap);
		CPrintToChatAll("%s{lightgreen} Have fun hunting the stage records!", PLUGIN_PREFIX);
		PrintToServer("[SurfTimer-Records] no stage records found for map %s", g_sCurrentMap);
		return;
	}

	new recordCounter = 0;
	new stageCount = 0;
	
	while (SQL_FetchRow(hndl)) {
		new orderId = SQL_FetchInt(hndl, 1);
		g_mapStageRecords[orderId][Id] = SQL_FetchInt(hndl, 0);
		g_mapStageRecords[orderId][OrderId] = SQL_FetchInt(hndl, 1);
		g_mapStageRecords[orderId][Type] = SQL_FetchInt(hndl, 3);
		g_mapStageRecords[orderId][WorldRecordTime] = SQL_FetchFloat(hndl, 5);
		if (0.0 == FloatAbs(SQL_FetchFloat(hndl, 5))) {
			g_mapStageRecords[orderId][Unfinished] = true;
		} else {
			g_mapStageRecords[orderId][Unfinished] = false;
			stageCount++;
		}
		
		SQL_FetchString(hndl, 6, g_mapStageRecords[orderId][Username], USERNAME_MAX);
		SQL_FetchString(hndl, 7, g_mapStageRecords[orderId][AuthName], AUTHID_MAX);
		recordCounter++;
	}
	

	g_map[CompletedStagesCount] = recordCounter;
	g_map[StageCount] = StageCount;
	PrintToServer("[SurfTimer-Records] loaded %d stage records (%d/%d completed) from database", recordCounter, stageCount, recordCounter);
}

public LoadLatestMapRecordsCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE) {
		PrintToServer("SQL Error on LoadMap: %s", error);
		return;
	}

	if (! SQL_GetRowCount(hndl)) {
		return;
	}

	new recordCounter = 0;
	while (SQL_FetchRow(hndl)) {
		g_latestMapRecords[recordCounter][Id] = SQL_FetchInt(hndl, 0);
	 	g_latestMapRecords[recordCounter][Time] = SQL_FetchFloat(hndl, 14);
	 	g_latestMapRecords[recordCounter][UserId] = SQL_FetchFloat(hndl, 7);
	 	SQL_FetchString(hndl, 8, g_latestMapRecords[recordCounter][AuthName], USERNAME_MAX);
	 	SQL_FetchString(hndl, 9, g_latestMapRecords[recordCounter][Username], USERNAME_MAX);
		recordCounter++;
		if (recordCounter == 9) {
			break;
		}
	}
	g_map[LatestRecordCount] = recordCounter; 
}

public Action:TimerLoadUserRecords(Handle:timer, any:serial)
{
	LoadUserRecords();
}

public LoadUserRecords()
{
	decl String:sQuery[2048];
	FormatEx(sQuery, sizeof(sQuery), "SELECT ranking.rank, ranking.user_name, ranking.user_id, ranking.user_points, (SELECT COUNT(*) as userCount FROM user) as userCount FROM (SELECT user_id, user_name, user_points, @rank := @rank+1 AS rank FROM user, (SELECT @rank := 0 AS rank) AS init ORDER BY user_points DESC) AS ranking");
	SQL_TQuery(g_hSQL, LoadUserRecordsCallback, sQuery, _, DBPrio_Low);
}

public LoadUserRecordsCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE) {
		PrintToServer("SQL Error on LoadMap: %s", error);
		CreateTimer(3.0, TimerLoadUserRecords, _, TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

	if (! SQL_GetRowCount(hndl)) {
		g_map[TimesCompleted] = 0;
		CPrintToChatAll("%s{lightgreen} No global record informations", PLUGIN_PREFIX);
		PrintToServer("[SurfTimer-Records] No global record informations");
		CreateTimer(3.0, TimerLoadUserRecords, _, TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

	new recordCounter = 0;

	while (SQL_FetchRow(hndl)) {
		g_userRank[recordCounter][Rank] = SQL_FetchInt(hndl, 0);
		SQL_FetchString(hndl, 1, g_userRank[recordCounter][Username], USERNAME_MAX);
		g_userRank[recordCounter][UserPoints] = SQL_FetchInt(hndl, 3);
		recordCounter++;
	}
	g_userGlobalCount = recordCounter;
	
	PrintToServer("[SurfTimer-Records] loaded %d overall records from database", recordCounter);
}

public LoadPlayerStageRecordsCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	new Handle:pack = data;
	ResetPack(pack);
	new client = ReadPackCell(pack);

	if (hndl == INVALID_HANDLE) {
		PrintToServer("SQL Error on LoadPlayerStageRecordsCallback: %s", error);
		LoadPlayerStageRecords(client);
		return;
	}

	if (! SQL_GetRowCount(hndl)) {
		PrintToServer("[SurfTimer-Records] no stage records found for map %s", g_sCurrentMap);
		return;
	}

	ResetPlayerStageRecord(client);

	new recordCounter = 0;
	new stageCount = 0;
	
	while (SQL_FetchRow(hndl)) {
		g_playerStageRecords[client][recordCounter][StageId] = SQL_FetchInt(hndl, 0);
		g_playerStageRecords[client][recordCounter][OrderId] = SQL_FetchInt(hndl, 1);
		g_playerStageRecords[client][recordCounter][StageType] = SQL_FetchInt(hndl, 3);
		g_playerStageRecords[client][recordCounter][RecordTime] = SQL_FetchFloat(hndl, 4);
		g_playerStageRecords[client][recordCounter][HasFinished] = SQL_FetchInt(hndl, 9);

		if (g_playerStageRecords[client][recordCounter][HasFinished]) {
			stageCount++;
		}

		recordCounter++;
	}
	

	g_playerStageRecords[client][0][CompletedStages] = stageCount;
	PrintToServer("[SurfTimer-Records] Player %d completed %d of %d stages (sql query found %d stages)", client, stageCount, recordCounter, g_map[StageCount]);
}

LoadUser(client)
{
	if (IsFakeClient(client)) {
		return;
	}
	
	decl String:sQuery[1024];

	new Handle:data = CreateDataPack();
	WritePackCell(data, client);
	FormatEx(sQuery, sizeof(sQuery), "select user_id from user where user_steam_id = '%s'", g_user[client][AuthName]);
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
		PrintToServer("Failed to load user id for ranking. (Client-Id %d)", client);
		CreateTimer(1.0, TimerLoadUser, data, TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

	SQL_FetchRow(hndl);
	g_user[client][Id] = SQL_FetchInt(hndl, 0);
	LoadPlayerStageRecords(client);
}

public Action:TimerLoadUser(Handle:timer, any:serial)
{
	ResetPack(serial);
	new client = ReadPackCell(serial);
	LoadUser(client);
}


public AddUserRecord(client, Float:time, bool:isWorldRecord, points)
{
	if (g_hSQL == INVALID_HANDLE) {
		PrintToServer("[SurfTimer-Rank] Failed to saved player record. SQL unavailable");
		return;
	}

	decl String:sQuery[1024];
	
	new userId = g_user[client][Id];
	if (! userId) {
		CPrintToChatAll("%s{red}[SurfTimer-Records] Player not found (Client %d)", PLUGIN_PREFIX ,userId, client);
	}

	Format(sQuery, sizeof(sQuery), "INSERT INTO user_records (user_user_id, maps_map_id, user_record_time, user_record_points, user_record_was_wr, user_record_created_at) VALUES (%d, %d, %f, %d, %d, %d)", userId, g_map[Id], time, points, isWorldRecord, GetTime());
	SQL_LockDatabase(g_hSQL);
	if (! SQL_FastQuery(g_hSQL, sQuery)) {
		new String:uerror[1024];
		SQL_GetError(g_hSQL, uerror, sizeof(uerror));
		PrintToServer("[SurfTimer-Records] Can not add record for user id %d - %s", userId, uerror);
		SQL_UnlockDatabase(g_hSQL);
		return;
	}
	SQL_UnlockDatabase(g_hSQL);

	Format(sQuery, sizeof(sQuery), "UPDATE user SET user_points = user_points + %d WHERE user_id = %d", points, userId);
	SQL_LockDatabase(g_hSQL);
	if (! SQL_FastQuery(g_hSQL, sQuery)) {
		PrintToServer("[SurfTimer-Records] Can not update user points for user id %d", userId);
	}
	SQL_UnlockDatabase(g_hSQL);

	// Update map counters and reload map data
	FormatEx(sQuery, sizeof(sQuery), "UPDATE maps SET map_total_completitions = map_total_completitions + 1%s WHERE map_name = '%s'", ((isWorldRecord) ? ", map_total_wrs = map_total_wrs + 1" : ""), g_sCurrentMap);
	SQL_LockDatabase(g_hSQL);
	if (! SQL_FastQuery(g_hSQL, sQuery)) {
		new String:uerror[1024];
		SQL_GetError(g_hSQL, uerror, sizeof(uerror));
		PrintToServer("[SurfTimer-Rank] Failed to update map_total_completitions for map %s (error: %s)", g_sCurrentMap, uerror); 
		SQL_UnlockDatabase(g_hSQL);
	}
	SQL_UnlockDatabase(g_hSQL);

	LoadMap();
}

public AddUserStageRecord(client, Float:time, bool:isWorldRecord, points, zoneId)
{
	if (g_hSQL == INVALID_HANDLE) {
		PrintToServer("[SurfTimer-Rank] Failed to saved player record. SQL unavailable");
		return;
	}

	decl String:sQuery[1024];
	
	new userId = g_user[client][Id];
	if (! userId) {
		CPrintToChatAll("%s{red}[SurfTimer-Records] Player not found (Client %d)", PLUGIN_PREFIX ,userId, client);
	}
																																																																			
	Format(sQuery, sizeof(sQuery), "INSERT INTO user_stage_records (user_stage_record_is_wr, user_stage_records_time, user_user_id, user_stage_records_stage_id, user_stage_records_created_at, maps_map_id, user_stage_record_points) VALUES ( %d, %f, %d, %d, %d, %d, %d)", isWorldRecord, time, userId, zoneId, GetTime(), g_map[Id], points);
	SQL_LockDatabase(g_hSQL);
	if (! SQL_FastQuery(g_hSQL, sQuery)) {
		new String:uerror[1024];
		SQL_GetError(g_hSQL, uerror, sizeof(uerror));
		PrintToServer("[SurfTimer-Records] Can not add stage record for user id %d - %s", userId, uerror);
		SQL_UnlockDatabase(g_hSQL);
		return;
	}
	SQL_UnlockDatabase(g_hSQL);

	Format(sQuery, sizeof(sQuery), "UPDATE user SET user_points = user_points + %d WHERE user_id = %d", points, userId);
	SQL_LockDatabase(g_hSQL);
	if (! SQL_FastQuery(g_hSQL, sQuery)) {
		PrintToServer("[SurfTimer-Records] Can not update user points for user id %d", userId);
	}
	SQL_UnlockDatabase(g_hSQL);
	LoadMapStageRecords();
}

public AddUserRecordCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{

	decl authName[AUTHID_MAX];
	new client = 0;
	new Float:time = 0;
	new bool:isWorldRecord = false;
	new points = 0;

	ResetPack(data);
	ReadPackString(data, authName, sizeof(authName));
	client = ReadPackCell(data);
	time = ReadPackFloat(data);
	isWorldRecord = ReadPackCell(data);
	points = ReadPackCell(data);
	CloseHandle(data);
	
	if (hndl == INVALID_HANDLE) {
		PrintToServer("[SurfTimer-Rank] SQL Error on AddUserRecordCallback: %s", error);
		return;
	}

	if (! SQL_GetRowCount(hndl)) {
		PrintToServer("[SurfTimer-Records] Player not found for Steam ID %s", authName);
		return;
	}

	SQL_FetchRow(hndl);
	new userId = SQL_FetchInt(hndl, 0);
	
	if (! userId) {
		PrintToServer("[SurfTimer-Records] Player not found for Steam ID %s", authName);
		return;
	}

	// Add user record
	
}

ShowMapPlayerRank(client, args)
{
	
	decl String:sQuery[2048];
	FormatEx(sQuery, sizeof(sQuery), "SELECT ranking.rank, ranking.record_time, (SELECT COUNT(*) FROM (SELECT COUNT(user_user_id) FROM user_records AS user_records LEFT JOIN user ON user.user_id = user_records.user_user_id WHERE maps_map_id = %i GROUP BY user_user_id) as total) as total FROM (SELECT @rank := @rank+1 AS rank, ranking.* FROM (SELECT @rank := 0 AS rank) AS init, (SELECT *, MIN(user_record_time) AS record_time FROM user_records AS user_records LEFT JOIN user ON user.user_id = user_records.user_user_id WHERE maps_map_id = %i GROUP BY user_user_id ORDER BY MIN(user_record_time)) as ranking) as ranking where user_steam_id = '%s' LIMIT 1", g_map[Id], g_map[Id], g_user[client][AuthName]);
	
	new Handle:user = CreateDataPack();
	if (user == INVALID_HANDLE) {
		CPrintToChatAll("%s{red}Ups, failed look up rank database. Please try it later again :(", PLUGIN_PREFIX);
	}
	WritePackCell(user, client);
	SQL_LockDatabase(g_hSQL);
	SQL_FastQuery(g_hSQL, "SET NAMES 'UTF8'");
	SQL_UnlockDatabase(g_hSQL);
	SQL_TQuery(g_hSQL, ShowMapPlayerRankCallback, sQuery, user, DBPrio_Low);
}

public ShowMapPlayerRankCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	ResetPack(data);
	new client = ReadPackCell(data);

	decl String:name[USERNAME_MAX];
	GetClientName(client, name, sizeof(name));

	if (hndl == INVALID_HANDLE) {
		PrintToServer("SQL Error on selecting play rank: %s", error);
		return;
	}

	if (! SQL_GetRowCount(hndl)) {
		CPrintToChatAll("%s{red}No ranking informations found for %s", PLUGIN_PREFIX, name);
		return;
	}

	SQL_FetchRow(hndl);
	new userRank = SQL_FetchInt(hndl, 0);
	decl String:userMax[11];
	SQL_FetchString(hndl, 2, userMax, sizeof(userMax));
	new float:userTime = SQL_FetchFloat(hndl, 1);
	
	decl String:sTimeFormatted[128];
	SurfTimer_secondsToTime(userTime, sTimeFormatted, sizeof(sTimeFormatted));
	
	CPrintToChatAll("%s{white}%s {lightgreen}ranks {white}%i{lightgreen}/{white}%s {lightgreen}with {white}%s {lightgreen}on {white}%s", PLUGIN_PREFIX, name, userRank, userMax, sTimeFormatted, g_sCurrentMap);
}

ShowMapPlayerRankWithParameters(client, const String:mapName[], const String:userName[])
{
	new String:newMapName[MAPNAME_MAX*2];
	new String:newUserName[USERNAME_MAX*2];

	SQL_EscapeString(g_hSQL, mapName, newMapName, MAPNAME_MAX*2);
	SQL_EscapeString(g_hSQL, userName, newUserName, USERNAME_MAX*2);

	decl String:sQuery[2048];
	FormatEx(sQuery, sizeof(sQuery), "SELECT ranking.rank, ranking.record_time, (SELECT COUNT(*) FROM (SELECT COUNT(user_user_id) FROM user_records AS user_records LEFT JOIN user ON user.user_id = user_records.user_user_id WHERE maps_map_id = (SELECT map_id FROM maps WHERE map_name = '%s' LIMIT 1) GROUP BY user_user_id) as total) as total FROM (SELECT @rank := @rank+1 AS rank, ranking.* FROM (SELECT @rank := 0 AS rank) AS init, (SELECT *, MIN(user_record_time) AS record_time FROM user_records AS user_records LEFT JOIN user ON user.user_id = user_records.user_user_id WHERE maps_map_id = (SELECT map_id FROM maps WHERE map_name = '%s' LIMIT 1) GROUP BY user_user_id ORDER BY MIN(user_record_time)) as ranking) as ranking where user_name = '%s' LIMIT 1", newMapName, newMapName, newUserName);
	
	new Handle:user = CreateDataPack();
	if (user == INVALID_HANDLE) {
		CPrintToChatAll("%s{red}Ups, failed look up rank database. Please try it later again :(", PLUGIN_PREFIX);
	}
	WritePackCell(user, client);
	WritePackString(user, mapName);
	WritePackString(user, newUserName);
	SQL_TQuery(g_hSQL, ShowMapPlayerRankWithParametersCallback, sQuery, user, DBPrio_Low);
}

public ShowMapPlayerRankWithParametersCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	new String:newMapName[MAPNAME_MAX*2];
	new String:newUserName[USERNAME_MAX*2];

	ResetPack(data);
	new client = ReadPackCell(data);
	ReadPackString(data, newMapName, MAPNAME_MAX*2);
	ReadPackString(data, newUserName, USERNAME_MAX*2);

	decl String:name[USERNAME_MAX];
	GetClientName(client, name, sizeof(name));

	if (hndl == INVALID_HANDLE) {
		PrintToServer("SQL Error selecting map / player rank: %s", error);
		return;
	}

	if (! SQL_GetRowCount(hndl)) {
		CPrintToChatAll("%s{red}No ranking informations found for map %s %s", PLUGIN_PREFIX, newMapName, (strlen(newUserName) ? newUserName : ""));
		return;
	}

	SQL_FetchRow(hndl);
	new userRank = SQL_FetchInt(hndl, 0);
	decl String:userMax[11];
	SQL_FetchString(hndl, 2, userMax, sizeof(userMax));
	new float:userTime = SQL_FetchFloat(hndl, 1);
	
	decl String:sTimeFormatted[128];
	SurfTimer_secondsToTime(userTime, sTimeFormatted, sizeof(sTimeFormatted));
	
	CPrintToChatAll("%s{white}%s {lightgreen}ranks {white}%i{lightgreen}/{white}%s {lightgreen}with {white}%s {lightgreen}on {white}%s", PLUGIN_PREFIX, (strlen(newUserName) ? newUserName : name), userRank, userMax, sTimeFormatted, newMapName);
}

ShowGlobalPlayerRank(client, args)
{
	new String:newPlayerName[USERNAME_MAX*2];
	decl String:playerName[USERNAME_MAX*2];
	decl String:sQuery[2048];
	if (args > 0) {
		SQL_LockDatabase(g_hSQL);
		SQL_FastQuery(g_hSQL, "SET NAMES 'UTF8'");
		SQL_UnlockDatabase(g_hSQL);
		GetCmdArgString(playerName, sizeof(playerName));
		SQL_EscapeString(g_hSQL, playerName, newPlayerName, USERNAME_MAX*2);
		strcopy(newPlayerName, sizeof(newPlayerName), playerName);

		FormatEx(sQuery, sizeof(sQuery), "SELECT ranking.rank, ranking.user_name, ranking.user_id, ranking.user_points, (SELECT COUNT(*) as userCount FROM user) as userCount FROM (SELECT user_id, user_name, user_steam_id, user_points, @rank := @rank+1 AS rank FROM user, (SELECT @rank := 0 AS rank) AS init ORDER BY user_points DESC) AS ranking WHERE ranking.user_name = '%s' LIMIT 1", newPlayerName);
	} else {
		GetClientName(client, playerName, sizeof(playerName));
		GetClientAuthString(client, newPlayerName, sizeof(newPlayerName));
		FormatEx(sQuery, sizeof(sQuery), "SELECT ranking.rank, ranking.user_name, ranking.user_id, ranking.user_points, (SELECT COUNT(*) as userCount FROM user) as userCount, ranking.user_steam_id FROM (SELECT user_id, user_name, user_steam_id, user_points, @rank := @rank+1 AS rank FROM user, (SELECT @rank := 0 AS rank) AS init ORDER BY user_points DESC) AS ranking WHERE ranking.user_steam_id = '%s' LIMIT 1", newPlayerName);
	}
	
	
	
	
	new Handle:user = CreateDataPack();
	if (user == INVALID_HANDLE) {
		CPrintToChatAll("%s{red}Ups, failed look up rank database. Please try it later again :(", PLUGIN_PREFIX);
	}
	WritePackCell(user, client);
	WritePackString(user, playerName);

	SQL_TQuery(g_hSQL, ShowGlobalPlayerRankCallback, sQuery, user, DBPrio_Low);
}

public ShowGlobalPlayerRankCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	ResetPack(data);
	new client = ReadPackCell(data);
	decl String:name[USERNAME_MAX*2];
	ReadPackString(data, name, sizeof(name));

	if (hndl == INVALID_HANDLE) {
		PrintToServer("SQL Error on selecting play rank: %s", error);
		return;
	}

	if (! SQL_GetRowCount(hndl)) {
		decl String:requestName[USERNAME_MAX];
		GetClientName(client, requestName, sizeof(requestName));
		if (strcmp(requestName, name) != 0) {
			CPrintToChatAll("%s{red}No ranking informations found or user {white}%s{red} not found.", PLUGIN_PREFIX, name);
			return;
		}
		CPrintToChatAll("%s{red}No ranking informations found for user {white}%s", PLUGIN_PREFIX, name);
		return;
	}

	SQL_FetchRow(hndl);
	new userRank = SQL_FetchInt(hndl, 0);
	new userPoints = SQL_FetchInt(hndl, 3);

	decl String:userMax[11];
	SQL_FetchString(hndl, 4, userMax, sizeof(userMax));

	CPrintToChatAll("%s{white}%s {lightgreen}ranks {white}%i{lightgreen}/{white}%s {lightgreen}with {white}%i{lightgreen} points", PLUGIN_PREFIX, name, userRank, userMax, userPoints);
}

/**
* Commands
*/

public Action:User_rank(client, args)
{
	ShowGlobalPlayerRank(client, args);
}


public Action:Map_User_rank(client, args)
{
	ShowMapPlayerRank(client, args);
}

/**

*/

public Action:Map_stageRecords(client, args) {


	// Arguments - ShowStageRecordMenu(client, stageId)
	if (args > 0) {
		new String:stageIdString[MAPNAME_MAX];
		GetCmdArg(1, stageIdString, sizeof(stageIdString));
		new stageId = StringToInt(stageIdString);
		ShowStageRecordMenu(client, (stageId-1));
		return Plugin_Handled;
	}

	new stageCount = 0;
	SurfTimerMap_stageCount(stageCount);

	if (stageCount == 1) {
		decl String:username[USERNAME_MAX];
		GetClientName(client, username, USERNAME_MAX);
		CPrintToChat(client, "%s{red}Sorry {white}%s{red}. {white}%s{red} has no stages.", PLUGIN_PREFIX, username, g_sCurrentMap);
		return Plugin_Handled;
	}

	new Handle:menu = CreateMenu(MapStageTopMenuHandler, MENU_ACTIONS_ALL);
	decl String:menuTitle[128];
	Format(menuTitle, sizeof(menuTitle), "Stage Top - %s", g_sCurrentMap);
	SetMenuTitle(menu, menuTitle);

	for (new i = 1; i < stageCount; i++) {
		AddRecordToStageRecordMenu(menu, i, StageCount);		
	}

	AddRecordToStageRecordMenu(menu, 0, stageCount);

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 20);
	
	return Plugin_Handled;
}

AddRecordToStageRecordMenu(Handle:menu, stageId, stageCount)
{
	decl String:titleString[256];
	if (FloatAbs(g_mapStageRecords[stageId][WorldRecordTime]) == 0.0) {
		Format(titleString, sizeof(titleString), "[#%d] No world record", ((stageId == 0) ? stageCount : stageId));
    	AddMenuItem(menu, "", titleString, ITEMDRAW_DISABLED);
    	return;
	}

	decl String:sTimeString[128];
	SurfTimer_secondsToTime(g_mapStageRecords[stageId][WorldRecordTime], sTimeString, sizeof(sTimeString), true);

	Format(titleString, sizeof(titleString), "[#%d] %s - %s", ((stageId == 0) ? stageCount : stageId), g_mapStageRecords[stageId][Username], sTimeString);
    AddMenuItem(menu, "", titleString);
}

public MapStageTopMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action) {
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
		case MenuAction_Select:
		{
			PrintToChatAll("%d %d", param1, param2);
			ShowStageRecordMenu(param1, param2);
			CloseHandle(menu);
		}
		// case MenuAction_DrawItem:
		// {
		// 	new style;
		// 	decl String:info[32];
		// 	GetMenuItem(menu, param2, info, sizeof(info), style);
		// 	return ITEMDRAW_DISABLED;
		// }
	}
 
	return 0;
}

public Action:Map_top(client, args)
{
	
	if (args == 0) {
		new Handle:menu = CreateMenu(MapTopMenuHandler, MENU_ACTIONS_ALL);
		decl String:menuTitle[128];
		Format(menuTitle, sizeof(menuTitle), "Map top - %s", g_sCurrentMap);
		SetMenuTitle(menu, menuTitle);

		for (new i = 0; i < g_map[TimesCompletedDistinct]; i++) {
			decl String:sTimeString[128];
			SurfTimer_secondsToTime(g_mapRecords[i][Time], sTimeString, sizeof(sTimeString), true);

			decl String:titleString[512];
			Format(titleString, sizeof(titleString), "[#%d] %s - %s", (i+1), g_mapRecords[i][Username], sTimeString);
		    AddMenuItem(menu, "", titleString, ITEMDRAW_DISABLED);
			
		}
		if (g_map[TimesCompletedDistinct] == 0) {
			decl String:titleString[512];
			Format(titleString, sizeof(titleString), "No world record found. Good luck!");
			AddMenuItem(menu, "", titleString, ITEMDRAW_DISABLED);
		}
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, 20);
		
		return Plugin_Handled;
	}
	
	new String:arg[128];
	GetCmdArg(1, arg, sizeof(arg));
	LoadMapRecordsAndShowTop(client, arg);

	return Plugin_Handled;
}

public MapTopMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action) {
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
		case MenuAction_DrawItem:
		{
			new style;
			decl String:info[32];
			GetMenuItem(menu, param2, info, sizeof(info), style);
			return ITEMDRAW_DISABLED;
		}
	}
 
	return 0;
}

public StageTopMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action) {
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
 
	return 0;
}

public Action:Map_latestRecords(client, args)
{
	if (args == 0) {
		
		new Handle:menu = CreateMenu(MapTopMenuHandler, MENU_ACTIONS_ALL);
		decl String:menuTitle[128];
		Format(menuTitle, sizeof(menuTitle), "Latest records on %s", g_sCurrentMap);
		SetMenuTitle(menu, menuTitle);

		for (new i = 0; i < g_map[LatestRecordCount]; i++) {
			decl String:sTimeString[128];
			SurfTimer_secondsToTime(g_latestMapRecords[i][Time], sTimeString, sizeof(sTimeString), true);

			decl String:titleString[512];
			Format(titleString, sizeof(titleString), "[#%d] %s - %s", (i+1), g_latestMapRecords[i][Username], sTimeString);
		    AddMenuItem(menu, "", titleString, ITEMDRAW_DISABLED);
			
		}
		if (g_map[LatestRecordCount] == 0) {
			decl String:titleString[512];
			Format(titleString, sizeof(titleString), "No world record found. Good luck!");
			AddMenuItem(menu, "", titleString, ITEMDRAW_DISABLED);
		}
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, 20);
		return Plugin_Handled;
	}

	return Plugin_Handled;
}

public Action:Map_latestRecordsGlobal(client, args)
{
	LoadLatestGlobalMapRecordsAndShowMenu(client);
	return Plugin_Handled;
	
}

public Action:Map_rank(client, args)
{

	if (args == 0) {
		CPrintToChatAll("%s{pink} use !mrank mapname or !mrank mapname \"username\"", PLUGIN_PREFIX);
		return Plugin_Handled;
	}

	new String:mapName[MAPNAME_MAX];
	GetCmdArg(1, mapName, sizeof(mapName));

	decl String:username[USERNAME_MAX];
	GetCmdArg(2, username, sizeof(username));

	if (strlen(username) == 0) {
		GetClientName(client, username, USERNAME_MAX);
	}

	ShowMapPlayerRankWithParameters(client, mapName, username);

	return Plugin_Handled;
}

public MapTopHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select) {
		// PrintToConsole(param1, "You selected item: %d", param2);
	} else if (action == MenuAction_Cancel) {
		
	}
}

public Action:Map_dhcTop(client, args)
{
	new String:arg[128];
	if (args > 0) {
		GetCmdArg(1, arg, sizeof(arg));
	} else {
		Format(arg, sizeof(arg), "%s", g_sCurrentMap);
	}

	new bool:abuse = false;
	if (-1 != StrContains(arg, "&", false)) {
		abuse = true;
	} else if (-1 != StrContains(arg, "&", false)) {
		abuse = true;
	} else if (-1 != StrContains(arg, "|", false)) {
		abuse = true;
	} else if (-1 != StrContains(arg, "{", false)) {
		abuse = true;
	} else if (-1 != StrContains(arg, "}", false)) {
		abuse = true;
	} else if (-1 != StrContains(arg, "(", false)) {
		abuse = true;
	} else if (-1 != StrContains(arg, ")", false)) {
		abuse = true;
	} else if (-1 != StrContains(arg, "rm", false)) {
		abuse = true;
	} else if (-1 != StrContains(arg, "~", false)) {
		abuse = true;
	} else if (-1 != StrContains(arg, "$", false)) {
		abuse = true;
	} else if (-1 != StrContains(arg, "\"", false)) {
		abuse = true;
	} else if (-1 != StrContains(arg, "/", false)) {
		abuse = true;
	} else if (-1 != StrContains(arg, "\\", false)) {
		abuse = true;
	} else if (-1 != StrContains(arg, "'", false)) {
		abuse = true;
	} else if (-1 != StrContains(arg, "=", false)) {
		abuse = true;
	} else if (-1 != StrContains(arg, "#", false)) {
		abuse = true;
	} else if (-1 != StrContains(arg, "+", false)) {
		abuse = true;
	}


	if (abuse) {
		CPrintToChatAll("%sDont try to abuse the command ;)", PLUGIN_PREFIX);
		return;
	}

	decl String:script[1024];
	Format(script, sizeof(script), "php /home/gameserver/srcds/Scripts/Dhctop/Dhctop.php %s %d", arg, client);
	System2_RunThreadCommand(Map_dhcTopCallback, script);
}

public Map_dhcTopCallback(const String:output[], const size, CMDReturn:status, any:data)
{
	new String:outputBuf[32][256];
	new count = ExplodeString(output, "\n", outputBuf, sizeof(outputBuf), sizeof(outputBuf[]));

	new client = StringToInt(outputBuf[0]);
	
	if (! Client_IsValid(client)) {
		return;
	}

	new String:titleString[128];
	Format(titleString, sizeof(titleString), "DHC Top 10");

	new Handle:panel = CreatePanel();
	SetPanelTitle(panel, titleString);

	if (count <= 2) {
		DrawPanelItem(panel, "Nothing found :( Wrong map name?", ITEMDRAW_DISABLED);
		DrawPanelItem(panel, "Try again later =)", ITEMDRAW_DISABLED);
	} else {
		for (new i = 1; i < 11; i++) {
			DrawPanelItem(panel, outputBuf[i], ITEMDRAW_DISABLED);	
		}
	}
	
	DrawPanelItem(panel, "", ITEMDRAW_DISABLED);
	DrawPanelItem(panel, "Exit", ITEMDRAW_DEFAULT);
	
	SendPanelToClient(panel, client, DhcTopPanelHandler, 20);
	CloseHandle(panel);
}

public DhcTopPanelHandler(Handle:menu, MenuAction:action, param1, param2)
{
	
}

public Action:Global_top(client, args)
{
 	new Handle:menu = CreateMenu(PlayerTopMenuHandler, MENU_ACTIONS_ALL);
	SetMenuTitle(menu, "Global top 100");
	for (new i = 0; i < 100; i++) {
		decl String:titleString[512];
		Format(titleString, sizeof(titleString), "[#%d] %s - %i points", (i+1), g_userRank[i][Username], g_userRank[i][UserPoints]);
	    AddMenuItem(menu, "", titleString, ITEMDRAW_RAWLINE);
	}
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 20);

	return Plugin_Handled;
}

public PlayerTopMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action) {
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
		case MenuAction_DrawItem:
		{
			new style;
			decl String:info[32];
			GetMenuItem(menu, param2, info, sizeof(info), style);
			return ITEMDRAW_DISABLED;
		}
	}
 
	return 0;
}

/**
* Calculations
*/

public CalculatePointsForFinish(bool:isRecord)
{


	new difficulty = g_map[Difficulty];
	new recordsCount = g_map[WorldRecordCount];

	new points = 0;

	switch (difficulty)
	{
		case 0:
		{
			points += 5;
		}
		case 1:
		{
			points += 10;
		}
		case 2:
		{
			points += 25;
		}
		case 3:
		{
			points += 50;
		}
		case 4:
		{
			points += 100;
		}
		default:
		{
			CPrintToChatAll("%s{red}We are sorry! Something went wrong when calculating your points.", PLUGIN_PREFIX);
			CPrintToChatAll("%s{red}Please send a screenshot with your time to stefan@opengl.io.", PLUGIN_PREFIX);
			return 0;
		}
	}

	if (! isRecord) {
		return points;
	}

	if (recordsCount <= 3) {
		points += 5;
	} else if (recordsCount > 3 && recordsCount <= 10) {
		points += 50;
	} else if (recordsCount > 10 && recordsCount <= 25) {
		points += 100;
	} else if (recordsCount > 25 && recordsCount <= 50) {
		points += 200;
	} else if (recordsCount > 50 && recordsCount <= 100) {
		points += 300;
	} else if (recordsCount > 100 && recordsCount <= 200) {
		points += 400;
	} else {
		points += 500;
	}

	return points;
}


/**
* Natives
*/

public Native_SurfTimer_currentWRData(Handle:plugin, numParams)
{
	// new client = GetNativeCell(1);
	if (g_map[TimesCompletedDistinct] > 0) {
		SetNativeCellRef(2, g_map[WorldRecordTime]);
	} else {
		new Float:noRecord = 0.0;
		SetNativeCellRef(2, noRecord);
	}
	return true;
}

public Native_SurfTimer_currentStageWRData(Handle:plugin, numParams)
{
	new orderId = GetNativeCell(3);

	if (orderId == g_map[StageCount]) {
		orderId = 0;
	}

	if (g_map[StageCount] > 0) {
		SetNativeCellRef(2, g_mapStageRecords[orderId][WorldRecordTime]);
	} else {
		new Float:noRecord = 0.0;
		SetNativeCellRef(2, noRecord);
	}
	return true;
}

public Native_SurfTimerRank_SurfTimer_stageCount(Handle:plugin, numParams)
{
	SetNativeCellRef(1, g_map[StageCount]);
}


public Native_SurfTimer_reloadStats(Handle:plugin, numParams)
{
	LoadMapRecords();
	CPrintToChatAll("%s{orange}Stats had been reloaded", PLUGIN_PREFIX);
	return true;
}

public Native_SurfTimerRank_playerDidFinishStage(Handle:plugin, numParams)
{
	decl String:authName[AUTHID_MAX]; decl String:playerName[USERNAME_MAX];
	decl String:sTimeString[32]; decl String:sTimeDifference[32]; decl String:sTimeDifferenceString[38];

	decl String:sOutput[512];
	
	new client = GetNativeCell(1);
	GetClientName(client, playerName, USERNAME_MAX);
	GetClientAuthString(client, authName, AUTHID_MAX);

	new Float:time = GetNativeCell(4);
	new stageId = GetNativeCell(5);
	new orderId = GetNativeCell(6);

	new points = 0;

	// 0 is impossible - 
	if (time == 0.0) {
		CPrintToChatAll("%s{red}xxx - {white}%s{red} sorry, your record is invalid! You can't finish a stage in 0 seconds - xxx", PLUGIN_PREFIX, playerName);
		return;
	}

	// Format output string
	SurfTimer_secondsToTime(time, sTimeString, sizeof(sTimeString), true);
	Format(sOutput, sizeof(sOutput), "%s", PLUGIN_PREFIX);

	new bool:isNegative = false;
	new Float:difference = time - g_mapStageRecords[orderId][WorldRecordTime];
	if (difference <= 0.0) {
		difference = g_mapStageRecords[orderId][WorldRecordTime] - time;
		isNegative = true;
	}
	SurfTimer_secondsToTime(difference, sTimeDifference, sizeof(sTimeDifference), true);
	Format(sTimeDifferenceString, sizeof(sTimeDifferenceString), "%s %s", ((isNegative) ? "-" : "+"), sTimeDifference);
	
	new bool:isWr = false;
	// Check if new time is stage world record
	if ((time > g_mapStageRecords[orderId][WorldRecordTime]) && ! g_mapStageRecords[orderId][HasFinished]) {
		CPrintToChat(client, "%s{orchid}You were {white}%s{orchid} behind the current stage record {orchid}({white}%s {orchid}).", PLUGIN_PREFIX, sTimeDifferenceString, sTimeString);
	} else {
		if (! g_mapStageRecords[orderId][Unfinished]) {
			if (orderId == 0) {
				CPrintToChatAll("%s{deepskyblue}%s{lightgreen} broke WR of {white}last stage{lightgreen} with {white}%s{lightgreen} ({white}%s {lightgreen})", PLUGIN_PREFIX, playerName, sTimeString, sTimeDifferenceString);
			} else {
				CPrintToChatAll("%s{deepskyblue}%s{lightgreen} broke WR on stage {white}%d{lightgreen} with {white}%s{lightgreen} ({white}%s {lightgreen})", PLUGIN_PREFIX, playerName, orderId, sTimeString, sTimeDifferenceString);
			}
		} else {
			if (orderId == 0) {
				CPrintToChatAll("%s{deepskyblue}%s{lightgreen} made first WR of {white}last stage{lightgreen} with {white} %s", PLUGIN_PREFIX, playerName, sTimeString);
			} else {
				CPrintToChatAll("%s{deepskyblue}%s{lightgreen} made first WR on stage {white}%d{lightgreen} with {white} %s", PLUGIN_PREFIX, playerName, orderId, sTimeString);
			}
		}
		isWr = true;
		points += 5;
		g_mapStageRecords[orderId][WorldRecordTime] = time;
		strcopy(g_mapStageRecords[orderId][Username], USERNAME_MAX, playerName);
		strcopy(g_mapStageRecords[orderId][AuthName], AUTHID_MAX, authName);
	}
	
	// Iterate personal world records and mark record for stage and set time
	for (new i = 0; i < MAX_ZONES; i++) {
		if (g_playerStageRecords[client][i][StageId] != stageId) {
			continue;
		}
		if (! g_playerStageRecords[client][i][HasFinished]) {
			g_playerStageRecords[client][i][HasFinished] = true;
			g_playerStageRecords[client][i][RecordTime] = time;
			CPrintToChat(client, "%s{lightgreen}You finished this stage the first time. You gain {white}5{lightgreen} points.", PLUGIN_PREFIX);
			points += 5;
			break;
		}
	}
	AddUserStageRecord(client, time, isWr, points, stageId);
}

public Native_SurfTimerRank_playerDidFinish(Handle:plugin, numParams)
{
	decl String:authName[AUTHID_MAX]; decl String:playerName[USERNAME_MAX];
	decl String:sTimeString[32]; decl String:sTimeDifference[32]; decl String:sTimeDifferenceString[38];

	decl String:sOutput[512];
	
	new client = GetNativeCell(1);
	GetNativeString(2, playerName, sizeof(playerName));
	GetNativeString(3, authName, sizeof(authName));
	new Float:time = GetNativeCell(4);
	if (time == 0.0) {
		Format(sOutput, sizeof(sOutput), "%s{red}xxx - {white}%s{red} sorry, your record is invalid! You can't finish in 0 seconds - xxx", PLUGIN_PREFIX, playerName);
		CPrintToChatAll(sOutput);
		return;
	}

	// Format output string
	SurfTimer_secondsToTime(time, sTimeString, sizeof(sTimeString), true);
	Format(sOutput, sizeof(sOutput), "%s", PLUGIN_PREFIX);

	if (g_map[TimesCompletedDistinct] > 0) {
		new bool:isNegative = false;
		new Float:difference = time - g_map[WorldRecordTime];
		if (difference <= 0) {
			difference = g_map[WorldRecordTime] - time;
			isNegative = true;
		}
		SurfTimer_secondsToTime(difference, sTimeDifference, sizeof(sTimeDifference), true);
		Format(sTimeDifferenceString, sizeof(sTimeDifferenceString), "(%s %s)", ((isNegative) ? "-" : "+"), sTimeDifference);
	}
	
	new bool:isWorldRecord = false;
	if (g_map[WorldRecordTime] > time) {
		isWorldRecord = true;
	}

	if (g_map[TimesCompletedDistinct] == 0) {
		isWorldRecord = true;	
	}

	// check if player time is best, otherwise give 0 points
	new personalWr = true;

	// get user id by authname
	for (new i = 0; i < g_map[TimesCompletedDistinct]; i++) {
		if (strcmp(g_mapRecords[i][AuthName], g_user[client][AuthName])) {
			continue;
		}
		
		if (time > g_mapRecords[i][Time]) {
			personalWr = false;
		}
	}
	
	new points = 0;
	if (personalWr) {
		points = CalculatePointsForFinish(isWorldRecord);
		if (! isWorldRecord) {
			EmitSoundToClient(client, g_soundNamePersonalWr, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_RAIDSIREN);
		}
	}

	if (isWorldRecord) {
		points = CalculatePointsForFinish(isWorldRecord);
	}

	if (isWorldRecord) {
		Format(sOutput, sizeof(sOutput), "%s{white}!! NEW WR !! ", sOutput);
		// temp override before reloading map data
		g_map[WorldRecordTime] = g_mapRecords[0][Time];
		EmitSoundToAll(g_soundName, SOUND_FROM_PLAYER);
		EmitSoundToAll(g_soundName, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_RAIDSIREN);
		// Play WR sound
	} else {
		// Play normal sound for finish
	}

	// Print tons of strings
	Format(sOutput, sizeof(sOutput), "%s{pink}✔✔✔ {white}%s{lightgreen} finished in {white}%s %s{pink} - Points: {white}%i {pink}✔✔✔", sOutput,playerName, sTimeString, ((g_map[TimesCompletedDistinct] > 0) ? sTimeDifferenceString : ""), points);
	CPrintToChatAll(sOutput);

	if (! points) {
		CPrintToChat(client, "%s{red}You did not improved your last time. You only gain new points, if you beat your personal record.", PLUGIN_PREFIX);
	} else {
		CPrintToChat(client, "%s{lightgreen}You improved your personal record. You gain {white}%s{lightgreen} points.", PLUGIN_PREFIX, points);
	}

	g_map[WorldRecordCount] += 1;
	AddUserRecord(client, time, isWorldRecord, points);
}

ResetPlayerStageRecord(client) 
{
	for (new i = 0; i < MAX_ZONES; i++) {
		g_playerStageRecords[client][i][StageId] = 0;
		g_playerStageRecords[client][i][OrderId] = 0;
	}
}



