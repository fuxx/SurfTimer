// #pragma semicolon 1

// #undef REQUIRE_PLUGIN
// #include <SurfTimer>

// new String:g_sCurrentMap[MAPNAME_MAX];

// public Plugin:myinfo =
// {
// 	name = "[SurfTimer]-NoJail",
// 	author = "Fuxx",
// 	description = "Removes jails from specific maps",
// 	version = PLUGIN_VERSION,
// 	url = "http://www.stefanpopp.de"
// };

// public OnPluginStart()
// {
// 	PrintToServer("[SurfTimer-NoJail] %s loaded...", PLUGIN_URL);	
// }

// public OnMapStart()
// {
// 	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
// 	StringToLower(g_sCurrentMap);

// 	if (0 ==strcmp("surf_2012_beta12", g_sCurrentMap, false)) {
// 		surf_2012_beta12();
// 	}

// }

// public OnMapEnd()
// {
	
// }

// public OnClientDisconnect(client)
// {
	
// }

// public OnClientPostAdminCheck(client)
// {
// 	// new String:authName[64];
// 	// GetClientAuthString(client, g_user[client][AuthName], sizeof(authName));
// }

// public RemoveEntityArrayWithClassname(const String:classname[], const String:nameArray[])
// {
// 	new index = -1;
// 	PrintToServer("[SurfTimer-NoJail] removing entites for class %s", classname);
// 	while ((index = FindEntityByClassname(index, classname)) != -1) {
// 		decl String:targetName[255];
// 		Entity_GetTargetName(index, targetName, sizeof(targetName));
// 		new count = sizeof(nameArray[]);

// 		PrintToServer("[SurfTimer-NoJail] Trying to remove %i objects", count);
// 		for (new i = 0; i < count; i++) {
// 			PrintToServer("[SurfTimer-NoJail] comparing %s against %s", targetName, nameArray[i]);
// 			if (0 == strcmp(targetName, nameArray[i], false)) {
// 				if (IsValidEntity(index)) {
// 					RemoveEdict(index);	
// 					PrintToServer("[SurfTimer-NoJail] Removed %s for class %s", targetName, classname);
// 				}
// 			}
// 		}
// 	}
// }

// public surf_2012_beta12()
// {
// 	PrintToServer("[SurfTimer-NoJail] Removing surf_2012_beta12 jails");
// 	// Logic relays
// 	decl String:relays[] = {"destruction_relay", "endgame_relay", "doors", "ct_win_relay", "t_win_relay", "no_win_relay"};
// 	RemoveEntityArrayWithClassname("trigger_teleport", relays);
// }