#pragma semicolon 1

#if defined _surfTimerZones_included
  #endinput
#endif
#define _surfTimerZones_included

#include <sourcemod>

#include <adminmenu>
#include <cstrike>
#include <sdktools>
#include <smlib/arrays>

native bool:SurfTimerZones_teleportPlayer(client, bool:toStart=false);
native bool:SurfTimerZones_teleportPlayerToStage(client, stage, bool:practice=true);
native bool:SurfTimerZones_isMapEnabled();
native bool:SurfTimerZones_reloadMap();
native bool:SurfTimerZones_setMapEnabled(bool:enabled);


public __pl_surfTimerZones_SetNTVOptional()
{
	MarkNativeAsOptional("SurfTimerZones_teleportPlayer");
	MarkNativeAsOptional("SurfTimerZones_teleportPlayerToStage");
	MarkNativeAsOptional("SurfTimerZones_isMapEnabled");
	MarkNativeAsOptional("SurfTimerZones_reloadMap");
	MarkNativeAsOptional("SurfTimerZones_setMapEnabled");
}
