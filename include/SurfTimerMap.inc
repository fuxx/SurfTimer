#pragma semicolon 1

#if defined _surfTimerMap_included
  #endinput
#endif
#define _surfTimerMap_included

#include <sourcemod>

#include <adminmenu>
#include <cstrike>
#include <sdktools>
#include <smlib/arrays>

native bool:SurfTimerMap_reloadInfo();
native bool:SurfTimerMap_hasStages(&bool:hasStages);
native bool:SurfTimerMap_stageCount(&stageCount);


public __pl_surfTimerMap_SetNTVOptional()
{
	MarkNativeAsOptional("SurfTimerMap_reloadInfo");
	MarkNativeAsOptional("SurfTimerMap_hasStages");
	MarkNativeAsOptional("SurfTimerMap_stageCount");
}
