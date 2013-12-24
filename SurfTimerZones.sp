#pragma semicolon 1

#include <SurfTimerZones>

#undef REQUIRE_PLUGIN
#include <SurfTimer>
#include <SurfTimerMap>

enum ZoneEditor
{
	Step,
	Float:PointOne[3],
	Float:PointTwo[3]
}

enum Zone
{
	Id,
	MapId,
	OrderId,
	EntityRef,
	Float:PointOne[3],
	Float:PointTwo[3],
	ZoneType:Type,
}

enum Map
{
	Id,
	Difficulty,
	String:MapName[MAPNAME_MAX],
	MapType,
	bool:Enabled,
	// other stuff will follow
	// enum points per things?
}

new Handle:g_hSQL;
new String:g_sCurrentMap[MAPNAME_MAX];

new g_iLaserMaterial = -1;
new g_iHaloMaterial = -1;
new g_iGlowSprite = -1;
new g_iWoodCrate = -1;

// Map
new g_map[Map];
new String:g_zoneTypeName[8][40];

// Zone handler
new Handle:g_hCvarZoneStartColor = INVALID_HANDLE;
new Handle:g_hCvarZoneEndColor = INVALID_HANDLE;
new Handle:g_hCvarZoneCheckpointZoneColor = INVALID_HANDLE;
new Handle:g_hCvarStopPrespeed = INVALID_HANDLE;
new Handle:g_hCvarDrawMapZones = INVALID_HANDLE;

// Zone editor
new g_mapZones[MAXPLAYERS][Zone];
new g_mapZonesCount = 0;
new Handle:g_ZoneDeleteHandle = INVALID_HANDLE;

// Zone editor preferences
new bool:g_zoneEditPerAxis = false;
new bool:g_zoneEditCallInProgress = false;

// Zone editor colors
new g_startColor[4] = {0, 255, 0, 255};
new g_endColor[4] = {0, 0, 255, 255};
new bool:g_bDrawMapZones = false;

// Admin menu
new Handle:hTopMenu = INVALID_HANDLE;
new TopMenuObject:oMapZoneMenu;
new g_mapZoneEditors[MAXPLAYERS][ZoneEditor];

// mysql 
new g_iSQLReconnectCounter = 0;

public Plugin:myinfo =
{
	name = "[SurfTimer]-ZoneEditor",
	author = "Fuxx",
	description = "The ultimative ZoneEditor tool for SurfTimer by Fuxx (forked from AlongTimer, heavily modified)",
	version = PLUGIN_VERSION,
	url = "http://www.stefanpopp.de"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("SurfTimerZones_teleportPlayer", Native_SurfTimerZones_teleportPlayer);
	CreateNative("SurfTimerZones_teleportPlayerToStage", Native_SurfTimerZones_teleportPlayerToStage);
	CreateNative("SurfTimerZones_isMapEnabled", Native_SurfTimerZones_isMapEnabled);
	CreateNative("SurfTimerZones_setMapEnabled", Native_SurfTimerZones_setMapEnabled);
	CreateNative("SurfTimerZones_reloadMap", Native_SurfTimerZones_reloadMap);
	
	RegPluginLibrary("surftimerzones");
	return APLRes_Success;
}

public OnPluginStart()
{
	// set names to string
	g_zoneTypeName[0] = "Somewhere";
	g_zoneTypeName[1] = "Start";
	g_zoneTypeName[2] = "Checkpoint";
	g_zoneTypeName[3] = "End";
	g_zoneTypeName[4] = "Bonus start";
	g_zoneTypeName[5] = "Bonus-CP";
	g_zoneTypeName[6] = "Bonus end";
	g_zoneTypeName[7] = "Glitch";
	
	// load map informations form sql
	if (g_hSQL == INVALID_HANDLE) {
		ConnectSQL();
	}

	PrintToServer("[SurfTimer-ZoneEditor] %s loaded...", PLUGIN_URL);

	g_hCvarZoneStartColor = CreateConVar("surftimer_startcolor", "0 255 0 255", "The color of the start map zone.");
	g_hCvarZoneEndColor = CreateConVar("surftimer_endcolor", "0 0 255 255", "The color of the end map zone.");
	g_hCvarDrawMapZones = CreateConVar("surftimer_drawzones", "0", "If enabled map zones will be drawn.");

	HookConVarChange(g_hCvarDrawMapZones, Action_OnSettingsChange);

	HookEntityOutput("trigger_multiple", "OnStartTouch", StartTouchTrigger); 
	HookEntityOutput("trigger_multiple", "OnEndTouch", EndTouchTrigger);

	// Add admin menu
	new Handle:topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE)) {
		OnAdminMenuReady(topmenu);
	}
}

/*
* Trigger handling
*/

public StartTouchTrigger(const String:name[], caller, activator, Float:delay) 
{   
	for (new i = 0; i < MAXPLAYERS; i++) {
		new index = EntRefToEntIndex(g_mapZones[i][EntityRef]);	
		if (index == INVALID_ENT_REFERENCE) {
			continue;
		} else if (index == 0) {
			continue;
		}

		if (index == caller) {
			DidEnterZone(activator, g_mapZones[i][Type], g_mapZones[i][OrderId], g_mapZones[i][Id]);
			break;
		}
	}
} 

public EndTouchTrigger(const String:name[], caller, activator, Float:delay) 
{     
    for (new i = 0; i < MAXPLAYERS; i++) {
		new index = EntRefToEntIndex(g_mapZones[i][EntityRef]);	
		if (index == INVALID_ENT_REFERENCE) {
			continue;
		} else if (index == 0) {
			continue;
		}

		if (index == caller) {
			DidLeftZone(activator, g_mapZones[i][Type], g_mapZones[i][OrderId], g_mapZones[i][Id]);
			break;
		}
	}
}  

/**
* Forwards
*/

public OnMapStart()
{
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
	StringToLower(g_sCurrentMap);

	// load map informations form sql
	if (g_hSQL == INVALID_HANDLE) {
		ConnectSQL();
	}
	
	g_iLaserMaterial = PrecacheModel("materials/sprites/laser.vmt", true);
	g_iHaloMaterial = PrecacheModel("materials/sprites/halo01.vmt", true);
	g_iGlowSprite = PrecacheModel("sprites/blueglow2.vmt", true);
	g_iWoodCrate = PrecacheModel("models/props_junk/wood_crate001a.mdl", true);
	
	g_map[Id] = 0;
	g_map[Difficulty] = 0;
	g_map[Enabled] = false;

	LoadMap();
	if (g_ZoneDeleteHandle != INVALID_HANDLE) {
		CloseHandle(g_ZoneDeleteHandle);
	}
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "adminmenu")) {
		hTopMenu = INVALID_HANDLE;
	}
}

