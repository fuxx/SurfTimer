#pragma semicolon 1

#include <sourcemod>
#include <smlib>
#include <sdkhooks>
#include <morecolors>

#include <SurfTimerConfig>

#if defined _surfTimers_included
  #endinput
#endif
#define _surfTimers_included

#define MAPNAME_MAX 48
#define AUTHID_MAX	64
#define USERNAME_MAX 128

enum ZoneType
{
	Somewhere = 0,
	Start,
	Checkpoint,
	End,
	Bonus_start,
	Bonus_checkpoint,
	Bonus_end,
	Glitch,
}
// new String:g_zoneTypeName[8][40];
native bool:SurfTimer_clientTimer(client, &enabled, &Float:time, &fpsmax, &zoneType = 0, &zoneId = 0, &Float:stageTime = 0, &bool:isStageEnabled = false);
native bool:SurfTimer_clientEnterZone(client, ZoneType:zone, orderId, zoneId = 0);
native bool:SurfTimer_clientLeftZone(client, ZoneType:zone, orderId, zoneId = 0);
native bool:SurfTimer_clientStopTimer(client);
native bool:SurfTimer_FinishRound(client);
native bool:SurfTimer_killallTimer();

public SharedPlugin:__pl_surfTimer = 
{
	name = "SurfTimer",
	file = "SurfTimer.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

public __pl_surfTimer_SetNTVOptional()
{
	MarkNativeAsOptional("SurfTimer_clientTimer");
	MarkNativeAsOptional("SurfTimer_clientEnterZone");
	MarkNativeAsOptional("SurfTimer_clientLeftZone");
	MarkNativeAsOptional("SurfTimer_clientStopTimer");
	MarkNativeAsOptional("SurfTimer_FinishRound");
	MarkNativeAsOptional("SurfTimer_killallTimer");
}

stock SurfTimer_secondsToTime(Float:seconds, String:buffer[], maxlength, bool:precision = true)
{
	new t = RoundToFloor(seconds);
	
	new hour, mins;
	
	if (t >= 3600) {
		hour = RoundToFloor(t / 3600.0);
		t %= 3600;
	}
	
	if (t >= 60) {
		mins = RoundToFloor(t / 60.0);
		t %= 60;
	}

	Format(buffer, maxlength, "");

	if (hour) {
		Format(buffer, maxlength, "%s%02d:", buffer, hour);
	}
	
	Format(buffer, maxlength, "%s%02d:", buffer, mins);
	
	if (precision) {
		Format(buffer, maxlength, "%s%06.3f", buffer, float(t) + seconds - RoundToFloor(seconds));
	} else {
		Format(buffer, maxlength, "%s%02d", buffer, t);
	}
}

stock StringToLower(String:f_sInput[])
{
	new f_iSize = strlen(f_sInput);
	for(new i=0;i<f_iSize;i++) {
		f_sInput[i] = CharToLower(f_sInput[i]);
	}
}

stock CenterOfTwoVectors(Float:resultArray[], const Float:vecOne[], const Float:vecTwo[]) 
{
	resultArray[0] = (vecOne[0] + vecTwo[0]) / 2.0;
	resultArray[1] = (vecOne[1] + vecTwo[1]) / 2.0;
	resultArray[2] = (vecOne[2] + vecTwo[2]) / 2.0;
}

stock TransformCoordinatesToLocalSpace(Float:resultArray[], const Float:origin[], const Float:vector[])
{
	resultArray[0] = origin[0] - vector[0]; // x
	resultArray[1] = origin[1] - vector[1]; // y
	resultArray[2] = origin[2] - vector[2]; // z


}

stock MinMaxVector(Float:vecOne[], Float:vecTwo[])
{
	new Float:minTemp[3], Float:maxTemp[3];
	Array_Copy(vecOne, minTemp, sizeof(minTemp));
	Array_Copy(vecTwo, maxTemp, sizeof(maxTemp));
	
	for (new i = 0; i < 3; i++) {
		minTemp[i] = Math_Max(vecOne[i], vecTwo[i]);
		maxTemp[i] = Math_Min(vecOne[i], vecTwo[i]);
	}
	Array_Copy(minTemp, vecOne, sizeof(minTemp));
	Array_Copy(maxTemp, vecTwo, sizeof(maxTemp));
}

stock PrintVec3(Float:vector[])
{
	PrintToServer("[SurfTimer] DEBUG - Vector 3 - x: %f y: %f z: %f", vector[0], vector[1], vector[2]);
}

stock KillTimerWithHandleCheck(Handle:timer)
{
	if (timer != INVALID_HANDLE) {
		KillTimer(timer, false);
	}
}

