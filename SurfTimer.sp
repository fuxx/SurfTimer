#include <sourcemod>
#include <steamtools.inc>

#include <SurfTimer>

#undef REQUIRE_PLUGIN
#include <SurfTimerRank>


new String:g_sCurrentMap[MAPNAME_MAX];
new bool:g_IsMapLoaded;

enum SurfTimer 
{
	bool:isEnabled,
	bool:isStageEnabled,
	Float:startTime,
	Float:endTime,
	Float:stageStartTime,
	Float:stageEndTime,
	fpsMax,
	lastZoneId,
	ZoneType:lastZoneType
}

// this does not really work
new g_timers[MAXPLAYERS][SurfTimer];

// connect sound
new String:g_soundName[] = "surftimer/SurfTimer_connect1.mp3";

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("SurfTimer_clientTimer", Native_SurfTimerClientTimer);
	CreateNative("SurfTimer_clientEnterZone", Native_SurfTimer_clientEnterZone);
	CreateNative("SurfTimer_clientLeftZone", Native_SurfTimer_clientLeftZone);
	CreateNative("SurfTimer_FinishRound", Native_SurfTimer_FinishRound);
	CreateNative("SurfTimer_clientStopTimer", Native_SurfTimer_clientStopTimer);
	CreateNative("SurfTimer_killallTimer", Native_SurfTimer_killallTimer);

	
	RegPluginLibrary("surftimer");
	return APLRes_Success;
}

public Plugin:myinfo =
{
	name = "[SurfTimer]",
	author = "Fuxx",
	description = "A professional surf timer, made with love!",
	version = PLUGIN_VERSION,
	url = "http://www.stefanpopp.de"
};
 
public OnPluginStart()
{
	// Show some useless stuff
	PrintToServer("[SurfTimer] Version %s by %s / foz", PLUGIN_VERSION, PLUGIN_AUTHOR);
	PrintToServer("[SurfTimer] This is a experimental version");
	PrintToServer("[SurfTimer] Dont expect to much");
	PrintToServer("[SurfTimer] %s", PLUGIN_URL);
	PrintToServer("[SurfTimer] programmed fuxx");

	// Convars
	CreateConVar("surf_version", PLUGIN_VERSION, "[SurfTimer] version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	// Timed spam
	CreateTimer(PLUGIN_VERSION_ANNOUNCE, Timer_PrintVersionToChat, INVALID_HANDLE, TIMER_REPEAT);

	// Register plugins

	// Events
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
}

public OnClientPutInServer(client)
{
	// damage handling
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);

	g_timers[client][lastZoneId] = 0;
	g_timers[client][lastZoneType] = Somewhere;
}

Action:OnGetGameDescription(String:gameDesc[64])
{

}

public OnClientDisconnect(client)
{
	StopTimer(client);
}

public OnConfigsExecuted()
{
	
}

public OnClientPostAdminCheck(client)
{
	new String:authName[64];
	GetClientAuthString(client, authName, sizeof(authName));
}

/* Prevent player form dying buy anything */
public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon,
		Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	// small work around to set no damag for player
	SetEntProp(victim, Prop_Data, "m_takedamage", 0, 1);
	return Plugin_Continue;
}

/* Prevent end of round */
public Action:CS_OnTerminateRound(&Float:delay, &CSRoundEndReason:reason)
{
	return Plugin_Handled;
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	return Plugin_Handled;
}

/* Timed events */
public Action:Timer_PrintVersionToChat(Handle:Timer)
{
	CPrintToChatAll("%s{lightgreen}crafted by the unawesome ActionPingPongNinja clan", PLUGIN_PREFIX);
	CPrintToChatAll("%s{lightgreen}use {deepskyblue}!info {lightgreen}to get latest news and commands.", PLUGIN_PREFIX);
	// CPrintToChatAll("%s{lightgreen}If you'd like to donate you can do it via {deepskyblue}PayPal {lightgreen}- {deepskyblue}mail@stefanpopp.de", PLUGIN_PREFIX);
	return Plugin_Continue;
}

/**
* SurfTimer core
*/
bool:StartTimer(client)
{
	if (! IsClientInGame(client) || ! IsPlayerAlive(client)) {
		return false;
	}
	
	if (g_timers[client][isEnabled]) {
		return false;
	}
	
	StopTimer(client);

	g_timers[client][isEnabled] = true;
	g_timers[client][startTime] = GetGameTime();
	g_timers[client][stageStartTime] = g_timers[client][startTime];
	g_timers[client][isStageEnabled] = true;
	g_timers[client][endTime] = -1.0;
	g_timers[client][stageEndTime] = -1.0;
	
	QueryClientConVar(client, "fps_max", SurfTimer_fpsMaxCallback, client);
	
	return true;
}

bool:StartStageTimer(client) 
{
	if (! IsClientInGame(client) || ! IsPlayerAlive(client)) {
		return false;
	}
	
	if (! g_timers[client][isEnabled]) {
		return false;
	}
	
	g_timers[client][stageStartTime] = GetGameTime();
	g_timers[client][stageEndTime] = -1.0;
	g_timers[client][isStageEnabled] = true;
	
	return true;
}

bool:StopTimer(client)
{

	if (! g_timers[client][isEnabled]) {
		return false;
	}
	
	g_timers[client][endTime] = GetGameTime();
	
	StopStageTimer(client);
	
	g_timers[client][isEnabled] = false;
	g_timers[client][isStageEnabled] = false;
	g_timers[client][stageEndTime] = g_timers[client][endTime];
	g_timers[client][lastZoneId] = 0;
	g_timers[client][lastZoneType] = End;

	return true;
}