public OnClientPostAdminCheck(client)
{
	RestartMapZoneEditor(client);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (g_mapZoneEditors[client][Step] == 0) {
		return Plugin_Continue;
	}

	new Float:vOrigin[3];
	if (g_mapZoneEditors[client][Step] < 3 && buttons & IN_ATTACK2) {
		if (g_mapZoneEditors[client][Step] == 1) {
			GetClientAbsOrigin(client, vOrigin);
			g_mapZoneEditors[client][PointOne] = vOrigin;
			AdminMenu_DisplayPleaseWaitMenu(client);
			CreateTimer(1.0, ChangeStep, GetClientSerial(client));
			return Plugin_Handled;
		} else if (g_mapZoneEditors[client][Step] == 2) {
			GetClientAbsOrigin(client, vOrigin);
			g_mapZoneEditors[client][PointTwo] = vOrigin;
			g_mapZoneEditors[client][Step] = 3;
			AdminMenu_DisplaySelectZoneTypeMenu(client);
			return Plugin_Handled;
		}		
	} 

	if (g_mapZoneEditors[client][Step] == 3) {
		if (buttons & IN_USE) {
			if (! g_zoneEditCallInProgress) {
				CreateTimer(0.2, SwitchAxisEditMode);
				g_zoneEditCallInProgress = true;
			}
			return Plugin_Handled;
		}
		
		new Float:offset = 1.0;
		if (g_zoneEditPerAxis) {
			if ((buttons & IN_MOVELEFT) && (buttons & IN_ATTACK)) { // Left
				g_mapZoneEditors[client][PointOne][0] = g_mapZoneEditors[client][PointOne][0] + offset;
				return Plugin_Handled;
			} else if ((buttons & IN_MOVERIGHT) && (buttons & IN_ATTACK)) { // Right
				g_mapZoneEditors[client][PointOne][0] = g_mapZoneEditors[client][PointOne][0] - offset;
				return Plugin_Handled;
			} else if ((buttons & IN_FORWARD) && (buttons & IN_ATTACK)) { // Forward
				g_mapZoneEditors[client][PointOne][1] = g_mapZoneEditors[client][PointOne][1] + offset;
				return Plugin_Handled;
			} else if ((buttons & IN_BACK) && (buttons & IN_ATTACK)) { // Back
				g_mapZoneEditors[client][PointOne][1] = g_mapZoneEditors[client][PointOne][1] - offset;
				return Plugin_Handled;
			} else if ((buttons & IN_JUMP) && (buttons & IN_ATTACK)) { // Top
				g_mapZoneEditors[client][PointOne][2] = g_mapZoneEditors[client][PointOne][2] + offset;
				return Plugin_Handled;
			} else if ((buttons & IN_DUCK) && (buttons & IN_ATTACK)) { // Bottom
				g_mapZoneEditors[client][PointOne][2] = g_mapZoneEditors[client][PointOne][2] - offset;
				return Plugin_Handled;
			}

			if ((buttons & IN_MOVELEFT) && (buttons & IN_ATTACK2)) { // Left
				g_mapZoneEditors[client][PointTwo][0] = g_mapZoneEditors[client][PointTwo][0] + offset;
				return Plugin_Handled;
			} else if ((buttons & IN_MOVERIGHT) && (buttons & IN_ATTACK2)) { // Right
				g_mapZoneEditors[client][PointTwo][0] = g_mapZoneEditors[client][PointTwo][0] - offset;
				return Plugin_Handled;
			} else if ((buttons & IN_FORWARD) && (buttons & IN_ATTACK2)) { // Forward
				g_mapZoneEditors[client][PointTwo][1] = g_mapZoneEditors[client][PointTwo][1] + offset;
				return Plugin_Handled;
			} else if ((buttons & IN_BACK) && (buttons & IN_ATTACK2)) { // Back
				g_mapZoneEditors[client][PointTwo][1] = g_mapZoneEditors[client][PointTwo][1] - offset;
				return Plugin_Handled;
			} else if ((buttons & IN_JUMP) && (buttons & IN_ATTACK2)) { // Top
				g_mapZoneEditors[client][PointTwo][2] = g_mapZoneEditors[client][PointTwo][2] + offset;
				return Plugin_Handled;
			} else if ((buttons & IN_DUCK) && (buttons & IN_ATTACK2)) { // Bottom
				g_mapZoneEditors[client][PointTwo][2] = g_mapZoneEditors[client][PointTwo][2] - offset;
				return Plugin_Handled;
			}
		} else {
			// extend
			if ((buttons & IN_MOVELEFT) && (buttons & IN_ATTACK)) { // Left
				g_mapZoneEditors[client][PointOne][0] = g_mapZoneEditors[client][PointOne][0] + offset;
				g_mapZoneEditors[client][PointTwo][0] = g_mapZoneEditors[client][PointTwo][0] - offset;
				return Plugin_Handled;
			} else if ((buttons & IN_MOVERIGHT) && (buttons & IN_ATTACK)) { // Right
				g_mapZoneEditors[client][PointOne][0] = g_mapZoneEditors[client][PointOne][0] - offset;
				g_mapZoneEditors[client][PointTwo][0] = g_mapZoneEditors[client][PointTwo][0] + offset;
				return Plugin_Handled;
			} else if ((buttons & IN_FORWARD) && (buttons & IN_ATTACK)) { // Forward
				g_mapZoneEditors[client][PointOne][1] = g_mapZoneEditors[client][PointOne][1] + offset;
				g_mapZoneEditors[client][PointTwo][1] = g_mapZoneEditors[client][PointTwo][1] - offset;
				return Plugin_Handled;
			} else if ((buttons & IN_BACK) && (buttons & IN_ATTACK)) { // Back
				g_mapZoneEditors[client][PointOne][1] = g_mapZoneEditors[client][PointOne][1] - offset;
				g_mapZoneEditors[client][PointTwo][1] = g_mapZoneEditors[client][PointTwo][1] + offset;
				return Plugin_Handled;
			} else if ((buttons & IN_JUMP) && (buttons & IN_ATTACK)) { // Top
				g_mapZoneEditors[client][PointOne][2] = g_mapZoneEditors[client][PointOne][2] + offset;
				g_mapZoneEditors[client][PointTwo][2] = g_mapZoneEditors[client][PointTwo][2] - offset;
				return Plugin_Handled;
			} else if ((buttons & IN_DUCK) && (buttons & IN_ATTACK)) { // Bottom
				g_mapZoneEditors[client][PointOne][2] = g_mapZoneEditors[client][PointOne][2] - offset;
				g_mapZoneEditors[client][PointTwo][2] = g_mapZoneEditors[client][PointTwo][2] + offset;
				return Plugin_Handled;
			}

			// move
			if ((buttons & IN_MOVELEFT) && (buttons & IN_ATTACK2)) { // Left
				g_mapZoneEditors[client][PointOne][0] = g_mapZoneEditors[client][PointOne][0] + offset;
				g_mapZoneEditors[client][PointTwo][0] = g_mapZoneEditors[client][PointTwo][0] + offset;
				return Plugin_Handled;
			} else if ((buttons & IN_MOVERIGHT) && (buttons & IN_ATTACK2)) { // Right
				g_mapZoneEditors[client][PointOne][0] = g_mapZoneEditors[client][PointOne][0] - offset;
				g_mapZoneEditors[client][PointTwo][0] = g_mapZoneEditors[client][PointTwo][0] - offset;
				return Plugin_Handled;
			} else if ((buttons & IN_FORWARD) && (buttons & IN_ATTACK2)) { // Forward
				g_mapZoneEditors[client][PointOne][1] = g_mapZoneEditors[client][PointOne][1] + offset;
				g_mapZoneEditors[client][PointTwo][1] = g_mapZoneEditors[client][PointTwo][1] + offset;
				return Plugin_Handled;
			} else if ((buttons & IN_BACK) && (buttons & IN_ATTACK2)) { // Back
				g_mapZoneEditors[client][PointOne][1] = g_mapZoneEditors[client][PointOne][1] - offset;
				g_mapZoneEditors[client][PointTwo][1] = g_mapZoneEditors[client][PointTwo][1] - offset;
				return Plugin_Handled;
			} else if ((buttons & IN_JUMP) && (buttons & IN_ATTACK2)) { // Top
				g_mapZoneEditors[client][PointOne][2] = g_mapZoneEditors[client][PointOne][2] + offset;
				g_mapZoneEditors[client][PointTwo][2] = g_mapZoneEditors[client][PointTwo][2] + offset;
				return Plugin_Handled;
			} else if ((buttons & IN_DUCK) && (buttons & IN_ATTACK2)) { // Bottom
				g_mapZoneEditors[client][PointOne][2] = g_mapZoneEditors[client][PointOne][2] - offset;
				g_mapZoneEditors[client][PointTwo][2] = g_mapZoneEditors[client][PointTwo][2] - offset;
				return Plugin_Handled;
			}
		}
		
	}

	return Plugin_Continue;
}

