#pragma semicolon 1 
#include <sourcemod> 
#include <sdktools>
#include <sdkhooks> 

// public StartTouchTrigger(const String:name[], caller, activator, Float:delay) 
// {   
// 	decl String:TriggerName[32]; 
// 	GetEntPropString(caller, Prop_Data, "m_iName", TriggerName, sizeof(TriggerName)); 
// 	new Float:flPosition[3];
// 	GetEntPropVector(caller, Prop_Send, "m_vecOrigin", flPosition);
// 	PrintToChat(activator, "Start Touched %s %s (%f %f %f)", TriggerName, name, flPosition[0], flPosition[1], flPosition[2]);
// } 

// public EndTouchTrigger(const String:name[], caller, activator, Float:delay) 
// {
// 	decl String:TriggerName[32]; 
// 	GetEntPropString(caller, Prop_Data, "m_iName", TriggerName, sizeof(TriggerName)); 
// 	new Float:flPosition[3];
// 	GetEntPropVector(caller, Prop_Send, "m_vecOrigin", flPosition);
// 	PrintToChat(activator, "End Touched %s %s (%f %f %f)", TriggerName, name, flPosition[0], flPosition[1], flPosition[2]);
// }  

public OnPluginStart() 
{ 
	RegAdminCmd("sm_tele", Teleport_User, ADMFLAG_KICK, "sm_tele x y z");
}

public Action:Teleport_User(client, args)
{
	if (args < 3)
	{
		ReplyToCommand(client, "[SM] Usage: sm_tele x y z");
		return Plugin_Handled;
	}

	new Float:origin[3];
	CmdArgsToVector(origin);
	ShowActivity(client, "teleported");
	TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);

	return Plugin_Handled;
}

CmdArgsToVector(Float:angles[3])
{
  new String:buffer[32];
  GetCmdArg(1, buffer, sizeof(buffer));
  angles[0] = StringToFloat(buffer);
  GetCmdArg(2, buffer, sizeof(buffer));
  angles[1] = StringToFloat(buffer);
  GetCmdArg(3, buffer, sizeof(buffer));
  angles[2] = StringToFloat(buffer);
}


public Plugin:SurfTimerTest =  
{ 
	name = "[SurfTimer-TestSuite]", 
	author = "Stefan Popp", 
	description = "", 
	version = "1.0", 
	url = "" 
};  
