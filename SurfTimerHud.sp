#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <SurfTimer>
#include <SurfTimerRank>
#include <SurfTimerMap>

new String:g_sCurrentMap[MAPNAME_MAX];

new Handle:g_hCvarUpdateTime = INVALID_HANDLE;

#define SPECMODE_NONE 				0
#define SPECMODE_FIRSTPERSON 		4
#define SPECMODE_3RDPERSON 			5
#define SPECMODE_FREELOOK	 		6

public Plugin:myinfo =
{
	name = "[SurfTimer]-HUD",
	author = "Fuxx",
	description = "The ultimative HUD for SurfTimer by Fuxx",
	version = PLUGIN_VERSION,
	url = "http://www.stefanpopp.de"
};

public OnPluginStart()
{
	PrintToServer("[SurfTimer-HUD] %s loaded...", PLUGIN_URL);
	g_hCvarUpdateTime = CreateConVar("surf_update_time", "0.2", "1 / 0.25 means 4 times per second.", 0, true, 0.1);
}

public OnMapStart() 
{
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
	StringToLower(g_sCurrentMap);
	
	PrecacheSound("UI/hint.wav");
	
	CreateTimer(GetConVarFloat(g_hCvarUpdateTime), SurfTimer_HUDTimer, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public OnMapEnd()
{
	
}

public Action:SurfTimer_HUDTimer(Handle:timer)
{
	for (new client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client) 
			&& !IsClientSourceTV(client) 
			&& !IsClientReplay(client)) {
			SurfTimerUpdateHUD(client);
		}
	}

	return Plugin_Continue;
}

SurfTimerUpdateHUD(client)
{
	new target = client;
	new t;
	
	if (IsClientObserver(client)) {
		new observerMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

		if (observerMode == 4 || observerMode == 3) {
			t = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
			if (t > 0 && IsClientInGame(t) && !IsFakeClient(t)) {
				target = t;
			}
		}		
	}
	SurfTimerUpdateRightInfo(client, target, t);
	SurfTimerUpdateBottomInfo(client, target, t);
}

SurfTimerUpdateRightInfo(client, target, t) 
{
	new iSpecModeUser = GetEntProp(client, Prop_Send, "m_iObserverMode");
	new iSpecMode, iTarget, iTargetUser;
	new bool:bDisplayHint = false;

	decl String:szText[512];
	szText[0] = '\0';

	if (IsPlayerAlive(client)) {	
		for(new i = 1; i <= MaxClients; i++)  {
			if (!IsClientInGame(i) || !IsClientObserver(i) || IsClientSourceTV(i))
				continue;
				
			iSpecMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
			
			// The client isn't spectating any one person, so ignore them.
			if (iSpecMode != SPECMODE_FIRSTPERSON && iSpecMode != SPECMODE_3RDPERSON)
				continue;
			
			// Find out who the client is spectating.
			iTarget = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
			
			// Are they spectating our player?
			if (iTarget == client) {
				Format(szText, sizeof(szText), "%s%N\n", szText, i);
				bDisplayHint = true;
			}
		}

	} else if (iSpecModeUser == SPECMODE_FIRSTPERSON || iSpecModeUser == SPECMODE_3RDPERSON) {
		// Find out who the User is spectating.
		iTargetUser = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		
		if (iTargetUser > 0)
			Format(szText, sizeof(szText), "Spectating %N:\n", iTargetUser);
		
		for(new i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || !IsClientObserver(i) || IsClientSourceTV(i))
				continue;
				
			iSpecMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
			
			// The client isn't spectating any one person, so ignore them.
			if (iSpecMode != SPECMODE_FIRSTPERSON && iSpecMode != SPECMODE_3RDPERSON)
				continue;
			
			// Find out who the client is spectating.
			iTarget = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
			
			// Are they spectating the same player as User?
			if (iTarget == iTargetUser)
				Format(szText, sizeof(szText), "%s%N\n", szText, i);
		}
	}
	
	/* We do this to prevent displaying a message
		to a player if no one is spectating them anyway. */
	if (bDisplayHint) {
		Format(szText, sizeof(szText), "Spectating %N:\n%s", client, szText);
		bDisplayHint = false;
	}
		
	new time = 0;
	GetMapTimeLeft(time);
	new timeAbs = Math_Abs((time/60));
	decl String:timeleft[32];
	timeleft[0] = '\0';

	if (timeAbs < 1) {
		Format(timeleft, sizeof(timeleft), "Timeleft: %d seconds", time);
	} else if (timeAbs == 1) {
		Format(timeleft, sizeof(timeleft), "Timeleft: 1 minute");
	} else {
		Format(timeleft, sizeof(timeleft), "Timeleft: %d minutes", timeAbs);
	}
	
	Format(szText, sizeof(szText), "%s\n%s", timeleft, szText);




	// Send our message
	new Handle:hBuffer = StartMessageOne("KeyHintText", client); 
	BfWriteByte(hBuffer, 1); 
	BfWriteString(hBuffer, szText); 
	EndMessage();
}

