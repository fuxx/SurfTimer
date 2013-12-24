#pragma semicolon 1

#if defined _surfTimerRank_included
  #endinput
#endif
#define _surfTimerRank_included

#include <sourcemod>

#include <adminmenu>
#include <cstrike>
#include <sdktools>
#include <smlib/arrays>


#define MAPNAME_MAX 48
#define AUTHID_MAX	64
#define USERNAME_MAX 128


native bool:SurfTimerRank_playerDidFinish(client, const String:playerName[USERNAME_MAX], const String:authName[AUTHID_MAX], Float:playerTime);
native bool:SurfTimerRank_playerDidFinishStage(client, const String:playerName[USERNAME_MAX], const String:authName[AUTHID_MAX], Float:playerTime, stageId, orderId);
native bool:SurfTimer_currentWRData(client, &Float:time);
native bool:SurfTimer_currentStageWRData(client, &Float:time, stage);
native bool:SurfTimerRank_SurfTimer_stageCount(&stageCount);
native bool:SurfTimer_reloadStats();

public __pl_surfTimerRank_SetNTVOptional()
{
	MarkNativeAsOptional("SurfTimerRank_playerDidFinish");
	MarkNativeAsOptional("SurfTimerRank_playerDidFinishStage");
	MarkNativeAsOptional("SurfTimerRank_SurfTimer_stageCount");
	MarkNativeAsOptional("SurfTimer_currentWRData");
	MarkNativeAsOptional("SurfTimer_currentStageWRData");
	MarkNativeAsOptional("SurfTimer_reloadStats");
}