/**
* Actions
*/

public Action_OnSettingsChange(Handle:cvar, const String:oldvalue[], const String:newvalue[])
{
	if  (cvar == g_hCvarDrawMapZones) {
		g_bDrawMapZones = bool:StringToInt(newvalue);
		
		if (g_bDrawMapZones) {
			CreateTimer(2.0, DrawZones, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
	}
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
	
	oMapZoneMenu = FindTopMenuCategory(topmenu, "Zones Management");
	if (oMapZoneMenu == INVALID_TOPMENUOBJECT) {
		oMapZoneMenu = AddToTopMenu(hTopMenu,
		"Zones Management",
		TopMenuObject_Category,
		AdminMenu_CategoryHandler,
		INVALID_TOPMENUOBJECT);
	}

	AddToTopMenu(hTopMenu, 
		"timer_mapzones_add",
		TopMenuObject_Item,
		AdminMenu_AddMapZone,
		oMapZoneMenu,
		"timer_mapzones_add",
		ADMFLAG_RCON
	);

	AddToTopMenu(hTopMenu, 
	"timer_mapzones_remove",
	TopMenuObject_Item,
	AdminMenu_RemoveMapZone,
	oMapZoneMenu,
	"timer_mapzones_remove",
	ADMFLAG_RCON);

	AddToTopMenu(hTopMenu, 
	"timer_mapzones_reload_all",
	TopMenuObject_Item,
	AdminMenu_ReloadAllMapZones,
	oMapZoneMenu,
	"timer_mapzones_reload_all",
	ADMFLAG_RCON);

	AddToTopMenu(hTopMenu, 
	"timer_mapzones_remove_all",
	TopMenuObject_Item,
	AdminMenu_RemoveAllMapZones,
	oMapZoneMenu,
	"timer_mapzones_remove_all",
	ADMFLAG_RCON);

}

public AdminMenu_CategoryHandler(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayTitle)  {
		FormatEx(buffer, maxlength, "[ST] Zone managment", param);
	} else if (action == TopMenuAction_DisplayOption) {
		FormatEx(buffer, maxlength, "[ST] Zone managment", param);
	}
}

public AdminMenu_AddMapZone(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption) {
		FormatEx(buffer, maxlength, "Add Map Zone", param);
	} else if (action == TopMenuAction_SelectOption) {
		RestartMapZoneEditor(param);
		g_mapZoneEditors[param][Step] = 1;
		AdminMenu_DisplaySelectPointMenu(param, 1);
	}
}

public AdminMenu_RemoveMapZone(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption) {
		FormatEx(buffer, maxlength, "Delete Map Zone", param);
	} else if (action == TopMenuAction_SelectOption) {
		AdminMenu_DisplaySelectDeleteZoneMenu(param);
	}
}

public AdminMenu_RemoveAllMapZones(Handle:topmenu,  TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)  {
		FormatEx(buffer, maxlength, "Delete All Map Zones", param);
	} else if (action == TopMenuAction_SelectOption) {
		DeleteAllMapZones(param);
	}
}

public AdminMenu_ReloadAllMapZones(Handle:topmenu,  TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)  {
		FormatEx(buffer, maxlength, "Reload zones", param);
	} else if (action == TopMenuAction_SelectOption) {
		LoadMap();
	}
}

public AdminMenu_DisplaySelectPointMenu(client, n)
{
	new Handle:panel = CreatePanel();

	decl String:sMessage[255];
	decl String:sFirst[32], String:sSecond[32];
	FormatEx(sFirst, sizeof(sFirst), "First");
	FormatEx(sSecond, sizeof(sSecond), "Second");
	
	FormatEx(sMessage, sizeof(sMessage), "Type select panel", (n == 1) ? sFirst : sSecond);

	DrawPanelItem(panel, sMessage, ITEMDRAW_RAWLINE);

	FormatEx(sMessage, sizeof(sMessage), "Cancel");
	DrawPanelItem(panel, sMessage);

	SendPanelToClient(panel, client, AdminMenu_PointSelect, 540);
	CloseHandle(panel);
}

public AdminMenu_PointSelect(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)  {
		CloseHandle(menu);
	}  else if (action == MenuAction_Select)  {
		if (param2 == MenuCancel_Exit && hTopMenu != INVALID_HANDLE)  {
			DisplayTopMenu(hTopMenu, param1, TopMenuPosition_LastCategory);
		}
		RestartMapZoneEditor(param1);
	}
}

public AdminMenu_DisplayPleaseWaitMenu(client)
{
	new Handle:panel = CreatePanel();
	
	decl String:sWait[64];
	FormatEx(sWait, sizeof(sWait), "Please wait");
	DrawPanelItem(panel, sWait, ITEMDRAW_RAWLINE);

	SendPanelToClient(panel, client, AdminMenu_PointSelect, 540);
	CloseHandle(panel);
}
// 