SurfTimerUpdateBottomInfo(client, target, t)
{
	new bool:bEnabled, Float:fTime, iFpsMax, ZoneType:zoneType, zoneId, Float:fStageTime, bool:bStageEnabled;
	SurfTimer_clientTimer(target, bEnabled, fTime, iFpsMax, zoneType, zoneId, fStageTime, bStageEnabled);
	new Float:fRecordTime = 0.0;
	new Float:fRecordStageTime = 0.0;
	new stageCount = 0;

	SurfTimer_currentWRData(target, fRecordTime);
	SurfTimer_currentStageWRData(target, fRecordStageTime, zoneId+1);	
	SurfTimerMap_stageCount(stageCount);
	
	new String:sHintText[1024];
	if (bEnabled) {
		// Show zone when timer is active
		switch (zoneType) {
			case Start: 
			{
				Format(sHintText, sizeof(sHintText), "Surfing [Stage 1/%d]\n   ", stageCount);
			}
			case Checkpoint:
			{
				Format(sHintText, sizeof(sHintText), "Surfing [Stage %d/%d]\n   ", (zoneId+1), stageCount);
			}
			case Bonus_start:
			{
				Format(sHintText, sizeof(sHintText), "Surfing stage 1\n   ");
			}
			case Bonus_checkpoint:
			{
				Format(sHintText, sizeof(sHintText), "Surfing Bonus [Stage %d]\n   ", (zoneId+1));
			}
		}
		
		new String:sTimeString[128];
		new bool:isNegative = false;

		if (fRecordTime > 0) {
			new Float:difference = fTime - fRecordTime;
			if (difference <= 0) {
				difference = fRecordTime - fTime;
				isNegative = true;
			}
			decl String:sTimeDifference[32]; decl String:sTimeDifferenceString[48];

			SurfTimer_secondsToTime(fTime, sTimeString, sizeof(sTimeString), true);
			SurfTimer_secondsToTime(difference, sTimeDifference, sizeof(sTimeDifference), true);
			Format(sTimeDifferenceString, sizeof(sTimeDifferenceString), "(WR %s%s)", ((isNegative) ? "-" : "+"), sTimeDifference);

			Format(sHintText, sizeof(sHintText), "%s%s %s  ", sHintText, sTimeString, sTimeDifferenceString);
		} else {
			SurfTimer_secondsToTime(fTime, sTimeString, sizeof(sTimeString), true);
			Format(sHintText, sizeof(sHintText), "%s%s (No WR)   ", sHintText, sTimeString);
		}
			
		decl String:sStageTimeString[128];
		if (stageCount > 1) {
			if (bStageEnabled) {
				Format(sHintText, sizeof(sHintText), "%s\n[Stage-Time]\n  ", sHintText);
				if (fRecordStageTime > 0) {
					new Float:difference = fStageTime - fRecordStageTime;
					if (difference <= 0) {
						difference = fRecordStageTime - fStageTime;
						isNegative = true;
					}
					decl String:sTimeDifference[32]; decl String:sTimeDifferenceString[48];

					SurfTimer_secondsToTime(fStageTime, sTimeString, sizeof(sTimeString), true);
					SurfTimer_secondsToTime(difference, sTimeDifference, sizeof(sTimeDifference), true);
					Format(sTimeDifferenceString, sizeof(sTimeDifferenceString), "(%s%s)", ((isNegative) ? "-" : "+"), sTimeDifference);

					Format(sHintText, sizeof(sHintText), "%s%s %s  ", sHintText, sTimeString, sTimeDifferenceString);
				} else {
					SurfTimer_secondsToTime(fStageTime, sTimeString, sizeof(sTimeString), true);
					Format(sHintText, sizeof(sHintText), "%s%s (No WR)   ", sHintText, sTimeString);
				}
			} else {
				Format(sHintText, sizeof(sHintText), "%s\n[Stage-Time]\n Leave zone to start   ", sHintText);
			}
		}
		


	} else if (Client_IsValid(client) && IsPlayerAlive(client)){ // if timer is disabled
		if (zoneType == Start) {
			Format(sHintText, sizeof(sHintText), "You're in the start zone  \nGo out to start surfin =) ", sHintText);
		} else if (zoneType == Somewhere) {
			Format(sHintText, sizeof(sHintText), "Go to the start zone\nor use !start to start surfin =)  ", sHintText);
		} else if (zoneType == End) {
			Format(sHintText, sizeof(sHintText), "Use !start to get back\nto the start zone =)  ", sHintText);
		} else if (zoneType == Bonus_start) {
			Format(sHintText, sizeof(sHintText), "You're in the bonus start zone  \nGo out to start surfin =) ", sHintText);
		} else if (zoneType == Bonus_end) {
			Format(sHintText, sizeof(sHintText), "Use !start to get back\nto the start zone =)  ", sHintText);
		} else if (zoneType == Checkpoint) {
			Format(sHintText, sizeof(sHintText), "Surfing [Stage %d/%d]\n[Practice mode]   ", (zoneId+1), stageCount);
		}
	}
	
	if (target == t) {
		decl String:sName[MAX_NAME_LENGTH];
		GetClientName(target, sName, sizeof(sName));
		
		if (bEnabled) {
			Format(sHintText, sizeof(sHintText), "%s\n", sHintText);
		}
		
		Format(sHintText, sizeof(sHintText), " %sPlayer: %s    ", sHintText, sName);
	}
	
	PrintHintText(client, sHintText);
	StopSound(client, SNDCHAN_STATIC, "UI/hint.wav");
}