bool:StopStageTimer(client)
{
	if (! g_timers[client][isStageEnabled] || ! g_timers[client][isEnabled]) {
		return false;
	}
	
	g_timers[client][stageEndTime] = GetGameTime();
	g_timers[client][isStageEnabled] = false;
	return true;
}


public SurfTimer_fpsMaxCallback(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[])
{
	g_timers[client][fpsMax] = StringToInt(cvarValue);
}

SurfTimer_clientDidEnterZone(client, ZoneType:type, orderId, zoneId = 0)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client)) {
		return;
	}

	new currentZoneId = g_timers[client][lastZoneId];
	new currentZoneType = g_timers[client][lastZoneType];
	g_timers[client][lastZoneId] = orderId;
	g_timers[client][lastZoneType] = type;

	// check if stage finish is plausible
	new bool:stagePlausible = true;
	if ( currentZoneId >= orderId) { // if player comes back to an old stage
		stagePlausible = false;
	} else if (currentZoneType == Start && orderId > 1) { // if player is on start zone and hits higher stage then 1
		stagePlausible = false;
	} else if ((currentZoneId+1) != orderId) { // if currentzone is higher then new orderid-1	
		stagePlausible = false;
	}

	if (orderId == 0 
		&& type == End 
		&& currentZoneId > 0
		&& currentZoneType == Checkpoint) {
		stagePlausible = true;
	}

	if (type == End && g_timers[client][isEnabled]) {
		StopTimer(client);
		FinishRound(client);
		if (stagePlausible) {
			FinishStage(client, zoneId, orderId, true);
		}
		CS_SetClientClanTag(client, "[End]");
	} else if (type == Start) {
		StopTimer(client);
		CS_SetClientClanTag(client, "[Start]");
	} else if (type == Glitch) {
		
	} else if (type == Checkpoint) {
		StopStageTimer(client);
		if (stagePlausible) {
			FinishStage(client, zoneId, orderId);
		}
		decl String:stageString[32];
		Format(stageString, sizeof(stageString), "[Stage %d]", (g_timers[client][lastZoneId]+1));
		CS_SetClientClanTag(client, stageString);
	}
}

SurfTimer_clientDidLeftZone(client, ZoneType:type, orderId, zoneId = 0)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client)) {
		return;
	}

	g_timers[client][lastZoneId] = orderId;
	g_timers[client][lastZoneType] = type;

	if (type == Start) {
		StartTimer(client);
		CS_SetClientClanTag(client, "[Stage 1]");
	} else if (type == End) {
		g_timers[client][lastZoneType] = Somewhere;
		g_timers[client][lastZoneId] = 0;
		CS_SetClientClanTag(client, "[End]");
	} else if (type == Checkpoint) {
		StartStageTimer(client);
		decl String:stageString[32];
		Format(stageString, sizeof(stageString), "[Stage %d]", (g_timers[client][lastZoneId]+1));
		CS_SetClientClanTag(client, stageString);
	}
}

FinishRound(client)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client)) {
		return;
	}
	
	new Float:playerTime = CalculateTime(client);

	decl String:authName[AUTHID_MAX]; 
	decl String:playerName[USERNAME_MAX];
	GetClientAuthString(client, authName, sizeof(authName));
	GetClientName(client, playerName, sizeof(playerName));

	SurfTimerRank_playerDidFinish(client, playerName, authName, playerTime);
}


FinishStage(client, stageId, orderId, bool:override = false)
{
	if (! IsClientInGame(client) || ! IsPlayerAlive(client)) {
		return;
	}

	if (! g_timers[client][isEnabled] && ! override) {
		return;
	}
	
	new Float:playerTime = CalculateStageTime(client);

	decl String:authName[AUTHID_MAX]; 
	decl String:playerName[USERNAME_MAX];
	GetClientAuthString(client, authName, sizeof(authName));
	GetClientName(client, playerName, sizeof(playerName));

	SurfTimerRank_playerDidFinishStage(client, playerName, authName, playerTime, stageId, orderId);
}

/**
*
* Surf timer natives
*
*/

public Native_SurfTimer_FinishRound(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	FinishRound(client);
}

public Native_SurfTimerClientTimer(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	SetNativeCellRef(2, g_timers[client][isEnabled]);
	SetNativeCellRef(3, CalculateTime(client));
	SetNativeCellRef(4, g_timers[client][fpsMax]);
	SetNativeCellRef(5, g_timers[client][lastZoneType]);
	SetNativeCellRef(6, g_timers[client][lastZoneId]);
	SetNativeCellRef(7, CalculateStageTime(client));
	SetNativeCellRef(8, g_timers[client][isStageEnabled]);
	return true;
}

public Native_SurfTimer_clientEnterZone(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new ZoneType:zone = GetNativeCell(2);
	new orderId = GetNativeCell(3);
	new zoneId = GetNativeCell(4);
	SurfTimer_clientDidEnterZone(client, zone, orderId, zoneId);
	return true;
}

public Native_SurfTimer_clientLeftZone(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new ZoneType:zone = GetNativeCell(2);
	new orderId = GetNativeCell(3);
	new zoneId = GetNativeCell(4);
	SurfTimer_clientDidLeftZone(client, zone, orderId, zoneId);
	return true;
}

public Native_SurfTimer_clientStopTimer(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	StopTimer(client);
	return true;
}

public Native_SurfTimer_killallTimer(Handle:plugin, numParams)
{
	for (new i = 1; i < MAXPLAYERS; i++) {
		StopTimer(i);
	}
}

Float:CalculateTime(client)
{
	return (g_timers[client][isEnabled] ? GetGameTime() : g_timers[client][endTime]) - g_timers[client][startTime];
}

Float:CalculateStageTime(client)
{
	return (g_timers[client][isEnabled] ? GetGameTime() : g_timers[client][stageEndTime]) - g_timers[client][stageStartTime];
}