AdminMenu_BuildDeleteZoneMenu()
{
	new Handle:menu = CreateMenu(AdminMenu_DeleteZoneSelect);

	decl String:sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "select * from map_zones where map_id = %d ORDER BY map_zone_type, map_zone_checkpoint_order_id ASC", g_map[Id]);
	SQL_LockDatabase(g_hSQL);
	new Handle:query = SQL_Query(g_hSQL, sQuery);
	if (query == INVALID_HANDLE) {
		new String:uerror[255];
		SQL_GetError(g_hSQL, uerror, sizeof(uerror));
		PrintToServer("[SurfTimer] Failed to to load zones for map %s when building map zones delete menu (error: %s)", g_sCurrentMap, uerror); 
		if (g_ZoneDeleteHandle != INVALID_HANDLE) {
			CloseHandle(g_ZoneDeleteHandle);
		}
		AddMenuItem(menu, "Failed", "Error");
		SQL_UnlockDatabase(g_hSQL);
		return menu;
	}
	SQL_UnlockDatabase(g_hSQL);


	new rowCount = SQL_GetRowCount(query);
	if (! rowCount) {
		CPrintToChatAll("%s{lightgreen}No zones have been found for map %s", PLUGIN_PREFIX, g_map[MapName]);
		CloseHandle(query);
		AddMenuItem(menu, "Failed", "Error");
		return menu;
	}
	
	while (SQL_FetchRow(query)) {
		decl String:typeString[64];
		Format(typeString, sizeof(typeString), "%d", SQL_FetchInt(query, 0));

		decl String:titleString[64];
		Format(titleString, sizeof(titleString), "%s", g_zoneTypeName[SQL_FetchInt(query, 2)]);

		new ZoneType:zoneType = SQL_FetchInt(query, 2);
		if (Checkpoint == zoneType || Glitch == zoneType) {
			new orderId = SQL_FetchInt(query, 3);
			Format(titleString, sizeof(titleString), "%s (%d)", titleString, orderId);
		}
		
		AddMenuItem(menu, typeString, titleString);
	}

	
	SetMenuTitle(menu, "Select zone to delete:");

	CloseHandle(query);
	return menu;
}

public AdminMenu_DeleteZoneSelect(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select) {
		new String:info[64];
 
		/* Get item info */
		GetMenuItem(menu, param2, info, sizeof(info));
 
		/* Tell the client */
		new zoneId = StringToInt(info);
		DeleteMapZone(param1, zoneId);
	}
}

public AdminMenu_DisplaySelectDeleteZoneMenu(client)
{
	// new Handle:menu = CreateMenu(AdminMenu_DeleteZoneSelect);
	if (g_ZoneDeleteHandle != INVALID_HANDLE) {
		CloseHandle(g_ZoneDeleteHandle);
	}

	g_ZoneDeleteHandle = AdminMenu_BuildDeleteZoneMenu();

	if (g_ZoneDeleteHandle == INVALID_HANDLE) {
		CPrintToChatAll("%s{red}Can't create zone delete menu!", PLUGIN_PREFIX);
		return Plugin_Handled;
	}	
 
	DisplayMenu(g_ZoneDeleteHandle, client, MENU_TIME_FOREVER);
 
	return Plugin_Handled;
}

public AdminMenu_DisplaySelectZoneTypeMenu(client)
{
	new Handle:menu = CreateMenu(AdminMenu_ZoneTypeSelect);
	SetMenuTitle(menu, "Select zone type", client);
	
	decl String:sText[256];
	
	// dynamic add types of zones

	FormatEx(sText, sizeof(sText), "Start (Blue)", client);
	AddMenuItem(menu, "0", sText);

	FormatEx(sText, sizeof(sText), "Checkpoint / Stage (Red)", client);
	AddMenuItem(menu, "1", sText);

	FormatEx(sText, sizeof(sText), "End (Green)", client);
	AddMenuItem(menu, "2", sText);

	FormatEx(sText, sizeof(sText), "Bonus start (Gold)", client);
	AddMenuItem(menu, "3", sText);

	FormatEx(sText, sizeof(sText), "Bonus Checkpoint / Stage (Cyan)", client);
	AddMenuItem(menu, "4", sText);

	FormatEx(sText, sizeof(sText), "Bonus end (Magenta)", client);
	AddMenuItem(menu, "5", sText);
	
	FormatEx(sText, sizeof(sText), "Glitch (teleport to startzone)", client);
	AddMenuItem(menu, "6", sText);
		
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 360);
}

public AdminMenu_ZoneTypeSelect(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End) {
		CloseHandle(menu);
		RestartMapZoneEditor(param1);
	} else if (action == MenuAction_Cancel) {
		if (param2 == MenuCancel_Exit && hTopMenu != INVALID_HANDLE) {
			DisplayTopMenu(hTopMenu, param1, TopMenuPosition_LastCategory);
			RestartMapZoneEditor(param1);
		}
	} else if (action == MenuAction_Select)  {
		new ZoneType:type = param2+1;

		if (type == Bonus_checkpoint) {
			decl String:sQuery[512];
			FormatEx(sQuery, sizeof(sQuery), "UPDATE maps SET map_bonus_type = 1 WHERE map_id = %d", g_map[Id]);
			SQL_LockDatabase(g_hSQL);
			SQL_FastQuery(g_hSQL, sQuery);
			SQL_UnlockDatabase(g_hSQL);
		} else if (type == Checkpoint) {
			decl String:sQuery[512];
			FormatEx(sQuery, sizeof(sQuery), "UPDATE maps SET map_type = 1 WHERE map_id = %d", g_map[Id]);
			SQL_LockDatabase(g_hSQL);
			SQL_FastQuery(g_hSQL, sQuery);
			SQL_UnlockDatabase(g_hSQL);
		}
		
		new Float:point1[3];
		Array_Copy(g_mapZoneEditors[param1][PointOne], point1, 3);

		new Float:point2[3];
		Array_Copy(g_mapZoneEditors[param1][PointTwo], point2, 3);

		AddMapZone(type, point1, point2);
		RestartMapZoneEditor(param1);
		LoadMapZones();
	}
}

/**
* Map Zones
*/

AddMapZone(ZoneType:type, Float:point1[3], Float:point2[3])
{
	decl String:sQuery[1024];
	new orderId = 0;
	if (type != Checkpoint && type != Bonus_checkpoint && type != Glitch) {
		decl String:sDeleteQuery[128];
		FormatEx(sDeleteQuery, sizeof(sDeleteQuery), "DELETE FROM map_zones WHERE map_id = %d AND map_zone_type = %d;", g_map[Id], type);
		SQL_TQuery(g_hSQL, AddMapZoneCallback, sDeleteQuery, _, DBPrio_High);	
	} else {
		// grab highest number of checkpoint
		FormatEx(sQuery, sizeof(sQuery), "select IFNULL(MAX(map_zone_checkpoint_order_id), 0) from map_zones where map_id = %d AND map_zone_type = %d", g_map[Id], type);
		SQL_LockDatabase(g_hSQL);
		new Handle:query = SQL_Query(g_hSQL, sQuery);
		
		if (query == INVALID_HANDLE) {
			new String:uerror[255];
			SQL_GetError(g_hSQL, uerror, sizeof(uerror));
			PrintToServer("[SurfTimer] Failed to get highest number of checkpoint (error: %s)", g_sCurrentMap, uerror); 
			SQL_UnlockDatabase(g_hSQL);
			LoadMapZones();
			return;
		}
		SQL_UnlockDatabase(g_hSQL);

		SQL_FetchRow(query);
		orderId = SQL_FetchInt(query, 0);
		orderId++;

	}

	FormatEx(sQuery, sizeof(sQuery), "INSERT INTO map_zones (map_id, map_zone_type, map_zone_checkpoint_order_id, map_zone_point1_x, map_zone_point1_y, map_zone_point1_z, map_zone_point2_x, map_zone_point2_y, map_zone_point2_z) VALUES (%d, %d, %d, %f, %f, %f, %f, %f, %f);", g_map[Id], type, orderId, point1[0], point1[1], point1[2], point2[0], point2[1], point2[2]);
	// PrintToServer("SURF SQL %d\n%s", type, sQuery);
	SQL_TQuery(g_hSQL, AddMapZoneCallback, sQuery, _, DBPrio_Normal);	
}

public AddMapZoneCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE) {
		PrintToServer("SQL Error on AddMapZone: %s", error);
		return;
	}
	
	LoadMapZones();
}

LoadMapZones()
{
	if (g_hSQL == INVALID_HANDLE) {
		ConnectSQL();
	} else {	 
		decl String:sQuery[384];
		FormatEx(sQuery, sizeof(sQuery), "SELECT map_zone_id, map_id, map_zone_type, map_zone_checkpoint_order_id, map_zone_point1_x, map_zone_point1_y, map_zone_point1_z, map_zone_point2_x, map_zone_point2_y, map_zone_point2_z FROM map_zones WHERE map_id = %d ORDER BY map_zone_type, map_zone_checkpoint_order_id ASC", g_map[Id]);
		SQL_TQuery(g_hSQL, LoadMapZonesCallback, sQuery, _, DBPrio_High);
	}
}

RestartMapZoneEditor(client)
{
	g_mapZoneEditors[client][Step] = 0;
	for (new i = 0; i < 3; i++) {
		g_mapZoneEditors[client][PointOne][i] = 0.0;
	}

	for (new i = 0; i < 3; i++) {
		g_mapZoneEditors[client][PointTwo][i] = 0.0;	
	}
}

public Action:ChangeStep(Handle:timer, any:serial)
{
	new client = GetClientFromSerial(serial);
	
	g_mapZoneEditors[client][Step] = 2;
	CreateTimer(0.1, DrawAdminBox, GetClientSerial(client), TIMER_REPEAT);

	AdminMenu_DisplaySelectPointMenu(client, 2);
}

public Action:SwitchAxisEditMode(Handle:timer)
{
	g_zoneEditCallInProgress = false;
	g_zoneEditPerAxis = ! g_zoneEditPerAxis;
	PrintToChatAll("Edit zone on each axis seperated is %s", ((g_zoneEditPerAxis == true) ? "on" : "off"));
}

/**
* Map
*/

AddMap()
{
	decl String:sQuery[1024];
	
	FormatEx(sQuery, sizeof(sQuery), "INSERT INTO maps (map_name, map_difficulty, map_last_played, map_times_played, map_total_completitions, map_creator_id, map_enabled) VALUES ('%s', 0, %d, 1, 0, 1, 0);", g_sCurrentMap, GetTime());
	PrintToServer("[SurfTimer] Adding map %s to database", g_sCurrentMap);
	SQL_TQuery(g_hSQL, AddMapCallback, sQuery, _, DBPrio_High);	
}

public AddMapCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE) {
		PrintToServer("[SurfTimer] SQL Error on AddMap: %s", error);
		return;
	}
	
	LoadMap();
}

LoadMap()
{
	decl String:sQuery[384];
	FormatEx(sQuery, sizeof(sQuery), "select * from maps where map_name = '%s' LIMIT 1", g_sCurrentMap);
	SQL_TQuery(g_hSQL, LoadMapCallback, sQuery, _, DBPrio_High);
}

public LoadMapCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE) {
		PrintToServer("SQL Error on LoadMap: %s", error);
		return;
	}

	if (! SQL_GetRowCount(hndl)) {
		PrintToServer("[SurfTimer] No informations found for map %s", error);
		PrintToServer("[SurfTimer] Trying to create them...");
		AddMap();
		return;
	}

	SQL_FetchRow(hndl);
	g_map[Id] = SQL_FetchInt(hndl, 0);
	SQL_FetchString(hndl, 1, g_map[MapName], MAPNAME_MAX);
	g_map[MapType] = SQL_FetchInt(hndl, 2);
	g_map[Difficulty] = SQL_FetchInt(hndl, 3);
	g_map[Enabled] = SQL_FetchInt(hndl, 4);

	PrintToServer("[SurfTimer] Map: %s, Map_Id: %d, Difficulty: %d, Type: %s", g_map[MapName], g_map[Id], g_map[Difficulty], g_map[MapType]);

	if (g_map[Id]) {
		LoadMapZones();
	}
}

DeleteAllMapZones(client)
{
	g_map[Enabled] = false;
	for (new i = 1; i < MAXPLAYERS; i++) {
		SurfTimer_clientStopTimer(i);	
	}
	
	decl String:sQuery[96];
	FormatEx(sQuery, sizeof(sQuery), "DELETE FROM map_zones WHERE map_id = %d", g_map[Id]);
	SQL_TQuery(g_hSQL, DeleteMapZoneCallback, sQuery, client, DBPrio_High);
}


DeleteMapZone(client, zoneId)
{
	decl String:sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "select * from map_zones where map_zone_id = %d", zoneId);
	SQL_LockDatabase(g_hSQL);
	new Handle:query = SQL_Query(g_hSQL, sQuery);
	if (query == INVALID_HANDLE) {
		new String:uerror[255];
		SQL_GetError(g_hSQL, uerror, sizeof(uerror));
		CPrintToChatAll("%s{red}Failed select zone id. Please retry! (error: %s)", PLUGIN_PREFIX, uerror); 
		SQL_UnlockDatabase(g_hSQL);
		LoadMapZones();
		return;
	}
	SQL_UnlockDatabase(g_hSQL);

	SQL_FetchRow(query);
	new ZoneType:zoneType = SQL_FetchInt(query, 2);
	new orderId = SQL_FetchInt(query, 3);
	if (zoneType == Checkpoint || zoneType == Bonus_checkpoint || zoneType == Glitch) {
		FormatEx(sQuery, sizeof(sQuery), "UPDATE map_zones SET map_zone_checkpoint_order_id = (map_zone_checkpoint_order_id - 1) WHERE map_id = %d AND map_zone_type = %d AND map_zone_checkpoint_order_id > %d", g_map[Id], zoneType, orderId);
		SQL_LockDatabase(g_hSQL);
		if (! SQL_FastQuery(g_hSQL, sQuery)) {
			new String:error[1024];
			SQL_GetError(g_hSQL, error, sizeof(error));
			PrintToServer("[SurfTimer] SQL Error on updating checkpoint order ids (Error: %s)", error);
			SQL_UnlockDatabase(g_hSQL);
			return;
		}
		SQL_UnlockDatabase(g_hSQL);

		// reset map type
		FormatEx(sQuery, sizeof(sQuery), "select IFNULL(count(map_zone_checkpoint_order_id), 0) from map_zones where map_id = %d and map_zone_type = %d", g_map[Id], (zoneType == Checkpoint) ? 2 : 5);
		SQL_LockDatabase(g_hSQL);
		query = SQL_Query(g_hSQL, sQuery);
		if (query == INVALID_HANDLE) {
			new String:uerror[255];
			SQL_GetError(g_hSQL, uerror, sizeof(uerror));
			CPrintToChatAll("%s{red}Failed update staging entry. Please retry! (error: %s)", PLUGIN_PREFIX, uerror); 
			SQL_UnlockDatabase(g_hSQL);
			LoadMapZones();
			return;
		}
		SQL_UnlockDatabase(g_hSQL);

		SQL_FetchRow(query);
		new checkpointCount = SQL_FetchInt(query, 0);
		if (! checkpointCount) {
			FormatEx(sQuery, sizeof(sQuery), "UPDATE maps SET %s = 0 WHERE map_id = %d", (zoneType == Checkpoint) ? "map_type" : "map_bonus_type", g_map[Id]);
			SQL_LockDatabase(g_hSQL);
			if (! SQL_FastQuery(g_hSQL, sQuery)) {
				new String:error[255];
				SQL_GetError(g_hSQL, error, sizeof(error));
				CPrintToChatAll("%s{red}SQL Error on updating map type. (Error: %s)", PLUGIN_PREFIX, error);
			}
			SQL_UnlockDatabase(g_hSQL);
		}
		CloseHandle(query);	
	}

	FormatEx(sQuery, sizeof(sQuery), "DELETE FROM map_zones WHERE map_zone_id = %d", zoneId);
	if (! SQL_FastQuery(g_hSQL, sQuery)) {
		new String:error[255];
		SQL_GetError(g_hSQL, error, sizeof(error));
		CPrintToChatAll("%s{red}SQL Error on updating checkpoint order ids (Error: %s)", PLUGIN_PREFIX, error);
	}
	LoadMapZones();
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
		LoadMap();	
		g_iSQLReconnectCounter = 0;
	}
}

public CreateSQLTableCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (owner == INVALID_HANDLE) {
		PrintToServer(error);
		g_iSQLReconnectCounter++;
		ConnectSQL();
		return;
	}
	
	if (hndl == INVALID_HANDLE) {
		PrintToServer("SQL Error on CreateSQLTable: %s", error);
		return;
	}
}

public LoadMapZonesCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE) {
		PrintToServer("[SurfTimer]SQL Error on LoadMapZones: %s.", error);
		return Plugin_Handled;
	}
	
	// reset old zones
	for (new i = 0; i < MAXPLAYERS; i++) {
		g_mapZones[i][Id] = 0;
		g_mapZones[i][MapId] = 0;
		g_mapZones[i][Type] = Somewhere;
		g_mapZones[i][OrderId] = 0;

		// Point 1
		g_mapZones[i][PointOne] = {0.0, 0.0, 0.0};
		
		// Point 2
		g_mapZones[i][PointTwo] = {0.0, 0.0, 0.0};
	}

	
	for (new i = 0; i < MAXPLAYERS; i++) {
		new index = EntRefToEntIndex(g_mapZones[i][EntityRef]);
		if (index == INVALID_ENT_REFERENCE) {
			continue;
		} else if (index == 0) {
			continue;
		}

		if (IsValidEntity(index)) {
			new String:classname[64];
			GetEdictClassname(index, classname, sizeof(classname));
			if (StrEqual(classname, "trigger_multiple", false)) {
				AcceptEntityInput(index, "Stop");
				AcceptEntityInput(index, "Kill");
			} else {
				PrintToChatAll("Delete Zone: not removing entity - not a particle '%s'", classname);
			}
		}
	}

	new rowCount = SQL_GetRowCount(hndl);
	if (! rowCount) {
		PrintToServer("[SurfTimer] No zones have been found for map %s", g_map[MapName]);
		CPrintToChatAll("%s{lightgreen}No zones have been found for map %s", PLUGIN_PREFIX, g_map[MapName]);
		SurfTimerMap_reloadInfo();
		return;
	} else {
		PrintToServer("[SurfTimer] %d zones have been found for map %s", rowCount, g_map[MapName]);
	}
	
	g_mapZonesCount = 0;

	while (SQL_FetchRow(hndl)) {
		//  Zone configuration
		g_mapZones[g_mapZonesCount][Id] = SQL_FetchInt(hndl, 0);
		g_mapZones[g_mapZonesCount][MapId] = SQL_FetchInt(hndl, 1);
		g_mapZones[g_mapZonesCount][Type] = SQL_FetchInt(hndl, 2);
		g_mapZones[g_mapZonesCount][OrderId] = SQL_FetchInt(hndl, 3);

		// Point 1
		g_mapZones[g_mapZonesCount][PointOne][0] = SQL_FetchFloat(hndl, 4);
		g_mapZones[g_mapZonesCount][PointOne][1] = SQL_FetchFloat(hndl, 5);
		g_mapZones[g_mapZonesCount][PointOne][2] = SQL_FetchFloat(hndl, 6);
		
		// Point 2
		g_mapZones[g_mapZonesCount][PointTwo][0] = SQL_FetchFloat(hndl, 7);
		g_mapZones[g_mapZonesCount][PointTwo][1] = SQL_FetchFloat(hndl, 8);
		g_mapZones[g_mapZonesCount][PointTwo][2] = SQL_FetchFloat(hndl, 9);

		new Float:Origin[3], Float:VecMins[3], Float:VecMaxs[3];

		CenterOfTwoVectors(Origin, g_mapZones[g_mapZonesCount][PointOne], g_mapZones[g_mapZonesCount][PointTwo]);
		TransformCoordinatesToLocalSpace(VecMins, Origin, g_mapZones[g_mapZonesCount][PointOne]);
		TransformCoordinatesToLocalSpace(VecMaxs, Origin, g_mapZones[g_mapZonesCount][PointTwo]);
		MinMaxVector(VecMins, VecMaxs);

		// Create entities here!
		CreateZoneEntity(Origin, VecMins, VecMaxs, g_mapZonesCount);
		
		// Debug
		g_mapZonesCount++;
	}
	
	if (g_bDrawMapZones) {
		CreateTimer(2.0, DrawZones, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
	CPrintToChatAll("%s{lightgreen}Map zones loaded...", PLUGIN_PREFIX);
	SurfTimerMap_reloadInfo();
}

public DeleteMapZoneCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE) {
		CPrintToChatAll("%s{red}SQL Error on DeleteMapZone: %s", PLUGIN_PREFIX, error);
		return;
	}

	LoadMapZones();
	
	if (IsClientInGame(data)) {
		CPrintToChatAll("%s{lightgreen}Map zone deleted", PLUGIN_PREFIX);
	}
}

public SetMapEnabled(bool:enabled)
{
	decl string:sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "UPDATE maps SET map_enabled = %d WHERE map_name = '%s'", enabled, g_sCurrentMap);
	SQL_LockDatabase(g_hSQL);
	if (! SQL_FastQuery(g_hSQL, sQuery)) {
		new String:uerror[255];
		SQL_GetError(g_hSQL, uerror, sizeof(uerror));
		PrintToServer("[SurfTimer] Failed to update map status for map %s (%d) (error: %s)", g_sCurrentMap, uerror); 
		CPrintToChatAll("%s{red}Failed to update map status for map %s (%d) (error: %s)", PLUGIN_PREFIX, g_sCurrentMap, uerror); 
		SQL_UnlockDatabase(g_hSQL);
		return;
	}
	SQL_UnlockDatabase(g_hSQL);
	LoadMap();
}

/**
* Player events
*/

TeleportPlayer(client, bool:toStart = false)
{
	new Float:Origin[3];
	new bool:bEnabled;
	new Float:time;
	
	new fpsmax, ZoneType:zoneType, zoneId;
	
	if (toStart) {
		TeleportEntity(client, {9999.0, 9999.0, 9999.0}, NULL_VECTOR, NULL_VECTOR);
		CreateTimer(0.11, DelayedTeleportToStart, GetClientSerial(client));
		return;
	}

	SurfTimer_clientTimer(client, bEnabled, Float:time, fpsmax, zoneType, zoneId);
	CenterOfTwoVectors(Origin, g_mapZones[zoneId][PointOne], g_mapZones[zoneId][PointTwo]);
	TeleportEntity(client, Origin, NULL_VECTOR, {0.0, 0.0, 0.0});
	DidEnterZone(client, g_mapZones[zoneId][Type], g_mapZones[zoneId][OrderId], g_mapZones[zoneId][Id]);
}

public Action:DelayedTeleportToStart(Handle:timer, any:serial)
{
	new client = GetClientFromSerial(serial);

	new Float:Origin[3];
	new bool:bEnabled;
	new Float:time;
	new fpsmax, ZoneType:zoneType, zoneId;

	SurfTimer_clientEnterZone(client, Start, 0);
	SurfTimer_clientTimer(client, bEnabled, Float:time, fpsmax, zoneType, zoneId);
	CenterOfTwoVectors(Origin, g_mapZones[zoneId][PointOne], g_mapZones[zoneId][PointTwo]);
	TeleportEntity(client, Origin, NULL_VECTOR, {0.0, 0.0, 0.0});
}

TeleportPlayerToStage(client, stage, bool:practice=true)
{
	new zone;
	new bool:found = false;
	for (zone = 0; zone < g_mapZonesCount; zone++) {
		if (g_mapZones[zone][Type] == Checkpoint && g_mapZones[zone][OrderId] == (stage-1)) {
			found = true;
			break;
		}
	}


	if (found && (stage-1) > 0) {
		new Float:Origin[3];
		
		TeleportEntity(client, {9999.0, 9999.0, 9999.0}, NULL_VECTOR, {0.0, 0.0, 0.0});
		
		new Handle:data = CreateDataPack();
		WritePackCell(data, client);
		WritePackCell(data, zone);
		CreateTimer(0.11, DelayedTeleportToPractice, data);
		CPrintToChat(client, "%s{lightgreen}Teleported to stage {white}%d", PLUGIN_PREFIX, stage);
		SurfTimer_clientEnterZone(client, Start, 0);
		return;
	} else if ((stage-1) == 0) {
		TeleportPlayer(client, true);
		CPrintToChat(client, "%s{lightgreen}Teleported to {white}stage %d", PLUGIN_PREFIX, stage);
		SurfTimer_clientEnterZone(client, Start, 0);
		return;
	}
	CPrintToChat(client, "%s{red}Stage {white}%d {red}not found.", PLUGIN_PREFIX, stage);
}

public Action:DelayedTeleportToPractice(Handle:timer, any:data)
{
	
	ResetPack(data);
	
	new client = ReadPackCell(data);
	new zoneId = ReadPackCell(data);
	new Float:Origin[3];
	
	SurfTimer_clientStopTimer(client);

	CenterOfTwoVectors(Origin, g_mapZones[zoneId][PointOne], g_mapZones[zoneId][PointTwo]);
	TeleportEntity(client, Origin, NULL_VECTOR, {0.0, 0.0, 0.0});
	DidEnterZone(client, g_mapZones[zoneId][Type], g_mapZones[zoneId][OrderId], g_mapZones[zoneId][Id]);
	CreateTimer(0.11, DelayedTimerStop, GetClientSerial(client));
}

public Action:DelayedTimerStop(Handle:timer, any:serial)
{
	new client = GetClientFromSerial(serial);
	SurfTimer_clientStopTimer(client);
}

/**
* Box drawing and calculations
*/

public Action:DrawZones(Handle:timer)
{
	if (! g_bDrawMapZones) {
		return Plugin_Stop;
	}
	
	for (new zone = 0; zone < g_mapZonesCount; zone++) {
		// if (g_mapZones[zone][Type] == Start || g_mapZones[zone][Type] == End) {
		new Float:point1[3];
		Array_Copy(g_mapZones[zone][PointOne], point1, sizeof(point1));

		new Float:point2[3];
		Array_Copy(g_mapZones[zone][PointTwo], point2, sizeof(point2));

		if (g_mapZones[zone][Type] == Start) {
			Effect_DrawBeamBoxToAll(point1, point2, g_iLaserMaterial, g_iHaloMaterial, 0, 30, 2.0, 4.0, 4.0, 1, 1.0, {0, 0, 255, 255}, 0); // Blue
		} else if (g_mapZones[zone][Type] == End) {
			Effect_DrawBeamBoxToAll(point1, point2, g_iLaserMaterial, g_iHaloMaterial, 0, 30, 2.0, 4.0, 4.0, 1, 1.0, {50, 205, 50, 255}, 0); // Green
		} else if (g_mapZones[zone][Type] == Checkpoint) {
			Effect_DrawBeamBoxToAll(point1, point2, g_iLaserMaterial, g_iHaloMaterial, 0, 30, 2.0, 4.0, 4.0, 1, 1.0, {255, 0, 0, 255}, 0); // Red
		} else if (g_mapZones[zone][Type] == Bonus_start) {
			Effect_DrawBeamBoxToAll(point1, point2, g_iLaserMaterial, g_iHaloMaterial, 0, 30, 2.0, 4.0, 4.0, 1, 1.0, {255, 185, 15, 255}, 0); // Gold
		} else if (g_mapZones[zone][Type] == Bonus_end) {
			Effect_DrawBeamBoxToAll(point1, point2, g_iLaserMaterial, g_iHaloMaterial, 0, 30, 2.0, 4.0, 4.0, 1, 1.0, {255, 0, 255, 255}, 0); // Magenta
		} else if (g_mapZones[zone][Type] == Bonus_checkpoint) {
			Effect_DrawBeamBoxToAll(point1, point2, g_iLaserMaterial, g_iHaloMaterial, 0, 30, 2.0, 4.0, 4.0, 1, 1.0, {50, 100, 200, 255}, 0); // Cyan
		} else if (g_mapZones[zone][Type] == Glitch) {
			Effect_DrawBeamBoxToAll(point1, point2, g_iLaserMaterial, g_iHaloMaterial, 0, 30, 2.0, 4.0, 4.0, 1, 1.0, {200, 50, 200, 255}, 0); // Gltich
		}
		// }
	}

	return Plugin_Continue;
}

public Action:DrawAdminBox(Handle:timer, any:serial)
{
	new client = GetClientFromSerial(serial);
	
	if (g_mapZoneEditors[client][Step] == 0) {
		return Plugin_Stop;
	}
	
	new Float:a[3], Float:b[3];

	Array_Copy(g_mapZoneEditors[client][PointOne], b, 3);

	if (g_mapZoneEditors[client][Step] == 3) {
		Array_Copy(g_mapZoneEditors[client][PointTwo], a, 3);
	} else {
		GetClientAbsOrigin(client, a);
	}

	new color[4] = {255, 255, 255, 255};

	Effect_DrawBeamBoxToAll(a, b, g_iLaserMaterial, g_iHaloMaterial, 0, 30, 0.1, 2.0, 2.0, 1, 5.0, {255,255,255,255}, 0);
	return Plugin_Continue;
}

/**
* Entity handling
*/

public CreateZoneEntity(Float:Origin[3], Float:VecMins[3], Float:VecMaxs[3], arrayId)
{  
	new entity = CreateEntityByName("trigger_multiple");
	
	if(!IsValidEntity(entity)) {
		new String:error[256];
		Format(error, sizeof(error), "[SurfTimer-ZoneEditor] Could not load zone!, %d", entity);
		PrintToChatAll(error);
		return;
	}
	
	SetEntityModel(entity, "models/props_junk/wood_crate001a.mdl"); 
		
	new Handle:pac = CreateDataPack();
	WritePackCell(pac, entity);
	WritePackFloat(pac, Origin[0]);
	WritePackFloat(pac, Origin[1]);
	WritePackFloat(pac, Origin[2]);
	WritePackFloat(pac, VecMins[0]);
	WritePackFloat(pac, VecMins[1]);
	WritePackFloat(pac, VecMins[2]);
	WritePackFloat(pac, VecMaxs[0]);
	WritePackFloat(pac, VecMaxs[1]);
	WritePackFloat(pac, VecMaxs[2]);
	WritePackCell(pac, arrayId);
	SpawnTrigger(Handle:pac);	
}

public Action:SpawnTrigger(Handle:pac)
{
	new Float:Origin[3];
	new Float:VecMins[3];
	new Float:VecMaxs[3];
	new entity;
	new arrayId;
	
	/* Set to the beginning and unpack it */
	ResetPack(pac);
	entity = ReadPackCell(Handle:pac);
	Origin[0] = ReadPackFloat(pac);
	Origin[1] = ReadPackFloat(pac);
	Origin[2] = ReadPackFloat(pac);
	VecMins[0] = ReadPackFloat(pac);
	VecMins[1] = ReadPackFloat(pac);
	VecMins[2] = ReadPackFloat(pac);
	VecMaxs[0] = ReadPackFloat(pac);
	VecMaxs[1] = ReadPackFloat(pac);
	VecMaxs[2] = ReadPackFloat(pac);
	arrayId = ReadPackCell(pac);
	
	if(IsValidEntity(entity)) { 
			
		DispatchKeyValue(entity, "spawnflags", "257"); 
		DispatchKeyValue(entity, "StartDisabled", "0");
		DispatchKeyValue(entity, "OnTrigger", "!activator,IgnitePlayer,,0,-1");
		DispatchKeyValue(entity, "targetname", "AwesomeName");

		if(DispatchSpawn(entity)) {
			ActivateEntity(entity);

			SetEntPropVector(entity, Prop_Send, "m_vecMins", VecMins);
			SetEntPropVector(entity, Prop_Send, "m_vecMaxs", VecMaxs);
			
			SetEntProp(entity, Prop_Send, "m_nSolidType", 2);

			TeleportEntity(entity, Origin, NULL_VECTOR, NULL_VECTOR);
			
			
			AcceptEntityInput(entity, "SetParent");
			g_mapZones[arrayId][EntityRef] = EntIndexToEntRef(entity);
		} else  {
			PrintToChatAll("[SurfTimer-ZoneEditor] Not able to dispatchspawn for trigger %i in zone load", entity);
		}
	} else {
		PrintToChatAll("[SurfTimer-ZoneEditor] Trigger %i did not pass the validation check in SpawnTrigger", entity);
	}
}

/**
* Global forwarding
*/

DidEnterZone(client, ZoneType:zone, orderId, id)
{
	if (g_map[Enabled]) {
		if (zone == Glitch) {
			new Float:Origin[3];
			new bool:bEnabled;
			new Float:time;
			new fpsmax, ZoneType:zoneType, zoneId;
			SurfTimer_clientTimer(client, bEnabled, Float:time, fpsmax, zoneType, zoneId);
			SurfTimer_clientEnterZone(client, g_mapZones[zoneId][Type], g_mapZones[zoneId][OrderId], g_mapZones[zoneId][Id]);
			SurfTimerZones_teleportPlayer(client);
			return;
		}
		SurfTimer_clientEnterZone(client, zone, orderId, id);
	}
	return;
}

DidLeftZone(client, ZoneType:zone, orderId, id)
{
	if (g_map[Enabled]) {
		SurfTimer_clientLeftZone(client, zone, orderId, id);
	}
}

/**
* Natives
*/

public Native_SurfTimerZones_teleportPlayer(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if (numParams > 1) {
		TeleportPlayer(client, GetNativeCell(2));
		return;
	}
	TeleportPlayer(client);
}


public Native_SurfTimerZones_teleportPlayerToStage(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if (numParams == 2) {
		TeleportPlayerToStage(client, GetNativeCell(2));
		return;
	} else if (numParams == 3) {
		TeleportPlayerToStage(client, GetNativeCell(2), GetNativeCell(3));
		return;
	}
	CPrintToChat(client, "%s{lightgreen}Use !stage <stagenumber> or !s <stagenumber>", PLUGIN_PREFIX);
}

public Native_SurfTimerZones_isMapEnabled(Handle:plugin, numParams)
{
	return g_map[Enabled];
}

public Native_SurfTimerZones_reloadMap(Handle:plugin, numParams)
{
	LoadMap();
}

public Native_SurfTimerZones_setMapEnabled(Handle:plugin, numParams)
{
	new bool:enabled = GetNativeCell(1);
	SetMapEnabled(enabled);
}


